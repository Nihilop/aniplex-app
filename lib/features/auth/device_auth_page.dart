import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/auth/device_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/tv_button.dart';

/// Page d'authentification par device code (RFC 8628).
/// Affiche un QR code + userCode. Polle le serveur jusqu'à approbation.
class DeviceAuthPage extends StatefulWidget {
  const DeviceAuthPage({super.key});

  @override
  State<DeviceAuthPage> createState() => _DeviceAuthPageState();
}

class _DeviceAuthPageState extends State<DeviceAuthPage> {
  final _service = DeviceAuthService();

  DeviceAuthResult? _result;
  DeviceAuthStatus _status = DeviceAuthStatus.pending;
  StreamSubscription<DeviceAuthStatus>? _sub;
  bool _loading = true;
  String? _error;
  int _secondsLeft = 300;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.init();
      setState(() {
        _result = result;
        _secondsLeft = result.expiresIn;
        _loading = false;
      });
      _startCountdown();
      _startPolling(result.deviceCode);
    } catch (e) {
      setState(() {
        _error = 'Impossible d\'initialiser l\'authentification.\nVérifie la connexion au serveur.';
        _loading = false;
      });
    }
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 99999));
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  void _startPolling(String deviceCode) {
    _sub?.cancel();
    _sub = _service.poll(deviceCode).listen((status) {
      if (!mounted) return;
      setState(() => _status = status);
      if (status == DeviceAuthStatus.approved) {
        _countdown?.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.go('/home');
        });
      } else if (status == DeviceAuthStatus.rejected || status == DeviceAuthStatus.expired) {
        _countdown?.cancel();
      }
    });
  }

  String get _minutesLeft {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKeyEvent: (e) {
            // Allow re-init on expired/rejected with Back or B
            if (e is KeyDownEvent &&
                (_status == DeviceAuthStatus.expired ||
                 _status == DeviceAuthStatus.rejected) &&
                (e.logicalKey == LogicalKeyboardKey.goBack ||
                 e.logicalKey == LogicalKeyboardKey.escape)) {
              _init();
            }
          },
          child: Center(
            child: _loading
                ? const CircularProgressIndicator(color: AppTheme.primary)
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _init)
                    : _AuthView(
                        result: _result!,
                        status: _status,
                        minutesLeft: _minutesLeft,
                        secondsLeft: _secondsLeft,
                        onRetry: _init,
                      ),
          ),
        ),
      ),
    );
  }
}

class _AuthView extends StatelessWidget {
  final DeviceAuthResult result;
  final DeviceAuthStatus status;
  final String minutesLeft;
  final int secondsLeft;
  final VoidCallback onRetry;

  const _AuthView({
    required this.result,
    required this.status,
    required this.minutesLeft,
    required this.secondsLeft,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (status == DeviceAuthStatus.approved) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 64),
          const SizedBox(height: 16),
          const Text('Connecté !', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Redirection...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        ],
      );
    }

    if (status == DeviceAuthStatus.rejected) {
      return _StatusMessage(
        icon: Icons.cancel_rounded,
        iconColor: Colors.redAccent,
        title: 'Accès refusé',
        subtitle: 'La demande a été rejetée.',
        actionLabel: 'Réessayer',
        onAction: onRetry,
      );
    }

    if (status == DeviceAuthStatus.expired || secondsLeft <= 0) {
      return _StatusMessage(
        icon: Icons.timer_off_rounded,
        iconColor: Colors.orangeAccent,
        title: 'Code expiré',
        subtitle: 'Le code a expiré. Génère-en un nouveau.',
        actionLabel: 'Nouveau code',
        onAction: onRetry,
      );
    }

    // Pending — show QR + code
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // QR Code
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: result.qrUrl,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 48),
        // Instructions
        SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ANIPLEX',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Scanne le QR code avec ton téléphone',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                '2. Connecte-toi si nécessaire',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                '3. Confirme le code affiché ci-dessous',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              ),
              const SizedBox(height: 24),
              // User code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                child: Text(
                  result.userCode,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppTheme.textMuted, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Expire dans $minutesLeft',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textMuted,
                      value: null, // indeterminate (polling indicator)
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _StatusMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 56),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        const SizedBox(height: 24),
        TvButton(
          autofocus: true,
          onTap: onAction,
          child: Text(actionLabel,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}


class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, color: AppTheme.textMuted, size: 48),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 20),
        TvButton(
          autofocus: true,
          onTap: onRetry,
          child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
