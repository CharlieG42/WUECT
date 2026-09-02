import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/projet.dart';
import '../../models/contact.dart';
import '../../models/systeme.dart';
import '../../models/pompe.dart';
import '../../services/database_service.dart';
import '../contact/contact_form_screen.dart';
import '../systeme/systeme_form_screen.dart';
import '../systeme/pompe_form_screen.dart';
import '../resultat/resultat_screen.dart';

class ProjetDetailScreen extends StatefulWidget {
  final int projetId;

  const ProjetDetailScreen({super.key, required this.projetId});

  @override
  State<ProjetDetailScreen> createState() => _ProjetDetailScreenState();
}

class _ProjetDetailScreenState extends State<ProjetDetailScreen> {
  final DatabaseService _db = DatabaseService.instance;
  
  Projet? _projet;
  Contact? _contact;
  List<Systeme> _systemes = [];
  Map<int, List<Pompe>> _pompesBySysteme = {}; // systemeId -> List<Pompe>
  Map<int, double> _energieSpecifiqueBySysteme = {}; // systemeId -> energieSpecifiqueCumulee
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
      if (projet != null) {
        final contact = await _db.getContactById(projet.contactId);
        final systemes = await _db.getSystemesByProjetId(widget.projetId);
        
        // Charger les pompes pour chaque système
        final pompesBySysteme = <int, List<Pompe>>{};
        final energieSpecifiqueBySysteme = <int, double>{};
        
        for (final systeme in systemes) {
          if (systeme.id != null) {
            pompesBySysteme[systeme.id!] = await _db.getPompesBySystemeId(systeme.id!);
            // Précalculer l'énergie spécifique cumulée pour ce système
            energieSpecifiqueBySysteme[systeme.id!] = _calculerEnergieSpecifiqueCumulee(pompesBySysteme[systeme.id!]!);
          }
        }
        
        setState(() {
          _projet = projet;
          _contact = contact;
          _systemes = systemes;
          _pompesBySysteme = pompesBySysteme;
          _energieSpecifiqueBySysteme = energieSpecifiqueBySysteme;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Projet non trouvé')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  Future<void> _deleteSysteme(int systemeId) async {
    try {
      await _db.deletePompeBySystemeId(systemeId);
      await _db.deleteSysteme(systemeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Système supprimé avec succès')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de suppression: $e')),
        );
      }
    }
  }

  bool _hasAncienSysteme() {
    final result = _systemes.any((s) => s.nom.toLowerCase().contains('ancien'));
    debugPrint('[DEBUG] _hasAncienSysteme: $result - Systèmes: ${_systemes.map((s) => s.nom).toList()}');
    return result;
  }
  
  bool _hasNouveauSysteme() {
    final result = _systemes.any((s) => s.nom.toLowerCase().contains('nouveau'));
    debugPrint('[DEBUG] _hasNouveauSysteme: $result - Systèmes: ${_systemes.map((s) => s.nom).toList()}');
    return result;
  }

  String _formatNumber(double value) {
    final format = NumberFormat("#,##0.0000", "fr_FR");
    return format.format(value);
  }

  /// Calcule l'énergie spécifique cumulée (somme) pour un système
  double _calculerEnergieSpecifiqueCumulee(List<Pompe> pompes) {
    if (pompes.isEmpty) return 0.0;
    
    return pompes.fold(
      0.0,
      (sum, pompe) => sum + pompe.energieSpecifique,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_projet?.nomSite ?? 'Détails du Projet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projet == null
              ? const Center(child: Text('Projet non trouvé'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Informations du projet
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informations du Projet',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 16),
                              Text('Nom du site: ${_projet!.nomSite}'),
                              if (_contact != null) ...[
                                const SizedBox(height: 8),
                                Text('Client: ${_contact!.client}'),
                                Text('Contact: ${_contact!.nom}'),
                                Text('Email: ${_contact!.email}'),
                                Text('Mobile: ${_contact!.mobile}'),
                              ],
                              const SizedBox(height: 8),
                              Text('Coût énergie: ${_projet!.coutEnergie} €/kWh'),
                              Text('Augmentation énergie/an: ${_projet!.pourcentageAugmentationEnergie}%'),
                              Text('Perte rendement/an: ${_projet!.percentagePerteRendement}%'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Boutons pour modifier le projet ou le contact
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifier Projet'),
                              onPressed: () => _showEditProjetDialog(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifier Contact'),
                              onPressed: () => _navigateToContactForm(_contact?.id),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Systèmes
                      const Text(
                        'Systèmes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      
                      if (_systemes.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Aucun système ajouté. Ajoutez l\'Ancien Système et le Nouveau Système pour continuer.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ..._systemes.map((systeme) => _buildSystemeCardWithPompes(systeme)),
                      
                      const SizedBox(height: 16),
                      
                      // Boutons pour ajouter des systèmes
                      Row(
                        children: [
                          if (!_hasAncienSysteme())
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Ancien Système'),
                                onPressed: () => _navigateToSystemeForm(null, 'Ancien Système'),
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),
                          const SizedBox(width: 8),
                          if (!_hasNouveauSysteme())
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Nouveau Système'),
                                onPressed: () => _navigateToSystemeForm(null, 'Nouveau Système'),
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Bouton pour voir les résultats (uniquement si les 2 systèmes existent)
                      if (_hasAncienSysteme() && _hasNouveauSysteme())
                        ElevatedButton.icon(
                          icon: const Icon(Icons.analytics),
                          label: const Text('Voir le Comparatif'),
                          onPressed: () {
                            debugPrint('[DEBUG] Bouton Voir le Comparatif cliqué - projetId: ${widget.projetId}');
                            debugPrint('[DEBUG] Navigation vers ResultatScreen...');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResultatScreen(projetId: widget.projetId),
                              ),
                            ).then((value) {
                              debugPrint('[DEBUG] Retour de ResultatScreen - value: $value');
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                          ),
                        )
                      else
                        Opacity(
                          opacity: 0.5,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.analytics),
                            label: const Text('Voir le Comparatif (2 systèmes requis)'),
                            onPressed: null,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _showEditProjetDialog() async {
    if (_projet == null) return;
    
    final nomSiteController = TextEditingController(text: _projet!.nomSite);
    final coutEnergieController = TextEditingController(text: _projet!.coutEnergie.toString());
    final pourcentageAugController = TextEditingController(text: _projet!.pourcentageAugmentationEnergie.toString());
    final percentagePerteController = TextEditingController(text: _projet!.percentagePerteRendement.toString());

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le Projet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nomSiteController,
                decoration: const InputDecoration(labelText: 'Nom du Site'),
              ),
              TextFormField(
                controller: coutEnergieController,
                decoration: const InputDecoration(labelText: 'Coût énergie (€/kWh)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: pourcentageAugController,
                decoration: const InputDecoration(labelText: 'Augmentation énergie/an (%)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: percentagePerteController,
                decoration: const InputDecoration(labelText: 'Perte rendement/an (µCoef %)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final projet = _projet!.copyWith(
                  nomSite: nomSiteController.text,
                  coutEnergie: double.parse(coutEnergieController.text),
                  pourcentageAugmentationEnergie: double.parse(pourcentageAugController.text),
                  percentagePerteRendement: double.parse(percentagePerteController.text),
                );
                await _db.updateProjet(projet);
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Projet mis à jour')),
                      );
                      _loadData();
                    }
                  });
                }
              } catch (e) {
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  });
                }
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
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

  Future<void> _navigateToSystemeForm(int? systemeId, [String? nomSysteme]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SystemeFormScreen(
          projetId: widget.projetId,
          systemeId: systemeId,
          nomSysteme: nomSysteme,
        ),
      ),
    );
    
    if (result == true && mounted) {
      _loadData();
    }
  }

  void _showDeleteSystemeConfirmation(int systemeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le Système'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce système ? Toutes les pompes associées seront également supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSysteme(systemeId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  /// Construit une carte pour un système avec la liste de ses pompes
  Widget _buildSystemeCardWithPompes(Systeme systeme) {
    final pompes = _pompesBySysteme[systeme.id] ?? [];
    // Utiliser la valeur précalculée au lieu de recalculer pendant le build
    final energieSpecifiqueCumulee = _energieSpecifiqueBySysteme[systeme.id] ?? 0.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête du système avec boutons
          ListTile(
            title: Text(
              systeme.nom,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coût investissement: ${systeme.coutInvestissementTotal} €'),
                if (pompes.isNotEmpty)
                  Text('Énergie spécifique cumulée: ${_formatNumber(energieSpecifiqueCumulee)} kW/m³/h'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _navigateToSystemeForm(systeme.id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteSystemeConfirmation(systeme.id!),
                ),
              ],
            ),
            onTap: () => _navigateToSystemeForm(systeme.id),
          ),
          
          // Section des pompes
          if (pompes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Pompes:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            ),
            ...pompes.map((pompe) => _buildPompeListItem(pompe, systeme.id!)),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Aucune pompe. Ajoutez-en une via le bouton Modifier.',
                style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Construit un item de liste pour une pompe (similaire à systeme_form_screen.dart)
  Widget _buildPompeListItem(Pompe pompe, int systemeId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        margin: const EdgeInsets.all(0),
        child: ListTile(
          title: Text('${pompe.marque} ${pompe.modele}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Puissance: ${pompe.puissanceNominale} kW'),
              Text('Débit: ${pompe.debit} m³/h'),
              Text('HMT: ${pompe.hmt} mce'),
              Text('P1 Calculée: ${pompe.p1Calculee.toStringAsFixed(2)} kW'),
              if (pompe.p1Estimee > 0 && pompe.p1Estimee != pompe.p1Calculee)
                Text('P1 Estimée: ${pompe.p1Estimee.toStringAsFixed(2)} kW'),
              Text('Es: ${pompe.energieSpecifique.toStringAsFixed(4)} kW/m³/h'),
              Text('Heures: ${pompe.heuresFonctionnement} h/an'),
              Text('Coût: ${pompe.coutInvestissement} €'),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                onPressed: () => _navigateToPompeForm(systemeId, pompe.id),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _showDeletePompeConfirmation(pompe.id!, systemeId),
              ),
            ],
          ),
          onTap: () => _navigateToPompeForm(systemeId, pompe.id),
        ),
      ),
    );
  }

  /// Navigation vers le formulaire de pompe
  Future<void> _navigateToPompeForm(int systemeId, int? pompeId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PompeFormScreen(
          systemeId: systemeId,
          pompeId: pompeId,
        ),
      ),
    );
    
    if (result == true && mounted) {
      _loadData();
    }
  }

  /// Affichage de la confirmation de suppression d'une pompe
  void _showDeletePompeConfirmation(int pompeId, int systemeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la Pompe'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette pompe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePompe(pompeId, systemeId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  /// Suppression d'une pompe
  Future<void> _deletePompe(int pompeId, int systemeId) async {
    try {
      await _db.deletePompe(pompeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pompe supprimée avec succès')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de suppression: $e')),
        );
      }
    }
  }
}
