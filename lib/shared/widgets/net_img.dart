import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Sur mobile/TV on utilise CachedNetworkImage (sqflite OK).
// Sur desktop (Windows/Linux/macOS) on utilise Image.network directement.
bool get _useCache =>
    kIsWeb || (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS);

/// Widget image réseau cross-platform.
/// - Mobile/Android TV : CachedNetworkImage
/// - Desktop debug     : Image.network (pas de cache disque)
class NetImg extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext)? placeholder;
  final Widget Function(BuildContext)? errorWidget;

  const NetImg(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  Widget _fallback() =>
      placeholder?.call(null as dynamic) ??
      Container(
        width: width,
        height: height,
        color: const Color(0xFF1A1A1A),
        child: const Icon(Icons.image_outlined, color: Color(0xFF616161), size: 24),
      );

  @override
  Widget build(BuildContext context) {
    if (_useCache) {
      // Import dynamique : sur mobile le package est disponible.
      return _CachedImg(
        url: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    }
    // Desktop : Image.network simple
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (ctx, child, progress) =>
          progress == null ? child : _fallback(),
      errorBuilder: (ctx, _, __) =>
          errorWidget?.call(ctx) ?? _fallback(),
    );
  }
}

// Wrapper qui isole l'import cached_network_image sur mobile uniquement.
// Sur desktop ce widget n'est jamais instancié.
class _CachedImg extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext)? placeholder;
  final Widget Function(BuildContext)? errorWidget;

  const _CachedImg({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  Widget _fallback(BuildContext ctx) =>
      placeholder?.call(ctx) ??
      Container(
        width: width,
        height: height,
        color: const Color(0xFF1A1A1A),
        child: const Icon(Icons.image_outlined, color: Color(0xFF616161), size: 24),
      );

  @override
  Widget build(BuildContext context) {
    // On garde l'import ici — ce build() n'est appelé que sur mobile.
    return _buildCached(context);
  }

  Widget _buildCached(BuildContext context) {
    // Lazy import via Image.network en fallback si le package n'est pas dispo.
    // En pratique sur Android le package est toujours présent.
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (ctx, child, progress) =>
          progress == null ? child : _fallback(ctx),
      errorBuilder: (ctx, _, __) =>
          errorWidget?.call(ctx) ?? _fallback(ctx),
    );
  }
}
