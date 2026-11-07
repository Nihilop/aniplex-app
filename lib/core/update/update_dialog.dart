import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/widgets/lumen_shell.dart';
import 'app_updater.dart';

/// Modal de mise à jour OTA — style Lumen, boutons focusables au d-pad.
class UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;
  const UpdateDialog({super.key, required this.release});

  static Future<bool> show(BuildContext context, ReleaseInfo release) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black87,
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
      backgroundColor: const Color(0xF21A1A1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: const BorderSide(color: AppTheme.borderFaint),
      ),
      child: SizedBox(
        width: 720,
        child: Padding(
          padding: const EdgeInsets.all(48),
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
        Icon(Icons.system_update_rounded, color: AppTheme.foreground, size: 40),
        SizedBox(width: 18),
        Text('Mise à jour disponible',
            style: TextStyle(color: AppTheme.foreground, fontSize: 36, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 16),
      Text('La version ${widget.release.version} est disponible.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 24)),
      if (widget.release.releaseNotes?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppTheme.materialLight, borderRadius: BorderRadius.circular(AppTheme.radiusThumb)),
          child: Text(widget.release.releaseNotes!.trim(),
              maxLines: 6, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 20, height: 1.5)),
        ),
      ],
      const SizedBox(height: 36),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PillButton(height: 62, label: 'Plus tard', onTap: () => Navigator.of(context).pop(false)),
          const SizedBox(width: 20),
          PillButton(height: 62, icon: Icons.download_rounded, label: 'Mettre à jour', autofocus: true, onTap: _download),
        ],
      ),
    ],
  );

  Widget _buildDownloading() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.download_rounded, color: AppTheme.foreground, size: 56),
      const SizedBox(height: 24),
      Text('Téléchargement… ${(_progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: AppTheme.foreground, fontSize: 26, fontWeight: FontWeight.w600)),
      const SizedBox(height: 24),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: _progress,
          backgroundColor: AppTheme.materialLight,
          valueColor: const AlwaysStoppedAnimation(AppTheme.foreground),
          minHeight: 8,
        ),
      ),
      const SizedBox(height: 14),
      const Text('Ne ferme pas l’application.', style: TextStyle(color: AppTheme.textMuted, fontSize: 20)),
    ],
  );

  Widget _buildError() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline_rounded, color: AppTheme.destructive, size: 56),
      const SizedBox(height: 18),
      const Text('Échec du téléchargement',
          style: TextStyle(color: AppTheme.foreground, fontSize: 26, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Text(_error ?? '', maxLines: 3, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 20), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PillButton(height: 62, label: 'Annuler', onTap: () => Navigator.of(context).pop(false)),
          const SizedBox(width: 20),
          PillButton(height: 62, icon: Icons.refresh_rounded, label: 'Réessayer', autofocus: true, onTap: _download),
        ],
      ),
    ],
  );
}

enum _Phase { prompt, downloading, error }
