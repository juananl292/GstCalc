import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/kakebo_category.dart';
import '../models/month_plan.dart';
import '../models/transaction.dart';

class HomeGridView extends StatelessWidget {
  final MonthPlan? monthPlan;
  final List<KakeboTransaction> transactions;
  final ValueChanged<KakeboCategory> onAddTransaction;
  final VoidCallback onStartMonthPlan;
  final VoidCallback onOpenReflection;

  const HomeGridView({
    super.key,
    required this.monthPlan,
    required this.transactions,
    required this.onAddTransaction,
    required this.onStartMonthPlan,
    required this.onOpenReflection,
  });

  @override
  Widget build(BuildContext context) {
    final plan = monthPlan;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Kakebo'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Reflexión mensual',
            onPressed: plan == null ? null : onOpenReflection,
            icon: const Icon(Icons.spa_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: plan == null
            ? _EmptyMonthPlan(onStartMonthPlan: onStartMonthPlan)
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    sliver: SliverToBoxAdapter(
                      child: _MonthBudgetHeader(
                        monthPlan: plan,
                        spentTotal: _spentTotal(transactions),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final oneColumn = constraints.crossAxisExtent < 340;
                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: oneColumn ? 1 : 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: oneColumn ? 1.35 : 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final category = KakeboCategory.values[index];
                              final spent = _spentByCategory(transactions, category);
                              final recommended = _recommendedRemaining(plan, transactions, category);
                              return _CategoryCard(
                                category: category,
                                spent: spent,
                                recommendedRemaining: recommended,
                                onAdd: () {
                                  HapticFeedback.lightImpact();
                                  onAddTransaction(category);
                                },
                              );
                            },
                            childCount: KakeboCategory.values.length,
                          ),
                        );
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverToBoxAdapter(
                      child: _RecentTransactions(transactions: transactions.take(5).toList()),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static double _spentTotal(List<KakeboTransaction> txs) {
    return txs.where((tx) => tx.deletedAt == null).fold(0, (sum, tx) => sum + tx.amount);
  }

  static double _spentByCategory(List<KakeboTransaction> txs, KakeboCategory category) {
    return txs
        .where((tx) => tx.deletedAt == null && tx.category == category)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  static double _recommendedRemaining(MonthPlan plan, List<KakeboTransaction> txs, KakeboCategory category) {
    final weights = {
      KakeboCategory.survival: 0.55,
      KakeboCategory.optional: 0.20,
      KakeboCategory.culture: 0.15,
      KakeboCategory.extra: 0.10,
    };
    final categoryBudget = plan.availableBudget * (weights[category] ?? 0.25);
    return categoryBudget - _spentByCategory(txs, category);
  }
}

class _MonthBudgetHeader extends StatelessWidget {
  final MonthPlan monthPlan;
  final double spentTotal;

  const _MonthBudgetHeader({required this.monthPlan, required this.spentTotal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = monthPlan.availableBudget - spentTotal;
    final progress = monthPlan.availableBudget <= 0 ? 0.0 : (spentTotal / monthPlan.availableBudget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.36),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ritual de ${monthPlan.month}', style: theme.textTheme.labelLarge),
          const SizedBox(height: 10),
          Text(_money(remaining), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('disponibles tras gastos fijos y ahorro', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 380 ? 2 : 3;
              final spacing = 16.0;
              final metricWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: [
                  SizedBox(width: metricWidth, child: _HeaderMetric(label: 'Gastado', value: _money(spentTotal))),
                  SizedBox(width: metricWidth, child: _HeaderMetric(label: 'Ahorro meta', value: _money(monthPlan.savingsGoal))),
                  SizedBox(width: metricWidth, child: _HeaderMetric(label: 'Fijos', value: _money(monthPlan.fixedExpensesTotal))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final KakeboCategory category;
  final double spent;
  final double recommendedRemaining;
  final VoidCallback onAdd;

  const _CategoryCard({
    required this.category,
    required this.spent,
    required this.recommendedRemaining,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = category.color;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: InkWell(
        onTap: onAdd,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 220 || constraints.maxHeight < 260) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: categoryColor.withOpacity(0.16), shape: BoxShape.circle),
                          child: Icon(category.icon, color: categoryColor, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(category.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              Text(category.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Gastado', style: theme.textTheme.labelSmall),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(_money(spent),
                                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Añadir gasto',
                              onPressed: onAdd,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            recommendedRemaining >= 0
                                ? 'Restan ${_money(recommendedRemaining)}'
                                : 'Exceso ${_money(recommendedRemaining.abs())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: recommendedRemaining >= 0 ? categoryColor : theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: categoryColor.withOpacity(0.16), shape: BoxShape.circle),
                    child: Icon(category.icon, color: categoryColor),
                  ),
                  const SizedBox(height: 14),
                  Text(category.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(category.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Text('Gastado', style: theme.textTheme.labelSmall),
                  Text(_money(spent), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    recommendedRemaining >= 0 ? 'Restan ${_money(recommendedRemaining)}' : 'Exceso ${_money(recommendedRemaining.abs())}',
                    style: theme.textTheme.labelMedium?.copyWith(color: recommendedRemaining >= 0 ? categoryColor : theme.colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: FilledButton.tonalIcon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Gasto'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final List<KakeboTransaction> transactions;

  const _RecentTransactions({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
        child: const Text('Aún no hay gastos registrados. Añade el primero desde una categoría.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Últimos movimientos', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...transactions.map((tx) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: tx.category.color.withOpacity(0.16),
                child: Icon(tx.category.icon, color: tx.category.color),
              ),
              title: Text(tx.title),
              subtitle: Text(tx.category.label),
              trailing: Text(_money(tx.amount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            )),
      ],
    );
  }
}

class _EmptyMonthPlan extends StatelessWidget {
  final VoidCallback onStartMonthPlan;

  const _EmptyMonthPlan({required this.onStartMonthPlan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 18),
            Text('Empieza tu ritual mensual', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'Registra ingresos, gastos fijos y objetivo de ahorro antes de gastar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onStartMonthPlan,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Planificar mes'),
            ),
          ],
        ),
      ),
    );
  }
}

String _money(double value) => '${value.toStringAsFixed(2)} €';
