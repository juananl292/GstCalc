import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/kakebo_category.dart';
import '../models/month_plan.dart';
import '../models/transaction.dart';
import '../views/reflection_wizard_view.dart';

class KakeboApi {
  KakeboApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? const String.fromEnvironment(
          'KAKEBO_API_BASE_URL',
          defaultValue: 'http://192.168.50.72:3001',
        )).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String baseUrl;
  static const _uuid = Uuid();
  static const deviceId = 'kakebo-windows';

  Future<void> checkHealth() async {
    final result = await _request('GET', '/health');
    if (result['ok'] != true || result['service'] != 'kakebo-casaos') {
      throw const KakeboApiException('El servidor respondió, pero no es la API de Kakebo.');
    }
  }

  Future<MonthPlan?> loadMonthPlan(String month) async {
    final plans = await _getList('/api/kakebo/month?month=${Uri.encodeQueryComponent(month)}');
    if (plans.isEmpty) return null;
    final json = plans.first;
    final planId = json['id'] as String;
    final recurring = await _getList(
      '/api/kakebo/recurring?monthPlanId=${Uri.encodeQueryComponent(planId)}',
    );
    return MonthPlan.fromJson({...json, 'fixedExpenses': recurring});
  }

  Future<List<KakeboTransaction>> loadTransactions(String monthPlanId) async {
    final rows = await _getList(
      '/api/kakebo/transactions?monthPlanId=${Uri.encodeQueryComponent(monthPlanId)}',
    );
    return rows.map(KakeboTransaction.fromJson).toList();
  }

  Future<MonthPlan> createMonthPlan({
    required String month,
    required double expectedIncome,
    required double savingsGoal,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    final response = await _request('POST', '/api/kakebo/month', body: {
      'id': _uuid.v4(),
      'month': month,
      'expectedIncome': expectedIncome,
      'savingsGoal': savingsGoal,
      'notes': notes,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'deviceId': deviceId,
    });
    final json = response['data'] as Map<String, dynamic>;
    return MonthPlan.fromJson({...json, 'fixedExpenses': <dynamic>[]});
  }

  Future<KakeboTransaction> createTransaction({
    required String monthPlanId,
    required KakeboCategory category,
    required String title,
    required double amount,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    final response = await _request('POST', '/api/kakebo/transactions', body: {
      'id': _uuid.v4(),
      'monthPlanId': monthPlanId,
      'category': category.key,
      'title': title,
      'amount': amount,
      'note': note,
      'occurredAt': now.toIso8601String(),
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'deviceId': deviceId,
    });
    return KakeboTransaction.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> saveReflection({
    required String monthPlanId,
    required MonthlyReflectionDraft draft,
  }) async {
    final now = DateTime.now().toUtc();
    await _request('POST', '/api/sync', body: {
      'deviceId': deviceId,
      'lastPulledVersion': 0,
      'changes': {
        'monthlyReflections': [
          {
            'id': 'reflection-$monthPlanId',
            'monthPlanId': monthPlanId,
            'actualSavings': draft.actualSavings,
            'reachedGoal': draft.reachedGoal,
            'overspentCategories': draft.overspentCategories.map((category) => category.key).toList(),
            'nextMonthActions': draft.nextMonthActions,
            'completedAt': now.toIso8601String(),
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
            'deviceId': deviceId,
          }
        ],
      },
    });
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final result = await _request('GET', path);
    return (result['data'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri).timeout(const Duration(seconds: 8));
        case 'POST':
          response = await _client
              .post(uri, headers: const {'Content-Type': 'application/json'}, body: jsonEncode(body))
              .timeout(const Duration(seconds: 8));
        default:
          throw ArgumentError.value(method, 'method', 'Método HTTP no admitido');
      }
    } on Exception catch (error) {
      throw KakeboApiException('No se pudo conectar con $baseUrl: $error');
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KakeboApiException(decoded['error'] as String? ?? 'Error HTTP ${response.statusCode}');
    }
    return decoded;
  }

  void dispose() => _client.close();
}

class KakeboApiException implements Exception {
  const KakeboApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
