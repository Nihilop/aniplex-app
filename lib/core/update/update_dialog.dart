import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/tv_button.dart';
import 'app_updater.dart';

class UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;
  const UpdateDialog({super.key, required this.release});

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
  _Phase  _phase    = _Phase.prompt;
  double  _progress = 0;
  String? _error;

  Future<void> _download() async {
    setState(() { _phase = _Phase.downloading; _progress = 0; _error = null; });
    try {
      await AppUpdater.downloadAndInstall(
        widget.release,
        onProgress: (p) { if (mounted) setState(() => _progress = p); },
      );
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
            _Phase.prompt      => _buildPrompt(),
            _Phase.downloading => _buildDownloading(),
            _Phase.error       => _buildError(),
          },
        ),
      ),
    );
  }

  Widget _buildPrompt() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(children: [
        Icon(Icons.system_update_rounded, color: AppTheme.primary, size: 28),
        SizedBox(width: 12),
        Text('Mise à jour disponible',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      Text('Version ${widget.release.version} est disponible.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
      if (widget.release.releaseNotes?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(8)),
          child: Text(widget.release.releaseNotes!.trim(),
              maxLines: 5, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.5)),
        ),
      ],
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TvButton(
            outlined: true,
            onTap: () => Navigator.of(context).pop(false),
            child: const Text('Plus tard',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          TvButton(
            autofocus: true,
            onTap: _download,
            child: const Text('Mettre à jour',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
      Text('Téléchargement… ${(_progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
      const SizedBox(height: 16),
      LinearProgressIndicator(
        value: _progress,
        backgroundColor: AppTheme.divider,
        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
        minHeight: 4,
        borderRadius: BorderRadius.circular(2),
      ),
      const SizedBox(height: 8),
      const Text('Ne ferme pas l\'application.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
    ],
  );

  Widget _buildError() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
      const SizedBox(height: 12),
      const Text('Échec du téléchargement',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(_error ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TvButton(
            outlined: true,
            onTap: () => Navigator.of(context).pop(false),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          TvButton(
            autofocus: true,
            onTap: _download,
            child: const Text('Réessayer',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ],
  );
}

enum _Phase { prompt, downloading, error }
