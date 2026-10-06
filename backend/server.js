const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const PORT = Number(process.env.PORT || 8787);
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const DB_PATH = process.env.DB_PATH || path.join(DATA_DIR, 'kakebo.sqlite');

fs.mkdirSync(DATA_DIR, { recursive: true });

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const TABLES = {
  monthPlans: 'month_plans',
  transactions: 'transactions',
  fixedExpenses: 'fixed_expenses',
  monthlyReflections: 'monthly_reflections',
};

const CATEGORY_VALUES = new Set(['survival', 'optional', 'culture', 'extra']);

function nowIso() {
  return new Date().toISOString();
}

function assertCategory(category) {
  if (!CATEGORY_VALUES.has(category)) {
    const error = new Error(`Invalid category: ${category}`);
    error.status = 400;
    throw error;
  }
}

function initDb() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS sync_clock (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      version INTEGER NOT NULL DEFAULT 0
    );

    INSERT OR IGNORE INTO sync_clock (id, version) VALUES (1, 0);

    CREATE TABLE IF NOT EXISTS month_plans (
      id TEXT PRIMARY KEY,
      month TEXT NOT NULL UNIQUE,
      expected_income REAL NOT NULL DEFAULT 0,
      savings_goal REAL NOT NULL DEFAULT 0,
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      sync_version INTEGER NOT NULL DEFAULT 0,
      device_id TEXT
    );

    CREATE TABLE IF NOT EXISTS fixed_expenses (
      id TEXT PRIMARY KEY,
      month_plan_id TEXT NOT NULL,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      category TEXT NOT NULL,
      due_day INTEGER,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      sync_version INTEGER NOT NULL DEFAULT 0,
      device_id TEXT,
      FOREIGN KEY(month_plan_id) REFERENCES month_plans(id)
    );

    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      month_plan_id TEXT NOT NULL,
      category TEXT NOT NULL,
      amount REAL NOT NULL,
      title TEXT NOT NULL,
      note TEXT,
      occurred_at TEXT NOT NULL,
      payment_method TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      sync_version INTEGER NOT NULL DEFAULT 0,
      device_id TEXT,
      FOREIGN KEY(month_plan_id) REFERENCES month_plans(id)
    );

    CREATE TABLE IF NOT EXISTS monthly_reflections (
      id TEXT PRIMARY KEY,
      month_plan_id TEXT NOT NULL UNIQUE,
      actual_savings REAL NOT NULL DEFAULT 0,
      reached_goal INTEGER NOT NULL DEFAULT 0,
      overspent_categories TEXT NOT NULL DEFAULT '[]',
      next_month_actions TEXT NOT NULL DEFAULT '',
      completed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      sync_version INTEGER NOT NULL DEFAULT 0,
      device_id TEXT,
      FOREIGN KEY(month_plan_id) REFERENCES month_plans(id)
    );

    CREATE INDEX IF NOT EXISTS idx_transactions_month_plan ON transactions(month_plan_id);
    CREATE INDEX IF NOT EXISTS idx_transactions_version ON transactions(sync_version);
    CREATE INDEX IF NOT EXISTS idx_fixed_expenses_month_plan ON fixed_expenses(month_plan_id);
    CREATE INDEX IF NOT EXISTS idx_month_plans_version ON month_plans(sync_version);
    CREATE INDEX IF NOT EXISTS idx_reflections_version ON monthly_reflections(sync_version);
  `);
}

function nextVersion() {
  const row = db.prepare('UPDATE sync_clock SET version = version + 1 WHERE id = 1 RETURNING version').get();
  return row.version;
}

function commonFields(input, existing = {}) {
  const timestamp = nowIso();
  return {
    created_at: input.createdAt || input.created_at || existing.created_at || timestamp,
    updated_at: input.updatedAt || input.updated_at || timestamp,
    deleted_at: input.deletedAt ?? input.deleted_at ?? null,
    device_id: input.deviceId || input.device_id || existing.device_id || null,
    sync_version: nextVersion(),
  };
}

function toCamel(row) {
  if (!row) return null;
  const mapped = {};
  for (const [key, value] of Object.entries(row)) {
    const camel = key.replace(/_([a-z])/g, (_, char) => char.toUpperCase());
    if (camel === 'isActive' || camel === 'reachedGoal') mapped[camel] = Boolean(value);
    else if (camel === 'overspentCategories') mapped[camel] = JSON.parse(value || '[]');
    else mapped[camel] = value;
  }
  return mapped;
}

function listRows(table, where = 'deleted_at IS NULL', params = []) {
  return db.prepare(`SELECT * FROM ${table} WHERE ${where} ORDER BY updated_at DESC`).all(...params).map(toCamel);
}

function getById(table, id) {
  return db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(id);
}

function upsertMonthPlan(input) {
  if (!input.id) throw Object.assign(new Error('id is required'), { status: 400 });
  if (!input.month) throw Object.assign(new Error('month is required'), { status: 400 });
  const existing = getById(TABLES.monthPlans, input.id) || {};
  const common = commonFields(input, existing);
  db.prepare(`
    INSERT INTO month_plans (id, month, expected_income, savings_goal, notes, created_at, updated_at, deleted_at, sync_version, device_id)
    VALUES (@id, @month, @expected_income, @savings_goal, @notes, @created_at, @updated_at, @deleted_at, @sync_version, @device_id)
    ON CONFLICT(id) DO UPDATE SET
      month = excluded.month,
      expected_income = excluded.expected_income,
      savings_goal = excluded.savings_goal,
      notes = excluded.notes,
      updated_at = excluded.updated_at,
      deleted_at = excluded.deleted_at,
      sync_version = excluded.sync_version,
      device_id = excluded.device_id
  `).run({
    id: input.id,
    month: input.month,
    expected_income: Number(input.expectedIncome ?? input.expected_income ?? 0),
    savings_goal: Number(input.savingsGoal ?? input.savings_goal ?? 0),
    notes: input.notes || null,
    ...common,
  });
  return toCamel(getById(TABLES.monthPlans, input.id));
}

function upsertFixedExpense(input) {
  if (!input.id || !input.monthPlanId) throw Object.assign(new Error('id and monthPlanId are required'), { status: 400 });
  assertCategory(input.category);
  const existing = getById(TABLES.fixedExpenses, input.id) || {};
  const common = commonFields(input, existing);
  db.prepare(`
    INSERT INTO fixed_expenses (id, month_plan_id, name, amount, category, due_day, is_active, created_at, updated_at, deleted_at, sync_version, device_id)
    VALUES (@id, @month_plan_id, @name, @amount, @category, @due_day, @is_active, @created_at, @updated_at, @deleted_at, @sync_version, @device_id)
    ON CONFLICT(id) DO UPDATE SET
      month_plan_id = excluded.month_plan_id,
      name = excluded.name,
      amount = excluded.amount,
      category = excluded.category,
      due_day = excluded.due_day,
      is_active = excluded.is_active,
      updated_at = excluded.updated_at,
      deleted_at = excluded.deleted_at,
      sync_version = excluded.sync_version,
      device_id = excluded.device_id
  `).run({
    id: input.id,
    month_plan_id: input.monthPlanId,
    name: input.name,
    amount: Number(input.amount || 0),
    category: input.category,
    due_day: input.dueDay ?? null,
    is_active: input.isActive === false ? 0 : 1,
    ...common,
  });
  return toCamel(getById(TABLES.fixedExpenses, input.id));
}

function upsertTransaction(input) {
  if (!input.id || !input.monthPlanId) throw Object.assign(new Error('id and monthPlanId are required'), { status: 400 });
  assertCategory(input.category);
  const existing = getById(TABLES.transactions, input.id) || {};
  const common = commonFields(input, existing);
  db.prepare(`
    INSERT INTO transactions (id, month_plan_id, category, amount, title, note, occurred_at, payment_method, created_at, updated_at, deleted_at, sync_version, device_id)
    VALUES (@id, @month_plan_id, @category, @amount, @title, @note, @occurred_at, @payment_method, @created_at, @updated_at, @deleted_at, @sync_version, @device_id)
    ON CONFLICT(id) DO UPDATE SET
      month_plan_id = excluded.month_plan_id,
      category = excluded.category,
      amount = excluded.amount,
      title = excluded.title,
      note = excluded.note,
      occurred_at = excluded.occurred_at,
      payment_method = excluded.payment_method,
      updated_at = excluded.updated_at,
      deleted_at = excluded.deleted_at,
      sync_version = excluded.sync_version,
      device_id = excluded.device_id
  `).run({
    id: input.id,
    month_plan_id: input.monthPlanId,
    category: input.category,
    amount: Number(input.amount || 0),
    title: input.title,
    note: input.note || null,
    occurred_at: input.occurredAt || input.occurred_at || nowIso(),
    payment_method: input.paymentMethod || input.payment_method || null,
    ...common,
  });
  return toCamel(getById(TABLES.transactions, input.id));
}

function upsertReflection(input) {
  if (!input.id || !input.monthPlanId) throw Object.assign(new Error('id and monthPlanId are required'), { status: 400 });
  const existing = getById(TABLES.monthlyReflections, input.id) || {};
  const common = commonFields(input, existing);
  db.prepare(`
    INSERT INTO monthly_reflections (id, month_plan_id, actual_savings, reached_goal, overspent_categories, next_month_actions, completed_at, created_at, updated_at, deleted_at, sync_version, device_id)
    VALUES (@id, @month_plan_id, @actual_savings, @reached_goal, @overspent_categories, @next_month_actions, @completed_at, @created_at, @updated_at, @deleted_at, @sync_version, @device_id)
    ON CONFLICT(id) DO UPDATE SET
      month_plan_id = excluded.month_plan_id,
      actual_savings = excluded.actual_savings,
      reached_goal = excluded.reached_goal,
      overspent_categories = excluded.overspent_categories,
      next_month_actions = excluded.next_month_actions,
      completed_at = excluded.completed_at,
      updated_at = excluded.updated_at,
      deleted_at = excluded.deleted_at,
      sync_version = excluded.sync_version,
      device_id = excluded.device_id
  `).run({
    id: input.id,
    month_plan_id: input.monthPlanId,
    actual_savings: Number(input.actualSavings ?? 0),
    reached_goal: input.reachedGoal ? 1 : 0,
    overspent_categories: JSON.stringify(input.overspentCategories || []),
    next_month_actions: input.nextMonthActions || '',
    completed_at: input.completedAt || null,
    ...common,
  });
  return toCamel(getById(TABLES.monthlyReflections, input.id));
}

function softDelete(table, id) {
  const version = nextVersion();
  const deletedAt = nowIso();
  const result = db.prepare(`UPDATE ${table} SET deleted_at = ?, updated_at = ?, sync_version = ? WHERE id = ?`).run(deletedAt, deletedAt, version, id);
  return result.changes > 0;
}

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));
app.use(morgan('tiny'));

app.get('/health', (_req, res) => {
  const version = db.prepare('SELECT version FROM sync_clock WHERE id = 1').get().version;
  res.json({ ok: true, service: 'kakebo-casaos', version: '1.0.0', serverVersion: version });
});

app.get('/api/kakebo/month', (req, res) => {
  const { month } = req.query;
  const rows = month
    ? listRows(TABLES.monthPlans, 'month = ? AND deleted_at IS NULL', [month])
    : listRows(TABLES.monthPlans);
  res.json({ data: rows });
});
app.post('/api/kakebo/month', (req, res) => res.status(201).json({ data: upsertMonthPlan(req.body) }));
app.put('/api/kakebo/month/:id', (req, res) => res.json({ data: upsertMonthPlan({ ...req.body, id: req.params.id }) }));
app.delete('/api/kakebo/month/:id', (req, res) => res.json({ deleted: softDelete(TABLES.monthPlans, req.params.id) }));

app.get('/api/kakebo/transactions', (req, res) => {
  const { monthPlanId } = req.query;
  const rows = monthPlanId
    ? listRows(TABLES.transactions, 'month_plan_id = ? AND deleted_at IS NULL', [monthPlanId])
    : listRows(TABLES.transactions);
  res.json({ data: rows });
});
app.post('/api/kakebo/transactions', (req, res) => res.status(201).json({ data: upsertTransaction(req.body) }));
app.put('/api/kakebo/transactions/:id', (req, res) => res.json({ data: upsertTransaction({ ...req.body, id: req.params.id }) }));
app.delete('/api/kakebo/transactions/:id', (req, res) => res.json({ deleted: softDelete(TABLES.transactions, req.params.id) }));

app.get('/api/kakebo/recurring', (req, res) => {
  const { monthPlanId } = req.query;
  const rows = monthPlanId
    ? listRows(TABLES.fixedExpenses, 'month_plan_id = ? AND deleted_at IS NULL', [monthPlanId])
    : listRows(TABLES.fixedExpenses);
  res.json({ data: rows });
});
app.post('/api/kakebo/recurring', (req, res) => res.status(201).json({ data: upsertFixedExpense(req.body) }));
app.put('/api/kakebo/recurring/:id', (req, res) => res.json({ data: upsertFixedExpense({ ...req.body, id: req.params.id }) }));
app.delete('/api/kakebo/recurring/:id', (req, res) => res.json({ deleted: softDelete(TABLES.fixedExpenses, req.params.id) }));

app.post('/api/sync', (req, res) => {
  const payload = req.body || {};
  const changes = payload.changes || {};
  const applied = { monthPlans: 0, transactions: 0, fixedExpenses: 0, monthlyReflections: 0 };

  const syncTx = db.transaction(() => {
    for (const item of changes.monthPlans || []) { upsertMonthPlan(item); applied.monthPlans += 1; }
    for (const item of changes.fixedExpenses || []) { upsertFixedExpense(item); applied.fixedExpenses += 1; }
    for (const item of changes.transactions || []) { upsertTransaction(item); applied.transactions += 1; }
    for (const item of changes.monthlyReflections || []) { upsertReflection(item); applied.monthlyReflections += 1; }
  });
  syncTx();

  const lastPulledVersion = Number(payload.lastPulledVersion || 0);
  const currentVersion = db.prepare('SELECT version FROM sync_clock WHERE id = 1').get().version;

  res.json({
    serverVersion: currentVersion,
    applied,
    changes: {
      monthPlans: listRows(TABLES.monthPlans, 'sync_version > ?', [lastPulledVersion]),
      fixedExpenses: listRows(TABLES.fixedExpenses, 'sync_version > ?', [lastPulledVersion]),
      transactions: listRows(TABLES.transactions, 'sync_version > ?', [lastPulledVersion]),
      monthlyReflections: listRows(TABLES.monthlyReflections, 'sync_version > ?', [lastPulledVersion]),
    },
  });
});

app.use((err, _req, res, _next) => {
  const status = err.status || 500;
  res.status(status).json({ error: err.message || 'Unexpected server error' });
});

initDb();

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Kakebo CasaOS API listening on http://0.0.0.0:${PORT}`);
  console.log(`SQLite database: ${DB_PATH}`);
});
