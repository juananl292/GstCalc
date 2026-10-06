import 'package:flutter/material.dart';

import 'models/kakebo_category.dart';
import 'models/month_plan.dart';
import 'models/transaction.dart';
import 'services/kakebo_api.dart';
import 'views/home_grid_view.dart';
import 'views/reflection_wizard_view.dart';

void main() => runApp(const KakeboApp());

class KakeboApp extends StatefulWidget {
  const KakeboApp({super.key});

  @override
  State<KakeboApp> createState() => _KakeboAppState();
}

class _KakeboAppState extends State<KakeboApp> {
  final KakeboApi _api = KakeboApi();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final String _month = _currentMonth();
  MonthPlan? _monthPlan;
  List<KakeboTransaction> _transactions = const [];
  bool _loading = true;
  String? _loadError;

  static String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await _api.checkHealth();
      final plan = await _api.loadMonthPlan(_month);
      final transactions = plan == null ? <KakeboTransaction>[] : await _api.loadTransactions(plan.id);
      if (!mounted) return;
      setState(() {
        _monthPlan = plan;
        _transactions = transactions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  void _showError(Object error) {
    final appContext = _navigatorKey.currentContext;
    if (!mounted || appContext == null) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(error.toString()), backgroundColor: Theme.of(appContext).colorScheme.error),
    );
  }

  Future<void> _startMonthPlan() async {
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null) return;
    final draft = await showDialog<_MonthPlanDraft>(
      context: dialogContext,
      builder: (context) => _MonthPlanDialog(month: _month),
    );
    if (draft == null) return;
    try {
      final plan = await _api.createMonthPlan(
        month: _month,
        expectedIncome: draft.expectedIncome,
        savingsGoal: draft.savingsGoal,
        notes: draft.notes,
      );
      if (!mounted) return;
      setState(() {
        _monthPlan = plan;
        _transactions = const [];
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _addTransaction(KakeboCategory category) async {
    final plan = _monthPlan;
    final dialogContext = _navigatorKey.currentContext;
    if (plan == null || dialogContext == null) return;
    final draft = await showDialog<_TransactionDraft>(
      context: dialogContext,
      builder: (context) => _TransactionDialog(category: category),
    );
    if (draft == null) return;
    try {
      final transaction = await _api.createTransaction(
        monthPlanId: plan.id,
        category: category,
        title: draft.title,
        amount: draft.amount,
        note: draft.note,
      );
      if (!mounted) return;
      setState(() => _transactions = [transaction, ..._transactions]);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openReflection() async {
    final plan = _monthPlan;
    final navigatorContext = _navigatorKey.currentContext;
    if (plan == null || navigatorContext == null) return;
    final draft = await Navigator.of(navigatorContext).push<MonthlyReflectionDraft>(
      MaterialPageRoute(
        builder: (_) => ReflectionWizardView(
          savingsGoal: plan.savingsGoal,
          onComplete: (draft) => Navigator.of(context).pop(draft),
        ),
      ),
    );
    if (draft == null) return;
    try {
      await _api.saveReflection(monthPlanId: plan.id, draft: draft);
      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Reflexión guardada en el backend.')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Kakebo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: _loading
          ? const _LoadingScreen()
          : _loadError != null
              ? _ConnectionErrorScreen(message: _loadError!, onRetry: _load)
              : HomeGridView(
                  monthPlan: _monthPlan,
                  transactions: _transactions,
                  onAddTransaction: _addTransaction,
                  onStartMonthPlan: _startMonthPlan,
                  onOpenReflection: _openReflection,
                ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Conectando con Kakebo…')],
          ),
        ),
      );
}

class _ConnectionErrorScreen extends StatelessWidget {
  const _ConnectionErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: 16),
                const Text('No se pudo conectar con el backend', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                SelectableText(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      );
}

class _MonthPlanDraft {
  const _MonthPlanDraft(this.expectedIncome, this.savingsGoal, this.notes);
  final double expectedIncome;
  final double savingsGoal;
  final String? notes;
}

class _MonthPlanDialog extends StatefulWidget {
  const _MonthPlanDialog({required this.month});
  final String month;

  @override
  State<_MonthPlanDialog> createState() => _MonthPlanDialogState();
}

class _MonthPlanDialogState extends State<_MonthPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _income = TextEditingController();
  final _savings = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _income.dispose();
    _savings.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? _parse(String? value) => double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Planificar ${widget.month}'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _income,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Ingresos previstos', suffixText: '€'),
                  validator: (value) => (_parse(value) == null || _parse(value)! < 0) ? 'Introduce un importe válido' : null,
                ),
                TextFormField(
                  controller: _savings,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Objetivo de ahorro', suffixText: '€'),
                  validator: (value) => (_parse(value) == null || _parse(value)! < 0) ? 'Introduce un importe válido' : null,
                ),
                TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Intención del mes (opcional)')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(context, _MonthPlanDraft(_parse(_income.text)!, _parse(_savings.text)!, _notes.text.trim()));
            },
            child: const Text('Guardar plan'),
          ),
        ],
      );
}

class _TransactionDraft {
  const _TransactionDraft(this.title, this.amount, this.note);
  final String title;
  final double amount;
  final String? note;
}

class _TransactionDialog extends StatefulWidget {
  const _TransactionDialog({required this.category});
  final KakeboCategory category;

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double? _parse(String? value) => double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Gasto · ${widget.category.label}'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: '¿En qué has gastado?'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Escribe una descripción' : null,
              ),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importe', suffixText: '€'),
                validator: (value) => (_parse(value) == null || _parse(value)! <= 0) ? 'Introduce un importe mayor que cero' : null,
              ),
              TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Nota (opcional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(context, _TransactionDraft(_title.text.trim(), _parse(_amount.text)!, _note.text.trim()));
            },
            child: const Text('Guardar gasto'),
          ),
        ],
      );
}
