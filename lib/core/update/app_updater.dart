import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

// ── Config ────────────────────────────────────────────────────────────────────
const _kGithubOwner = 'nihilop';
const _kGithubRepo  = 'aniplex-app';
const _kApkAsset    = 'app-release.apk';

const _installChannel = MethodChannel('com.aniplex.aniplex_tv/install');

class ReleaseInfo {
  final String tagName;
  final String version;
  final String downloadUrl;
  final String? releaseNotes;

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.downloadUrl,
    this.releaseNotes,
  });
}

class AppUpdater {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  ));

  /// Vérifie si une mise à jour est disponible. Silencieux en cas d'erreur.
  static Future<ReleaseInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;
    try {
      final info    = await PackageInfo.fromPlatform();
      final current = _parseVersion(info.version);

      final res  = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$_kGithubOwner/$_kGithubRepo/releases/latest',
      );
      final data    = res.data!;
      final tagName = data['tag_name'] as String? ?? '';
      final latest  = _parseVersion(tagName.replaceFirst('v', ''));

      if (!_isNewer(latest, current)) return null;

      final assets = (data['assets'] as List? ?? []);
      final asset  = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => a['name'] == _kApkAsset,
        orElse: () => {},
      );
      final url = asset['browser_download_url'] as String?;
      if (url == null || url.isEmpty) return null;

      return ReleaseInfo(
        tagName:      tagName,
        version:      tagName.replaceFirst('v', ''),
        downloadUrl:  url,
        releaseNotes: data['body'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Télécharge l'APK et déclenche l'installeur système Android.
  static Future<void> downloadAndInstall(
    ReleaseInfo release, {
    void Function(double)? onProgress,
  }) async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/aniplex-update.apk';

    await _dio.download(
      release.downloadUrl,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    await _installChannel.invokeMethod('installApk', {'path': path});
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<int> _parseVersion(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }

  static bool _isNewer(List<int> latest, List<int> current) {
    for (int i = 0; i < 3; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
  }
}
