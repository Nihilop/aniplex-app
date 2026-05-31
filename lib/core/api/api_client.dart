import 'dart:io' show Platform;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBaseUrlKey = 'aniplex_base_url';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance!;

  final Dio _dio;
  final CookieJar _cookieJar; // CookieJar (base class) pour supporter les deux implémentations

  ApiClient._(this._dio, this._cookieJar);

  static Future<ApiClient> init() async {
    if (_instance != null) return _instance!;

    // Sur desktop (debug) : cookie jar en mémoire (pas de sqflite nécessaire).
    // Sur Android/TV : cookie jar persistant sur disque.
    final CookieJar cookieJar;
    if (_isDesktop) {
      cookieJar = CookieJar();
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      cookieJar = PersistCookieJar(
        storage: FileStorage('${appDir.path}/.cookies/'),
      );
    }

    final prefs   = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_kBaseUrlKey) ?? '';

    final dio = Dio(BaseOptions(
      baseUrl:        baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept':            'application/json',
        'X-Requested-With':  'XMLHttpRequest',
      },
    ));

    dio.interceptors.add(CookieManager(cookieJar));

    _instance = ApiClient._(dio, cookieJar);
    return _instance!;
  }

  // ── Config ────────────────────────────────────────────────────────

  String get baseUrl => _dio.options.baseUrl;
  bool   get hasBaseUrl => baseUrl.isNotEmpty;

  Future<void> setBaseUrl(String url) async {
    final normalized = url.trimRight().replaceAll(RegExp(r'/$'), '');
    _dio.options.baseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrlKey, normalized);
  }

  Future<void> clearSession() async {
    await _cookieJar.deleteAll();
  }

  // ── HTTP helpers ──────────────────────────────────────────────────

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? params}) =>
      _dio.get<T>(path, queryParameters: params);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) =>
      _dio.delete<T>(path);

  // ── Session cookie pour les players externes (ExoPlayer) ─────────

  /// Retourne le header Cookie à passer à VideoPlayerController
  /// pour que ExoPlayer puisse s'authentifier sur le serveur HLS.
  Future<Map<String, String>> getVideoHeaders() async {
    try {
      final uri     = Uri.parse(baseUrl);
      final cookies = await _cookieJar.loadForRequest(uri);
      if (cookies.isEmpty) return {};
      final cookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      return {'Cookie': cookieHeader};
    } catch (_) {
      return {};
    }
  }

  // ── Auth check ────────────────────────────────────────────────────

  Future<bool> isAuthenticated() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/aniplex/auth/me');
      return res.statusCode == 200 && res.data?['user'] != null;
    } catch (_) {
      return false;
    }
  }
}
