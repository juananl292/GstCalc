import 'package:flutter/material.dart';

import '../models/kakebo_category.dart';

class MonthlyReflectionDraft {
  final double actualSavings;
  final bool reachedGoal;
  final Set<KakeboCategory> overspentCategories;
  final String nextMonthActions;

  const MonthlyReflectionDraft({
    required this.actualSavings,
    required this.reachedGoal,
    required this.overspentCategories,
    required this.nextMonthActions,
  });
}

class ReflectionWizardView extends StatefulWidget {
  final double savingsGoal;
  final ValueChanged<MonthlyReflectionDraft> onComplete;

  const ReflectionWizardView({
    super.key,
    required this.savingsGoal,
    required this.onComplete,
  });

  @override
  State<ReflectionWizardView> createState() => _ReflectionWizardViewState();
}

class _ReflectionWizardViewState extends State<ReflectionWizardView> {
  final PageController _controller = PageController();
  final TextEditingController _savingsController = TextEditingController();
  final TextEditingController _actionsController = TextEditingController();
  final Set<KakeboCategory> _overspent = {};
  int _page = 0;
  bool? _reachedGoal;

  @override
  void dispose() {
    _controller.dispose();
    _savingsController.dispose();
    _actionsController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 3) {
      _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      widget.onComplete(
        MonthlyReflectionDraft(
          actualSavings: double.tryParse(_savingsController.text.replaceAll(',', '.')) ?? 0,
          reachedGoal: _reachedGoal ?? false,
          overspentCategories: _overspent,
          nextMonthActions: _actionsController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cierre de mes')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: LinearProgressIndicator(value: (_page + 1) / 4, minHeight: 8, borderRadius: BorderRadius.circular(999)),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  _StepShell(
                    title: '¿Cuánto dinero has conseguido ahorrar?',
                    subtitle: 'Anota el ahorro real sin juzgarlo. Este dato cierra el ciclo.',
                    child: TextField(
                      controller: _savingsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(prefixText: '€ ', labelText: 'Ahorro real'),
                    ),
                  ),
                  _StepShell(
                    title: '¿Has alcanzado tu objetivo de ahorro?',
                    subtitle: 'Tu objetivo era ${widget.savingsGoal.toStringAsFixed(2)} €.',
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Sí'), icon: Icon(Icons.check_rounded)),
                        ButtonSegment(value: false, label: Text('No'), icon: Icon(Icons.close_rounded)),
                      ],
                      selected: _reachedGoal == null ? <bool>{} : <bool>{_reachedGoal!},
                      emptySelectionAllowed: true,
                      onSelectionChanged: (values) => setState(() => _reachedGoal = values.isEmpty ? null : values.first),
                    ),
                  ),
                  _StepShell(
                    title: '¿En qué categorías has gastado más de lo planeado?',
                    subtitle: 'Selecciona solo las categorías que merecen atención el mes próximo.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: KakeboCategory.values.map((category) {
                        final selected = _overspent.contains(category);
                        return FilterChip(
                          selected: selected,
                          avatar: Icon(category.icon, size: 18, color: selected ? category.color : null),
                          label: Text(category.label),
                          onSelected: (value) => setState(() {
                            if (value) {
                              _overspent.add(category);
                            } else {
                              _overspent.remove(category);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  _StepShell(
                    title: '¿Qué acciones concretas tomarás el próximo mes?',
                    subtitle: 'Escribe compromisos observables, pequeños y accionables.',
                    child: TextField(
                      controller: _actionsController,
                      minLines: 5,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Cocinar tres cenas en casa, revisar suscripciones y fijar límite semanal de ocio.',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic),
                      child: const Text('Atrás'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_page == 3 ? 'Guardar reflexión' : 'Continuar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}

class _StepShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepShell({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 34),
          child,
        ],
      ),
    );
  }
}
