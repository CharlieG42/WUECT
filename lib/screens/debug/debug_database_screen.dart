import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/contact.dart';
import '../../models/projet.dart';
import '../../models/systeme.dart';
import '../../models/pompe.dart';
import '../../services/database_service.dart';
import '../../utils/error_handler.dart';

class DebugDatabaseScreen extends StatefulWidget {
  const DebugDatabaseScreen({super.key});

  @override
  State<DebugDatabaseScreen> createState() => _DebugDatabaseScreenState();
}

class _DebugDatabaseScreenState extends State<DebugDatabaseScreen> {
  final DatabaseService _db = DatabaseService.instance;
  
  List<Contact> _contacts = [];
  List<Projet> _projets = [];
  List<Systeme> _systemes = [];
  List<Pompe> _pompes = [];
  bool _isLoading = true;
  String _hivePath = 'Non disponible sur cette plateforme';

  @override
  void initState() {
    super.initState();
    _loadData();
    _getHivePath();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await _db.getAllContacts();
      final projets = await _db.getAllProjets();
      final systemes = await _db.getAllSystemes();
      final pompes = await _db.getAllPompes();
      
      setState(() {
        _contacts = contacts;
        _projets = projets;
        _systemes = systemes;
        _pompes = pompes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Erreur de chargement: $e', error: true);
      }
    }
  }

  Future<void> _getHivePath() async {
    try {
      // Chemin selon la plateforme
      String path;
      
      // Sur desktop (Windows, Linux, macOS), Hive utilise le système de fichiers
      // Sur Web, Hive utilise IndexedDB
      // Sur mobile, Hive utilise le stockage interne de l'app
      
      // Note: En mode Web, Hive ne donne pas accès au chemin physique
      // car il utilise IndexedDB du navigateur
      
      // Pour Flutter Desktop
      if (defaultTargetPlatform == TargetPlatform.windows) {
        path = '%LOCALAPPDATA%<package>app_datahive';
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        path = '~/.local/share/<package>/hive';
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        path = '~/Library/Application Support/<package>/hive';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        path = '/data/data/<package>/app_flutter/hive';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        path = 'Documents/hive';
      } else {
        // Web
        path = 'Web: IndexedDB (visible via DevTools F12 > Application > IndexedDB)';
      }
      
      setState(() {
        _hivePath = path;
      });
    } catch (e) {
      setState(() {
        _hivePath = 'Erreur: $e';
      });
    }
  }

  Widget _buildTableCard(String title, List<dynamic> items, List<String> columns, List<Function(dynamic)> getters) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Aucune donnée', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title (${items.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
                rows: items.map((item) {
                  return DataRow(
                    cells: List.generate(getters.length, (index) {
                      final value = getters[index](item);
                      return DataCell(
                        Text(value != null ? value.toString() : 'null'),
                      );
                    }),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Base de données'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Chemin de la base de données
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Localisation de Hive', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_hivePath, style: const TextStyle(fontFamily: 'monospace')),
                          const SizedBox(height: 8),
                          const Text(
                            'Pour Flutter Web (Chrome): Ouvrez DevTools (F12) → Application → IndexedDB',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Table Contacts
                  _buildTableCard(
                    'Contacts',
                    _contacts,
                    ['ID', 'Client', 'Nom', 'Email', 'Mobile'],
                    [(c) => c.id, (c) => c.client, (c) => c.nom, (c) => c.email, (c) => c.mobile],
                  ),
                  const SizedBox(height: 12),
                  
                  // Table Projets
                  _buildTableCard(
                    'Projets',
                    _projets,
                    ['ID', 'Nom Site', 'Contact ID', 'Coût Énergie', 'Augmentation %', 'Perte %'],
                    [
                      (p) => p.id,
                      (p) => p.nomSite,
                      (p) => p.contactId,
                      (p) => p.coutEnergie,
                      (p) => p.pourcentageAugmentationEnergie,
                      (p) => p.percentagePerteRendement,
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Table Systèmes
                  _buildTableCard(
                    'Systèmes',
                    _systemes,
                    ['ID', 'Projet ID', 'Nom', 'Coût Investissement'],
                    [
                      (s) => s.id,
                      (s) => s.projetId,
                      (s) => s.nom,
                      (s) => s.coutInvestissementTotal,
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Table Pompes
                  _buildTableCard(
                    'Pompes',
                    _pompes,
                    ['ID', 'Système ID', 'Nom', 'Puissance', 'Rendement'],
                    [
                      (p) => p.id,
                      (p) => p.systemeId,
                      (p) => p.nom,
                      (p) => p.puissance,
                      (p) => p.rendement,
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bouton pour forcer la sauvegarde (test)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Forcer sauvegarde test'),
                    onPressed: () async {
                      try {
                        final testContact = Contact(
                          client: 'Test Client ${DateTime.now().millisecondsSinceEpoch}',
                          nom: 'Test Contact',
                          email: 'test@example.com',
                          mobile: '0000000000',
                        );
                        final id = await _db.insertContact(testContact);
                        if (mounted) {
                          await _loadData();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                              ErrorHandler.showSnackBar(context, 'Contact test créé avec ID: $id');
                            }
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                              ErrorHandler.showSnackBar(context, 'Erreur: $e', error: true);
                            }
                          });
                        }
                      }
                    },
                  ),
                  
                ],
              ),
            ),
    );
  }
}
