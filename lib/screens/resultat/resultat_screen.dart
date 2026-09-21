import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import '../../models/projet.dart';
import '../../models/contact.dart';
import '../../models/systeme.dart';
import '../../models/pompe.dart';
import '../../services/calcul_service.dart';
import 'dart:math' as math;
import 'package:wu_ect/utils/decimation.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/settings_dialog.dart';
import 'package:intl/intl.dart';
import '../../utils/error_handler.dart';
import '../../utils/exportPDF.dart';
import '../contact/contact_form_screen.dart';


// Fonction wrapper pour compute() - doit être top-level
Map<String, List<double>> _calculerDonnees10AnsWrapper(List<dynamic> args) {
  final pompes = args[0] as List<Pompe>;
  final projet = args[1] as Projet;
  final dureeAnnee = args.length > 2 ? args[2] as int : 10;
  return CalculService.calculerDonnees10AnsAvecPompes(pompes, projet, dureeAnnee: dureeAnnee);
}

class ResultatScreen extends StatefulWidget {
  final int projetId;

  const ResultatScreen({super.key, required this.projetId});

  @override
  State<ResultatScreen> createState() => _ResultatScreenState();
}

class _ResultatScreenState extends State<ResultatScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final SettingsService _settings = SettingsService.instance;

  // Durée de l'étude en années (par défaut 10 ans)
  late int _dureeEtude;

  // Clés pour capturer les graphiques en image
  final GlobalKey _consoGraphKey = GlobalKey();
  final GlobalKey _coutGraphKey = GlobalKey();

  Projet? _projet;
  Contact? _contact;
  List<Contact> _contacts = [];
  int? _selectedContactId;
  Systeme? _systemeAncien;
  Systeme? _systemeNouveau;
  List<double> _consommationsAncien = [];
  List<double> _consommationsNouveau = [];
  List<double> _coutsAncien = [];
  List<double> _coutsNouveau = [];
  List<FlSpot> _spotsConsommationAncien = [];
  List<FlSpot> _spotsConsommationNouveau = [];
  List<FlSpot> _spotsCoutAncien = [];
  List<FlSpot> _spotsCoutNouveau = [];
  List<int> _annees = [];
  Map<String, dynamic>? _roiData;

  List<Pompe> _pompesAncien = [];
  List<Pompe> _pompesNouveau = [];
  double _volumeAncien = 0;
  double _volumeNouveau = 0;
  double _energieAncien = 0;
  double _energieNouveau = 0;
  
  // Parameters for detailed verification - P1 and Hours per year for each system
  List<double> _p1AncienParAnnee = [];
  List<double> _p1NouveauParAnnee = [];
  List<double> _muAncienParAnnee = [];
  List<double> _muNouveauParAnnee = [];
  int _heuresAncienTotal = 0;
  int _heuresNouveauTotal = 0;

  // Detailed P1 calculation strings for each year and system
  List<String> _p1AncienDetailParAnnee = [];
  List<String> _p1NouveauDetailParAnnee = [];

  // Detailed cost calculation strings for each year and system
  List<String> _coutsAncienDetailParAnnee = [];
  List<String> _coutsNouveauDetailParAnnee = [];

  bool _isLoading = true;
  bool _safeMode = false;


  @override
  void initState() {
    super.initState();
    debugPrint('[DEBUG ResultatScreen] initState appelé - projetId: ${widget.projetId}');
    _dureeEtude = _settings.dureeEtudeAnnee;
    _loadData();
  }

  Widget _buildPlaceholder(String title) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              height: 200,
              child: Center(child: Text('Charts disabled (safe mode)')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphiqueFromSpots(
    String title,
    String unite,
    List<FlSpot> ancien,
    List<FlSpot> nouveau,
    Color colorAncien,
    Color colorNouveau,
    bool isCurrency, {
    bool forceMinYToZero = false,
    required String unit,
  }) {
    if (ancien.isEmpty && nouveau.isEmpty) {
      return _buildPlaceholder(title);
    }

    const minX = 0.0;
    var maxX = math.max(
      ancien.isNotEmpty ? ancien.map((s) => s.x).reduce((a, b) => a > b ? a : b) : 0.0,
      nouveau.isNotEmpty ? nouveau.map((s) => s.x).reduce((a, b) => a > b ? a : b) : 0.0,
    );
    var minY = math.min(
      ancien.isNotEmpty ? ancien.map((s) => s.y).reduce((a, b) => a < b ? a : b) : 0.0,
      nouveau.isNotEmpty ? nouveau.map((s) => s.y).reduce((a, b) => a < b ? a : b) : 0.0,
    );
    var maxY = math.max(
      ancien.isNotEmpty ? ancien.map((s) => s.y).reduce((a, b) => a > b ? a : b) : 0.0,
      nouveau.isNotEmpty ? nouveau.map((s) => s.y).reduce((a, b) => a > b ? a : b) : 0.0,
    );

    // For cost charts, enforce Y starts at 0 and maxY is the maximum cumulative cost between series
    if (isCurrency) {
      final maxAnc = ancien.isNotEmpty ? ancien.map((s) => s.y).reduce((a, b) => a > b ? a : b) : 0.0;
      final maxNouv = nouveau.isNotEmpty ? nouveau.map((s) => s.y).reduce((a, b) => a > b ? a : b) : 0.0;
      minY = 0.0;
      maxY = math.max(maxAnc, maxNouv);
      if (maxY <= 0) maxY = 1.0;
    }
    
    // Force Y axis origin to 0 for consumption charts
    if (forceMinYToZero) {
      minY = 0.0;
    }

    if (maxX <= minX) maxX = minX + 1.0;
    if (maxY <= minY) {
      final delta = (minY.abs() * 0.01).clamp(1.0, double.infinity);
      maxY = minY + delta;
    }

    String formatAxis(double v) => _formatNumber(v);

    // Years for x-axis labels (use available years or numeric indices)
    final xLabels = _annees.isNotEmpty ? _annees : List.generate((maxX - minX + 1).toInt(), (i) => i);
    final int xTickCount = xLabels.length;
    const int yTickCount = 10; // number of portions -> produces yTickCount+1 horizontal lines/labels

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                // Legend
                Row(children: [
                    Row(children: [Container(width: 16, height: 8, color: colorAncien), const SizedBox(width: 6), const Text('Ancien')]),
                  const SizedBox(width: 12),
                  Row(children: [Container(width: 16, height: 8, color: colorNouveau), const SizedBox(width: 6), const Text('Nouveau')]),
                ])
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 300,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Y axis labels (min/max) - aligned to the right for better readability
                  SizedBox(
                      width: 80,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Unit label on Y axis
                            Text(unite, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(yTickCount + 1, (i) {
                                  final v = minY + (maxY - minY) * ((yTickCount - i) / yTickCount);
                                  return Text(formatAxis(v), 
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.right);
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Chart area
                  Expanded(
                    child: _SimpleLineChart(
                      ancien: ancien,
                      nouveau: nouveau,
                      colorAncien: colorAncien,
                      colorNouveau: colorNouveau,
                      minX: minX,
                      maxX: maxX,
                      minY: minY,
                      maxY: maxY,
                      xTickCount: xTickCount,
                      yTickCount: yTickCount,
                      isCurrency: isCurrency,
                      unit: unit,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            // X axis labels: show every year evenly spaced with precise alignment
            // Each label is positioned exactly under its corresponding vertical grid line
            Row(
              children: [
                const SizedBox(width: 80), // align with Y labels column
                Expanded(
                  child: xTickCount <= 1
                      ? Center(child: Text('${xLabels.first}', style: const TextStyle(fontSize: 11)))
                      : Row(
                          children: List.generate(xTickCount, (i) {
                            final lbl = xLabels.length > i ? xLabels[i] : (minX + (maxX - minX) * (i / (xTickCount - 1))).toInt();
                            return Expanded(
                              child: Center(
                                child: Text('$lbl', 
                                    style: const TextStyle(fontSize: 11),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            );
                          }),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    debugPrint('[DEBUG ResultatScreen] _loadData() démarré');
    // Recharger la durée de l'étude au cas où elle a été modifiée
    _dureeEtude = _settings.dureeEtudeAnnee;
    setState(() => _isLoading = true);
    try {
      debugPrint('[DEBUG ResultatScreen] Chargement du projet...');
      final projet = await _db.getProjetById(widget.projetId);
      if (projet == null) {
        debugPrint('[DEBUG ResultatScreen] Projet non trouvé');
        setState(() => _isLoading = false);
        if (mounted) {
          ErrorHandler.showSnackBar(context, 'Projet non trouvé', error: true);
          Navigator.pop(context);
        }
        return;
      }

      debugPrint('[DEBUG ResultatScreen] Chargement des systèmes...');
      final systemes = await _db.getSystemesByProjetId(widget.projetId);
      if (systemes.length != 2) {
        setState(() => _isLoading = false);
        if (mounted) {
          ErrorHandler.showSnackBar(context, 'Un projet doit avoir exactement 2 systèmes pour le comparatif', error: true);
          Navigator.pop(context);
        }
        return;
      }

      _projet = projet;
      
      // Charger le contact et tous les contacts pour le sélecteur
      _contact = await _db.getContactById(projet.contactId);
      _contacts = await _db.getAllContacts();
      _selectedContactId = _contact?.id;
      
      final ancienSystems = systemes.where((s) => s.nom.toLowerCase().contains('ancien')).toList();
      final nouveauSystems = systemes.where((s) => s.nom.toLowerCase().contains('nouveau')).toList();
      _systemeAncien = ancienSystems.isNotEmpty ? ancienSystems.first : null;
      _systemeNouveau = nouveauSystems.isNotEmpty ? nouveauSystems.first : null;

      if (_systemeAncien == null || _systemeNouveau == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ErrorHandler.showSnackBar(context, 'Les systèmes doivent contenir "Ancien" et "Nouveau" dans leur nom', error: true);
          Navigator.pop(context);
        }
        return;
      }

      final pompesAncienFuture = _db.getPompesBySystemeId(_systemeAncien!.id!);
      final pompesNouveauFuture = _db.getPompesBySystemeId(_systemeNouveau!.id!);
      _pompesAncien = await pompesAncienFuture;
      _pompesNouveau = await pompesNouveauFuture;

      // ========================================================================
      // CALCUL 1: Volume Total et Énergie Totale
      // ========================================================================
      // Volume = Σ(Débit × Heures de fonctionnement × $_dureeEtude ans)
      // Énergie = Σ(Énergie Spécifique × Débit × Heures de fonctionnement × $_dureeEtude ans)
      // Ces valeurs sont utilisées pour l'affichage comparatif des systèmes
      _volumeAncien = _calculerVolumeTotal(_pompesAncien, _dureeEtude);
      _volumeNouveau = _calculerVolumeTotal(_pompesNouveau, _dureeEtude);
      _energieAncien = _calculerEnergieTotale(_pompesAncien, _dureeEtude);
      _energieNouveau = _calculerEnergieTotale(_pompesNouveau, _dureeEtude);

      // Générer les prochaines années à partir de l'année en cours
      final anneeEnCours = DateTime.now().year;
      _annees = List.generate(_dureeEtude, (i) => anneeEnCours + i);

      // ========================================================================
      // CALCUL 2: Données sur $_dureeEtude ans (Consommations et Coûts)
      // ========================================================================
      // Calcul des consommations et coûts énergétiques annuels pour chaque système
      // sur une période de $_dureeEtude ans, en tenant compte de :
      // - L'augmentation annuelle du coût de l'énergie
      // - La perte de rendement annuelle des équipements
      // Retourne un Map avec 'consommations' et 'coutsEnergetiques'
      
      // Use default parameters from SettingsService if configured
      final projetForCalculation = _settings.useDefaultParams
          ? Projet(
              id: projet.id,
              nomSite: projet.nomSite,
              contactId: projet.contactId,
              coutEnergie: _settings.coutEnergieDefault,
              pourcentageAugmentationEnergie: _settings.pourcentageAugmentationEnergieDefault,
              percentagePerteRendement: _settings.perteRendementDefault,
            )
          : projet;
      
      final donneesAncienFuture = compute(_calculerDonnees10AnsWrapper, [_pompesAncien, projetForCalculation, _dureeEtude]);
      final donneesNouveauFuture = compute(_calculerDonnees10AnsWrapper, [_pompesNouveau, projetForCalculation, _dureeEtude]);
      final results = await Future.wait<Map<String, List<double>>>([donneesAncienFuture, donneesNouveauFuture]);

      final donneesAncien = results[0];
      final donneesNouveau = results[1];

      _consommationsAncien = donneesAncien['consommations']!;
      _consommationsNouveau = donneesNouveau['consommations']!;
      _coutsAncien = donneesAncien['coutsEnergetiques']!;
      _coutsNouveau = donneesNouveau['coutsEnergetiques']!;

      // ========================================================================
      // CALCUL 2b: Paramètres pour vérification (P1, Heures et μ)
      // ========================================================================
      // Calcul des P1 totales et rendements moyens par année pour chaque système
      // afin de permettre la vérification détaillée des calculs de consommation
      // Use default parameters from SettingsService if configured, otherwise use project parameters
      final effectivePerteRendement = _settings.useDefaultParams ? _settings.perteRendementDefault : projet.percentagePerteRendement;
      
      // Calculate P1 with details for each year
      _p1AncienParAnnee = [];
      _p1NouveauParAnnee = [];
      _p1AncienDetailParAnnee = [];
      _p1NouveauDetailParAnnee = [];
      
      for (int i = 0; i < _dureeEtude; i++) {
        final resultAncien = _calculerP1TotaleSystemeAvecDetail(_pompesAncien, effectivePerteRendement, _annees[i]);
        final resultNouveau = _calculerP1TotaleSystemeAvecDetail(_pompesNouveau, effectivePerteRendement, _annees[i]);
        _p1AncienParAnnee.add(resultAncien['p1'] as double);
        _p1NouveauParAnnee.add(resultNouveau['p1'] as double);
        _p1AncienDetailParAnnee.add(resultAncien['detail'] as String);
        _p1NouveauDetailParAnnee.add(resultNouveau['detail'] as String);
      }
      
      _muAncienParAnnee = List.generate(_dureeEtude, (i) => 
          _calculerMuMoyenSysteme(_pompesAncien, effectivePerteRendement, _annees[i]));
      _muNouveauParAnnee = List.generate(_dureeEtude, (i) => 
          _calculerMuMoyenSysteme(_pompesNouveau, effectivePerteRendement, _annees[i]));
      
      _heuresAncienTotal = _calculerHeuresTotalesSysteme(_pompesAncien);
      _heuresNouveauTotal = _calculerHeuresTotalesSysteme(_pompesNouveau);
      
      // Calculate cost details for each year
      final coutEnergie = _settings.useDefaultParams ? _settings.coutEnergieDefault : projet.coutEnergie;
      final pourcentageAugmentationEnergie = _settings.useDefaultParams ? _settings.pourcentageAugmentationEnergieDefault : projet.pourcentageAugmentationEnergie;
      final anneeDebut = _annees.isEmpty ? DateTime.now().year : _annees[0];
      
      _coutsAncienDetailParAnnee = [];
      _coutsNouveauDetailParAnnee = [];
      
      for (int i = 0; i < _dureeEtude; i++) {
        final resultAncien = _calculerCoutTotaleSystemeAvecDetail(
          _pompesAncien,
          coutEnergie,
          pourcentageAugmentationEnergie,
          effectivePerteRendement,
          _annees[i],
          anneeDebut,
        );
        final resultNouveau = _calculerCoutTotaleSystemeAvecDetail(
          _pompesNouveau,
          coutEnergie,
          pourcentageAugmentationEnergie,
          effectivePerteRendement,
          _annees[i],
          anneeDebut,
        );
        _coutsAncienDetailParAnnee.add(resultAncien['detail'] as String);
        _coutsNouveauDetailParAnnee.add(resultNouveau['detail'] as String);
      }

      // ========================================================================
      // CALCUL 3: Intégration de l'investissement initial
      // ========================================================================
      // Le coût d'investissement du système nouveau est ajouté à la première année
      // pour refléter le coût total initial (investissement + première année d'exploitation)
      // Intégrer le montant d'investissement dans la première année du coût (pour le système nouveau)
      try {
        if (_systemeNouveau != null && _coutsNouveau.isNotEmpty) {
          _coutsNouveau[0] = _coutsNouveau[0] + (_systemeNouveau!.coutInvestissementTotal);
        }
      } catch (_) {}

      try {
        // ========================================================================
        // CALCUL 4: Consommations et Coûts cumulatifs pour les graphiques
        // ========================================================================
        // Construction des séries cumulatives
        
        // Consommations cumulées (sans investissement, juste la consommation énergétique)
        final consommationsAncienCumulees = <double>[];
        double sumConsAnc = 0.0;
        for (var i = 0; i < _consommationsAncien.length; i++) {
          sumConsAnc += _consommationsAncien[i];
          consommationsAncienCumulees.add(sumConsAnc);
        }

        final consommationsNouveauCumulees = <double>[];
        double sumConsNouv = 0.0;
        for (var i = 0; i < _consommationsNouveau.length; i++) {
          sumConsNouv += _consommationsNouveau[i];
          consommationsNouveauCumulees.add(sumConsNouv);
        }
        
        // Coûts cumulatifs qui incluent :
        // - L'investissement initial (une seule fois en année 0)
        // - Les coûts énergétiques annuels cumulés
        // Cela permet d'afficher l'évolution du coût total sur $_dureeEtude ans
        final cumulativeAncien = <double>[];
        double sumAnc = 0.0;
        for (var i = 0; i < _coutsAncien.length; i++) {
          sumAnc += _coutsAncien[i];
          final investAnc = _systemeAncien?.coutInvestissementTotal ?? 0.0;
          cumulativeAncien.add(investAnc + sumAnc);
        }

        final cumulativeNouveau = <double>[];
        double sumNouv = 0.0;
        for (var i = 0; i < _coutsNouveau.length; i++) {
          sumNouv += _coutsNouveau[i];
          final investNouv = _systemeNouveau?.coutInvestissementTotal ?? 0.0;
          cumulativeNouveau.add(investNouv + sumNouv);
        }

        // ========================================================================
        // CALCUL 5: Préparation des points pour les graphiques (Downsampling)
        // ========================================================================
        // Réduction du nombre de points pour optimiser l'affichage des graphiques
        // tout en conservant la forme des courbes (algorithme LTTB - Largest Triangle Three Buckets)
        // Limite à 500 points maximum par série pour éviter les problèmes de performance
        final spotsAncien = await compute(computeDownsampleSerialized, {'values': consommationsAncienCumulees, 'maxPoints': 500});
        final spotsNouveau = await compute(computeDownsampleSerialized, {'values': consommationsNouveauCumulees, 'maxPoints': 500});
        final spotsCoutAncien = await compute(computeDownsampleSerialized, {'values': cumulativeAncien, 'maxPoints': 500});
        final spotsCoutNouveau = await compute(computeDownsampleSerialized, {'values': cumulativeNouveau, 'maxPoints': 500});

        // Conversion des points downsamplés en FlSpot pour fl_chart
        _spotsConsommationAncien = spotsAncien.map((m) => FlSpot(m['x']!, m['y']!)).toList();
        _spotsConsommationNouveau = spotsNouveau.map((m) => FlSpot(m['x']!, m['y']!)).toList();
        _spotsCoutAncien = spotsCoutAncien.map((m) => FlSpot(m['x']!, m['y']!)).toList();
        _spotsCoutNouveau = spotsCoutNouveau.map((m) => FlSpot(m['x']!, m['y']!)).toList();
      } catch (_) {
        // Consommations cumulées pour le cas sans downsampling
        final consommationsAncienCumulees = <double>[];
        double sumConsAnc = 0.0;
        for (var i = 0; i < _consommationsAncien.length; i++) {
          sumConsAnc += _consommationsAncien[i];
          consommationsAncienCumulees.add(sumConsAnc);
        }

        final consommationsNouveauCumulees = <double>[];
        double sumConsNouv = 0.0;
        for (var i = 0; i < _consommationsNouveau.length; i++) {
          sumConsNouv += _consommationsNouveau[i];
          consommationsNouveauCumulees.add(sumConsNouv);
        }
        
        _spotsConsommationAncien = List.generate(consommationsAncienCumulees.length, (i) => FlSpot(i.toDouble(), consommationsAncienCumulees[i]));
        _spotsConsommationNouveau = List.generate(consommationsNouveauCumulees.length, (i) => FlSpot(i.toDouble(), consommationsNouveauCumulees[i]));

        final cumulativeAncien = <double>[];
        double sumAnc = 0.0;
        for (var i = 0; i < _coutsAncien.length; i++) {
          sumAnc += _coutsAncien[i];
          cumulativeAncien.add((_systemeAncien?.coutInvestissementTotal ?? 0.0) + sumAnc);
        }

        final cumulativeNouveau = <double>[];
        double sumNouv = 0.0;
        for (var i = 0; i < _coutsNouveau.length; i++) {
          sumNouv += _coutsNouveau[i];
          cumulativeNouveau.add((_systemeNouveau?.coutInvestissementTotal ?? 0.0) + sumNouv);
        }

        _spotsCoutAncien = List.generate(cumulativeAncien.length, (i) => FlSpot(i.toDouble(), cumulativeAncien[i]));
        _spotsCoutNouveau = List.generate(cumulativeNouveau.length, (i) => FlSpot(i.toDouble(), cumulativeNouveau[i]));
      }

      final debugBuf = StringBuffer();
      debugBuf.writeln('safeMode=$_safeMode');
      debugBuf.writeln('consommationsAncien=${_consommationsAncien.length} spotsAncien=${_spotsConsommationAncien.length}');
      debugBuf.writeln('consommationsNouveau=${_consommationsNouveau.length} spotsNouveau=${_spotsConsommationNouveau.length}');
      debugBuf.writeln('coutsAncien=${_coutsAncien.length} spotsCoutAncien=${_spotsCoutAncien.length}');
      debugBuf.writeln('coutsNouveau=${_coutsNouveau.length} spotsCoutNouveau=${_spotsCoutNouveau.length}');

      // ========================================================================
      // CALCUL 6: Analyse de Rentabilité (ROI - Return On Investment)
      // ========================================================================
      // Calcul du temps de retour sur investissement pour comparer les deux systèmes
      final coutAncienTotal = (donneesAncien['coutsEnergetiques'] as List<double>).reduce((a, b) => a + b);
      final coutNouveauTotal = (donneesNouveau['coutsEnergetiques'] as List<double>).reduce((a, b) => a + b);
      
      // Économies totales sur $_dureeEtude ans (sans compter l'investissement)
      final economieTotale = coutAncienTotal - coutNouveauTotal;
      
      // Différence d'investissement entre les deux systèmes
      final deltaInvestissement = _systemeNouveau!.coutInvestissementTotal - _systemeAncien!.coutInvestissementTotal;

      // Calcul du ROI en années
      // Formule: ROI = Delta Investissement / (Économie annuelle moyenne)
      // où Économie annuelle moyenne = économieTotale / $_dureeEtude
      double roiAnnee = double.infinity;
      if (deltaInvestissement > 0 && economieTotale > 0) {
        roiAnnee = deltaInvestissement / (economieTotale / _dureeEtude);
      } else if (deltaInvestissement <= 0 && economieTotale >= 0) {
        // Si pas de delta ou économie immédiate, ROI = 0
        roiAnnee = 0.0;
      }

      // Stockage des données ROI pour l'affichage
      _roiData = {
        'coutAncienTotal': coutAncienTotal,
        'coutNouveauTotal': coutNouveauTotal,
        'economieTotale': economieTotale,
        'deltaInvestissement': deltaInvestissement,
        'roiAnnee': roiAnnee,
        'estRentable': economieTotale >= deltaInvestissement,
      };

      setState(() => _isLoading = false);
    } catch (e, stackTrace) {
      debugPrint('[DEBUG ResultatScreen] ERREUR dans _loadData(): $e');
      debugPrint('[DEBUG ResultatScreen] Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) ErrorHandler.showSnackBar(context, 'Erreur de calcul: $e', error: true);
    }
  }

  Future<void> _updateProjetContact(int? newContactId) async {
    if (_projet == null || newContactId == null) return;
    
    try {
      final updatedProjet = _projet!.copyWith(contactId: newContactId);
      await _db.updateProjet(updatedProjet);
      
      if (mounted) {
        setState(() {
          _selectedContactId = newContactId;
          // Recharger le contact
          _contact = _contacts.firstWhere((c) => c.id == newContactId);
        });
        ErrorHandler.showSnackBar(context, 'Contact du projet mis à jour');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Erreur de mise à jour: $e', error: true);
      }
    }
  }

  Future<void> _navigateToContactForm(int? contactId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactFormScreen(contactId: contactId),
      ),
    );
    
    if (result == true && mounted) {
      _loadData();
    }
  }

  // ============================================================================
  // FORMATTING UTILITY METHODS
  // ============================================================================

  /// Format a number with French locale formatting (2 decimal places, comma separator)
  /// Ex: 1234.567 -> "1 234,57"
  String _formatNumber(double value) {
    final format = NumberFormat("#,##0.00", "fr_FR");
    return format.format(value);
  }

  String _formatRendement(double value) {
    final format = NumberFormat("#,##0.000", "fr_FR");
    return format.format(value);
  }

  String formatUnit(double value) {
    final format = NumberFormat("#,##0", "fr_FR");
    return format.format(value);
  }

  /// Format a currency value with French locale (€ symbol, 2 decimal places)
  /// Ex: 1234.567 -> "1 234,57 EUR"
  /// Note: Utilisation de EUR au lieu de € pour eviter les problemes de font sur certaines plateformes
  String _formatCurrency(double value) {
    final format = NumberFormat.currency(
      symbol: 'EUR ',
      decimalDigits: 2,
      locale: 'fr_FR',
    );
    return format.format(value);
  }

  /// Determines the appropriate scale factor and unit suffix for consumption values
  /// Returns a tuple of (scaleFactor, unitSuffix)
  /// Multiplicateur max : 1000
  /// For example: if maxValue is 500000, returns (1000, '*1000 kWh')
  /// if maxValue is 500, returns (1, 'kWh')
  Map<String, dynamic> _getConsommationScale(double maxValue) {
    if (maxValue >= 1000) {
      return {'factor': 1000.toDouble(), 'unit': '*1000 kWh'};
    } else if (maxValue >= 100) {
      return {'factor': 100.toDouble(), 'unit': '*100 kWh'};
    } else if (maxValue >= 10) {
      return {'factor': 10.toDouble(), 'unit': '*10 kWh'};
    } else {
      return {'factor': 1.toDouble(), 'unit': 'kWh'};
    }
  }

  /// Determines the appropriate scale factor and unit suffix for cost values
  /// Returns a tuple of (scaleFactor, unitSuffix)
  /// For example: if maxValue is 5000000, returns (1000000, '*1M EUR')
  /// if maxValue is 500000, returns (1000, '*1000 EUR')
  /// if maxValue is 500, returns (1, 'EUR')
  Map<String, dynamic> _getCoutScale(double maxValue) {
    //if (maxValue >= 1000000) {
      //return {'factor': 1000000.toDouble(), 'unit': '*1M EUR'};
    //} else if (maxValue >= 1000) {
    if (maxValue >= 1000) {
      return {'factor': 1000.toDouble(), 'unit': 'k€'};
    } else {
      return {'factor': 1.toDouble(), 'unit': '€'};
    }
  }


  /// Builds the consumption graph with automatic scaling
  /// This wraps the graph building to apply scaling to consumption values
  Widget _buildGraphiqueConsommationAvecScale() {
    // Calculate max value for scaling
    final maxAncien = _spotsConsommationAncien.isNotEmpty 
        ? _spotsConsommationAncien.map((s) => s.y).reduce((a, b) => a > b ? a : b) 
        : 0.0;
    final maxNouveau = _spotsConsommationNouveau.isNotEmpty 
        ? _spotsConsommationNouveau.map((s) => s.y).reduce((a, b) => a > b ? a : b) 
        : 0.0;
    final maxValue = math.max(maxAncien, maxNouveau);
    
    // Get scale factor and unit
    final scaleInfo = _getConsommationScale(maxValue);
    final scaleFactor = (scaleInfo['factor'] as num).toDouble();
    final unit = scaleInfo['unit'] as String;
    
    // Create scaled spots
    final scaledAncien = _spotsConsommationAncien.map((s) => FlSpot(s.x, s.y / scaleFactor)).toList();
    final scaledNouveau = _spotsConsommationNouveau.map((s) => FlSpot(s.x, s.y / scaleFactor)).toList();
    
    return RepaintBoundary(
      key: _consoGraphKey,
      child: _buildGraphiqueFromSpots(
        'Consommation Énergétique sur $_dureeEtude ans',
        unit,
        scaledAncien,
        scaledNouveau,
        Colors.orange,
        Colors.blue,
        false,
        forceMinYToZero: true,
        unit: unit,
      ),
    );
  }

  /// Builds the cost graph with automatic scaling
  /// This wraps the graph building to apply scaling to cost values
  Widget _buildGraphiqueCoutAvecScale() {
    // Calculate max value for scaling
    final maxAncien = _spotsCoutAncien.isNotEmpty 
        ? _spotsCoutAncien.map((s) => s.y).reduce((a, b) => a > b ? a : b) 
        : 0.0;
    final maxNouveau = _spotsCoutNouveau.isNotEmpty 
        ? _spotsCoutNouveau.map((s) => s.y).reduce((a, b) => a > b ? a : b) 
        : 0.0;
    final maxValue = math.max(maxAncien, maxNouveau);
    
    // Get scale factor and unit
    final scaleInfo = _getCoutScale(maxValue);
    final scaleFactor = (scaleInfo['factor'] as num).toDouble();
    final unit = scaleInfo['unit'] as String;
    
    // Create scaled spots
    final scaledAncien = _spotsCoutAncien.map((s) => FlSpot(s.x, s.y / scaleFactor)).toList();
    final scaledNouveau = _spotsCoutNouveau.map((s) => FlSpot(s.x, s.y / scaleFactor)).toList();
    
    return RepaintBoundary(
      key: _coutGraphKey,
      child: _buildGraphiqueFromSpots(
        'Coût sur $_dureeEtude ans',
        unit,
        scaledAncien,
        scaledNouveau,
        Colors.orange,
        Colors.blue,
        true,
        unit: unit,
      ),
    );
  }

  // ============================================================================
  // CALCULATION UTILITY METHODS
  // ============================================================================

  /// Calculate the total volume for a list of pumps over a given period
  /// Formula: Σ(debit × hours × dureeAnnee) for all pumps
  /// Result in m³ (cubic meters)
  double _calculerVolumeTotal(List<Pompe> pompes, [int dureeAnnee = 10]) {
    return pompes.fold(0.0, (sum, pompe) => sum + pompe.debit * pompe.heuresFonctionnement * dureeAnnee);
  }

  /// Calculate the total energy consumption for a list of pumps over a given period
  /// Formula: Σ(es × debit × hours × dureeAnnee) for all pumps
  /// where es = énergie spécifique (specific energy) in kW/m³/h
  /// Result in kWh (kilowatt-hours)
  double _calculerEnergieTotale(List<Pompe> pompes, [int dureeAnnee = 10]) {
    return pompes.fold(0.0, (sum, pompe) => sum + pompe.energieSpecifique * pompe.debit * pompe.heuresFonctionnement * dureeAnnee);
  }

  /// Calculate total P1 for a system for a specific year, taking into account rendement loss
  /// Uses p1Estimee (Puissance Corrigée) if available, otherwise calculates from base parameters
  /// 
  /// Case 1: If p1Estimee is set (> 0), uses corrected power with degradation formula:
  ///   P1(year) = p1Estimee / (1 - muCoef)^(2 * yearsPassed)
  ///   This accounts for efficiency losses on both pump and motor sides
  /// 
  /// Case 2: If p1Estimee is not set, calculates P1 from base parameters:
  ///   P1 = (debit * hmt) / (367 * μPompeCorrige * μMoteurCorrige)
  ///   where μPompeCorrige = rendementInitialPompe * μPerte / 100
  ///   and μPerte = (1 - percentagePerteRendement/100)^(currentYear - installationYear)
  /// 
  /// Returns the total P1 and a string with the calculation detail
  Map<String, dynamic> _calculerP1TotaleSystemeAvecDetail(List<Pompe> pompes, double percentagePerteRendement, int anneeCalcul) {
    if (pompes.isEmpty) return {'p1': 0.0, 'detail': 'Aucune pompe'}; 
    
    double p1Totale = 0.0;
    final muCoef = percentagePerteRendement.clamp(0.0, 100.0) / 100.0;
    final detailBuffer = StringBuffer();
    
    for (final pompe in pompes) {
      // Calculate muPerte for this pump and year
      final anneesEcoulees = anneeCalcul - pompe.anneeInstallation;
      // Use configurable max years limit from settings
      final maxYears = _settings.maxAnneesPerteRendement;
      final anneesLimitees = anneesEcoulees.clamp(0, maxYears);
      final muPerte = anneesEcoulees <= 0 ? 1.0 : math.pow(1 - muCoef, anneesLimitees).toDouble();
      
      final p1 = _calculerP1Pompe(pompe, muCoef, anneesLimitees, muPerte, anneeCalcul);
      
      p1Totale += p1;
      
      // Add to detail
      if (pompes.length == 1) {
        if (pompe.p1Estimee > 0) {
          detailBuffer.writeln('P1 = Puissance Corrigée: ${_formatNumber(pompe.p1Estimee)} kW');
          if (anneesLimitees > 0) {
            detailBuffer.writeln('  Dégradation sur $anneesLimitees ans: / (1 - ${_formatNumber(muCoef)})^${2 * anneesLimitees}');
          }
          detailBuffer.writeln('  = ${_formatNumber(p1)} kW');
        } else {
          final muPompeCorrige = pompe.rendementInitialPompe * muPerte / 100.0;
          final muMoteurCorrige = pompe.rendementInitialMoteur * muPerte / 100.0;
          detailBuffer.writeln('P1 = (${_formatNumber(pompe.debit)} × ${_formatNumber(pompe.hmt)}) / (367 × ${_formatRendement(muPompeCorrige)} × ${_formatRendement(muMoteurCorrige)})');
          detailBuffer.writeln('  = ${_formatNumber(pompe.debit * pompe.hmt)} / ${_formatNumber(367 * muPompeCorrige * muMoteurCorrige)}');
          detailBuffer.writeln('  = ${_formatNumber(p1)} kW');
        }
      } else {
        if (pompe.p1Estimee > 0) {
          detailBuffer.writeln('Pompe (corrigée): ${_formatNumber(pompe.p1Estimee)} kW → ${_formatNumber(p1)} kW');
        } else {
          final muPompeCorrige = pompe.rendementInitialPompe * muPerte / 100.0;
          final muMoteurCorrige = pompe.rendementInitialMoteur * muPerte / 100.0;
          detailBuffer.writeln('Pompe: (${_formatNumber(pompe.debit)} × ${_formatNumber(pompe.hmt)}) / (367 × ${_formatRendement(muPompeCorrige)} × ${_formatRendement(muMoteurCorrige)}) = ${_formatNumber(p1)} kW');
        }
      }
    }
    
    if (pompes.length > 1) {
      detailBuffer.writeln('Total P1 = ${_formatNumber(p1Totale)} kW');
    }
    
    return {'p1': p1Totale, 'detail': detailBuffer.toString()};
  }

  /// Calculate P1 for a single pump, using either corrected power or calculated power
  double _calculerP1Pompe(Pompe pompe, double muCoef, int anneesLimitees, double muPerte, int anneeCalcul) {
    // Case 1: Use corrected power (p1Estimee) if available
    if (pompe.p1Estimee > 0) {
      // P1(year) = p1Estimee / (1 - muCoef)^(2 * anneesLimitees)
      // This accounts for efficiency losses on both pump and motor sides
      final degradationFactor = anneesLimitees > 0 ? math.pow(1 - muCoef, 2 * anneesLimitees).toDouble() : 1.0;
      return pompe.p1Estimee / degradationFactor;
    }
    
    // Case 2: Calculate P1 from base parameters (debit, hmt, rendements)
    // P1 = (debit * hmt) / (367 * μPompeCorrigé * μMoteurCorrigé)
    final muPompeCorrige = pompe.rendementInitialPompe * muPerte / 100.0;
    final muMoteurCorrige = pompe.rendementInitialMoteur * muPerte / 100.0;
    return (pompe.debit * pompe.hmt) / (367 * muPompeCorrige * muMoteurCorrige);
  }

  /// Calculate total hours for a system (sum of all pumps' hours)
  int _calculerHeuresTotalesSysteme(List<Pompe> pompes) {
    if (pompes.isEmpty) return 0;
    return pompes.fold(0, (sum, pompe) => sum + pompe.heuresFonctionnement);
  }

  /// Calculate total cost for a system for a specific year, with calculation details
  /// Returns the total cost and a string with the calculation detail
  Map<String, dynamic> _calculerCoutTotaleSystemeAvecDetail(
    List<Pompe> pompes,
    double coutEnergie,
    double pourcentageAugmentationEnergie,
    double percentagePerteRendement,
    int anneeCalcul,
    int anneeDebut,
  ) {
    if (pompes.isEmpty) return {'cout': 0.0, 'detail': 'Aucune pompe'}; 
    
    // Calculate consumption for this year using CalculService
    final consommation = CalculService.calculerConsommationAnnuelleSystemeAvecPompes(
      pompes,
      anneeCalcul,
      percentagePerteRendement,
    );
    
    // Calculate energy cost for this year
    // The energy cost increases annually from anneeDebut
    final anneesEcoulees = anneeCalcul - anneeDebut;
    final coutEnergieActuel = coutEnergie * math.pow(1 + pourcentageAugmentationEnergie / 100.0, anneesEcoulees).toDouble();
    final cout = consommation * coutEnergieActuel;
    
    // Build detail string
    final detailBuffer = StringBuffer();
    detailBuffer.writeln('Consommation: ${_formatNumber(consommation)} kWh');
    if (anneesEcoulees > 0) {
      detailBuffer.writeln('Coût énergie: ${_formatNumber(coutEnergie)} × (1 + ${_formatNumber(pourcentageAugmentationEnergie)}%)^$anneesEcoulees = ${_formatNumber(coutEnergieActuel)} EUR/kWh');
    } else {
      detailBuffer.writeln('Coût énergie: ${_formatNumber(coutEnergie)} EUR/kWh');
    }
    detailBuffer.writeln('Coût total = ${_formatNumber(consommation)} kWh × ${_formatNumber(coutEnergieActuel)} EUR/kWh = ${_formatNumber(cout)} EUR');
    
    return {'cout': cout, 'detail': detailBuffer.toString()};
  }

  /// Calculate average corrected efficiency (μ) for a system for a specific year
  /// This shows the combined pump and motor efficiency after accounting for yearly degradation
  /// Formula: Product of (rendementInitialPompe * μPerte / 100) and (rendementInitialMoteur * μPerte / 100)
  /// Returns the global μ as a percentage (0-100)
  double _calculerMuMoyenSysteme(List<Pompe> pompes, double percentagePerteRendement, int anneeCalcul) {
    if (pompes.isEmpty) return 0.0;
    
    double muTotal = 0.0;
    int count = 0;
    final muCoef = percentagePerteRendement.clamp(0.0, 100.0) / 100.0;
    final maxYears = _settings.maxAnneesPerteRendement;
    
    for (final pompe in pompes) {
      final anneesEcoulees = anneeCalcul - pompe.anneeInstallation;
      // Use configurable max years limit from settings
      final anneesLimitees = anneesEcoulees.clamp(0, maxYears);
      final muPerte = anneesEcoulees <= 0 ? 1.0 : math.pow(1 - muCoef, anneesLimitees).toDouble();
      
      // Calculate corrected rendements as percentages (0-100)
      final muPompePercent = pompe.rendementInitialPompe * muPerte;
      final muMoteurPercent = pompe.rendementInitialMoteur * muPerte;
      
      // Global efficiency is the product of pump and motor efficiency (not the average)
      // Convert from percentage to decimal, multiply, then convert back to percentage
      muTotal += (muPompePercent * muMoteurPercent) / 100;
      count += 1;
    }
    
    return count > 0 ? muTotal / count : 0.0;
  }

  // ============================================================================
  // CALCULATION DETAILS DIALOG
  // ============================================================================
  // Shows a detailed breakdown of how the calculations are performed
  void _showCalculationDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détail des Calculs'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // General info
              Text('Les calculs sont effectués pour chaque année sur $_dureeEtude ans.', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              
              // Consumption calculation
              Text('1. Calcul de la Consommation (kWh) :', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              SizedBox(height: 4),
              Text('Formule: P1 × Heures de fonctionnement'),
              Text('où P1 = Puissance utile de la pompe en kW'),
              Text('Les rendements pompe et moteur sont pris en compte dans P1.'),
              SizedBox(height: 8),
              
              // Cost calculation
              Text('2. Calcul du Coût Énergétique (EUR) :', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              SizedBox(height: 4),
              Text('Formule: Consommation × Coût de l\'énergie (EUR/kWh)'),
              Text('Le coût de l\'énergie provient du projet et peut augmenter chaque année.'),
              SizedBox(height: 8),
              
              // Savings calculation
              Text('3. Calcul des Économies :', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              SizedBox(height: 4),
              Text('Économie kWh = Consommation Ancien - Consommation Nouveau'),
              Text('Économie EUR = Coût Ancien - Coût Nouveau'),
              SizedBox(height: 8),
              
              // ROI calculation
              Text('4. Calcul du ROI (Retour sur Investissement) :', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
              SizedBox(height: 4),
              Text('Économie totale sur $_dureeEtude ans = Somme des économies annuelles'),
              Text('Delta Investissement = Coût Nouveau - Coût Ancien'),
              Text('ROI (années) = Delta Investissement / (Économie annuelle moyenne)'),
              SizedBox(height: 8),
              
              // Volume calculation
              Text('5. Calcul du Volume Total :', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              SizedBox(height: 4),
              Text('Formule: Σ(Débit × Heures de fonctionnement × $_dureeEtude)'),
              Text('Le facteur $_dureeEtude convertit en m³ (débit en m³/h × heures × $_dureeEtude ans)'),
              SizedBox(height: 8),
              
              // Note about corrected power
              Text('Note sur la Puissance Corrigée :', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Si une valeur de P1 Corrigée est saisie, elle est utilisée'),
              Text('au lieu de la P1 Calculée pour tous les calculs.'),
              Text('La dégradation annuelle est appliquée selon:'),
              Text('P1(n) = P1 corrigée / (1 - %perte)^(2 × n)'),
              Text('Cela permet de tenir compte des pertes de rendement côté pompe et moteur.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comparatif - ${_projet?.nomSite ?? 'Projet'}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exporter PDF',
            onPressed: _exportComparatifPdf,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Sauvegarder PDF',
            onPressed: _saveComparatifPdfLocally,
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => SettingsDialog.show(context, 
            title: 'Paramètres de Calcul',
            onSaved: _loadData,
          )),
          IconButton(icon: Icon(_safeMode ? Icons.shield : Icons.show_chart), onPressed: () => setState(() => _safeMode = !_safeMode)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projet == null || _systemeAncien == null || _systemeNouveau == null
              ? const Center(child: Text('Données non disponibles'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sélecteur de contact
                      if (_contacts.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Contact Associé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  value: _selectedContactId,
                                  decoration: const InputDecoration(
                                    labelText: 'Sélectionner un contact',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _contacts.map((contact) {
                                    return DropdownMenuItem<int>(
                                      value: contact.id!,
                                      child: Text('${contact.client} - ${contact.nom}'),
                                    );
                                  }).toList(),
                                  onChanged: (newContactId) {
                                    if (newContactId != null) {
                                      _updateProjetContact(newContactId);
                                    }
                                  },
                                  hint: const Text('Sélectionner un contact'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Modifier le contact sélectionné'),
                                  onPressed: _selectedContactId != null 
                                      ? () => _navigateToContactForm(_selectedContactId)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('Résumé des Systèmes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const Divider(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildSystemeCard('Ancien Système', _systemeAncien!, _consommationsAncien, _coutsAncien, _annees.isEmpty ? 0 : _annees[0], Colors.orange),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSystemeCard('Nouveau Système', _systemeNouveau!, _consommationsNouveau, _coutsNouveau, _annees.isEmpty ? 0 : _annees[0], Colors.blue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _safeMode ? _buildPlaceholder('Consommation Énergétique sur $_dureeEtude ans') : 
                        _buildGraphiqueConsommationAvecScale(),
                      const SizedBox(height: 24),
                      _safeMode ? _buildPlaceholder('Coût sur $_dureeEtude ans') : _buildGraphiqueCoutAvecScale(),
                      const SizedBox(height: 24),
                      _safeMode ? _buildPlaceholder('Énergie spécifique') : _buildGraphiqueEnergieSpecifique(),
                      const SizedBox(height: 24),
                      if (_roiData != null) _buildRoiCard(),
                      const SizedBox(height: 16),
                      _buildDataTable(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRoiCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analyse de Rentabilité (ROI)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Coût énergétique total ($_dureeEtude ans):'),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Ancien: ${_formatCurrency(_roiData!['coutAncienTotal'])}', style: const TextStyle(color: Colors.orange)),
                Text('Nouveau: ${_formatCurrency(_roiData!['coutNouveauTotal'])}', style: const TextStyle(color: Colors.blue)),
              ])
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Économie sur $_dureeEtude ans:'),
              Text(_roiData!['economieTotale'] >= 0 ? '+${_formatCurrency(_roiData!['economieTotale'])}' : _formatCurrency(_roiData!['economieTotale']), style: TextStyle(color: _roiData!['economieTotale'] >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Données Détaillées par Année', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'Détail des calculs',
                onPressed: _showCalculationDetailsDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              columns: const [
                DataColumn(label: Text('Année')),
                DataColumn(label: Text('P1 Ancien\n(kW)')),
                DataColumn(label: Text('Détail P1\nAncien', textAlign: TextAlign.center)),
                DataColumn(label: Text('μ Ancien\n(%)')),
                DataColumn(label: Text('P1 Nouveau\n(kW)')),
                DataColumn(label: Text('Détail P1\nNouveau', textAlign: TextAlign.center)),
                DataColumn(label: Text('μ Nouveau\n(%)')),
                DataColumn(label: Text('Heures Ancien\n(h)')),
                DataColumn(label: Text('Heures Nouveau\n(h)')),
                DataColumn(label: Text('Conso Ancien\n(kWh)')),
                DataColumn(label: Text('Conso Nouveau\n(kWh)')),
                DataColumn(label: Text('Économie\n(kWh)')),
                DataColumn(label: Text('Coût Ancien\n(EUR)')),
                DataColumn(label: Text('Détail Coût\nAncien', textAlign: TextAlign.center)),
                DataColumn(label: Text('Coût Nouveau\n(EUR)')),
                DataColumn(label: Text('Détail Coût\nNouveau', textAlign: TextAlign.center)),
                DataColumn(label: Text('Économie\nEUR')),
                DataColumn(label: Text('Éco. cumulée\n(kWh)')),
                DataColumn(label: Text('Éco. cumulée\n(EUR)')),
              ],
              rows: List.generate(_dureeEtude, (i) {
                final economieKWh = _consommationsAncien[i] - _consommationsNouveau[i];
                final economieEuro = _coutsAncien[i] - _coutsNouveau[i];
                
                // Calculate cumulative savings
                final cumuleKWh = _consommationsAncien.take(i+1).fold(0.0, (sum, val) => sum + val) - 
                                  _consommationsNouveau.take(i+1).fold(0.0, (sum, val) => sum + val);
                final cumuleEuro = _coutsAncien.take(i+1).fold(0.0, (sum, val) => sum + val) - 
                                   _coutsNouveau.take(i+1).fold(0.0, (sum, val) => sum + val);
                
                return DataRow(cells: [
                  DataCell(Text('${_annees[i]}')),
                  DataCell(Text(_formatNumber(_p1AncienParAnnee[i]))),
                  DataCell(Tooltip(
                    message: _p1AncienDetailParAnnee[i],
                    child: const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  )),
                  DataCell(Text(_formatNumber(_muAncienParAnnee[i]))),
                  DataCell(Text(_formatNumber(_p1NouveauParAnnee[i]))),
                  DataCell(Tooltip(
                    message: _p1NouveauDetailParAnnee[i],
                    child: const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  )),
                  DataCell(Text(_formatNumber(_muNouveauParAnnee[i]))),
                  DataCell(Text('$_heuresAncienTotal')),
                  DataCell(Text('$_heuresNouveauTotal')),
                  DataCell(Text(formatUnit(_consommationsAncien[i]))),
                  DataCell(Text(formatUnit(_consommationsNouveau[i]))),
                  DataCell(Text(formatUnit(economieKWh), style: TextStyle(color: economieKWh >= 0 ? Colors.green : Colors.red))),
                  DataCell(Text(formatUnit(_coutsAncien[i]))),
                  DataCell(Tooltip(
                    message: _coutsAncienDetailParAnnee[i],
                    child: const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  )),
                  DataCell(Text(formatUnit(_coutsNouveau[i]))),
                  DataCell(Tooltip(
                    message: _coutsNouveauDetailParAnnee[i],
                    child: const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  )),
                  DataCell(Text(formatUnit(economieEuro), style: TextStyle(color: economieEuro >= 0 ? Colors.green : Colors.red))),
                  DataCell(Text(formatUnit(cumuleKWh), style: TextStyle(color: cumuleKWh >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
                  DataCell(Text(formatUnit(cumuleEuro), style: TextStyle(color: cumuleEuro >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
                ]);
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSystemeCard(String title, Systeme systeme, List<double> consommations, List<double> couts, int premiereAnnee, Color color) {
    final consommationPremiereAnnee = consommations.isEmpty ? 0.0 : consommations[0];
    final coutPremiereAnnee = couts.isEmpty ? 0.0 : couts[0];
    
    // Calcul des moyennes sur $_dureeEtude ans
    final consommationMoyenne = consommations.isEmpty ? 0.0 : consommations.reduce((a, b) => a + b).toDouble() / consommations.length;
    final coutMoyen = couts.isEmpty ? 0.0 : couts.reduce((a, b) => a + b).toDouble() / couts.length;
    
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text('Coût investissement: ${_formatCurrency(systeme.coutInvestissementTotal)}'),
          const SizedBox(height: 4),
          Text('Consommation Année $premiereAnnee: ${_formatNumber(consommationPremiereAnnee)} kWh'),
          Text('Coût total pour l\'année $premiereAnnee: ${_formatCurrency(coutPremiereAnnee)}'),
          const SizedBox(height: 4),
          Text('Consommation moyenne sur $_dureeEtude ans: ${_formatNumber(consommationMoyenne)} kWh'),
          Text('Coût total moyen sur $_dureeEtude ans: ${_formatCurrency(coutMoyen)}'),
        ]),
      ),
    );
  }

  Widget _buildGraphiqueEnergieSpecifique() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Volume vs Énergie Consommée (sur $_dureeEtude ans)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Comparaison des systèmes basée sur l\'énergie spécifique des pompes', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(height: 160, child: Row(children: [
            Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Ancien Système', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Volume: ${_formatNumber(_volumeAncien)} m³'), Text('Énergie: ${_formatNumber(_energieAncien)} kWh')] )))),
            const SizedBox(width: 12),
            Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Nouveau Système', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Volume: ${_formatNumber(_volumeNouveau)} m³'), Text('Énergie: ${_formatNumber(_energieNouveau)} kWh')] )))),
          ])),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // Methodes d'export PDF
  Future<void> _exportComparatifPdf() async {
    if (_projet == null || _roiData == null) return;

    // Capture des graphiques
    final consoImage = await PdfExportService.captureWidgetAsImage(_consoGraphKey);
    final coutImage = await PdfExportService.captureWidgetAsImage(_coutGraphKey);

    // Preparation des donnees comparatif
    final comparatifData = {
      'dataAncien': {
        'totalConsommation': _energieAncien,
        'totalCout': _roiData!['coutAncienTotal'] as double? ?? 0,
        'investissement': _systemeAncien?.coutInvestissementTotal ?? 0,
      },
      'dataNouveau': {
        'totalConsommation': _energieNouveau,
        'totalCout': _roiData!['coutNouveauTotal'] as double? ?? 0,
        'investissement': _systemeNouveau?.coutInvestissementTotal ?? 0,
      },
      'economieData': {
        'economieConsommation': _energieAncien - _energieNouveau,
        'economieCout': (_roiData!['coutAncienTotal'] as double? ?? 0) - (_roiData!['coutNouveauTotal'] as double? ?? 0),
        'economieInvestissement': (_systemeNouveau?.coutInvestissementTotal ?? 0) - (_systemeAncien?.coutInvestissementTotal ?? 0),
      },
      'annualData': {
        'annees': _annees,
        'consommationsAncien': _consommationsAncien,
        'consommationsNouveau': _consommationsNouveau,
        'coutsAncien': _coutsAncien,
        'coutsNouveau': _coutsNouveau,
      },
    };

    await PdfExportService.exportFullReportToPdf(
      context: context,
      projet: _projet!,
      contact: _contact,
      systemes: [_systemeAncien!, _systemeNouveau!],
      pompesBySysteme: {
        if (_systemeAncien?.id != null) _systemeAncien!.id!: _pompesAncien,
        if (_systemeNouveau?.id != null) _systemeNouveau!.id!: _pompesNouveau,
      },
      comparatifData: comparatifData,
      graphiqueConsommationImage: consoImage,
      graphiqueCoutImage: coutImage,
    );
  }

  Future<void> _saveComparatifPdfLocally() async {
    if (_projet == null || _roiData == null) return;

    // Capture des graphiques
    final consoImage = await PdfExportService.captureWidgetAsImage(_consoGraphKey);
    final coutImage = await PdfExportService.captureWidgetAsImage(_coutGraphKey);

    // Preparation des donnees comparatif
    final comparatifData = {
      'dataAncien': {
        'totalConsommation': _energieAncien,
        'totalCout': _roiData!['coutAncienTotal'] as double? ?? 0,
        'investissement': _systemeAncien?.coutInvestissementTotal ?? 0,
      },
      'dataNouveau': {
        'totalConsommation': _energieNouveau,
        'totalCout': _roiData!['coutNouveauTotal'] as double? ?? 0,
        'investissement': _systemeNouveau?.coutInvestissementTotal ?? 0,
      },
      'economieData': {
        'economieConsommation': _energieAncien - _energieNouveau,
        'economieCout': (_roiData!['coutAncienTotal'] as double? ?? 0) - (_roiData!['coutNouveauTotal'] as double? ?? 0),
        'economieInvestissement': (_systemeNouveau?.coutInvestissementTotal ?? 0) - (_systemeAncien?.coutInvestissementTotal ?? 0),
      },
      'annualData': {
        'annees': _annees,
        'consommationsAncien': _consommationsAncien,
        'consommationsNouveau': _consommationsNouveau,
        'coutsAncien': _coutsAncien,
        'coutsNouveau': _coutsNouveau,
      },
    };

    await PdfExportService.saveFullReportPdfLocally(
      context: context,
      projet: _projet!,
      contact: _contact,
      systemes: [_systemeAncien!, _systemeNouveau!],
      pompesBySysteme: {
        if (_systemeAncien?.id != null) _systemeAncien!.id!: _pompesAncien,
        if (_systemeNouveau?.id != null) _systemeNouveau!.id!: _pompesNouveau,
      },
      comparatifData: comparatifData,
      graphiqueConsommationImage: consoImage,
      graphiqueCoutImage: coutImage,
    );
  }

  @override
  void dispose() {
    // Note: We don't close _calculService here because DatabaseService is a singleton
    // and closing it would close all Hive boxes, including SettingsService's box.
    // Hive boxes are automatically managed by Hive and don't need explicit closing.
    super.dispose();
  }
}

class _SimpleLineChart extends StatefulWidget {
  final List<FlSpot> ancien;
  final List<FlSpot> nouveau;
  final Color colorAncien;
  final Color colorNouveau;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final int xTickCount;
  final int yTickCount;
  final bool isCurrency;
  final String unit;

  const _SimpleLineChart({Key? key, required this.ancien, required this.nouveau, required this.colorAncien, required this.colorNouveau, required this.minX, required this.maxX, required this.minY, required this.maxY, required this.xTickCount, required this.yTickCount, required this.isCurrency, required this.unit}) : super(key: key);

  @override
  State<_SimpleLineChart> createState() => _SimpleLineChartState();
}

class _SimpleLineChartState extends State<_SimpleLineChart> {
  double? _hoverFraction; // 0..1 over width

  void _updateHover(Offset localPosition, double width) {
    final frac = (localPosition.dx / width).clamp(0.0, 1.0);
    setState(() => _hoverFraction = frac);
  }

  void _clearHover() => setState(() => _hoverFraction = null);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (e) => _updateHover(e.localPosition, w),
        onPanUpdate: (e) => _updateHover(e.localPosition, w),
        onPanEnd: (_) => _clearHover(),
        child: MouseRegion(
          onHover: (e) => _updateHover(e.localPosition, w),
          onExit: (_) => _clearHover(),
          child: CustomPaint(
            painter: _SimpleLinePainter(
              ancien: widget.ancien,
              nouveau: widget.nouveau,
              colorAncien: widget.colorAncien,
              colorNouveau: widget.colorNouveau,
              minX: widget.minX,
              maxX: widget.maxX,
              minY: widget.minY,
              maxY: widget.maxY,
              xTickCount: widget.xTickCount,
              yTickCount: widget.yTickCount,
              hoverFraction: _hoverFraction,
              isCurrency: widget.isCurrency,
              unit: widget.unit,
            ),
            size: Size.infinite,
          ),
        ),
      );
    });
  }
}

class _SimpleLinePainter extends CustomPainter {
  final List<FlSpot> ancien;
  final List<FlSpot> nouveau;
  final Color colorAncien;
  final Color colorNouveau;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final int xTickCount;
  final int yTickCount;
  final double? hoverFraction; // 0..1 or null
  final bool isCurrency;
  final String unit;

  _SimpleLinePainter({required this.ancien, required this.nouveau, required this.colorAncien, required this.colorNouveau, required this.minX, required this.maxX, required this.minY, required this.maxY, required this.xTickCount, required this.yTickCount, this.hoverFraction, required this.isCurrency, required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    final paintAnc = Paint()..color = colorAncien..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true;
    final paintNouv = Paint()..color = colorNouveau..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true;
    final paintGrid = Paint()..color = Colors.grey.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 1.0;

    Offset toOffset(FlSpot s) {
      final dx = (s.x - minX) / (maxX - minX) * size.width;
      final dy = size.height - (s.y - minY) / (maxY - minY) * size.height;
      return Offset(dx.clamp(0.0, size.width), dy.clamp(0.0, size.height));
    }

    // Draw hover cursor if available
    if (hoverFraction != null) {
      final hoverX = minX + (maxX - minX) * hoverFraction!;
      final dx = (hoverFraction! * size.width).clamp(0.0, size.width);
      final paintCursor = Paint()..color = Colors.black.withValues(alpha: 0.6)..strokeWidth = 1.0;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paintCursor);

      // Draw markers at nearest points on each series
      FlSpot? nearestAnc;
      FlSpot? nearestNouv;
      double bestAnc = double.infinity;
      double bestNouv = double.infinity;
      for (var s in ancien) {
        final d = (s.x - hoverX).abs();
        if (d < bestAnc) {
          bestAnc = d;
          nearestAnc = s;
        }
      }
      for (var s in nouveau) {
        final d = (s.x - hoverX).abs();
        if (d < bestNouv) {
          bestNouv = d;
          nearestNouv = s;
        }
      }
      if (nearestAnc != null) {
        final o = toOffset(nearestAnc);
        final p = Paint()..color = colorAncien..style = PaintingStyle.fill;
        canvas.drawCircle(o, 4.0, p);
        // horizontal line
        final paintH = Paint()..color = colorAncien.withValues(alpha: 0.2)..strokeWidth = 1.0;
        canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), paintH);
        // tooltip
        final fmt = isCurrency ? NumberFormat.currency(symbol: '', decimalDigits: 2, locale: 'fr_FR') : NumberFormat('#,##0.00', 'fr_FR');
        final text = '${fmt.format(nearestAnc.y)} $unit';
        final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 11)), textDirection: ui.TextDirection.ltr);
        tp.layout();
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH((o.dx + 6).clamp(0.0, size.width - tp.width - 8), (o.dy - tp.height - 8).clamp(0.0, size.height - tp.height), tp.width + 8, tp.height + 4), const Radius.circular(4));
        final back = Paint()..color = colorAncien.withValues(alpha: 0.9);
        canvas.drawRRect(rect, back);
        tp.paint(canvas, Offset(rect.left + 4, rect.top + 2));
      }
      if (nearestNouv != null) {
        final o = toOffset(nearestNouv);
        final p = Paint()..color = colorNouveau..style = PaintingStyle.fill;
        canvas.drawCircle(o, 4.0, p);
        final paintH = Paint()..color = colorNouveau.withValues(alpha: 0.2)..strokeWidth = 1.0;
        canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), paintH);
        final fmt = isCurrency ? NumberFormat.currency(symbol: '', decimalDigits: 2, locale: 'fr_FR') : NumberFormat('#,##0.00', 'fr_FR');
        final text = '${fmt.format(nearestNouv.y)} $unit';
        final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 11)), textDirection: ui.TextDirection.ltr);
        tp.layout();
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH((o.dx + 6).clamp(0.0, size.width - tp.width - 8), (o.dy - tp.height - 8).clamp(0.0, size.height - tp.height), tp.width + 8, tp.height + 4), const Radius.circular(4));
        final back = Paint()..color = colorNouveau.withValues(alpha: 0.9);
        canvas.drawRRect(rect, back);
        tp.paint(canvas, Offset(rect.left + 4, rect.top + 2));
      }
    }

    // Draw grid lines based on tick counts
    final int vCount = xTickCount > 1 ? xTickCount : 5;
    final int hCount = yTickCount > 0 ? (yTickCount + 1) : 5; // yTickCount portions -> yTickCount+1 lines
    for (var i = 0; i < vCount; i++) {
      final dx = (i / (vCount - 1)) * size.width;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paintGrid);
    }
    // Draw horizontal grid lines aligned with Y axis ticks
    // Calculate actual Y values for each tick to align grid lines with axis labels
    for (var i = 0; i <= yTickCount; i++) {
      // Calculate the value at this tick position (same formula as in _buildGraphiqueFromSpots)
      final v = minY + (maxY - minY) * ((yTickCount - i) / yTickCount);
      // Convert value to Y position (same formula as toOffset)
      final dy = size.height - ((v - minY) / (maxY - minY)) * size.height;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paintGrid);
    }

    if (ancien.length >= 2) {
      final path = Path();
      for (var i = 0; i < ancien.length; i++) {
        final o = toOffset(ancien[i]);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, paintAnc);
    }

    if (nouveau.length >= 2) {
      final path2 = Path();
      for (var i = 0; i < nouveau.length; i++) {
        final o = toOffset(nouveau[i]);
        if (i == 0) {
          path2.moveTo(o.dx, o.dy);
        } else {
          path2.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path2, paintNouv);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
