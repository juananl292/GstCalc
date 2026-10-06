import 'dart:convert';

import 'kakebo_category.dart';

class KakeboTransaction {
  final String id;
  final String monthPlanId;
  final KakeboCategory category;
  final double amount;
  final String title;
  final String? note;
  final DateTime occurredAt;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;
  final String deviceId;

  const KakeboTransaction({
    required this.id,
    required this.monthPlanId,
    required this.category,
    required this.amount,
    required this.title,
    this.note,
    required this.occurredAt,
    this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncVersion = 0,
    required this.deviceId,
  });

  factory KakeboTransaction.fromJson(Map<String, dynamic> json) => KakeboTransaction(
        id: json['id'] as String,
        monthPlanId: json['monthPlanId'] as String,
        category: KakeboCategoryX.fromJson(json['category'] as String),
        amount: (json['amount'] as num).toDouble(),
        title: json['title'] as String,
        note: json['note'] as String?,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        paymentMethod: json['paymentMethod'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null ? null : DateTime.parse(json['deletedAt'] as String),
        syncVersion: json['syncVersion'] as int? ?? 0,
        deviceId: json['deviceId'] as String? ?? 'unknown-device',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'monthPlanId': monthPlanId,
        'category': category.key,
        'amount': amount,
        'title': title,
        'note': note,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'paymentMethod': paymentMethod,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
        'syncVersion': syncVersion,
        'deviceId': deviceId,
      };

  String encode() => jsonEncode(toJson());

  static KakeboTransaction decode(String source) {
    return KakeboTransaction.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }
}
