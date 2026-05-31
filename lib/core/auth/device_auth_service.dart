import 'dart:async';
import '../api/api_client.dart';

enum DeviceAuthStatus { pending, approved, rejected, expired }

class DeviceAuthResult {
  final String deviceCode;
  final String userCode;     // ex: "LION-4827"
  final String qrUrl;        // URL complète à encoder dans le QR
  final int expiresIn;       // secondes

  const DeviceAuthResult({
    required this.deviceCode,
    required this.userCode,
    required this.qrUrl,
    required this.expiresIn,
  });
}

class DeviceAuthService {
  final _api = ApiClient.instance;

  /// Initialise le device auth : retourne le code + QR URL.
  Future<DeviceAuthResult> init() async {
    final res = await _api.post<Map<String, dynamic>>('/api/auth/device/init');
    final data = res.data!;
    return DeviceAuthResult(
      deviceCode: data['deviceCode'] as String,
      userCode:   data['userCode']   as String,
      qrUrl:      data['qrUrl']      as String,
      expiresIn:  data['expiresIn']  as int? ?? 300,
    );
  }

  /// Poll toutes les [intervalSeconds] secondes jusqu'à approbation ou expiration.
  /// Émet les statuts intermédiaires via le stream.
  Stream<DeviceAuthStatus> poll(
    String deviceCode, {
    int intervalSeconds = 5,
  }) async* {
    while (true) {
      await Future.delayed(Duration(seconds: intervalSeconds));
      try {
        final res = await _api.get<Map<String, dynamic>>(
          '/api/auth/device/poll',
          params: {'device_code': deviceCode},
        );
        final status = res.data?['status'] as String? ?? 'pending';
        switch (status) {
          case 'approved':
            yield DeviceAuthStatus.approved;
            return;
          case 'rejected':
            yield DeviceAuthStatus.rejected;
            return;
          case 'expired':
            yield DeviceAuthStatus.expired;
            return;
          default:
            yield DeviceAuthStatus.pending;
        }
      } catch (_) {
        yield DeviceAuthStatus.pending;
      }
    }
  }
}
