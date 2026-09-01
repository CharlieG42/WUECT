import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/projet.dart';
import '../../models/systeme.dart';
import '../../models/pompe.dart';
import '../../services/calcul_service.dart';
import '../../services/database_service.dart';
import 'package:intl/intl.dart';

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
  List<int> _annees = [];
  Map<String, dynamic>? _roiData;
  
  // Données pour le graphique énergie spécifique
  List<Pompe> _pompesAncien = [];
  List<Pompe> _pompesNouveau = [];
  double _volumeAncien = 0;
  double _volumeNouveau = 0;
  double _energieAncien = 0;
  double _energieNouveau = 0;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final projet = await _db.getProjetById(widget.projetId);
      if (projet == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Projet non trouvé')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final systemes = await _db.getSystemesByProjetId(widget.projetId);
      if (systemes.length != 2) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Un projet doit avoir exactement 2 systèmes pour le comparatif')),
          );
          Navigator.pop(context);
        }
        return;
      }

      _projet = projet;
      
      // Trouver les systèmes ancien et nouveau (avec gestion d'erreur si noms non conformes)
      final ancienSystems = systemes.where((s) => s.nom.toLowerCase().contains('ancien')).toList();
      final nouveauSystems = systemes.where((s) => s.nom.toLowerCase().contains('nouveau')).toList();
      
      _systemeAncien = ancienSystems.isNotEmpty ? ancienSystems.first : null;
      _systemeNouveau = nouveauSystems.isNotEmpty ? nouveauSystems.first : null;
      
      // Vérifier qu'on a bien trouvé les deux systèmes
      if (_systemeAncien == null || _systemeNouveau == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Les systèmes doivent contenir "Ancien" et "Nouveau" dans leur nom')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Charger les pompes pour chaque système (en parallèle)
      final pompesAncienFuture = _db.getPompesBySystemeId(_systemeAncien!.id!);
      final pompesNouveauFuture = _db.getPompesBySystemeId(_systemeNouveau!.id!);
      
      _pompesAncien = await pompesAncienFuture;
      _pompesNouveau = await pompesNouveauFuture;
      
      // Calculer volume et énergie pour chaque système
      _volumeAncien = _calculerVolumeTotal(_pompesAncien);
      _volumeNouveau = _calculerVolumeTotal(_pompesNouveau);
      _energieAncien = _calculerEnergieTotale(_pompesAncien);
      _energieNouveau = _calculerEnergieTotale(_pompesNouveau);

      final anneeEnCours = DateTime.now().year;
      _annees = List.generate(10, (i) => anneeEnCours + i);

      // Calcul des données sur 10 ans en parallèle
      final donneesAncienFuture = Future(() => CalculService.calculerDonnees10AnsAvecPompes(
        _pompesAncien,
        projet,
      ));
      final donneesNouveauFuture = Future(() => CalculService.calculerDonnees10AnsAvecPompes(
        _pompesNouveau,
        projet,
      ));

      final results = await Future.wait<Map<String, List<double>>>([
        donneesAncienFuture,
        donneesNouveauFuture,
      ]);

      final donneesAncien = results[0];
      final donneesNouveau = results[1];

      _consommationsAncien = donneesAncien['consommations']!;
      _consommationsNouveau = donneesNouveau['consommations']!;
      _coutsAncien = donneesAncien['coutsEnergetiques']!;
      _coutsNouveau = donneesNouveau['coutsEnergetiques']!;

      // Calcul du ROI à partir des données déjà calculées
      final coutAncienTotal = _coutsAncien.reduce((a, b) => a + b);
      final coutNouveauTotal = _coutsNouveau.reduce((a, b) => a + b);
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
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de calcul: $e')),
        );
      }
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

  /// Calcule le volume total pompé sur 10 ans pour un système
  /// Vol = SOMME des (Débit * heures * 10) pour chaque pompe
  double _calculerVolumeTotal(List<Pompe> pompes) {
    return pompes.fold(0.0, (sum, pompe) => sum + pompe.debit * pompe.heuresFonctionnement * 10);
  }

  /// Calcule l'énergie totale consommée pour un système
  /// Energie = SOMME des (Energie Spécifique * Débit * heures * 10) pour chaque pompe
  double _calculerEnergieTotale(List<Pompe> pompes) {
    return pompes.fold(0.0, (sum, pompe) => sum + pompe.energieSpecifique * pompe.debit * pompe.heuresFonctionnement * 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comparatif - ${_projet?.nomSite ?? 'Projet'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
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
                      // Résumé des systèmes
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'Résumé des Systèmes',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildSystemeCard(
                                      'Ancien Système',
                                      _systemeAncien!,
                                      _consommationsAncien.isEmpty ? 0 : _consommationsAncien[0],
                                      _coutsAncien.isEmpty ? 0 : _coutsAncien[0],
                                      Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSystemeCard(
                                      'Nouveau Système',
                                      _systemeNouveau!,
                                      _consommationsNouveau.isEmpty ? 0 : _consommationsNouveau[0],
                                      _coutsNouveau.isEmpty ? 0 : _coutsNouveau[0],
                                      Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Graphique Consommation Energétique
                      _buildGraphiqueSection(
                        'Consommation Énergétique sur 10 ans',
                        'kWh',
                        _consommationsAncien,
                        _consommationsNouveau,
                        Colors.orange,
                        Colors.green,
                        false,
                      ),
                      const SizedBox(height: 24),

                      // Graphique Coût Energétique
                      _buildGraphiqueSection(
                        'Coût Énergétique sur 10 ans',
                        '€',
                        _coutsAncien,
                        _coutsNouveau,
                        Colors.red,
                        Colors.blue,
                        true,
                      ),
                      const SizedBox(height: 24),

                      // Graphique Énergie Spécifique - Comparaison Volume vs Énergie
                      _buildGraphiqueEnergieSpecifique(),
                      const SizedBox(height: 24),

                      // ROI et analyse
                      if (_roiData != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Analyse de Rentabilité (ROI)',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const Divider(height: 16),
                                const SizedBox(height: 8),
                                
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Coût énergétique total (10 ans):'),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Ancien: ${_formatCurrency(_roiData!['coutAncienTotal'])}',
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                        Text(
                                          'Nouveau: ${_formatCurrency(_roiData!['coutNouveauTotal'])}',
                                          style: const TextStyle(color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Économie sur 10 ans:'),
                                    Text(
                                      _roiData!['economieTotale'] >= 0
                                          ? '+${_formatCurrency(_roiData!['economieTotale'])}'
                                          : _formatCurrency(_roiData!['economieTotale']),
                                      style: TextStyle(
                                        color: _roiData!['economieTotale'] >= 0 ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Différence d\'investissement:'),
                                    Text(
                                      _formatCurrency(_roiData!['deltaInvestissement']),
                                      style: TextStyle(
                                        color: _roiData!['deltaInvestissement'] >= 0 ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                if (_roiData!['roiAnnee'] == 0.0)
                                  const Text(
                                    'ROI: Rentable immédiatement !',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                else if (_roiData!['roiAnnee'] == double.infinity)
                                  const Text(
                                    'ROI: Non rentable sur 10 ans',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                else
                                  Text(
                                    'ROI: ${_formatNumber(_roiData!['roiAnnee'])} années',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                
                                Text(
                                  'Statut: ${_roiData!['estRentable'] ? 'Rentable' : 'Non rentable'}',
                                  style: TextStyle(
                                    color: _roiData!['estRentable'] ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Tableau des données détaillées
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Données Détaillées par Année',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
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
                                    return DataRow(
                                      cells: [
                                        DataCell(Text('${_annees[i]}')),
                                        DataCell(Text(_formatNumber(_consommationsAncien[i]))),
                                        DataCell(Text(_formatNumber(_consommationsNouveau[i]))),
                                        DataCell(
                                          Text(
                                            _formatNumber(economieKWh),
                                            style: TextStyle(
                                              color: economieKWh >= 0 ? Colors.green : Colors.red,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(_formatCurrency(_coutsAncien[i]))),
                                        DataCell(Text(_formatCurrency(_coutsNouveau[i]))),
                                        DataCell(
                                          Text(
                                            _formatCurrency(economieEuro),
                                            style: TextStyle(
                                              color: economieEuro >= 0 ? Colors.green : Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                  columnSpacing: 8,
                                  horizontalMargin: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSystemeCard(String title, Systeme systeme, double consommation, double cout, Color color) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text('Coût investissement: ${_formatCurrency(systeme.coutInvestissementTotal)}'),
            const SizedBox(height: 4),
            Text('Consommation annuelle: ${_formatNumber(consommation)} kWh'),
            Text('Coût énergétique annuel: ${_formatCurrency(cout)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphiqueSection(
    String title,
    String unite,
    List<double> dataAncien,
    List<double> dataNouveau,
    Color colorAncien,
    Color colorNouveau,
    bool isCurrency,
  ) {
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
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    verticalInterval: 1,
                    horizontalInterval: dataAncien.isNotEmpty && dataNouveau.isNotEmpty
                        ? (dataAncien.reduce((a, b) => a > b ? a : b) - dataAncien.reduce((a, b) => a < b ? a : b)) / 5
                        : 1,
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    ),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _annees.length) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text('${_annees[value.toInt()]}'),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: isCurrency ? 80 : 60,
                        interval: isCurrency ? 1000 : 1000,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              isCurrency ? _formatCurrency(value) : _formatNumber(value),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 9,
                  minY: 0,
                  maxY: dataAncien.isNotEmpty && dataNouveau.isNotEmpty
                      ? [
                          ...dataAncien,
                          ...dataNouveau,
                        ].reduce((a, b) => a > b ? a : b) * 1.1
                      : 1000,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        dataAncien.length,
                        (i) => FlSpot(i.toDouble(), dataAncien[i]),
                      ),
                      isCurved: true,
                      color: colorAncien,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                    LineChartBarData(
                      spots: List.generate(
                        dataNouveau.length,
                        (i) => FlSpot(i.toDouble(), dataNouveau[i]),
                      ),
                      isCurved: true,
                      color: colorNouveau,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      VerticalLine(
                        x: 0,
                        color: Colors.grey[400]!,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend('Ancien Système', colorAncien),
                const SizedBox(width: 16),
                _buildLegend('Nouveau Système', colorNouveau),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  /// Graphique scatter plot comparant Volume vs Énergie pour les systèmes
  Widget _buildGraphiqueEnergieSpecifique() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Volume vs Énergie Consommée (sur 10 ans)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Comparaison des systèmes basée sur l\'énergie spécifique des pompes',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ScatterChart(
                ScatterChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    verticalInterval: 1,
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    ),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text('${value.toInt()} m³'),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        interval: _energieAncien > _energieNouveau 
                            ? _energieAncien / 5
                            : _energieNouveau / 5,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text('${value.toInt()} kWh'),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: _volumeAncien > _volumeNouveau ? _volumeAncien * 1.1 : _volumeNouveau * 1.1,
                  minY: 0,
                  maxY: _energieAncien > _energieNouveau ? _energieAncien * 1.1 : _energieNouveau * 1.1,
                  scatterSpots: [
                    // Point pour l'ancien système
                    ScatterSpot(
                      _volumeAncien,
                      _energieAncien,
                      color: Colors.grey,
                      radius: 8,
                    ),
                    // Point pour le nouveau système
                    ScatterSpot(
                      _volumeNouveau,
                      _energieNouveau,
                      color: Colors.blue,
                      radius: 8,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend('Ancien Système', Colors.grey),
                const SizedBox(width: 16),
                _buildLegend('Nouveau Système', Colors.blue),
              ],
            ),
            const SizedBox(height: 16),
            // Affichage des valeurs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ancien Système:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Volume: ${_formatNumber(_volumeAncien)} m³'),
                    Text('Énergie: ${_formatNumber(_energieAncien)} kWh'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Nouveau Système:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Volume: ${_formatNumber(_volumeNouveau)} m³'),
                    Text('Énergie: ${_formatNumber(_energieNouveau)} kWh'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _calculService.close();
    super.dispose();
  }
}
