import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;

import '../models/projet.dart';
import '../models/systeme.dart';
import '../models/pompe.dart';
import '../models/contact.dart';
import 'error_handler.dart';

/// Service d'export PDF pour les projets et comparatifs
/// 
/// Note sur le symbole : Le package pdf n'a pas de police par defaut supportant .
/// Solution : utiliser 'EUR ' au lieu de '€' dans les formats de devise pour le PDF.
class PdfExportService {
  /// Symbole de devise a utiliser dans les PDF (par defaut EUR pour eviter les problemes de font)
  static const String currencySymbol = 'EUR ';

  // ============================================================================
  // METHODES PRINCIPALES - RAPPORT COMPLET
  // ============================================================================

  /// Exporte un rapport complet (projet + comparatif) en PDF et propose de le partager
  static Future<void> exportFullReportToPdf({
    required BuildContext context,
    required Projet projet,
    Contact? contact,
    List<Systeme> systemes = const [],
    Map<int, List<Pompe>> pompesBySysteme = const {},
    Map<String, dynamic>? comparatifData,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
  }) async {
    if (projet.id == null) return;

    final doc = _buildFullReportPdfDocument(
      projet: projet,
      contact: contact,
      systemes: systemes,
      pompesBySysteme: pompesBySysteme,
      comparatifData: comparatifData,
      graphiqueConsommationImage: graphiqueConsommationImage,
      graphiqueCoutImage: graphiqueCoutImage,
    );

    try {
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${_sanitizeFilename(projet.nomSite)}_rapport_complet.pdf',
      );
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Erreur export PDF: $e', error: true);
    }
  }

  /// Sauvegarde un rapport complet (projet + comparatif) en PDF localement
  static Future<void> saveFullReportPdfLocally({
    required BuildContext context,
    required Projet projet,
    Contact? contact,
    List<Systeme> systemes = const [],
    Map<int, List<Pompe>> pompesBySysteme = const {},
    Map<String, dynamic>? comparatifData,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
  }) async {
    if (projet.id == null) return;

    final doc = _buildFullReportPdfDocument(
      projet: projet,
      contact: contact,
      systemes: systemes,
      pompesBySysteme: pompesBySysteme,
      comparatifData: comparatifData,
      graphiqueConsommationImage: graphiqueConsommationImage,
      graphiqueCoutImage: graphiqueCoutImage,
    );

    try {
      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final safeName = _sanitizeFilename(projet.nomSite);
      final filePath = p.join(dir.path, '${safeName}_rapport_complet.pdf');
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      ErrorHandler.showSnackBar(context, 'PDF sauvegardé: $filePath');
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Erreur sauvegarde PDF: $e', error: true);
    }
  }

  // ============================================================================
  // METHODES POUR PROJET SEUL (compatibilite ascendante)
  // ============================================================================

  /// Exporte un projet en PDF et propose de le partager
  static Future<void> exportProjetToPdf({
    required BuildContext context,
    required Projet projet,
    Contact? contact,
    List<Systeme> systemes = const [],
    Map<int, List<Pompe>> pompesBySysteme = const {},
  }) async {
    await exportFullReportToPdf(
      context: context,
      projet: projet,
      contact: contact,
      systemes: systemes,
      pompesBySysteme: pompesBySysteme,
    );
  }

  /// Sauvegarde un projet en PDF localement
  static Future<void> saveProjetPdfLocally({
    required BuildContext context,
    required Projet projet,
    Contact? contact,
    List<Systeme> systemes = const [],
    Map<int, List<Pompe>> pompesBySysteme = const {},
  }) async {
    await saveFullReportPdfLocally(
      context: context,
      projet: projet,
      contact: contact,
      systemes: systemes,
      pompesBySysteme: pompesBySysteme,
    );
  }

  // ============================================================================
  // METHODES POUR COMPARATIF SEUL (compatibilite ascendante)
  // ============================================================================

  /// Exporte un comparatif en PDF et propose de le partager
  static Future<void> exportComparatifToPdf({
    required BuildContext context,
    required String title,
    required String projetName,
    required Map<String, dynamic> dataAncien,
    required Map<String, dynamic> dataNouveau,
    required Map<String, dynamic> economieData,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
  }) async {
    final doc = _buildComparatifPdfDocument(
      title: title,
      projetName: projetName,
      dataAncien: dataAncien,
      dataNouveau: dataNouveau,
      economieData: economieData,
      graphiqueConsommationImage: graphiqueConsommationImage,
      graphiqueCoutImage: graphiqueCoutImage,
    );

    try {
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${_sanitizeFilename('comparatif_$projetName')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Erreur export PDF: $e', error: true);
    }
  }

  /// Sauvegarde un comparatif en PDF localement
  static Future<void> saveComparatifPdfLocally({
    required BuildContext context,
    required String title,
    required String projetName,
    required Map<String, dynamic> dataAncien,
    required Map<String, dynamic> dataNouveau,
    required Map<String, dynamic> economieData,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
  }) async {
    final doc = _buildComparatifPdfDocument(
      title: title,
      projetName: projetName,
      dataAncien: dataAncien,
      dataNouveau: dataNouveau,
      economieData: economieData,
      graphiqueConsommationImage: graphiqueConsommationImage,
      graphiqueCoutImage: graphiqueCoutImage,
    );

    try {
      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final safeName = _sanitizeFilename('comparatif_$projetName');
      final filePath = p.join(dir.path, '${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      ErrorHandler.showSnackBar(context, 'PDF sauvegardé: $filePath');
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Erreur sauvegarde PDF: $e', error: true);
    }
  }

  /// Capture un widget en image (pour les graphiques)
  static Future<Uint8List?> captureWidgetAsImage(GlobalKey widgetKey, {double pixelRatio = 2.0}) async {
    try {
      final boundary = widgetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Erreur capture widget: $e');
      return null;
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  /// Construit le document PDF pour un rapport complet (projet + comparatif)
  static pw.Document _buildFullReportPdfDocument({
    required Projet projet,
    Contact? contact,
    List<Systeme> systemes = const [],
    Map<int, List<Pompe>> pompesBySysteme = const {},
    Map<String, dynamic>? comparatifData,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
  }) {
    final doc = pw.Document();
    final numberFormat = NumberFormat('#,##0.00', 'fr_FR');
    
    // Utiliser EUR au lieu de € pour eviter les problemes de font
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2, locale: 'fr_FR');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return <pw.Widget>[
            // ====================================================================
            // EN-TETE
            // ====================================================================
            pw.Header(
              level: 0,
              child: pw.Text('Rapport Complet - ${projet.nomSite}'),
            ),
            pw.Paragraph(text: 'Generé le ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
            pw.SizedBox(height: 24),

            // ====================================================================
            // PARTIE 1 : INFORMATIONS DU PROJET
            // ====================================================================
            pw.Text(
              '1. Informations du Projet',
              style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(height: 12),
            
            // Client et contact
            pw.Paragraph(
              text: 'Client: ${contact?.client ?? 'N/C'} - Contact: ${contact?.nom ?? 'N/C'}',
            ),
            pw.Paragraph(text: 'Email: ${contact?.email ?? 'N/C'} - Mobile: ${contact?.mobile ?? 'N/C'}'),
            pw.SizedBox(height: 8),

            // Parametres du projet
            pw.Text('Parametres:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: 'Nom du site: ${projet.nomSite}'),
            pw.Bullet(text: 'Coût énergie: ${projet.coutEnergie} ${currencySymbol}kWh'),
            pw.Bullet(text: 'Augmentation energie/an: ${projet.pourcentageAugmentationEnergie}%'),
            pw.Bullet(text: 'Perte rendement/an: ${projet.percentagePerteRendement}%'),
            pw.SizedBox(height: 24),

            // ====================================================================
            // PARTIE 2 : SYSTEMES ET POMPES
            // ====================================================================
            pw.Text(
              '2. Systemes et Pompes',
              style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(height: 12),
            
            if (systemes.isEmpty)
              pw.Paragraph(text: 'Aucun systeme')
            else
              for (final systeme in systemes) 
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 8),
                    pw.Text(
                      systeme.nom,
                      style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                    ),
                    pw.Text('Coût investissement: ${currencyFormat.format(systeme.coutInvestissementTotal)}'),
                    pw.SizedBox(height: 6),
                    _buildPompeTable(pompesBySysteme[systeme.id] ?? []),
                    pw.Divider(height: 8),
                  ],
                ),
            pw.SizedBox(height: 24),

            // ====================================================================
            // PARTIE 3 : COMPARATIF (si donnees disponibles)
            // ====================================================================
            if (comparatifData != null) ...[
              pw.Text(
                '3. Analyse Comparatif',
                style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(height: 12),
              
              // Resume des economies
              _buildComparatifSummaryTable(comparatifData, numberFormat, currencyFormat),
              pw.SizedBox(height: 24),

              // Donnees detaillees par annee
              _buildAnnualDataTable(comparatifData, numberFormat, currencyFormat),
              pw.SizedBox(height: 24),

              // Graphiques (si images fournies)
              if (graphiqueConsommationImage != null) ...[
                pw.Text(
                  'Consommation Energetique sur 10 ans',
                  style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Image(pw.MemoryImage(graphiqueConsommationImage)),
                pw.SizedBox(height: 16),
              ],

              if (graphiqueCoutImage != null) ...[
                pw.Text(
                  'Coût sur 10 ans',
                  style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Image(pw.MemoryImage(graphiqueCoutImage)),
                pw.SizedBox(height: 16),
              ],
            ],

            // ====================================================================
            // PIED DE PAGE
            // ====================================================================
            pw.SizedBox(height: 24),
            pw.Divider(height: 8),
            pw.Paragraph(
              text: 'Rapport genere par WUECT - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    return doc;
  }

  /// Construit le document PDF pour un comparatif
  static pw.Document _buildComparatifPdfDocument({
    required String title,
    required String projetName,
    required Map<String, dynamic> dataAncien,
    required Map<String, dynamic> dataNouveau,
    required Map<String, dynamic> economieData,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
  }) {
    final doc = pw.Document();
    final numberFormat = NumberFormat('#,##0.00', 'fr_FR');
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2, locale: 'fr_FR');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Header(
              level: 0,
              child: pw.Text('Comparatif - $projetName'),
            ),
            pw.Paragraph(text: 'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
            pw.SizedBox(height: 16),

            // Resume des economies
            pw.Text(
              'Resume',
              style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            _buildComparatifSummaryTable(
              {
                'dataAncien': dataAncien,
                'dataNouveau': dataNouveau,
                'economieData': economieData,
              },
              numberFormat,
              currencyFormat,
            ),
            pw.SizedBox(height: 24),

            // Graphiques (si images fournies)
            if (graphiqueConsommationImage != null) ...[
              pw.Text(
                'Consommation Energetique sur 10 ans',
                style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Image(pw.MemoryImage(graphiqueConsommationImage)),
              pw.SizedBox(height: 16),
            ],

            if (graphiqueCoutImage != null) ...[
              pw.Text(
                'Coût sur 10 ans',
                style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Image(pw.MemoryImage(graphiqueCoutImage)),
              pw.SizedBox(height: 16),
            ],
          ];
        },
      ),
    );

    return doc;
  }

  /// Construit un tableau recapitulatif du comparatif
  static pw.Widget _buildComparatifSummaryTable(
    Map<String, dynamic> comparatifData,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
  ) {
    final dataAncien = comparatifData['dataAncien'] as Map<String, dynamic>? ?? {};
    final dataNouveau = comparatifData['dataNouveau'] as Map<String, dynamic>? ?? {};
    final economieData = comparatifData['economieData'] as Map<String, dynamic>? ?? {};

    return pw.Table.fromTextArray(
      headers: ['', 'Ancien', 'Nouveau', 'Economie'],
      data: [
        ['Consommation (kWh)', 
         numberFormat.format(dataAncien['totalConsommation'] ?? 0), 
         numberFormat.format(dataNouveau['totalConsommation'] ?? 0),
         numberFormat.format(economieData['economieConsommation'] ?? 0)],
        ['Coût energetique', 
         currencyFormat.format(dataAncien['totalCout'] ?? 0), 
         currencyFormat.format(dataNouveau['totalCout'] ?? 0),
         currencyFormat.format(economieData['economieCout'] ?? 0)],
        ['Investissement', 
         currencyFormat.format(dataAncien['investissement'] ?? 0), 
         currencyFormat.format(dataNouveau['investissement'] ?? 0),
         currencyFormat.format(economieData['economieInvestissement'] ?? 0)],
      ],
    );
  }

  /// Construit un tableau des pompes
  static pw.Widget _buildPompeTable(List<Pompe> pompes) {
    if (pompes.isEmpty) {
      return pw.Text('Aucune pompe');
    }

    return pw.Table.fromTextArray(
      headers: ['Marque/Modele', 'P (kW)', 'Debit (m3/h)', 'HMT', 'Es', 'Heures', 'Coût'],
      data: pompes.map((pompe) => [
        '${pompe.marque} ${pompe.modele}',
        pompe.puissanceNominale.toStringAsFixed(2),
        pompe.debit.toStringAsFixed(2),
        pompe.hmt.toStringAsFixed(2),
        pompe.energieSpecifique.toStringAsFixed(4),
        pompe.heuresFonctionnement.toString(),
        _formatCurrency(pompe.coutInvestissement),
      ]).toList(),
    );
  }

  /// Construit un tableau des donnees annuelles du comparatif
  static pw.Widget _buildAnnualDataTable(
    Map<String, dynamic> comparatifData,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
  ) {
    final annualData = comparatifData['annualData'] as Map<String, dynamic>? ?? {};
    
    final annees = annualData['annees'] as List<int>? ?? [];
    final consommationsAncien = annualData['consommationsAncien'] as List<double>? ?? [];
    final consommationsNouveau = annualData['consommationsNouveau'] as List<double>? ?? [];
    final coutsAncien = annualData['coutsAncien'] as List<double>? ?? [];
    final coutsNouveau = annualData['coutsNouveau'] as List<double>? ?? [];
    
    if (annees.isEmpty || consommationsAncien.isEmpty || consommationsNouveau.isEmpty) {
      return pw.Text('Pas de données annuelles disponibles');
    }
    
    // Construction du tableau
    final headers = ['Année', 'Consommation Ancien (kWh)', 'Consommation Nouveau (kWh)', 'Économie (kWh)', 'Coût Ancien (EUR)', 'Coût Nouveau (EUR)', 'Économie (EUR)'];
    final data = <List<String>>[];
    
    final maxLength = annees.length > consommationsAncien.length ? annees.length : consommationsAncien.length;
    final maxLength2 = maxLength > consommationsNouveau.length ? maxLength : consommationsNouveau.length;
    
    for (int i = 0; i < maxLength2; i++) {
      final year = i < annees.length ? annees[i].toString() : (i + 1).toString();
      final consoAnc = i < consommationsAncien.length ? consommationsAncien[i] : 0.0;
      final consoNouv = i < consommationsNouveau.length ? consommationsNouveau[i] : 0.0;
      final coutAnc = i < coutsAncien.length ? coutsAncien[i] : 0.0;
      final coutNouv = i < coutsNouveau.length ? coutsNouveau[i] : 0.0;
      
      data.add([
        year,
        numberFormat.format(consoAnc),
        numberFormat.format(consoNouv),
        numberFormat.format(consoAnc - consoNouv),
        currencyFormat.format(coutAnc),
        currencyFormat.format(coutNouv),
        currencyFormat.format(coutAnc - coutNouv),
      ]);
    }
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Données Détaillées par Année',
          style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(headers: headers, data: data),
      ],
    );
  }

  /// Formate un montant en devise (utilise EUR pour eviter les problemes de font)
  static String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2, locale: 'fr_FR').format(amount);
  }

  /// Nettoie un nom de fichier pour enlever les caracteres speciaux
  static String _sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r"[^a-zA-Z0-9_\-\s]"), '_').replaceAll(' ', '_');
  }
}
