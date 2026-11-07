# Handoff : Lumen TV — app de streaming pour TV (navigation télécommande)

## Overview
Interface 10-foot (TV) d'une app de streaming films / séries / animés, pensée pour la télécommande (D-pad + OK + Retour). Écrans : Accueil, Planning (sorties de la semaine), Catalogue (Films, Séries, Animés), Détails, Lecture. Style visuel inspiré d'iOS / tvOS : matériaux floutés (backdrop blur + saturate, pas de « liquid glass »), focus par mise à l'échelle + ombre.

Le design s'intègre dans un front existant (Aniplex-like, nav centrée en pilule : Home / Catalogue / Planning / Favoris). Réutiliser les composants, données et tokens du codebase cible quand ils existent.

## About the Design Files
`Lumen TV.dc.html` est une **référence de design en HTML** (prototype interactif), pas du code de production. Il faut **recréer ces écrans dans l'environnement du codebase cible** (React, Vue, etc.) avec ses patterns et librairies. Le fichier s'ouvre directement dans un navigateur (`support.js` à côté) : flèches = D-pad, Entrée/Espace = OK, Échap/Backspace = Retour. La souris marche aussi (hover = focus, clic = OK).

Le prototype est autonome : toute la logique est dans la classe `Component` (bloc `<script data-dc-script>`) — données, modèle de focus, navigation, lecture simulée.

## Fidelity
**High-fidelity** pour layout, typo, couleurs, états de focus et comportements de navigation. Les visuels (affiches, backdrops, vidéo) sont des **placeholders** (dégradés oklch générés par teinte) à remplacer par les vraies images de l'API.

## Canvas & scaling
- Canvas fixe **1920×1080**, mis à l'échelle `min(innerWidth/1920, innerHeight/1080)`, centré, fond `#000`.
- Marges latérales : **96px** partout (safe area TV).
- Tailles mini : texte ≥ 17px (méta), corps 22–30px, titres 84–128px.

## Modèle de navigation (le cœur du design)
Chaque écran = liste de **rangées** ; chaque rangée = N éléments focusables. Focus `{r, c}` par écran, conservé quand on change d'écran (retour = focus restauré).
- ←/→ : élément précédent/suivant dans la rangée (clampé).
- ↑/↓ : rangée précédente/suivante ; la colonne est **mémorisée par rangée** (`m[r]`) pour revenir au même élément. Les rangées vides sont sautées.
- Exception grille Catalogue : entre rangées de grille, on garde la même colonne.
- OK : active l'élément focusé. Retour : pile de navigation (`stack`) ; pile vide → Accueil.
- Les onglets du haut s'activent sur OK (pas au focus).
- Défilement : le contenu se translate verticalement selon la rangée focusée ; les rangées horizontales se translatent pour garder l'élément focusé en 2e position (`shift = -min(max, max(0,c-1)*(w+gap))`).
- Transitions : `transform .45–.55s cubic-bezier(.2,.8,.2,1)` pour les scrolls, `.2–.25s` pour le focus.

### États de focus
- **Cartes (affiches / vignettes)** : `scale(1.1)`, `box-shadow: 0 30px 60px rgba(0,0,0,.6)`, reflet spéculaire `linear-gradient(135deg, rgba(255,255,255,.28), transparent 45%)` en overlay (opacity 0→1). Repos : `scale(1)`, `0 10px 24px rgba(0,0,0,.35)`. Le texte sous la carte passe de `rgba(255,255,255,.55)` à `#f5f5f7`.
- Variante (tweak « Contour ») : `scale(1.03)` + `0 0 0 5px #f5f5f7`.
- **Boutons pilule** : repos `rgba(255,255,255,.16)` + blur, texte `#f5f5f7` ; focus fond `#f5f5f7`, texte `#0b0b0d`, `scale(1.08)`, `0 18px 40px rgba(0,0,0,.45)`.
- **Onglets / chips** : focus = blanc plein + texte noir + `scale(1.08)` ; sélectionné non focusé = `rgba(255,255,255,.2)` ; autre = transparent, texte `rgba(255,255,255,.7)`.

## Écrans

### Barre de navigation (Accueil, Planning, Catalogue)
- Hauteur 150px, padding 0 96px, 3 zones : logo « LUMEN » (32px/800, letter-spacing .34em) · pilule d'onglets centrée · horloge (26px/500) + avatar 56px rond.
- Pilule : padding 8px, gap 6px, `rgba(40,40,46,.5)`, `backdrop-filter: blur(30px) saturate(180%)`, bordure `1px rgba(255,255,255,.08)`, radius 999. Onglets : padding 16px 38px, 26px/600.
- Onglets : **Accueil · Planning · Films · Séries · Animés** (Films/Séries/Animés = Catalogue filtré).
- Se masque (opacity 0, translateY -30px) quand on descend dans le contenu.

### 1. Accueil
Rangées : 0 nav · 1 boutons hero · 2 « Continuer à regarder » · 3 « Récent ».
- Backdrop plein écran = visuel du titre focusé (à la une par défaut), avec overlays `linear-gradient(90deg, rgba(8,8,10,.92) 0%, rgba(8,8,10,.55) 42%, transparent 75%)` + `linear-gradient(0deg, rgba(8,8,10,1), transparent 60%)`. Dim supplémentaire `rgba(8,8,10,.5)` quand r ≥ 2.
- Hero (hauteur 740, contenu aligné en bas, gap 22) : sur-titre 22px/600 tracking .16em ; titre 128px/800, letter-spacing -.035em, line-height .95 ; méta 24px + badges (4K, HDR, 5.1 : bordure 1.5px rgba(255,255,255,.5), radius 6, 17px/700) ; synopsis 28px/1.4, max 880px ; boutons 76px de haut, padding 0 42px, 28px/600 : « ▶ Lecture/Reprendre », « ⓘ Plus d'infos ». Le hero passe à opacity 0 quand r ≥ 2.
- Translate vertical du contenu selon r : `[0, 0, -380, -870]`.
- Titres de section : 34px/700.
- **Continuer à regarder** : cartes 16:9 416×234, radius 20, gap 40. Titre en surimpression 30px/800, barre de progression 6px (piste rgba(255,255,255,.3), remplissage #f5f5f7) en bas. Sous la carte : « S1 · É4 — reste 19 min » / « Film · reste 84 min » (22px). OK = reprise de lecture directe.
- **Récent** : affiches 250×375, radius 20, gap 36. Type (FILM/SÉRIE/ANIMÉ, 14px/700, tracking .16em) en haut à gauche, titre 29px/800 en bas. OK = Détails.

### 2. Planning
Rangées : 0 nav · 1 contrôles · 2 grille semaine (navigation 2D spécifique).
- Fond : `radial-gradient(70% 55% at 50% 0%, oklch(0.36 0.07 200 / .5), transparent 70%), #0b0b0d`.
- En-tête (top 180) : « Planning » 84px/800 + « N épisodes » 24px rgba(255,255,255,.55). À droite, pilules de 64px de haut : « ♡ Favoris » (bascule : filtre sur Ma liste, ♥ quand actif), « ‹ Préc. », « 2–8 nov. › » (semaine suivante).
- Grille 7 colonnes `minmax(0,1fr)`, gap 20, top 310. En-tête de jour : pilule 52px, « Lun 2 » 22px/700 + compteur ; **aujourd'hui** = fond #f5f5f7 / texte #0b0b0d.
- Carte épisode : padding 10, radius 20, fond rgba(255,255,255,.07) + blur. Vignette 64×92 radius 12 ; titre 20px/700 sur une ligne (ellipsis) ; « Ép. 5 » 18px ; ligne du bas : heure 17px tabular-nums + statut (nowrap).
- Statuts : **Vu** oklch(0.78 0.16 155) (vignette assombrie + pastille ✓ verte) · **Dispo** blanc · **Nouveau** oklch(0.8 0.13 215) (sorti aujourd'hui) · **À venir** oklch(0.82 0.14 80).
- Focus carte : fond #f5f5f7, texte #0b0b0d, `scale(1.07)`, ombre `0 22px 44px rgba(0,0,0,.55)` ; couleur du statut assombrie pour le contraste.
- Navigation grille : ←/→ = jour (saute les jours vides, garde l'index clampé), ↑/↓ = épisode dans le jour ; ↑ depuis le premier → contrôles ; ↓ depuis les contrôles → jour mémorisé (aujourd'hui par défaut). La grille défile de 126px par épisode au-delà du 4e, et l'en-tête s'estompe.
- OK : épisode sorti → Lecture ; à venir → Détails.
- Le numéro d'épisode varie avec la semaine affichée ; statut calculé à partir de la date/heure courante.

### 3. Catalogue (Films / Séries / Animés)
Rangées : 0 nav · 1 chips genre · 2+ rangées de grille.
- Fond : halo radial de la teinte du titre focusé en haut + #0b0b0d.
- Titre 84px/800 + compteur « 10 titres » à droite. Chips : Tout, Action, Drame, Sci-fi, Thriller, Comédie, Fantasy — padding 14px 30px, 24px/600 (OK = filtrer).
- Grille 6 × 250px (space-between), row-gap 48, affiches identiques à Récent (méta « GENRE · ANNÉE » en haut). Défilement -423px par rangée au-delà de la 1re. État vide : « Aucun titre dans cette catégorie pour le moment. »

### 4. Détails
Rangées (série/animé) : 0 boutons · 1 saisons · 2..n épisodes (un épisode = une rangée, **liste verticale**). Film : 0 boutons · 1 titres similaires.
- Backdrop plein écran + overlays (90deg .94 → .1, et 0deg .95 → transparent 50%).
- Infos (padding-top 200) : sur-titre « SÉRIE · THRILLER » ; titre 112px/800 ; méta « 2025 · 16+ · 3 saisons » + badges 4K / HDR / VF · VOSTFR ; synopsis 29px/1.42 max 960 ; boutons « ▶ Lecture S1 É1 / Reprendre S1 É4 » et « + / ✓ Ma liste » (bascule).
- Section du bas **sans container**, margin 72px 96px 0 : titre « Épisodes » 34px/700 + **contrôle segmenté iOS** pour les saisons (fond rgba(118,118,128,.24), padding 6, segments 12px 30px 23px/600 ; sélectionné rgba(255,255,255,.22) ; focus blanc). Focuser une saison la sélectionne.
- Liste d'épisodes verticale, gap 24, max 1400px : vignette 320×180 radius 18 (barre de progression si commencé) + « 1. Titre » 30px/700 + « 48 min · Vu / En cours » 23px rgba(255,255,255,.5).
- Défilement : r=0 → 0 ; r≥1 → -340px, puis -204px par épisode au-delà du 2e. Les infos passent à opacity .35 quand r ≥ 1.
- Film : rangée horizontale « Titres similaires » (affiches 250×375).

### 5. Lecture
Rangées : 0 barre de progression · 1 boutons.
- Vidéo plein écran (placeholder animé en Ken Burns léger).
- Les commandes reposent directement sur des **dégradés, sans container** : haut `linear-gradient(180deg, rgba(0,0,0,.7), transparent)` sur 260px ; bas `linear-gradient(0deg, rgba(0,0,0,.9) 0%, rgba(0,0,0,.6) 45%, transparent)` sur 520px.
- Haut (top 64, marges 96) : titre 46px/800 + « Saison 1 · Épisode 4 — Titre » 26px ; horloge à droite.
- Bas (left/right 96, bottom 64, gap 18) : barre de progression 8px (16px au focus + halo `0 0 0 4px rgba(255,255,255,.15)`), temps écoulé / « -restant » 23px tabular-nums ; boutons centrés 68px de haut : « −10 s », « ❚❚ Pause / ▶ Lecture », « +10 s », « Sous-titres : Non/FR/EN », « Épisode suivant › » (séries).
- Focus sur la barre : ←/→ = ±10 s, OK = play/pause. Clic sur la barre = seek.
- Les commandes se masquent après 4 s de lecture sans interaction (opacity .35s, curseur masqué) ; n'importe quelle touche les réaffiche (OK quand masquées = play/pause direct). En pause : bouton rond central 168px flouté avec ▶.
- Sous-titres : bandeau 40px/600 sur fond rgba(0,0,0,.55), bottom 360 (commandes visibles) / 110 (masquées).
- La progression est enregistrée chaque seconde ; le titre passe en tête de « Continuer à regarder ». Fin d'épisode → épisode suivant automatiquement.

### Aide télécommande
Pilule en bas à droite (sauf en Lecture) : « ↑ ↓ ← → Naviguer · Entrée · OK · Échap · Retour », 19px, fond flouté. Désactivable (tweak).

## State Management
- `screen` : home | planning | catalog | detail | watch ; `stack` (historique : écran, detailId, saison, focus détail).
- `f[screen]` : focus `{r, c, m}` (Planning : `{r, c, i, m1, m2}`).
- Catalogue : `type` (0 films, 1 séries, 2 animés), `genre`.
- Planning : `week` (offset de semaine), `favOnly`.
- Détails : `detailId`, `season`. `myList` : ids favoris.
- Lecture : `watchId`, `ws`/`we` (saison/épisode), `time`, `playing`, `ctrl` (commandes visibles), `subs` (0 non, 1 FR, 2 EN).
- `progress[id] = {s, e, t, d}` (saison, épisode, secondes, durée) + `order` (ordre de Continuer à regarder).
- Données à brancher sur l'API : catalogue, planning hebdo (id, jour, heure, n° épisode), progression, favoris.

## Design Tokens
- Fond app #0b0b0d · fond overlays rgba(8,8,10,…) · texte #f5f5f7 · texte secondaire rgba(255,255,255,.5–.8).
- Matériau flouté : `backdrop-filter: blur(24–40px) saturate(180%)`, fond rgba(40,40,46,.5) ou rgba(255,255,255,.07–.16), bordure 1px rgba(255,255,255,.08).
- Statuts : vert oklch(0.78 0.16 155), cyan oklch(0.8 0.13 215), ambre oklch(0.82 0.14 80).
- Radius : 999 (pilules), 20 (affiches, cartes), 18 (vignettes), 12 (miniatures), 6 (badges).
- Ombres : repos `0 10px 24px rgba(0,0,0,.35)` · focus `0 30px 60px rgba(0,0,0,.6)` · bouton focus `0 18px 40px rgba(0,0,0,.45)`.
- Typo : -apple-system / SF Pro Display → Helvetica Neue → Helvetica. Graisses 500/600/700/800. Titres en letter-spacing négatif (-.01 à -.035em). Utiliser la police du front existant si différente.
- Espacements : marges 96 ; gaps 14/20/24/36/40 ; sections 30–72.

## Assets
Aucun asset réel. Affiches, backdrops, vignettes et vidéo sont des placeholders (`art(hue)` = dégradés radiaux oklch) à remplacer par les images de l'API. Icônes = glyphes texte (▶ ❚❚ ⓘ ✓ ♡ ‹ ›) → remplacer par le set d'icônes du codebase.

## Files
- `Lumen TV.dc.html` — prototype complet (template + logique dans la classe `Component`).
- `support.js` — runtime nécessaire pour ouvrir le prototype dans un navigateur.
