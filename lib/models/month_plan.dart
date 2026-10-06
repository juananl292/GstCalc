import 'dart:convert';

class FixedExpense {
  final String id;
  final String monthPlanId;
  final String name;
  final double amount;
  final String category;
  final int? dueDay;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;
  final String deviceId;

  const FixedExpense({
    required this.id,
    required this.monthPlanId,
    required this.name,
    required this.amount,
    required this.category,
    this.dueDay,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncVersion = 0,
    required this.deviceId,
  });

  factory FixedExpense.fromJson(Map<String, dynamic> json) => FixedExpense(
        id: json['id'] as String,
        monthPlanId: json['monthPlanId'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        dueDay: json['dueDay'] as int?,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null ? null : DateTime.parse(json['deletedAt'] as String),
        syncVersion: json['syncVersion'] as int? ?? 0,
        deviceId: json['deviceId'] as String? ?? 'unknown-device',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'monthPlanId': monthPlanId,
        'name': name,
        'amount': amount,
        'category': category,
        'dueDay': dueDay,
        'isActive': isActive,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
        'syncVersion': syncVersion,
        'deviceId': deviceId,
      };
}

class MonthPlan {
  final String id;
  final String month;
  final double expectedIncome;
  final double savingsGoal;
  final String? notes;
  final List<FixedExpense> fixedExpenses;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;
  final String deviceId;

  const MonthPlan({
    required this.id,
    required this.month,
    required this.expectedIncome,
    required this.savingsGoal,
    this.notes,
    this.fixedExpenses = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncVersion = 0,
    required this.deviceId,
  });

  double get fixedExpensesTotal => fixedExpenses
      .where((expense) => expense.isActive && expense.deletedAt == null)
      .fold(0, (total, expense) => total + expense.amount);

  double get availableBudget => expectedIncome - fixedExpensesTotal - savingsGoal;

  factory MonthPlan.fromJson(Map<String, dynamic> json) => MonthPlan(
        id: json['id'] as String,
        month: json['month'] as String,
        expectedIncome: (json['expectedIncome'] as num).toDouble(),
        savingsGoal: (json['savingsGoal'] as num).toDouble(),
        notes: json['notes'] as String?,
        fixedExpenses: ((json['fixedExpenses'] as List<dynamic>?) ?? [])
            .map((item) => FixedExpense.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null ? null : DateTime.parse(json['deletedAt'] as String),
        syncVersion: json['syncVersion'] as int? ?? 0,
        deviceId: json['deviceId'] as String? ?? 'unknown-device',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'month': month,
        'expectedIncome': expectedIncome,
        'savingsGoal': savingsGoal,
        'notes': notes,
        'fixedExpenses': fixedExpenses.map((expense) => expense.toJson()).toList(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
        'syncVersion': syncVersion,
        'deviceId': deviceId,
      };

  String encode() => jsonEncode(toJson());

  static MonthPlan decode(String source) => MonthPlan.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
