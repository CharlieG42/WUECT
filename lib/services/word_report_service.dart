import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Génère un rapport `.docx` à partir d'un gabarit Word éditable par
/// l'utilisateur (police, mise en page, couleurs libres) contenant des tags
/// `{{TAG}}` — voir `assets/templates/TEMPLATE_TAGS.md`.
///
/// Contrairement à un PDF généré par du code (widgets positionnés en dur),
/// un `.docx` est une archive ZIP de fichiers XML en texte clair : on peut
/// donc remplacer le contenu textuel sans dépendre d'un moteur Word, tout en
/// laissant l'utilisateur restyler le document dans Word ensuite.
///
/// Fonctionnalités :
/// - Remplacement des tags textuels `{{TAG}}` par des valeurs
/// - Duplication des lignes de tableau annuel basées sur `{{ANNEE_1}}`
/// - Insertion d'images (graphiques) à partir de placeholders texte comme
///   `{{GRAPHIQUE_CONSOMMATION}}`, chacun seul dans son propre paragraphe.
class WordReportService {
  /// Cherche un fichier par chemin exact dans l'archive (équivalent d'un
  /// `firstOrNull`, sans dépendre de `package:collection`).
  static ArchiveFile? _findFile(Archive archive, String name) {
    for (final f in archive.files) {
      if (f.name == name) return f;
    }
    return null;
  }

  /// Nom du fichier dans le tableau (première ligne du tableau annuel)
  /// servant de modèle de duplication. Doit correspondre à
  /// `{{ANNEE_1}}` dans `assets/templates/rapport_template.docx`.
  static const String _annualRowAnchorTag = 'ANNEE_1';

  static const String _documentXmlPath = 'word/document.xml';
  static const String _relsPath = 'word/_rels/document.xml.rels';
  static const String _mediaPathPrefix = 'word/media/';
  static const String _contentTypesPath = '[Content_Types].xml';

  /// Largeur de repli, en EMU (914400 EMU = 1 pouce), utilisée uniquement si
  /// la largeur de page réelle du gabarit n'a pas pu être lue (section
  /// `<w:sectPr>` absente ou inattendue). En temps normal, la largeur
  /// utilisée est calculée dynamiquement depuis `<w:pgSz>`/`<w:pgMar>` du
  /// document (voir [_pageContentWidthEmu]) pour occuper toute la largeur
  /// imprimable de la page, marges déduites.
  static const int _fallbackImageWidthEmu = 5486400; // 6 pouces

  /// Construit le `.docx` final :
  /// - [templateBytes] : contenu du gabarit `.docx` (chargé depuis les
  ///   assets ou choisi par l'utilisateur).
  /// - [tags] : valeurs des tags globaux (non indexés), ex.
  ///   `{'PROJET_NOM': 'Camping Les Pins', ...}` — sans les accolades.
  /// - [annualRows] : une entrée par année, chacune étant la map des tags
  ///   *sans* le suffixe `_i` (ex. `{'ANNEE': '1', 'CONSOMMATION_ANCIEN':
  ///   '50000 kWh', ...}`) ; le service ajoute lui-même `_1`, `_2`, ... et
  ///   duplique la ligne de tableau modèle en conséquence.
  /// - [images] : map placeholder (sans accolades, ex. `GRAPHIQUE_COUT`) ->
  ///   bytes PNG. Chaque placeholder doit être seul dans son propre
  ///   paragraphe dans le gabarit (ex. `{{GRAPHIQUE_COUT}}` sur sa ligne) :
  ///   ce paragraphe entier est remplacé par l'image.
  static Future<Uint8List> generateReport({
    required Uint8List templateBytes,
    required Map<String, String> tags,
    List<Map<String, String>> annualRows = const [],
    Map<String, Uint8List> images = const {},
  }) async {
    final archive = ZipDecoder().decodeBytes(templateBytes);

    final documentFile = archive.files.firstWhere(
      (f) => f.name == _documentXmlPath,
      orElse: () => throw StateError(
          'Gabarit invalide : $_documentXmlPath introuvable dans le .docx'),
    );

    var xml = utf8.decode(documentFile.content as List<int>);

    // 1) Dupliquer la ligne "modèle" du tableau annuel (une fois par année)
    //    et fusionner ses tags indexés dans la map globale.
    final allTags = Map<String, String>.from(tags);
    xml = _expandAnnualTable(xml, annualRows, allTags);

    // 2) Remplacer tous les tags {{...}} restants, y compris ceux éclatés
    //    entre plusieurs runs Word (<w:t>). Les placeholders d'image (dans
    //    `images`, pas dans `tags`) sont ignorés ici et traités ensuite.
    xml = _replaceTags(xml, allTags);

    // 3) Insérer les images : chaque placeholder d'image trouvé remplace le
    //    paragraphe entier qui le contient par un paragraphe <w:drawing>,
    //    dimensionné à la largeur imprimable réelle de la page du gabarit.
    Map<String, Uint8List> mediaFiles = const {};
    Map<String, String> newRelationships = const {};
    if (images.isNotEmpty) {
      final startingRelId = _nextFreeRelId(archive);
      final targetWidthEmu = _pageContentWidthEmu(xml) ?? _fallbackImageWidthEmu;
      final result = _insertImages(xml, images, startingRelId, targetWidthEmu);
      xml = result.xml;
      mediaFiles = result.mediaFiles;
      newRelationships = result.relationships;
    }

    final newDocumentBytes = Uint8List.fromList(utf8.encode(xml));

    // 4) Mettre à jour le fichier de relations (word/_rels/document.xml.rels)
    //    pour déclarer chaque nouvelle image, et [Content_Types].xml pour
    //    déclarer l'extension .png si le gabarit n'a jamais contenu d'image.
    Uint8List? newRelsBytes;
    Uint8List? newContentTypesBytes;
    if (newRelationships.isNotEmpty) {
      final relsFile = _findFile(archive, _relsPath);
      final relsXml = relsFile != null
          ? utf8.decode(relsFile.content as List<int>)
          : _emptyRelationshipsXml();
      newRelsBytes = Uint8List.fromList(
        utf8.encode(_addRelationships(relsXml, newRelationships)),
      );

      final contentTypesFile =
          _findFile(archive, _contentTypesPath);
      if (contentTypesFile != null) {
        final ctXml = utf8.decode(contentTypesFile.content as List<int>);
        if (!ctXml.contains('Extension="png"')) {
          newContentTypesBytes = Uint8List.fromList(
            utf8.encode(_addPngContentType(ctXml)),
          );
        }
      }
    }

    // 5) Reconstruit l'archive à l'identique, sauf les fichiers remplacés
    //    ci-dessus, plus les nouvelles images dans word/media/.
    final outArchive = Archive();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name == _documentXmlPath) {
        outArchive.addFile(ArchiveFile(_documentXmlPath, newDocumentBytes.length, newDocumentBytes));
      } else if (file.name == _relsPath && newRelsBytes != null) {
        outArchive.addFile(ArchiveFile(_relsPath, newRelsBytes.length, newRelsBytes));
      } else if (file.name == _contentTypesPath && newContentTypesBytes != null) {
        outArchive.addFile(ArchiveFile(_contentTypesPath, newContentTypesBytes.length, newContentTypesBytes));
      } else {
        final content = file.content as List<int>;
        outArchive.addFile(ArchiveFile(file.name, content.length, content));
      }
    }
    // Si le gabarit n'avait encore aucun word/_rels/document.xml.rels (cas
    // extrême, gabarit minimal), on l'ajoute.
    if (newRelsBytes != null &&
        !archive.files.any((f) => f.name == _relsPath)) {
      outArchive.addFile(ArchiveFile(_relsPath, newRelsBytes.length, newRelsBytes));
    }

    for (final entry in mediaFiles.entries) {
      outArchive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    final encoded = ZipEncoder().encode(outArchive);
    if (encoded == null) {
      throw StateError('Échec de la réécriture du fichier .docx (ZipEncoder)');
    }
    return Uint8List.fromList(encoded);
  }

  // ==========================================================================
  // Duplication de la ligne annuelle
  // ==========================================================================

  /// Repère la ligne de tableau `<w:tr>...</w:tr>` contenant
  /// `{{ANNEE_1}}`, la duplique une fois par entrée de [annualRows] en
  /// renumérotant `_1` -> `_i`, et remplace la ligne modèle par
  /// l'ensemble des lignes générées. Si aucune ligne modèle n'est trouvée
  /// (gabarit personnalisé sans tableau annuel), ne fait rien.
  static String _expandAnnualTable(
    String xml,
    List<Map<String, String>> annualRows,
    Map<String, String> allTags,
  ) {
    if (annualRows.isEmpty) return xml;

    final anchor = '{{$_annualRowAnchorTag}}';
    final anchorIndex = xml.indexOf(anchor);
    if (anchorIndex == -1) {
      // Pas de tableau annuel dans ce gabarit : rien à dupliquer, les tags
      // indexés fournis dans annualRows resteront simplement inutilisés.
      return xml;
    }

    // Remonte jusqu'au <w:tr ...> englobant, puis descend jusqu'au
    // </w:tr> correspondant. On exige un caractère non-alphabétique juste
    // après "<w:tr" pour ne pas confondre avec <w:trPr> (propriétés de
    // ligne), que Word peut ajouter à l'édition.
    final trOpenPattern = RegExp(r'<w:tr[ >/]');
    final trOpenMatches = trOpenPattern
        .allMatches(xml.substring(0, anchorIndex))
        .toList();
    if (trOpenMatches.isEmpty) return xml; // gabarit inattendu, on n'y touche pas
    final trStart = trOpenMatches.last.start;
    final trEndTagIndex = xml.indexOf('</w:tr>', anchorIndex);
    if (trEndTagIndex == -1) return xml;
    final trEnd = trEndTagIndex + '</w:tr>'.length;

    final rowTemplate = xml.substring(trStart, trEnd);

    // Tags indexés que la ligne modèle est censée contenir (tout tag se
    // terminant par _1 dans cette ligne). On les retrouve dynamiquement
    // plutôt que de les lister en dur, pour rester robuste si le gabarit
    // est modifié (colonnes ajoutées/retirées par l'utilisateur).
    final tagPattern = RegExp(r'\{\{([A-Z0-9_]+)_1\}\}');
    final baseTagNames = tagPattern
        .allMatches(rowTemplate)
        .map((m) => m.group(1)!)
        .toSet();

    final buffer = StringBuffer();
    for (var i = 0; i < annualRows.length; i++) {
      final rowValues = annualRows[i];
      final index = i + 1;
      var rowXml = rowTemplate.replaceAllMapped(
        RegExp(r'\{\{([A-Z0-9_]+)_1\}\}'),
        (m) => '{{${m.group(1)}_$index}}',
      );
      buffer.write(rowXml);

      for (final baseName in baseTagNames) {
        final value = rowValues[baseName];
        if (value != null) {
          allTags['${baseName}_$index'] = value;
        }
      }
    }

    return xml.replaceRange(trStart, trEnd, buffer.toString());
  }

  // ==========================================================================
  // Remplacement des tags {{TAG}}, robuste aux runs Word éclatés
  // ==========================================================================

  /// Repère chaque bloc `<w:t ...>texte</w:t>` (ou `<w:t .../>` vide),
  /// concatène leur contenu textuel en un flux continu, y cherche les tags
  /// `{{TAG}}`, puis réécrit uniquement les runs concernés. Cela permet de
  /// remplacer un tag même si Word (correction automatique, relecture...)
  /// l'a scindé entre deux `<w:t>` consécutifs, et gère aussi plusieurs
  /// tags présents dans un même run.
  static String _replaceTags(String xml, Map<String, String> tags) {
    // Important : (?=[ >/]) juste après "<w:t" garantit qu'on ne matche que
    // la vraie balise <w:t> (texte), pas <w:tc>, <w:tr>, <w:tcPr>, <w:tbl>,
    // <w:tab/>... qui commencent toutes aussi par le préfixe littéral
    // "<w:t". Sans cette garde, "<w:tc>" était pris pour "<w:t c...>" et
    // tout le XML jusqu'au prochain </w:t> se faisait avaler et écraser
    // (c'est ce qui corrompait le document généré).
    final runPattern = RegExp(
      r'<w:t(?=[ >/])(?:/>|[^>]*?>(?<text>.*?)</w:t>)',
      dotAll: true,
    );

    final runs = runPattern.allMatches(xml).toList();
    if (runs.isEmpty) return xml;

    final runTexts = runs.map((m) => m.namedGroup('text') ?? '').toList();
    final flatText = runTexts.join();

    // Offset (dans flatText) où commence chaque run.
    final runStartOffsets = <int>[];
    var cursor = 0;
    for (final t in runTexts) {
      runStartOffsets.add(cursor);
      cursor += t.length;
    }

    final tagPattern = RegExp(r'\{\{([A-Z0-9_]+)\}\}');
    final tagMatches = tagPattern
        .allMatches(flatText)
        .where((m) => tags.containsKey(m.group(1)))
        .toList();
    if (tagMatches.isEmpty) return xml;

    int runIndexForOffset(int offset) {
      // runStartOffsets est croissant : dernier index dont le start <= offset.
      var lo = 0, hi = runStartOffsets.length - 1, res = 0;
      while (lo <= hi) {
        final mid = (lo + hi) >> 1;
        if (runStartOffsets[mid] <= offset) {
          res = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }
      return res;
    }

    // Pour chaque run touché : liste de (localStart, localEnd, valeurDeRemplacement)
    // triée par position, valeurDeRemplacement = null pour les runs qui ne
    // portent que la "queue" ou le "milieu" d'un tag démarré ailleurs (ils
    // sont alors simplement vidés sur ce segment).
    final spansByRun = <int, List<_Span>>{};

    for (final m in tagMatches) {
      final value = tags[m.group(1)!]!;
      final firstRun = runIndexForOffset(m.start);
      final lastRun = runIndexForOffset(m.end - 1);
      for (var i = firstRun; i <= lastRun; i++) {
        final rStart = runStartOffsets[i];
        final rLen = runTexts[i].length;
        final localStart = (m.start - rStart).clamp(0, rLen);
        final localEnd = (m.end - rStart).clamp(0, rLen);
        // Seul le premier run touché reçoit la valeur ; les suivants sont
        // vidés sur la portion recouverte par le tag.
        final replacement = i == firstRun ? _escapeXml(value) : '';
        (spansByRun[i] ??= []).add(_Span(localStart, localEnd, replacement));
      }
    }

    final newRunTexts = List<String?>.filled(runs.length, null);
    spansByRun.forEach((i, spans) {
      spans.sort((a, b) => a.start.compareTo(b.start));
      final text = runTexts[i];
      final out = StringBuffer();
      var pos = 0;
      for (final span in spans) {
        out.write(text.substring(pos, span.start));
        out.write(span.replacement);
        pos = span.end;
      }
      out.write(text.substring(pos));
      newRunTexts[i] = out.toString();
    });

    // Réécrit uniquement les runs modifiés.
    final out = StringBuffer();
    var lastEnd = 0;
    for (var i = 0; i < runs.length; i++) {
      if (newRunTexts[i] == null) continue;
      final m = runs[i];
      out.write(xml.substring(lastEnd, m.start));
      out.write('<w:t xml:space="preserve">${newRunTexts[i]}</w:t>');
      lastEnd = m.end;
    }
    out.write(xml.substring(lastEnd));
    return out.toString();
  }

  // ==========================================================================
  // Insertion des images (graphiques)
  // ==========================================================================

  /// Repère chaque occurrence d'un placeholder d'image (ex.
  /// `{{GRAPHIQUE_COUT}}`) — robuste aux runs Word éclatés, comme
  /// [_replaceTags] — et remplace le **paragraphe entier** qui le contient
  /// par un paragraphe `<w:drawing>`.
  ///
  /// Important : on remplace tout le `<w:p>...</w:p>` englobant, jamais
  /// seulement le texte du `<w:t>`, car un `<w:drawing>` (comme tout
  /// contenu de niveau paragraphe) ne peut pas être imbriqué à l'intérieur
  /// d'un `<w:t>` — cela produit un `.docx` illisible que Word refuse
  /// d'ouvrir (propose une réparation qui supprime le contenu).
  static _ImageInsertResult _insertImages(
    String xml,
    Map<String, Uint8List> images,
    int startingRelId,
    int targetWidthEmu,
  ) {
    final runPattern = RegExp(
      r'<w:t(?=[ >/])(?:/>|[^>]*?>(?<text>.*?)</w:t>)',
      dotAll: true,
    );
    final runs = runPattern.allMatches(xml).toList();
    if (runs.isEmpty) return _ImageInsertResult(xml, {}, {});

    final runTexts = runs.map((m) => m.namedGroup('text') ?? '').toList();
    final flatText = runTexts.join();
    final runStartOffsets = <int>[];
    var cursor = 0;
    for (final t in runTexts) {
      runStartOffsets.add(cursor);
      cursor += t.length;
    }

    int runIndexForOffset(int offset) {
      var lo = 0, hi = runStartOffsets.length - 1, res = 0;
      while (lo <= hi) {
        final mid = (lo + hi) >> 1;
        if (runStartOffsets[mid] <= offset) {
          res = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }
      return res;
    }

    final tagPattern = RegExp(r'\{\{([A-Z0-9_]+)\}\}');
    final matches = tagPattern
        .allMatches(flatText)
        .where((m) => images.containsKey(m.group(1)))
        .toList();
    if (matches.isEmpty) return _ImageInsertResult(xml, {}, {});

    // Une seule table de correspondance placeholder -> (relId, nom de
    // fichier), construite en un seul passage sur `images` : contrairement
    // à la version précédente, il n'y a plus deux compteurs indépendants
    // qui pouvaient se désynchroniser et faire pointer une image vers le
    // mauvais fichier.
    final placeholderRelId = <String, String>{};
    final placeholderFileName = <String, String>{};
    final mediaFiles = <String, Uint8List>{};
    final relationships = <String, String>{};
    var relCounter = startingRelId;
    for (final entry in images.entries) {
      final relId = 'rId${relCounter++}';
      final safeName = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      final fileName = 'wuect_$safeName.png';
      placeholderRelId[entry.key] = relId;
      placeholderFileName[entry.key] = fileName;
      mediaFiles['$_mediaPathPrefix$fileName'] = entry.value;
      relationships[relId] = 'media/$fileName';
    }

    // <w:p[ >/] : même garde que pour <w:tr> (voir _expandAnnualTable) afin
    // de ne pas confondre avec <w:pPr> (propriétés du paragraphe) ou
    // <w:proofErr> (marqueur de vérification orthographique), qui
    // commencent aussi par le préfixe littéral "<w:p".
    final pOpenPattern = RegExp(r'<w:p[ >/]');
    final replacements = <_ParaReplacement>[];

    for (final m in matches) {
      final placeholder = m.group(1)!;
      final firstRun = runIndexForOffset(m.start);
      final lastRun = runIndexForOffset(m.end - 1);
      final anchorXmlStart = runs[firstRun].start;
      final searchFrom = runs[lastRun].end;

      final pOpens = pOpenPattern.allMatches(xml.substring(0, anchorXmlStart)).toList();
      if (pOpens.isEmpty) continue; // structure inattendue : tag laissé tel quel
      final pStart = pOpens.last.start;
      final pEndTagIndex = xml.indexOf('</w:p>', searchFrom);
      if (pEndTagIndex == -1) continue;
      final pEnd = pEndTagIndex + '</w:p>'.length;

      final paragraphXml = _buildImageParagraphXml(
        relId: placeholderRelId[placeholder]!,
        imageDescription: placeholder,
        imageBytes: images[placeholder]!,
        uniqueSeed: replacements.length + 1,
        widthEmu: targetWidthEmu,
      );
      replacements.add(_ParaReplacement(pStart, pEnd, paragraphXml));
    }

    if (replacements.isEmpty) return _ImageInsertResult(xml, {}, {});

    replacements.sort((a, b) => a.start.compareTo(b.start));
    final out = StringBuffer();
    var lastEnd = 0;
    for (final r in replacements) {
      if (r.start < lastEnd) continue; // chevauchement inattendu : ignoré par sécurité
      out.write(xml.substring(lastEnd, r.start));
      out.write(r.xml);
      lastEnd = r.end;
    }
    out.write(xml.substring(lastEnd));

    return _ImageInsertResult(out.toString(), mediaFiles, relationships);
  }

  /// Construit un paragraphe Word autonome (`<w:p>...</w:p>`) contenant
  /// l'image à la largeur [widthEmu] (en EMU — normalement la largeur
  /// imprimable de la page, voir [_pageContentWidthEmu]), avec une hauteur
  /// calculée pour préserver le ratio d'aspect réel du PNG capturé.
  static String _buildImageParagraphXml({
    required String relId,
    required String imageDescription,
    required Uint8List imageBytes,
    required int uniqueSeed,
    required int widthEmu,
  }) {
    final pngSize = _pngPixelSize(imageBytes);
    var heightEmu = (widthEmu * 0.6).round(); // repli si dimensions PNG illisibles
    if (pngSize != null && pngSize.width > 0 && pngSize.height > 0) {
      heightEmu = (widthEmu * pngSize.height / pngSize.width).round();
    }

    final paraId = (0xFFFF0000 + uniqueSeed).toRadixString(16).padLeft(8, '0').toUpperCase();
    final drawId = 1000 + uniqueSeed;
    final safeDescr = _escapeXml(imageDescription);

    return '<w:p w14:paraId="$paraId" w14:textId="$paraId" '
        'xmlns:w14="http://schemas.microsoft.com/office/word/2009/wordml">'
        '<w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>'
        '<w:r>'
        '<w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
        '<wp:extent cx="$widthEmu" cy="$heightEmu"/>'
        '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '<wp:docPr id="$drawId" name="$safeDescr" descr="$safeDescr"/>'
        '<wp:cNvGraphicFramePr>'
        '<a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>'
        '</wp:cNvGraphicFramePr>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr>'
        '<pic:cNvPr id="$drawId" name="$safeDescr"/>'
        '<pic:cNvPicPr/>'
        '</pic:nvPicPr>'
        '<pic:blipFill>'
        '<a:blip r:embed="$relId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>'
        '<a:stretch><a:fillRect/></a:stretch>'
        '</pic:blipFill>'
        '<pic:spPr>'
        '<a:xfrm xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:off x="0" y="0"/>'
        '<a:ext cx="$widthEmu" cy="$heightEmu"/>'
        '</a:xfrm>'
        '<a:prstGeom prst="rect" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:avLst/></a:prstGeom>'
        '</pic:spPr>'
        '</pic:pic>'
        '</a:graphicData>'
        '</a:graphic>'
        '</wp:inline>'
        '</w:drawing>'
        '</w:r>'
        '</w:p>';
  }

  /// Lit la largeur/hauteur en pixels depuis l'en-tête IHDR d'un PNG.
  /// Retourne `null` si les octets ne sont pas un PNG valide (fallback vers
  /// un ratio par défaut dans [_buildImageParagraphXml]).
  static _PngSize? _pngPixelSize(Uint8List bytes) {
    const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length < 24) return null;
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != signature[i]) return null;
    }
    // Octets 12-15 doivent être le tag de chunk "IHDR" (ASCII 73,72,68,82).
    if (bytes[12] != 0x49 || bytes[13] != 0x48 || bytes[14] != 0x44 || bytes[15] != 0x52) {
      return null;
    }
    final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    return _PngSize(width, height);
  }

  /// Largeur imprimable de la page (largeur de page moins marges gauche et
  /// droite), en EMU, lue depuis `<w:pgSz>`/`<w:pgMar>` de la dernière
  /// section (`<w:sectPr>`) du document. C'est cette largeur qui est
  /// utilisée pour que chaque image occupe toute la largeur de la page.
  /// Retourne `null` si le document n'a pas de `<w:sectPr>` exploitable
  /// (gabarit inhabituel) — [_fallbackImageWidthEmu] est alors utilisé.
  ///
  /// Unité : dans `<w:pgSz>`/`<w:pgMar>`, les valeurs sont en twips
  /// (1/20e de point ; 1 pouce = 1440 twips = 914400 EMU, donc
  /// 1 twip = 635 EMU).
  static int? _pageContentWidthEmu(String xml) {
    final sectPrMatches = RegExp(r'<w:sectPr[ >/][\s\S]*?</w:sectPr>').allMatches(xml).toList();
    if (sectPrMatches.isEmpty) return null;
    final sectPr = sectPrMatches.last.group(0)!;

    final pgSzMatch = RegExp(r'<w:pgSz\b[^>]*\bw:w="(\d+)"').firstMatch(sectPr);
    if (pgSzMatch == null) return null;
    final pageWidthTwips = int.parse(pgSzMatch.group(1)!);

    final pgMarMatch = RegExp(r'<w:pgMar\b[^>]*/>').firstMatch(sectPr);
    var marginLeftTwips = 1440; // 1 pouce par défaut si <w:pgMar> absent
    var marginRightTwips = 1440;
    if (pgMarMatch != null) {
      final pgMar = pgMarMatch.group(0)!;
      final left = RegExp(r'w:left="(\d+)"').firstMatch(pgMar);
      final right = RegExp(r'w:right="(\d+)"').firstMatch(pgMar);
      if (left != null) marginLeftTwips = int.parse(left.group(1)!);
      if (right != null) marginRightTwips = int.parse(right.group(1)!);
    }

    final contentWidthTwips = pageWidthTwips - marginLeftTwips - marginRightTwips;
    if (contentWidthTwips <= 0) return null;
    return contentWidthTwips * 635; // twips -> EMU
  }

  /// Numéro de relation (`rIdN`) le plus élevé déjà utilisé dans le gabarit,
  /// +1. Évite de coder en dur un numéro de départ (ex. 100) qui pourrait
  /// entrer en collision avec un gabarit ayant déjà beaucoup de relations
  /// (images, en-têtes, styles...).
  static int _nextFreeRelId(Archive archive) {
    final relsFile = _findFile(archive, _relsPath);
    if (relsFile == null) return 1;
    final relsXml = utf8.decode(relsFile.content as List<int>);
    final ids = RegExp(r'Id="rId(\d+)"')
        .allMatches(relsXml)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    if (ids.isEmpty) return 1;
    return ids.reduce((a, b) => a > b ? a : b) + 1;
  }

  static String _emptyRelationshipsXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '</Relationships>';
  }

  /// Ajoute une relation d'image par entrée de [newRelationships]
  /// (relId -> chemin cible relatif à `word/`, ex. `media/wuect_xxx.png`).
  static String _addRelationships(String relsXml, Map<String, String> newRelationships) {
    if (newRelationships.isEmpty) return relsXml;

    var closingTagIndex = relsXml.lastIndexOf('</Relationships>');
    if (closingTagIndex == -1) return relsXml; // fichier de relations inattendu : on n'y touche pas

    final buffer = StringBuffer(relsXml.substring(0, closingTagIndex));
    for (final entry in newRelationships.entries) {
      buffer.write('<Relationship Id="${entry.key}" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
          'Target="${entry.value}"/>');
    }
    buffer.write(relsXml.substring(closingTagIndex));
    return buffer.toString();
  }

  /// Ajoute `<Default Extension="png" .../>` à [Content_Types].xml si le
  /// gabarit ne contenait encore aucune image (donc pas déjà déclaré).
  static String _addPngContentType(String contentTypesXml) {
    const pngDefault = '<Default Extension="png" ContentType="image/png"/>';
    final typesOpenEnd = contentTypesXml.indexOf('>',
        contentTypesXml.indexOf('<Types'));
    if (typesOpenEnd == -1) return contentTypesXml;
    return contentTypesXml.substring(0, typesOpenEnd + 1) +
        pngDefault +
        contentTypesXml.substring(typesOpenEnd + 1);
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}

/// Portion locale (dans le texte d'un run) recouverte par un tag, et le
/// texte par lequel elle doit être remplacée.
class _Span {
  final int start;
  final int end;
  final String replacement;
  const _Span(this.start, this.end, this.replacement);
}

/// Résultat de [WordReportService._insertImages].
class _ImageInsertResult {
  final String xml;
  final Map<String, Uint8List> mediaFiles; // chemin dans l'archive -> bytes
  final Map<String, String> relationships; // relId -> cible relative à word/
  const _ImageInsertResult(this.xml, this.mediaFiles, this.relationships);
}

/// Un paragraphe `<w:p>...</w:p>` (délimité par [start]/[end], offsets dans
/// le XML d'origine) à remplacer intégralement par [xml].
class _ParaReplacement {
  final int start;
  final int end;
  final String xml;
  const _ParaReplacement(this.start, this.end, this.xml);
}

/// Dimensions en pixels lues depuis l'en-tête IHDR d'un PNG.
class _PngSize {
  final int width;
  final int height;
  const _PngSize(this.width, this.height);
}
