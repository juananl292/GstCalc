import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class SyncPayload {
  final String deviceId;
  final int lastPulledVersion;
  final Map<String, List<Map<String, dynamic>>> changes;

  const SyncPayload({
    required this.deviceId,
    required this.lastPulledVersion,
    required this.changes,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'lastPulledVersion': lastPulledVersion,
        'changes': changes,
      };
}

class SyncResult {
  final int serverVersion;
  final Map<String, int> applied;
  final Map<String, List<Map<String, dynamic>>> changes;

  const SyncResult({
    required this.serverVersion,
    required this.applied,
    required this.changes,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    Map<String, List<Map<String, dynamic>>> decodeChanges(dynamic source) {
      final map = (source as Map<String, dynamic>? ?? {});
      return map.map((key, value) => MapEntry(
            key,
            (value as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
          ));
    }

    return SyncResult(
      serverVersion: json['serverVersion'] as int? ?? 0,
      applied: (json['applied'] as Map<String, dynamic>? ?? {}).map((key, value) => MapEntry(key, value as int)),
      changes: decodeChanges(json['changes']),
    );
  }
}

enum SyncStatus {
  offline,
  probing,
  syncing,
  synced,
  failed,
}

/// Offline-first sync coordinator for CasaOS LAN backup.
///
/// This service deliberately does not own the local database. Instead, the app
/// provides callbacks so the same service can be used with sqflite, Isar or a
/// repository abstraction.
class SyncService {
  final String deviceId;
  final String defaultBaseUrl;
  final http.Client _client;
  final Duration timeout;
  final ValueChangedSyncStatus? onStatusChanged;

  SyncService({
    required this.deviceId,
    this.defaultBaseUrl = 'http://192.168.50.72:3001',
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
    this.onStatusChanged,
  }) : _client = client ?? http.Client();

  Timer? _timer;
  SyncStatus _status = SyncStatus.offline;

  SyncStatus get status => _status;

  void startPeriodicSync({
    required Future<int> Function() readLastPulledVersion,
    required Future<Map<String, List<Map<String, dynamic>>>> Function() readPendingChanges,
    required Future<void> Function(SyncResult result) applyRemoteChanges,
    Duration interval = const Duration(minutes: 15),
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      syncOnce(
        readLastPulledVersion: readLastPulledVersion,
        readPendingChanges: readPendingChanges,
        applyRemoteChanges: applyRemoteChanges,
      );
    });
  }

  void stopPeriodicSync() {
    _timer?.cancel();
    _timer = null;
  }

  Future<SyncResult?> syncOnce({
    required Future<int> Function() readLastPulledVersion,
    required Future<Map<String, List<Map<String, dynamic>>>> Function() readPendingChanges,
    required Future<void> Function(SyncResult result) applyRemoteChanges,
    int maxAttempts = 3,
  }) async {
    _setStatus(SyncStatus.probing);
    final baseUrl = await discoverCasaOsBaseUrl();
    if (baseUrl == null) {
      _setStatus(SyncStatus.offline);
      return null;
    }

    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        _setStatus(SyncStatus.syncing);
        final payload = SyncPayload(
          deviceId: deviceId,
          lastPulledVersion: await readLastPulledVersion(),
          changes: await readPendingChanges(),
        );

        final response = await _client
            .post(
              Uri.parse('$baseUrl/api/sync'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload.toJson()),
            )
            .timeout(timeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('Sync failed with ${response.statusCode}: ${response.body}');
        }

        final result = SyncResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        await applyRemoteChanges(result);
        _setStatus(SyncStatus.synced);
        return result;
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1) * (attempt + 1)));
      }
    }

    _setStatus(SyncStatus.failed);
    stderr.writeln('Kakebo sync failed: $lastError');
    return null;
  }

  Future<String?> discoverCasaOsBaseUrl() async {
    final candidates = <String>[
      defaultBaseUrl,
      'http://192.168.50.72:8787',
      'http://casaos.local:8787',
      'http://kakebo-casaos.local:8787',
    ].toSet();

    for (final baseUrl in candidates) {
      if (await _isHealthy(baseUrl)) return baseUrl;
    }
    return null;
  }

  Future<bool> _isHealthy(String baseUrl) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/health')).timeout(timeout);
      if (response.statusCode != 200) return false;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['ok'] == true && json['service'] == 'kakebo-casaos';
    } catch (_) {
      return false;
    }
  }

  void _setStatus(SyncStatus next) {
    if (_status == next) return;
    _status = next;
    onStatusChanged?.call(next);
  }

  void dispose() {
    stopPeriodicSync();
    _client.close();
  }
}

typedef ValueChangedSyncStatus = void Function(SyncStatus status);
