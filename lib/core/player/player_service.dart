import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Wrapper media_kit (libmpv) réutilisable : possède le Player + le
/// VideoController, encapsule l'ouverture avec en-têtes d'auth et la reprise.
/// Le rendu des sous-titres ASS passe par libmpv/libass (cf. [SubtitleController]).
class PlayerService {
  late final Player player;
  late final VideoController controller;

  PlayerService() {
    player = Player();
    controller = VideoController(player);
    _configure();
  }

  /// Le HLS transcodé est servi en live-style (sans ENDLIST) → mpv le croit
  /// non-seekable. On force la seekabilité pour que la reprise fonctionne.
  Future<void> _configure() async {
    try {
      final dynamic p = player.platform;
      await p?.setProperty('force-seekable', 'yes');
      await p?.setProperty('hr-seek', 'yes');
      // Décodage matériel : media_kit laisse mpv en hwdec=no (décodage CPU) →
      // les flux lourds (film « Originale » brut, HEVC/10-bit/1080p+) saturent
      // le CPU faible de la TV. `auto-safe` confie le décodage au décodeur
      // matériel (mediacodec sur Android) et retombe en soft si non supporté.
      await p?.setProperty('hwdec', 'auto-safe');
    } catch (_) {}
  }

  // Flux prêts à l'emploi pour l'UI.
  Stream<Duration> get position  => player.stream.position;
  Stream<Duration> get duration  => player.stream.duration;
  Stream<bool>     get playing   => player.stream.playing;
  Stream<bool>     get buffering => player.stream.buffering;
  Stream<bool>     get completed => player.stream.completed;
  Stream<String>   get error     => player.stream.error;

  Duration get currentPosition => player.state.position;
  Duration get totalDuration   => player.state.duration;
  bool     get isPlaying       => player.state.playing;

  /// Ouvre une source HLS/fichier. [headers] porte le cookie de session pour que
  /// libmpv s'authentifie. [startSeconds] reprend la lecture après le 1er tick
  /// de durée connue (une source live n'a pas de durée immédiate).
  Future<void> open(String url, {Map<String, String>? headers, int startSeconds = 0}) async {
    // mpv commence directement à l'offset au chargement (`start`) : plus fiable
    // qu'un seek après coup sur un flux HLS que mpv croit non-seekable.
    await _setProp('start', startSeconds > 5 ? '$startSeconds' : 'none');
    await player.open(Media(url, httpHeaders: headers));
  }

  Future<void> _setProp(String name, String value) async {
    try {
      final dynamic p = player.platform;
      await p?.setProperty(name, value);
    } catch (_) {}
  }

  Future<void> playOrPause() => player.playOrPause();
  Future<void> play()        => player.play();
  Future<void> pause()       => player.pause();
  Future<void> seek(Duration to) => player.seek(to);
  Future<void> setRate(double rate) => player.setRate(rate);

  Future<void> dispose() => player.dispose();
}
