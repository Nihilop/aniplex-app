import 'package:media_kit/media_kit.dart' hide Track;

import '../api/subtitles_api.dart';
import '../../shared/models/media.dart';

/// Une entrée du sélecteur de sous-titres.
class SubtitleOption {
  final String label;
  final bool isOff;
  final Subtitle? stock;      // piste du stock
  final Track? track;         // piste render-engine
  final String? lang;

  const SubtitleOption._({required this.label, this.isOff = false, this.stock, this.track, this.lang});

  static const off = SubtitleOption._(label: 'Désactivés', isOff: true);
  factory SubtitleOption.fromStock(Subtitle s) => SubtitleOption._(label: s.label, stock: s, lang: s.lang);
  factory SubtitleOption.fromTrack(Track t) => SubtitleOption._(label: t.label, track: t, lang: t.lang);
}

/// Sous-titres v2 : chargés en **WebVTT** (décalage admin déjà appliqué côté
/// serveur) et rendus par la SubtitleView de media_kit. Le français est activé
/// par défaut s'il existe. On privilégie le stock, sinon le repli render-engine.
class SubtitleController {
  SubtitleController(this.player);
  final Player player;

  final _subs = SubtitlesApi();
  String? _sourceId;

  List<SubtitleOption> options = const [SubtitleOption.off];
  SubtitleOption active = SubtitleOption.off;

  bool get hasSubtitles => options.length > 1;

  /// Libellé court de la piste active (« Non », « FR »…).
  String get activeLabel => active.isOff ? 'Non' : (active.lang?.toUpperCase() ?? 'ST');

  Future<void> load({required String episodeId, String? sourceId}) async {
    _sourceId = sourceId;
    final opts = <SubtitleOption>[SubtitleOption.off];

    final stock = await _subs.episodeSubtitles(episodeId);
    final textStock = stock.where((s) => s.isText).toList();
    if (textStock.isNotEmpty) {
      opts.addAll(textStock.map(SubtitleOption.fromStock));
    } else if (sourceId != null) {
      final tracks = await _subs.renderTracks(sourceId);
      opts.addAll(tracks.map(SubtitleOption.fromTrack));
    }
    options = opts;

    final def = _pickDefault(opts);
    if (def != null) await select(def);
  }

  /// Français non-forcé en priorité, puis la piste par défaut.
  SubtitleOption? _pickDefault(List<SubtitleOption> opts) {
    bool isFr(SubtitleOption o) => (o.lang ?? '').toLowerCase().startsWith('fr');
    final fr = opts.where((o) => !o.isOff && isFr(o));
    for (final o in fr) {
      if (o.stock?.forced == false || o.track?.forced == false) return o;
    }
    if (fr.isNotEmpty) return fr.first;
    for (final o in opts) {
      if (o.stock?.isDefault == true || o.track?.isDefault == true) return o;
    }
    return null;
  }

  Future<void> select(SubtitleOption o) async {
    active = o;
    if (o.isOff) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    String? vtt;
    if (o.stock != null) {
      vtt = await _subs.subtitleContent(o.stock!.id, vtt: true); // décalage serveur appliqué
    } else if (o.track != null && _sourceId != null) {
      vtt = await _subs.renderTrackVtt(_sourceId!, o.track!.index);
    }
    if (vtt == null || vtt.isEmpty) return;
    await player.setSubtitleTrack(SubtitleTrack.data(vtt, title: o.label, language: o.lang ?? 'und'));
  }

  /// Piste suivante (off → … → off).
  Future<void> cycle() async {
    if (options.length < 2) return;
    final idx = options.indexOf(active);
    await select(options[(idx + 1) % options.length]);
  }
}
