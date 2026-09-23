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
/// - Insertion d'images (graphiques) à partir de placeholders comme `{{GRAPHIQUE_CONSOMMATION}}`
class WordReportService {
  /// Nom du fichier dans le tableau (première ligne du tableau annuel)
  /// servant de modèle de duplication. Doit correspondre à
  /// `{{ANNEE_1}}` dans `assets/templates/rapport_template.docx`.
  static const String _annualRowAnchorTag = 'ANNEE_1';

  static const String _documentXmlPath = 'word/document.xml';
  static const String _relsPath = 'word/_rels/document.xml.rels';
  static const String _mediaPathPrefix = 'word/media/';

  /// Construit le `.docx` final :
  /// - [templateBytes] : contenu du gabarit `.docx` (chargé depuis les
  ///   assets ou choisi par l'utilisateur).
  /// - [tags] : valeurs des tags globaux (non indexés), ex.
  ///   `{'PROJET_NOM': 'Camping Les Pins', ...}` — sans les accolades.
  /// - [annualRows] : une entrée par année, chacune étant la map des tags
  ///   *sans* le suffixe `_i` (ex. `{'ANNEE': '1', 'CONSOMMATION_ANCIEN':
  ///   '50000 kWh', ...}`) ; le service ajoute lui-même `_1`, `_2`, ... et
  ///   duplique la ligne de tableau modèle en conséquence.
  /// - [images] : map des noms de placeholders d'image vers les bytes de l'image.
  ///   Ex: `{'GRAPHIQUE_CONSOMMATION': Uint8List(...), 'GRAPHIQUE_COUT': Uint8List(...)}`
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
    //    entre plusieurs runs Word (<w:t>).
    xml = _replaceTags(xml, allTags);

    // 3) Insérer les images si des placeholders sont fournis
    final imageReplacements = <String, String>{};
    final imageFiles = <String, Uint8List>{};
    final imageRels = <String, String>{};
    
    if (images.isNotEmpty) {
      xml = _replaceImagePlaceholders(
        xml, 
        images, 
        imageReplacements, 
        imageRels,
      );
      imageFiles.addAll(images);
    }

    final newDocumentBytes = utf8.encode(xml);

    // 4) Mettre à jour le fichier de relations si des images ont été ajoutées
    ArchiveFile? relsFile;
    for (final file in archive.files) {
      if (file.name == _relsPath) {
        relsFile = file;
        break;
      }
    }
    
    Uint8List? newRelsBytes;
    if (relsFile != null && imageRels.isNotEmpty) {
      final relsXml = utf8.decode(relsFile.content as List<int>);
      newRelsBytes = Uint8List.fromList(utf8.encode(_updateRelationships(relsXml, imageRels)));
    }

    // Reconstruit l'archive à l'identique, sauf document.xml et éventuellement document.xml.rels
    final outArchive = Archive();
    
    // Conserver tous les fichiers existants (sauf ceux qu'on remplace)
    for (final file in archive.files) {
      // Remplacer document.xml
      if (file.name == _documentXmlPath) {
        outArchive.addFile(ArchiveFile(
          _documentXmlPath,
          newDocumentBytes.length,
          newDocumentBytes,
        ));
      }
      // Remplacer document.xml.rels si modifié
      else if (file.name == _relsPath && newRelsBytes != null) {
        outArchive.addFile(ArchiveFile(
          _relsPath,
          newRelsBytes.length,
          newRelsBytes,
        ));
      }
      // Ajouter les images dans word/media/
      else if (file.name.startsWith(_mediaPathPrefix)) {
        // Conserver les images existantes du template
        final content = file.content as List<int>;
        outArchive.addFile(ArchiveFile(file.name, content.length, content));
      }
      else if (file.isFile) {
        final content = file.content as List<int>;
        outArchive.addFile(ArchiveFile(file.name, content.length, content));
      }
    }
    
    // Ajouter les nouvelles images dans word/media/
    var imageIndex = 1;
    for (final entry in imageFiles.entries) {
      final imageName = 'image$imageIndex.png';
      final imagePath = _mediaPathPrefix + imageName;
      
      outArchive.addFile(ArchiveFile(
        imagePath,
        entry.value.length,
        entry.value,
      ));
      
      // Stocker la correspondance placeholder -> nom d'image
      imageReplacements[entry.key] = imageName;
      imageIndex++;
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

  /// Remplace les placeholders d'image (ex: {{GRAPHIQUE_CONSOMMATION}}) par
  /// des références à des images dans le document Word.
  /// Retourne le XML modifié et remplit [imageRels] avec les relations à ajouter.
  static String _replaceImagePlaceholders(
    String xml,
    Map<String, Uint8List> images,
    Map<String, String> imageReplacements,
    Map<String, String> imageRels,
  ) {
    if (images.isEmpty) return xml;

    // Trouver tous les placeholders d'image dans le document
    final placeholderPattern = RegExp(r'\{\{([A-Z0-9_]+)\}\}');
    final matches = placeholderPattern.allMatches(xml).toList();
    
    // Filtrer uniquement les placeholders qui correspondent à des images fournies
    final imagePlaceholders = matches.where((m) {
      final placeholderName = m.group(1)!;
      return images.containsKey(placeholderName);
    }).toList();
    
    if (imagePlaceholders.isEmpty) return xml;

    // Remplacer chaque placeholder par un élément de dessin Word
    var resultXml = xml;
    var imageIndex = 1;
    
    for (final match in imagePlaceholders) {
      final placeholderName = match.group(1)!;
      final imageName = 'image$imageIndex.png';
      
      // Créer un ID de relation unique
      final relId = 'rId${100 + imageIndex}';
      
      // Stocker la correspondance pour la mise à jour des relations
      imageReplacements[placeholderName] = imageName;
      imageRels[relId] = imageName;
      
      // Créer l'élément de dessin Word pour l'image
      // Ce sera un paragraphe avec un drawing inline
      final drawingXml = _createImageDrawingXml(relId, imageName, imageIndex);
      
      // Remplacer le placeholder par le drawing
      resultXml = resultXml.replaceFirst(
        '{{$placeholderName}}',
        drawingXml,
      );
      
      imageIndex++;
    }
    
    return resultXml;
  }

  /// Crée le XML pour un élément de dessin Word avec une image.
  /// Le drawing est encapsulé dans un paragraphe <w:p>.
  static String _createImageDrawingXml(String relId, String imageName, int imageIndex) {
    // Éléments de base avec des identifiants uniques
    final drawId = 1000 + imageIndex;
    
    return '''
<w:p w14:paraId="FFFF000${imageIndex}" w14:textId="7777000${imageIndex}" w:rsidR="00000000" w:rsidRPr="00000000" w:rsidP="00000000" xmlns:w14="http://schemas.microsoft.com/office/word/2009/wordml">
  <w:pPr>
    <w:pStyle w:val="Normal"/>
    <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
      <w:sz w:val="24"/>
      <w:szCs w:val="24"/>
    </w:rPr>
  </w:pPr>
  <w:r w:rsidRPr="00000000">
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
      <w:sz w:val="24"/>
      <w:szCs w:val="24"/>
    </w:rPr>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <wp:extent cx="6000000" cy="4000000"/>
        <wp:effectExtent l="0" t="0" r="0" b="0"/>
        <wp:docPr id="$drawId" name="$imageName" descr="Graphique"/>
        <wp:cNvGraphicFramePr>
          <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1" noChangeArrowheads="1"/>
        </wp:cNvGraphicFramePr>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:blipFill>
                <a:blip r:embed="$relId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                <a:stretch>
                  <a:fillRect/>
                </a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                  <a:off x="0" y="0"/>
                  <a:ext cx="6000000" cy="4000000"/>
                </a:xfrm>
                <a:prstGeom prst="rect" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                  <a:avLst/>
                </a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
'''.replaceAll('$drawId', drawId.toString())
      .replaceAll('$imageName', _escapeXml(imageName))
      .replaceAll('$relId', relId);
  }

  /// Met à jour le fichier de relations pour ajouter les références aux images.
  static String _updateRelationships(String relsXml, Map<String, String> imageRels) {
    if (imageRels.isEmpty) return relsXml;
    
    // Trouver la position avant la balise de fermeture </Relationships>
    var closingTagIndex = relsXml.lastIndexOf('</Relationships>');
    if (closingTagIndex == -1) {
      // Essayer avec </relationships> en minuscules
      closingTagIndex = relsXml.lastIndexOf('</relationships>');
      if (closingTagIndex == -1) {
        return relsXml;
      }
    }
    
    // Ajouter chaque relation d'image
    final buffer = StringBuffer(relsXml.substring(0, closingTagIndex));
    
    for (final entry in imageRels.entries) {
      final relId = entry.key;
      final imageName = entry.value;
      final imagePath = _mediaPathPrefix + imageName;
      
      // Créer une relation pour l'image
      buffer.writeln('''
    <Relationship Id="$relId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="$imagePath"/>
''');
    }
    
    buffer.write(relsXml.substring(closingTagIndex));
    
    return buffer.toString();
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
