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
/// Limitations connues (volontairement pas traitées ici, cf. discussion) :
/// - Pas d'insertion d'image (graphiques) dans le `.docx` pour l'instant.
/// - Un seul niveau de répétition de ligne de tableau est géré (la ligne
///   "année 1", dupliquée pour chaque année) — pas de répétition imbriquée.
class WordReportService {
  /// Nom du fichier dans le tableau (première ligne du tableau annuel)
  /// servant de modèle de duplication. Doit correspondre à
  /// `{{ANNEE_1}}` dans `assets/templates/rapport_template.docx`.
  static const String _annualRowAnchorTag = 'ANNEE_1';

  static const String _documentXmlPath = 'word/document.xml';

  /// Construit le `.docx` final :
  /// - [templateBytes] : contenu du gabarit `.docx` (chargé depuis les
  ///   assets ou choisi par l'utilisateur).
  /// - [tags] : valeurs des tags globaux (non indexés), ex.
  ///   `{'PROJET_NOM': 'Camping Les Pins', ...}` — sans les accolades.
  /// - [annualRows] : une entrée par année, chacune étant la map des tags
  ///   *sans* le suffixe `_i` (ex. `{'ANNEE': '1', 'CONSOMMATION_ANCIEN':
  ///   '50000 kWh', ...}`) ; le service ajoute lui-même `_1`, `_2`, ... et
  ///   duplique la ligne de tableau modèle en conséquence.
  static Future<Uint8List> generateReport({
    required Uint8List templateBytes,
    required Map<String, String> tags,
    List<Map<String, String>> annualRows = const [],
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
    //    entre plusieurs runs Word (<w:t>).
    xml = _replaceTags(xml, allTags);

    final newDocumentBytes = utf8.encode(xml);

    // Reconstruit l'archive à l'identique, sauf document.xml.
    final outArchive = Archive();
    for (final file in archive.files) {
      if (file.name == _documentXmlPath) {
        outArchive.addFile(ArchiveFile(
          _documentXmlPath,
          newDocumentBytes.length,
          newDocumentBytes,
        ));
      } else if (file.isFile) {
        final content = file.content as List<int>;
        outArchive.addFile(ArchiveFile(file.name, content.length, content));
      }
    }

    final encoded = ZipEncoder().encode(outArchive);
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

    const anchor = '{{$_annualRowAnchorTag}}';
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
        // Si value est null, on ajoute une chaîne vide pour éviter les tags non remplacés
        else {
          allTags['${baseName}_$index'] = '';
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
    final runPattern = RegExp(
      r'<w:t(?:/>|(?:[^>]*?)>(?<text>.*?)</w:t>)',
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
    
    // Supprimer tous les tags non remplacés pour éviter les {{TAG}} restants
    // qui pourraient corrompre le document
    final result = out.toString();
    return result.replaceAll(RegExp(r'\{\{[A-Z0-9_]+\}\}'), '');
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// Portion locale (dans le texte d'un run) recouverte par un tag, et le
/// texte par lequel elle doit être remplacée.
class _Span {
  final int start;
  final int end;
  final String replacement;
  _Span(this.start, this.end, this.replacement);
}
