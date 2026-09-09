import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import '../../models/projet.dart';
import '../../models/systeme.dart';
import '../../models/pompe.dart';
import '../../services/calcul_service.dart';
import 'dart:math' as math;
import 'package:wu_ect/utils/decimation.dart';
import '../../services/database_service.dart';
import 'package:intl/intl.dart';
import '../../utils/error_handler.dart';

// Fonction wrapper pour compute() - doit être top-level
Map<String, List<double>> _calculerDonnees10AnsWrapper(List<dynamic> args) {
  final pompes = args[0] as List<Pompe>;
  final projet = args[1] as Projet;
  return CalculService.calculerDonnees10AnsAvecPompes(pompes, projet);
}

class ResultatScreen extends StatefulWidget {
  final int projetId;

  const ResultatScreen({super.key, required this.projetId});

  @override
  State<ResultatScreen> createState() => _ResultatScreenState();
}

class _ResultatScreenState extends State<ResultatScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final CalculService _calculService = CalculService();

  Projet? _projet;
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
  String _debugInfo = '';

  List<Pompe> _pompesAncien = [];
  List<Pompe> _pompesNouveau = [];
  double _volumeAncien = 0;
  double _volumeNouveau = 0;
  double _energieAncien = 0;
  double _energieNouveau = 0;

  bool _isLoading = true;
  bool _safeMode = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[DEBUG ResultatScreen] initState appelé - projetId: ${widget.projetId}');
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
    bool isCurrency,
  ) {
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

    if (maxX <= minX) maxX = minX + 1.0;
    if (maxY <= minY) {
      final delta = (minY.abs() * 0.01).clamp(1.0, double.infinity);
      maxY = minY + delta;
    }

    String formatAxis(double v) => _formatNumber(v);

    // Years for x-axis labels (use available years or numeric indices)
    final xLabels = _annees.isNotEmpty ? _annees : List.generate((maxX - minX + 1).toInt(), (i) => i);
    final int xTickCount = xLabels.length;
    final int yTickCount = 10;

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
                  // Y axis labels (min/max)
                  SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Unit label on Y axis
                          Text(unite, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(yTickCount, (i) {
                                final v = minY + (maxY - minY) * ( (yTickCount - 1 - i) / (yTickCount - 1) );
                                return Text(formatAxis(v), style: const TextStyle(fontSize: 12));
                              }),
                            ),
                          ),
                        ],
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
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            // X axis labels: first, middle, last (or use years if available)
            // X axis: show every year evenly spaced
            Row(
              children: [
                const SizedBox(width: 80), // align with Y labels column
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Stack(
                      children: xLabels.asMap().entries.map((entry) {
                        final i = entry.key;
                        final lbl = entry.value;
                        final frac = xTickCount > 1 ? (i / (xTickCount - 1)) : 0.0;
                        final alignX = -1.0 + 2.0 * frac; // convert [0..1] -> [-1..1] for Alignment
                        return Align(
                          alignment: Alignment(alignX, 0.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text('$lbl', style: const TextStyle(fontSize: 11)),
                          ),
                        );
                      }).toList(),
                    );
                  }),
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

      _volumeAncien = _calculerVolumeTotal(_pompesAncien);
      _volumeNouveau = _calculerVolumeTotal(_pompesNouveau);
      _energieAncien = _calculerEnergieTotale(_pompesAncien);
      _energieNouveau = _calculerEnergieTotale(_pompesNouveau);

      final anneeEnCours = DateTime.now().year;
      _annees = List.generate(10, (i) => anneeEnCours + i);

      final donneesAncienFuture = compute(_calculerDonnees10AnsWrapper, [_pompesAncien, projet]);
      final donneesNouveauFuture = compute(_calculerDonnees10AnsWrapper, [_pompesNouveau, projet]);
      final results = await Future.wait<Map<String, List<double>>>([donneesAncienFuture, donneesNouveauFuture]);

      final donneesAncien = results[0];
      final donneesNouveau = results[1];

      _consommationsAncien = donneesAncien['consommations']!;
      _consommationsNouveau = donneesNouveau['consommations']!;
      _coutsAncien = donneesAncien['coutsEnergetiques']!;
      _coutsNouveau = donneesNouveau['coutsEnergetiques']!;

      // Intégrer le montant d'investissement dans la première année du coût (pour le système nouveau)
      try {
        if (_systemeNouveau != null && _coutsNouveau.isNotEmpty) {
          _coutsNouveau[0] = _coutsNouveau[0] + (_systemeNouveau!.coutInvestissementTotal);
        }
      } catch (_) {}

      try {
        // Prepare adjusted costs list that includes investment in first year for nouveau
        final coutsNouveauAdjusted = List<double>.from(_coutsNouveau);
        if (_systemeNouveau != null && coutsNouveauAdjusted.isNotEmpty) {
          coutsNouveauAdjusted[0] = coutsNouveauAdjusted[0] + (_systemeNouveau!.coutInvestissementTotal);
        }

        final spotsAncien = await compute(computeDownsampleSerialized, {'values': _consommationsAncien, 'maxPoints': 500});
        final spotsNouveau = await compute(computeDownsampleSerialized, {'values': _consommationsNouveau, 'maxPoints': 500});
        final spotsCoutAncien = await compute(computeDownsampleSerialized, {'values': _coutsAncien, 'maxPoints': 500});
        final spotsCoutNouveau = await compute(computeDownsampleSerialized, {'values': coutsNouveauAdjusted, 'maxPoints': 500});

        _spotsConsommationAncien = spotsAncien.map((m) => FlSpot(m['x']!, m['y']!)).toList();
        _spotsConsommationNouveau = spotsNouveau.map((m) => FlSpot(m['x']!, m['y']!)).toList();
        _spotsCoutAncien = spotsCoutAncien.map((m) => FlSpot(m['x']!, m['y']!)).toList();
        _spotsCoutNouveau = spotsCoutNouveau.map((m) => FlSpot(m['x']!, m['y']!)).toList();
      } catch (_) {
        _spotsConsommationAncien = List.generate(_consommationsAncien.length, (i) => FlSpot(i.toDouble(), _consommationsAncien[i]));
        _spotsConsommationNouveau = List.generate(_consommationsNouveau.length, (i) => FlSpot(i.toDouble(), _consommationsNouveau[i]));
        _spotsCoutAncien = List.generate(_coutsAncien.length, (i) => FlSpot(i.toDouble(), _coutsAncien[i]));
        final coutsNouveauAdjusted = List<double>.from(_coutsNouveau);
        if (_systemeNouveau != null && coutsNouveauAdjusted.isNotEmpty) coutsNouveauAdjusted[0] = coutsNouveauAdjusted[0] + (_systemeNouveau!.coutInvestissementTotal);
        _spotsCoutNouveau = List.generate(coutsNouveauAdjusted.length, (i) => FlSpot(i.toDouble(), coutsNouveauAdjusted[i]));
      }

      final debugBuf = StringBuffer();
      debugBuf.writeln('safeMode=$_safeMode');
      debugBuf.writeln('consommationsAncien=${_consommationsAncien.length} spotsAncien=${_spotsConsommationAncien.length}');
      debugBuf.writeln('consommationsNouveau=${_consommationsNouveau.length} spotsNouveau=${_spotsConsommationNouveau.length}');
      debugBuf.writeln('coutsAncien=${_coutsAncien.length} spotsCoutAncien=${_spotsCoutAncien.length}');
      debugBuf.writeln('coutsNouveau=${_coutsNouveau.length} spotsCoutNouveau=${_spotsCoutNouveau.length}');
      setState(() => _debugInfo = debugBuf.toString());

      final coutAncienTotal = (donneesAncien['coutsEnergetiques'] as List<double>).reduce((a, b) => a + b);
      final coutNouveauTotal = (donneesNouveau['coutsEnergetiques'] as List<double>).reduce((a, b) => a + b);
      final economieTotale = coutAncienTotal - coutNouveauTotal;
      final deltaInvestissement = _systemeNouveau!.coutInvestissementTotal - _systemeAncien!.coutInvestissementTotal;

      double roiAnnee = double.infinity;
      if (deltaInvestissement > 0 && economieTotale > 0) {
        roiAnnee = deltaInvestissement / (economieTotale / 10);
      } else if (deltaInvestissement <= 0 && economieTotale >= 0) {
        roiAnnee = 0.0;
      }

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

  String _formatNumber(double value) {
    final format = NumberFormat("#,##0.00", "fr_FR");
    return format.format(value);
  }

  String _formatCurrency(double value) {
    final format = NumberFormat.currency(
      symbol: '€ ',
      decimalDigits: 2,
      locale: 'fr_FR',
    );
    return format.format(value);
  }

  double _calculerVolumeTotal(List<Pompe> pompes) {
    return pompes.fold(0.0, (sum, pompe) => sum + pompe.debit * pompe.heuresFonctionnement * 10);
  }

  double _calculerEnergieTotale(List<Pompe> pompes) {
    return pompes.fold(0.0, (sum, pompe) => sum + pompe.energieSpecifique * pompe.debit * pompe.heuresFonctionnement * 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comparatif - ${_projet?.nomSite ?? 'Projet'}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
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
                                    child: _buildSystemeCard('Ancien Système', _systemeAncien!, _consommationsAncien.isEmpty ? 0 : _consommationsAncien[0], _coutsAncien.isEmpty ? 0 : _coutsAncien[0], Colors.orange),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSystemeCard('Nouveau Système', _systemeNouveau!, _consommationsNouveau.isEmpty ? 0 : _consommationsNouveau[0], _coutsNouveau.isEmpty ? 0 : _coutsNouveau[0], Colors.blue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _safeMode ? _buildPlaceholder('Consommation Énergétique sur 10 ans') : RepaintBoundary(child: _buildGraphiqueFromSpots('Consommation Énergétique sur 10 ans', 'kWh', _spotsConsommationAncien, _spotsConsommationNouveau, Colors.orange, Colors.blue, false)),
                      const SizedBox(height: 24),
                      _safeMode ? _buildPlaceholder('Coût sur 10 ans') : RepaintBoundary(child: _buildGraphiqueFromSpots('Coût sur 10 ans', '€', _spotsCoutAncien, _spotsCoutNouveau, Colors.orange, Colors.blue, true)),
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
            const Text('Analyse de Rentabilité (ROI)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Coût énergétique total (10 ans):'),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Ancien: ${_formatCurrency(_roiData!['coutAncienTotal'])}', style: const TextStyle(color: Colors.orange)),
                Text('Nouveau: ${_formatCurrency(_roiData!['coutNouveauTotal'])}', style: const TextStyle(color: Colors.blue)),
              ])
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Économie sur 10 ans:'),
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
          const Text('Données Détaillées par Année', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Année')),
                DataColumn(label: Text('Conso Ancien (kWh)')),
                DataColumn(label: Text('Conso Nouveau (kWh)')),
                DataColumn(label: Text('Économie kWh')),
                DataColumn(label: Text('Coût Ancien (€)')),
                DataColumn(label: Text('Coût Nouveau (€)')),
                DataColumn(label: Text('Économie €')),
              ],
              rows: List.generate(10, (i) {
                final economieKWh = _consommationsAncien[i] - _consommationsNouveau[i];
                final economieEuro = _coutsAncien[i] - _coutsNouveau[i];
                return DataRow(cells: [
                  DataCell(Text('${_annees[i]}')),
                  DataCell(Text(_formatNumber(_consommationsAncien[i]))),
                  DataCell(Text(_formatNumber(_consommationsNouveau[i]))),
                  DataCell(Text(_formatNumber(economieKWh), style: TextStyle(color: economieKWh >= 0 ? Colors.green : Colors.red))),
                  DataCell(Text(_formatCurrency(_coutsAncien[i]))),
                  DataCell(Text(_formatCurrency(_coutsNouveau[i]))),
                  DataCell(Text(_formatCurrency(economieEuro), style: TextStyle(color: economieEuro >= 0 ? Colors.green : Colors.red))),
                ]);
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSystemeCard(String title, Systeme systeme, double consommation, double cout, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text('Coût investissement: ${_formatCurrency(systeme.coutInvestissementTotal)}'),
          const SizedBox(height: 4),
          Text('Consommation annuelle: ${_formatNumber(consommation)} kWh'),
          Text('Coût énergétique annuel: ${_formatCurrency(cout)}'),
        ]),
      ),
    );
  }

  Widget _buildGraphiqueEnergieSpecifique() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Volume vs Énergie Consommée (sur 10 ans)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  @override
  void dispose() {
    _calculService.close();
    super.dispose();
  }
}

class _SimpleLineChart extends StatelessWidget {
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

  const _SimpleLineChart({Key? key, required this.ancien, required this.nouveau, required this.colorAncien, required this.colorNouveau, required this.minX, required this.maxX, required this.minY, required this.maxY, required this.xTickCount, required this.yTickCount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SimpleLinePainter(ancien: ancien, nouveau: nouveau, colorAncien: colorAncien, colorNouveau: colorNouveau, minX: minX, maxX: maxX, minY: minY, maxY: maxY, xTickCount: xTickCount, yTickCount: yTickCount),
      size: Size.infinite,
    );
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
  _SimpleLinePainter({required this.ancien, required this.nouveau, required this.colorAncien, required this.colorNouveau, required this.minX, required this.maxX, required this.minY, required this.maxY, required this.xTickCount, required this.yTickCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paintAnc = Paint()..color = colorAncien..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true;
    final paintNouv = Paint()..color = colorNouveau..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true;
    final paintGrid = Paint()..color = Colors.grey.withOpacity(0.25)..style = PaintingStyle.stroke..strokeWidth = 1.0;

    Offset toOffset(FlSpot s) {
      final dx = (s.x - minX) / (maxX - minX) * size.width;
      final dy = size.height - (s.y - minY) / (maxY - minY) * size.height;
      return Offset(dx.clamp(0.0, size.width), dy.clamp(0.0, size.height));
    }

    // Draw grid lines based on tick counts
    final int vCount = xTickCount > 1 ? xTickCount : 5;
    final int hCount = yTickCount > 1 ? yTickCount : 5;
    for (var i = 0; i < vCount; i++) {
      final dx = (i / (vCount - 1)) * size.width;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paintGrid);
    }
    for (var i = 0; i < hCount; i++) {
      final dy = size.height - (i / (hCount - 1)) * size.height;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paintGrid);
    }

    if (ancien.length >= 2) {
      final path = Path();
      for (var i = 0; i < ancien.length; i++) {
        final o = toOffset(ancien[i]);
        if (i == 0) path.moveTo(o.dx, o.dy);
        else path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paintAnc);
    }

    if (nouveau.length >= 2) {
      final path2 = Path();
      for (var i = 0; i < nouveau.length; i++) {
        final o = toOffset(nouveau[i]);
        if (i == 0) path2.moveTo(o.dx, o.dy);
        else path2.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path2, paintNouv);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
