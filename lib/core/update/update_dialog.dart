import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'app_updater.dart';

/// Affiche un dialog TV-friendly pour proposer la mise à jour.
/// Gère le téléchargement + barre de progression inline.
class UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;

  const UpdateDialog({super.key, required this.release});

  /// Affiche le dialog ; retourne true si l'install a été lancée.
  static Future<bool> show(BuildContext context, ReleaseInfo release) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => UpdateDialog(release: release),
        ) ??
        false;
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _Phase _phase = _Phase.prompt;
  double _progress = 0;
  String? _error;

  Future<void> _download() async {
    setState(() { _phase = _Phase.downloading; _progress = 0; _error = null; });
    try {
      await AppUpdater.downloadAndInstall(
        widget.release,
        onProgress: (p) { if (mounted) setState(() => _progress = p); },
      );
      // L'installeur système prend le relais
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { _phase = _Phase.error; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: switch (_phase) {
            _Phase.prompt     => _buildPrompt(),
            _Phase.downloading => _buildDownloading(),
            _Phase.error      => _buildError(),
          },
        ),
      ),
    );
  }

  Widget _buildPrompt() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.system_update_rounded, color: AppTheme.primary, size: 28),
          const SizedBox(width: 12),
          Text(
            'Mise à jour disponible',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        'Version ${widget.release.version} est disponible.',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
      ),
      if (widget.release.releaseNotes != null && widget.release.releaseNotes!.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.release.releaseNotes!.trim(),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.5),
          ),
        ),
      ],
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _TvButton(
            label: 'Plus tard',
            outlined: true,
            onTap: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(width: 12),
          _TvButton(
            label: 'Mettre à jour',
            autofocus: true,
            onTap: _download,
          ),
        ],
      ),
    ],
  );

  Widget _buildDownloading() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.download_rounded, color: AppTheme.primary, size: 40),
      const SizedBox(height: 16),
      Text(
        'Téléchargement… ${(_progress * 100).toStringAsFixed(0)}%',
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
      ),
      const SizedBox(height: 16),
      LinearProgressIndicator(
        value: _progress,
        backgroundColor: AppTheme.divider,
        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
        minHeight: 4,
        borderRadius: BorderRadius.circular(2),
      ),
      const SizedBox(height: 8),
      const Text(
        'Ne ferme pas l\'application.',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
    ],
  );

  Widget _buildError() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
      const SizedBox(height: 12),
      const Text('Échec du téléchargement', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(_error ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TvButton(label: 'Annuler',  outlined: true, onTap: () => Navigator.of(context).pop(false)),
          const SizedBox(width: 12),
          _TvButton(label: 'Réessayer', autofocus: true, onTap: _download),
        ],
      ),
    ],
  );
}

enum _Phase { prompt, downloading, error }

class _TvButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final bool autofocus;

  const _TvButton({
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.autofocus = false,
  });

  @override
  State<_TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<_TvButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: widget.outlined
                ? Colors.transparent
                : (_focused ? AppTheme.primary.withOpacity(0.85) : AppTheme.primary),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.outlined
                  ? (_focused ? Colors.white : AppTheme.divider)
                  : (_focused ? Colors.white : Colors.transparent),
              width: 2,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.outlined
                  ? (_focused ? Colors.white : AppTheme.textSecondary)
                  : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
