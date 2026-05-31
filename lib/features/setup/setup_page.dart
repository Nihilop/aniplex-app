import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/tv_focus_card.dart';

/// Première page au lancement si aucun serveur configuré.
/// L'utilisateur entre l'URL de son instance Aniplex (ex: http://192.168.1.10:3000)
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _controller = TextEditingController(text: 'http://');
  final _focusNode  = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final url = _controller.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() => _error = 'URL invalide. Ex: http://192.168.1.10:3000');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.setBaseUrl(url);
      // Vérification ping rapide
      await ApiClient.instance.get<dynamic>('/api/aniplex/render-engine/ping');
      if (mounted) context.go('/auth');
    } catch (_) {
      setState(() => _error = 'Impossible de joindre le serveur. Vérifie l\'URL et le réseau.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ANIPLEX',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entrez l\'adresse de votre serveur',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 40),
              // Champ URL
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (e) {
                    if (e is KeyDownEvent &&
                        (e.logicalKey == LogicalKeyboardKey.enter ||
                         e.logicalKey == LogicalKeyboardKey.select)) {
                      _confirm();
                    }
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'http://192.168.1.10:3000',
                      hintStyle: TextStyle(color: AppTheme.textMuted),
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
              ],
              const SizedBox(height: 24),
              TvFocusCard(
                onTap: _loading ? null : _confirm,
                borderRadius: 8,
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Continuer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
