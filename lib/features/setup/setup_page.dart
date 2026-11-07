import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/focus/tv_keys.dart';
import '../../ui/widgets/lumen_shell.dart';

/// Setup « Lumen » : saisie de l'URL via le **clavier natif** Android TV.
/// Le clavier est ouvert explicitement (`TextInput.show`) car le raccourci OK
/// global empêche le TextField de l'ouvrir seul.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  late final TextEditingController _ctrl;
  final _fieldFocus = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = ApiClient.instance.baseUrl;
    _ctrl = TextEditingController(text: current.isEmpty ? 'https://plex.streemkit.com' : current);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openKeyboard());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _openKeyboard() {
    if (!mounted) return;
    _fieldFocus.requestFocus();
    // Curseur en fin de texte.
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  Future<void> _confirm() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty || !url.startsWith('http') || url == 'https://') {
      setState(() => _error = 'URL invalide. Ex : https://mon-serveur.com');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.setBaseUrl(url);
      await ApiClient.instance.get<dynamic>('/api/aniplex/render-engine/ping');
      if (mounted) context.go('/auth');
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de joindre le serveur.\nVérifie l’URL et le réseau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.safeH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Aniplex', textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.foreground, fontSize: 72, fontWeight: FontWeight.w800, letterSpacing: -2)),
                const SizedBox(height: 10),
                const Text('Adresse du serveur', textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 26)),
                const SizedBox(height: 40),

                // OK sur le champ (ré)ouvre le clavier natif, avant le raccourci global.
                Focus(
                  canRequestFocus: false,
                  onKeyEvent: (_, e) {
                    if (e is! KeyDownEvent) return KeyEventResult.ignored;
                    if (TvKeys.isSelect(e.logicalKey)) {
                      _openKeyboard();
                      return KeyEventResult.handled;
                    }
                    // Flèche bas : fermer le clavier et descendre vers le bouton.
                    if (TvKeys.isDown(e.logicalKey)) {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                      FocusScope.of(context).focusInDirection(TraversalDirection.down);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _fieldFocus,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => _confirm(),
                    onTap: _openKeyboard,
                    style: const TextStyle(color: AppTheme.foreground, fontSize: 30, fontWeight: FontWeight.w500),
                    cursorColor: AppTheme.foreground,
                    decoration: InputDecoration(
                      hintText: 'https://mon-serveur.com',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 30),
                      filled: true,
                      fillColor: AppTheme.materialLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        borderSide: const BorderSide(color: AppTheme.borderFaint),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        borderSide: const BorderSide(color: AppTheme.borderFaint),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        borderSide: const BorderSide(color: AppTheme.foreground, width: 2),
                      ),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFE1192B), fontSize: 20)),
                ],

                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.center,
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: AppTheme.foreground),
                        )
                      : PillButton(
                          icon: Icons.arrow_forward_rounded,
                          label: 'Se connecter',
                          onTap: _confirm,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
