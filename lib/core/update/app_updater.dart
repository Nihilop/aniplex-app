import 'dart:io' show Platform, Directory;
import 'package:dio/dio.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

// ── Config ────────────────────────────────────────────────────────────────────
// À adapter à ton dépôt GitHub.
const _kGithubOwner = 'nihilop';
const _kGithubRepo  = 'aniplex-app';
const _kApkAsset    = 'app-release.apk';

class ReleaseInfo {
  final String tagName;     // ex: "v1.2.0"
  final String version;     // ex: "1.2.0"
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

  /// Vérifie si une mise à jour est disponible.
  /// Retourne [ReleaseInfo] si une version plus récente existe, null sinon.
  /// Ne lance jamais d'exception — silencieux en cas d'erreur réseau.
  static Future<ReleaseInfo?> checkForUpdate() async {
    // Seulement sur Android
    if (!Platform.isAndroid) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      final current = _parseVersion(info.version);

      final res = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$_kGithubOwner/$_kGithubRepo/releases/latest',
      );
      final data = res.data!;
      final tagName = data['tag_name'] as String? ?? '';
      final latest  = _parseVersion(tagName.replaceFirst('v', ''));

      if (!_isNewer(latest, current)) return null;

      // Trouver l'asset APK
      final assets = (data['assets'] as List? ?? []);
      final asset  = assets.firstWhere(
        (a) => (a as Map<String, dynamic>)['name'] == _kApkAsset,
        orElse: () => null,
      );
      if (asset == null) return null;

      return ReleaseInfo(
        tagName:      tagName,
        version:      tagName.replaceFirst('v', ''),
        downloadUrl:  (asset as Map<String, dynamic>)['browser_download_url'] as String,
        releaseNotes: data['body'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Télécharge l'APK et lance l'installation système.
  /// [onProgress] reçoit 0.0 → 1.0.
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

    await OpenFile.open(path, type: 'application/vnd.android.package-archive');
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
