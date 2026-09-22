import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/projet.dart';
import '../models/systeme.dart';
import 'settings_service.dart';

/// Service pour générer des rapports PDF à partir des données du projet
/// 
/// **Fonctionnalités :**
/// - Génération de rapports avec template et tags
/// - Intégration des graphiques comme images
/// - Export direct vers l'imprimante ou fichier PDF
///
/// **Utilisation :**
/// Appeler `genererRapportAvecTemplate()` depuis la page de résultats
class RapportService {
  /// Symbole de devise pour les PDF (EUR au lieu de € pour compatibilité police)
  static const String currencySymbol = 'EUR ';

  // ============================================================================
  // MÉTHODE PRINCIPALE : Génération avec données
  // ============================================================================

  /// Génère un rapport PDF en utilisant les données et l'affiche pour impression
  /// 
  /// **Paramètres :**
  /// - Tous les paramètres sont obligatoires sauf les images des graphiques
  /// - Les graphiques seront intégrés s'ils sont disponibles
  ///
  /// **Utilisation :**
  /// ```dart
  /// await RapportService.genererRapportAvecTemplate(
  ///   context,
  ///   projet,
  ///   systemeAncien,
  ///   systemeNouveau,
  ///   consommationsAncien,
  ///   consommationsNouveau,
  ///   coutsAncien,
  ///   coutsNouveau,
  ///   cumulativeAncien,
  ///   cumulativeNouveau,
  ///   economiesCumulees,
  ///   await RapportService.captureWidgetAsImage(_consoGraphKey),
  ///   await RapportService.captureWidgetAsImage(_coutGraphKey),
  ///   dureeEtude,
  /// );
  /// ```
  static Future<void> genererRapportAvecTemplate(
    BuildContext context,
    Projet projet,
    Systeme? systemeAncien,
    Systeme? systemeNouveau,
    List<double> consommationsAncien,
    List<double> consommationsNouveau,
    List<double> coutsAncien,
    List<double> coutsNouveau,
    List<double> cumulativeAncien,
    List<double> cumulativeNouveau,
    List<double> economiesCumulees,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
    int dureeEtude,
  ) async {
    await _genererEtAfficherRapport(
      context,
      projet,
      systemeAncien,
      systemeNouveau,
      consommationsAncien,
      consommationsNouveau,
      coutsAncien,
      coutsNouveau,
      cumulativeAncien,
      cumulativeNouveau,
      economiesCumulees,
      graphiqueConsommationImage,
      graphiqueCoutImage,
      dureeEtude,
      share: true,
    );
  }

  /// Sauvegarde le rapport avec template localement
  static Future<void> saveRapportAvecTemplateLocally(
    BuildContext context,
    Projet projet,
    Systeme? systemeAncien,
    Systeme? systemeNouveau,
    List<double> consommationsAncien,
    List<double> consommationsNouveau,
    List<double> coutsAncien,
    List<double> coutsNouveau,
    List<double> cumulativeAncien,
    List<double> cumulativeNouveau,
    List<double> economiesCumulees,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
    int dureeEtude,
  ) async {
    await _genererEtAfficherRapport(
      context,
      projet,
      systemeAncien,
      systemeNouveau,
      consommationsAncien,
      consommationsNouveau,
      coutsAncien,
      coutsNouveau,
      cumulativeAncien,
      cumulativeNouveau,
      economiesCumulees,
      graphiqueConsommationImage,
      graphiqueCoutImage,
      dureeEtude,
      share: false,
    );
  }

  /// Méthode interne pour générer le rapport PDF
  static Future<void> _genererEtAfficherRapport(
    BuildContext context,
    Projet projet,
    Systeme? systemeAncien,
    Systeme? systemeNouveau,
    List<double> consommationsAncien,
    List<double> consommationsNouveau,
    List<double> coutsAncien,
    List<double> coutsNouveau,
    List<double> cumulativeAncien,
    List<double> cumulativeNouveau,
    List<double> economiesCumulees,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
    int dureeEtude, {
    required bool share,
  }) async {
    try {
      // Créer le document PDF
      final pdf = pw.Document();

      // Ajouter les pages au rapport
      _ajouterPageDeGarde(pdf, projet, systemeAncien, systemeNouveau, dureeEtude);
      _ajouterPageSynthese(pdf, projet, systemeAncien, systemeNouveau, 
          consommationsAncien, consommationsNouveau, 
          cumulativeAncien, cumulativeNouveau, economiesCumulees, dureeEtude);
      _ajouterPageDetailsAnnuels(pdf, projet, systemeAncien, systemeNouveau, 
          consommationsAncien, consommationsNouveau, coutsAncien, coutsNouveau, 
          cumulativeAncien, cumulativeNouveau, economiesCumulees, dureeEtude);
      
      // Ajouter les graphiques (si disponibles)
      if (graphiqueConsommationImage != null || graphiqueCoutImage != null) {
        _ajouterPageGraphiques(pdf, graphiqueConsommationImage, graphiqueCoutImage, dureeEtude);
      }

      // Générer le PDF
      final bytes = await pdf.save();
      final dateStr = _formatDate(DateTime.now());
      final sanitizedName = _sanitizeFilename(projet.nomSite);
      final filename = 'Rapport_${sanitizedName}_$dateStr.pdf';

      if (share) {
        // Afficher le PDF pour impression/partage
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
        );
      } else {
        // Sauvegarder localement
        // Utiliser le dossier personnalisé si défini, sinon le dossier Documents
        final settings = SettingsService.instance;
        Directory dir;
        if (settings.pdfExportDirectory != null && settings.pdfExportDirectory!.isNotEmpty) {
          dir = Directory(settings.pdfExportDirectory!);
          // Créer le dossier s'il n'existe pas
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
        final filePath = p.join(dir.path, filename);
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF sauvegardé: $filePath')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la génération du rapport: $e')),
      );
    }
  }

  // ============================================================================
  // PAGES DU RAPPORT
  // ============================================================================

  /// Ajoute la page de garde au rapport
  static void _ajouterPageDeGarde(
    pw.Document pdf,
    Projet projet,
    Systeme? systemeAncien,
    Systeme? systemeNouveau,
    int dureeEtude,
  ) {
    final investAncien = systemeAncien?.coutInvestissementTotal ?? 0.0;
    final investNouveau = systemeNouveau?.coutInvestissementTotal ?? 0.0;
    
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(height: 50),
                  pw.Text(
                    'Étude Comparative Économique',
                    style: _styleTitrePrincipal,
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    projet.nomSite,
                    style: _styleTitreSecondaire,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Système Ancien : ${systemeAncien?.nom ?? 'Non défini'}',
                    style: _styleTexteNormal,
                  ),
                  pw.Text(
                    'Système Nouveau : ${systemeNouveau?.nom ?? 'Non défini'}',
                    style: _styleTexteNormal,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Durée de l\'étude : $dureeEtude ans',
                    style: _styleTexteNormal,
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    'Investissement Ancien : ${_formatCurrency(investAncien)}',
                    style: _styleTexteNormal,
                  ),
                  pw.Text(
                    'Investissement Nouveau : ${_formatCurrency(investNouveau)}',
                    style: _styleTexteNormal,
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    'Généré le ${_formatDate(DateTime.now())}',
                    style: _styleTextePetit,
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }

  /// Ajoute la page de synthèse au rapport
  static void _ajouterPageSynthese(
    pw.Document pdf,
    Projet projet,
    Systeme? systemeAncien,
    Systeme? systemeNouveau,
    List<double> consommationsAncien,
    List<double> consommationsNouveau,
    List<double> cumulativeAncien,
    List<double> cumulativeNouveau,
    List<double> economiesCumulees,
    int dureeEtude,
  ) {
    // Calculer les totaux
    final totalAncien = cumulativeAncien.isNotEmpty ? cumulativeAncien.last : 0.0;
    final totalNouveau = cumulativeNouveau.isNotEmpty ? cumulativeNouveau.last : 0.0;
    final economieTotale = totalAncien - totalNouveau;
    
    // Calculer le seuil de rentabilité
    int seuilRentabilite = 0;
    for (int i = 0; i < economiesCumulees.length; i++) {
      if (economiesCumulees[i] >= 0) {
        seuilRentabilite = i + 1;
        break;
      }
    }
    
    // Calculer le taux de rentabilité
    final investAncien = systemeAncien?.coutInvestissementTotal ?? 0.0;
    final investNouveau = systemeNouveau?.coutInvestissementTotal ?? 0.0;
    final coutEnergAncien = totalAncien - investAncien;
    final coutEnergNouveau = totalNouveau - investNouveau;
    final economieEnergTotale = coutEnergAncien - coutEnergNouveau;
    final tauxRentabilite = economieTotale > 0 
        ? (economieTotale / investNouveau * 100) 
        : 0.0;
    
    // Calculer consommation moyenne
    final consoMoyAnc = consommationsAncien.isNotEmpty 
        ? consommationsAncien.reduce((a, b) => a + b) / consommationsAncien.length 
        : 0.0;
    final consoMoyNouv = consommationsNouveau.isNotEmpty 
        ? consommationsNouveau.reduce((a, b) => a + b) / consommationsNouveau.length 
        : 0.0;

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Text('Synthèse', style: _styleTitrePage),
            pw.SizedBox(height: 20),
            
            // Tableau comparatif
            pw.Text('Comparaison des Systèmes', style: _styleSousTitre),
            pw.SizedBox(height: 10),
            _buildTableauComparatif(
              systemeAncien?.nom ?? 'Ancien',
              systemeNouveau?.nom ?? 'Nouveau',
              investAncien,
              investNouveau,
              totalAncien,
              totalNouveau,
              consoMoyAnc,
              consoMoyNouv,
            ),
            pw.SizedBox(height: 20),
            
            // Résultats
            pw.Text('Résultats', style: _styleSousTitre),
            pw.SizedBox(height: 10),
            _buildLigneResultat('Économie totale sur $dureeEtude ans :', 
                _formatCurrency(economieTotale), 
                economieTotale >= 0 ? PdfColors.green700 : PdfColors.red700),
            pw.SizedBox(height: 5),
            _buildLigneResultat('Seuil de rentabilité :', 
                seuilRentabilite > 0 ? 'Année $seuilRentabilite' : 'Non atteint', null),
            pw.SizedBox(height: 5),
            _buildLigneResultat('Taux de rentabilité :', 
                '${tauxRentabilite.toStringAsFixed(2)}%', null),
            pw.SizedBox(height: 5),
            _buildLigneResultat('Économie énergétique totale :', 
                _formatCurrency(economieEnergTotale), 
                economieEnergTotale >= 0 ? PdfColors.green700 : PdfColors.red700),
          ];
        },
      ),
    );
  }

  /// Ajoute la page avec les détails annuels
  static void _ajouterPageDetailsAnnuels(
    pw.Document pdf,
    Projet projet,
    Systeme? systemeAncien,
    Systeme? systemeNouveau,
    List<double> consommationsAncien,
    List<double> consommationsNouveau,
    List<double> coutsAncien,
    List<double> coutsNouveau,
    List<double> cumulativeAncien,
    List<double> cumulativeNouveau,
    List<double> economiesCumulees,
    int dureeEtude,
  ) {
    // Créer les données du tableau
    final List<pw.TableRow> tableRows = [];
    
    // En-tête
    tableRows.add(
      pw.TableRow(
        children: [
          _celluleTableau('Année', _styleHeader),
          _celluleTableau('Conso Ancien\n(kWh)', _styleHeader),
          _celluleTableau('Conso Nouveau\n(kWh)', _styleHeader),
          _celluleTableau('Éco. kWh', _styleHeader),
          _celluleTableau('Coût Ancien\n(EUR)', _styleHeader),
          _celluleTableau('Coût Nouveau\n(EUR)', _styleHeader),
          _celluleTableau('Éco. EUR', _styleHeader),
          _celluleTableau('Cumul EUR', _styleHeader),
        ],
      ),
    );
    
    // Données
    final investAncien = systemeAncien?.coutInvestissementTotal ?? 0.0;
    final investNouveau = systemeNouveau?.coutInvestissementTotal ?? 0.0;
    
    for (int i = 0; i < dureeEtude && i < consommationsAncien.length && i < coutsAncien.length; i++) {
      final annee = i + 1;
      final consoAnc = consommationsAncien[i];
      final consoNouv = consommationsNouveau[i];
      final coutAnc = coutsAncien[i];
      final coutNouv = coutsNouveau[i];
      final economieKWh = consoAnc - consoNouv;
      final economieEuro = (i == 0 ? (investAncien - investNouveau) : 0.0) + (coutAnc - coutNouv);
      final cumuleEuro = economiesCumulees.length > i ? economiesCumulees[i] : 0.0;
      
      tableRows.add(
        pw.TableRow(
          children: [
            _celluleTableau(annee.toString(), _styleCellule),
            _celluleTableau('${_formatNumber(consoAnc)}', _styleCellule),
            _celluleTableau('${_formatNumber(consoNouv)}', _styleCellule),
            _celluleTableau('${_formatNumber(economieKWh)}', _styleCellule),
            _celluleTableau(_formatCurrency(coutAnc), _styleCellule),
            _celluleTableau(_formatCurrency(coutNouv), _styleCellule),
            _celluleTableau(_formatCurrency(economieEuro), _styleCellule),
            _celluleTableau(_formatCurrency(cumuleEuro), _styleCellule),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Text('Détails Annuels', style: _styleTitrePage),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: tableRows,
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              '* Les coûts incluent l\'investissement initial uniquement en année 1',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );
  }

  /// Ajoute la page avec les graphiques
  static void _ajouterPageGraphiques(
    pw.Document pdf,
    Uint8List? graphiqueConsommationImage,
    Uint8List? graphiqueCoutImage,
    int dureeEtude,
  ) {
    final List<pw.Widget> widgets = [];
    
    widgets.add(
      pw.Text('Graphiques', style: _styleTitrePage),
    );
    widgets.add(pw.SizedBox(height: 20));

    // Graphique de consommation
    if (graphiqueConsommationImage != null) {
      widgets.add(
        pw.Text('Consommation Énergétique sur $dureeEtude ans', style: _styleSousTitre),
      );
      widgets.add(pw.SizedBox(height: 10));
      widgets.add(
        pw.Center(
          child: pw.Image(
            pw.MemoryImage(graphiqueConsommationImage),
            width: 500,
            height: 300,
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 30));
    }

    // Graphique de coût
    if (graphiqueCoutImage != null) {
      widgets.add(
        pw.Text('Coût sur $dureeEtude ans', style: _styleSousTitre),
      );
      widgets.add(pw.SizedBox(height: 10));
      widgets.add(
        pw.Center(
          child: pw.Image(
            pw.MemoryImage(graphiqueCoutImage),
            width: 500,
            height: 300,
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return widgets;
        },
      ),
    );
  }

  // ============================================================================
  // HELPERS POUR LA MISE EN PAGE
  // ============================================================================

  /// Style pour les titres principaux
  static const _styleTitrePrincipal = pw.TextStyle(
    fontSize: 24,
    fontWeight: pw.FontWeight.bold,
  );

  /// Style pour les titres de page
  static const _styleTitrePage = pw.TextStyle(
    fontSize: 20,
    fontWeight: pw.FontWeight.bold,
  );

  /// Style pour les sous-titres
  static const _styleSousTitre = pw.TextStyle(
    fontSize: 16,
    fontWeight: pw.FontWeight.bold,
  );

  /// Style pour les titres secondaires
  static const _styleTitreSecondaire = pw.TextStyle(
    fontSize: 18,
    fontWeight: pw.FontWeight.bold,
  );

  /// Style pour le texte normal
  static const _styleTexteNormal = pw.TextStyle(
    fontSize: 14,
  );

  /// Style pour le texte petit
  static const _styleTextePetit = pw.TextStyle(
    fontSize: 12,
    color: PdfColors.grey600,
  );

  /// Style pour les en-têtes de tableau
  static const _styleHeader = pw.TextStyle(
    fontSize: 12,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.white,
  );

  /// Style pour les cellules de tableau
  static const _styleCellule = pw.TextStyle(
    fontSize: 12,
  );

  /// Crée une cellule de tableau avec fond coloré pour l'en-tête
  static pw.Widget _celluleTableau(String text, pw.TextStyle style, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      color: isHeader ? PdfColors.blue700 : null,
      child: pw.Text(text, style: style, textAlign: pw.TextAlign.center),
    );
  }

  /// Crée une ligne de résultat (clé : valeur)
  static pw.Widget _buildLigneResultat(String label, String value, PdfColor? color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: _styleTexteNormal),
        pw.Text(
          value,
          style: _styleTexteNormal.copyWith(
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Crée un tableau comparatif
  static pw.Widget _buildTableauComparatif(
    String nomAncien,
    String nomNouveau,
    double investAncien,
    double investNouveau,
    double totalAncien,
    double totalNouveau,
    double consoMoyAnc,
    double consoMoyNouv,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          children: [
            _celluleTableau('Système', _styleHeader, isHeader: true),
            _celluleTableau('Investissement', _styleHeader, isHeader: true),
            _celluleTableau('Coût Total', _styleHeader, isHeader: true),
            _celluleTableau('Consommation Moyenne', _styleHeader, isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _celluleTableau(nomAncien, _styleCellule),
            _celluleTableau(_formatCurrency(investAncien), _styleCellule),
            _celluleTableau(_formatCurrency(totalAncien), _styleCellule),
            _celluleTableau('${_formatNumber(consoMoyAnc)} kWh', _styleCellule),
          ],
        ),
        pw.TableRow(
          children: [
            _celluleTableau(nomNouveau, _styleCellule),
            _celluleTableau(_formatCurrency(investNouveau), _styleCellule),
            _celluleTableau(_formatCurrency(totalNouveau), _styleCellule),
            _celluleTableau('${_formatNumber(consoMoyNouv)} kWh', _styleCellule),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // FONCTIONS UTILITAIRES
  // ============================================================================

  /// Nettoie un nom de fichier pour enlever les caracteres speciaux
  /// Supprime les caracteres interdits dans les noms de fichiers Windows
  static String _sanitizeFilename(String filename) {
    // Remplacer les caracteres interdits dans les noms de fichiers Windows
    // < > : " / \ | ? *
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '_')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'_+'), '_')  // Supprimer les doubles underscores
        .replaceAll(RegExp(r'^-+|-+$'), ''); // Supprimer les tirets en debut/fin
  }

  /// Formate un nombre comme monnaie
  static String _formatCurrency(double value) {
    return '${currencySymbol}${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2).replaceAll('.', ',')}';
  }

  /// Formate un nombre avec des séparateurs de milliers
  static String _formatNumber(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2) 
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ') 
        .replaceAll('.', ',')
        .trim();
  }

  /// Formate une date en DD/MM/YYYY
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Capture un widget Flutter comme image
  /// Utiliser avec RepaintBoundary
  static Future<Uint8List?> captureWidgetAsImage(GlobalKey key) async {
    try {
      final RenderRepaintBoundary? boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Erreur lors de la capture du widget: $e');
    }
    return null;
  }
}
