import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final StringBuffer _input = StringBuffer('https://plex.streemkit.com');
  bool   _loading = false;
  String? _error;

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        final s = _input.toString();
        if (s.isNotEmpty) { _input.clear(); _input.write(s.substring(0, s.length - 1)); }
      } else if (key == 'https://') {
        if (!_input.toString().startsWith('https://')) {
          _input.clear(); _input.write('https://');
        }
      } else {
        _input.write(key);
      }
    });
  }

  Future<void> _confirm() async {
    final url = _input.toString().trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() => _error = 'URL invalide. Ex: http://192.168.1.10:3000');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.setBaseUrl(url);
      await ApiClient.instance.get<dynamic>('/api/aniplex/render-engine/ping');
      if (mounted) context.go('/auth');
    } catch (_) {
      setState(() => _error = 'Impossible de joindre le serveur.\nVérifie l\'URL et le réseau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Keyboard layout ────────────────────────────────────────────────────────
  static const _rows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'],
    ['k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't'],
    ['u', 'v', 'w', 'x', 'y', 'z', '.', ':', '-', '_'],
    ['https://', '⌫', '✓'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SizedBox(
          width: 680,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Logo ──────────────────────────────────────────────────────
              const Text(
                'ANIPLEX',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Adresse du serveur',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 24),

              // ── URL display ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _input.isEmpty ? 'http://' : _input.toString(),
                        style: TextStyle(
                          color: _input.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary,
                          fontSize: 20,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Curseur clignotant
                    const _Cursor(),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],

              const SizedBox(height: 20),

              // ── Keyboard ──────────────────────────────────────────────────
              _UrlKeyboard(
                rows: _rows,
                loading: _loading,
                onKey: _onKey,
                onConfirm: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── URL Keyboard ──────────────────────────────────────────────────────────────

class _UrlKeyboard extends StatelessWidget {
  final List<List<String>> rows;
  final bool loading;
  final void Function(String) onKey;
  final VoidCallback onConfirm;

  const _UrlKeyboard({
    required this.rows,
    required this.loading,
    required this.onKey,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              final isWide    = key == 'http://' || key == '⌫' || key == '✓';
              final isConfirm = key == '✓';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _UrlKey(
                  label: key,
                  wide: isWide,
                  confirm: isConfirm,
                  loading: isConfirm && loading,
                  autofocus: key == '1',
                  onTap: () {
                    if (isConfirm) onConfirm();
                    else onKey(key);
                  },
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _UrlKey extends StatefulWidget {
  final String label;
  final bool wide;
  final bool confirm;
  final bool loading;
  final bool autofocus;
  final VoidCallback onTap;

  const _UrlKey({
    required this.label,
    required this.onTap,
    this.wide    = false,
    this.confirm = false,
    this.loading = false,
    this.autofocus = false,
  });

  @override
  State<_UrlKey> createState() => _UrlKeyState();
}

class _UrlKeyState extends State<_UrlKey> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.wide ? 90.0 : 52.0;
    final bg = widget.confirm
        ? (_focused ? AppTheme.primary.withOpacity(0.85) : AppTheme.primary)
        : (_focused ? AppTheme.cardHover : AppTheme.surface);

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: w,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _focused ? Colors.white : AppTheme.divider,
              width: _focused ? 2 : 1,
            ),
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.confirm || _focused ? Colors.white : AppTheme.textPrimary,
                      fontSize: widget.label.length > 2 ? 11 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Curseur clignotant ────────────────────────────────────────────────────────

class _Cursor extends StatefulWidget {
  const _Cursor();
  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 530))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _ctrl.value > 0.5 ? 1.0 : 0.0,
        child: Container(
          width: 2,
          height: 22,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
