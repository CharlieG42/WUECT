import 'package:flutter/material.dart';
import '../../models/systeme.dart';
import '../../models/pompe.dart';
import '../../services/database_service.dart';
import 'pompe_form_screen.dart';

class SystemeFormScreen extends StatefulWidget {
  final int projetId;
  final int? systemeId;
  final String? nomSysteme;

  const SystemeFormScreen({
    super.key,
    required this.projetId,
    this.systemeId,
    this.nomSysteme,
  });

  @override
  State<SystemeFormScreen> createState() => _SystemeFormScreenState();
}

class _SystemeFormScreenState extends State<SystemeFormScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _coutInvestissementController = TextEditingController();

  List<Pompe> _pompes = [];
  bool _isLoading = true;
  bool _isNew = true;
  int? _systemeId;
  bool _systemeSaved = false; // Devient true une fois le système sauvegardé

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.systemeId != null) {
        final systeme = await _db.getSystemeById(widget.systemeId!);
        if (systeme != null) {
          _systemeId = systeme.id;
          _nomController.text = systeme.nom;
          _coutInvestissementController.text = systeme.coutInvestissementTotal.toString();
          _isNew = false;
          _systemeSaved = true; // Un système existant est considéré comme sauvegardé
        }
      } else {
        _nomController.text = widget.nomSysteme ?? '';
        _coutInvestissementController.text = '0.0';
        _isNew = true;
        _systemeSaved = false;
      }

      if (_systemeId != null) {
        final pompes = await _db.getPompesBySystemeId(_systemeId!);
        setState(() => _pompes = pompes);
      } else {
        setState(() => _pompes = []);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  Future<void> _saveSysteme() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Calculer le coût total depuis les pompes
      final coutTotal = _calculerCoutInvestissementTotal();
      
      final systeme = Systeme(
        id: _systemeId,
        projetId: widget.projetId,
        nom: _nomController.text,
        coutInvestissementTotal: coutTotal,
      );

      if (_isNew) {
        _systemeId = await _db.insertSysteme(systeme);
        _isNew = false;
        _systemeSaved = true;
        
        // Rafraîchir pour obtenir les données mises à jour
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Système créé avec succès. Ajoutez des pompes maintenant.')),
          );
        }
      } else {
        await _db.updateSysteme(systeme);
        _systemeSaved = true;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Système mis à jour')),
          );
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de sauvegarde: $e')),
        );
      }
    }
  }

  Future<void> _deletePompe(int pompeId) async {
    try {
      await _db.deletePompe(pompeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pompe supprimée avec succès')),
        );
        await _loadData();
        // Mettre à jour le coût total après suppression
        _updateCoutInvestissement();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de suppression: $e')),
        );
      }
    }
  }

  double _calculerCoutInvestissementTotal() {
    if (_pompes.isEmpty) return 0.0;
    return _pompes.fold(0.0, (sum, p) => sum + p.coutInvestissement);
  }

  double _calculerEsTotal() {
    if (_pompes.isEmpty) return 0.0;
    return _pompes.fold(0.0, (sum, p) => sum + p.energieSpecifique);
  }

  void _updateCoutInvestissement() {
    final coutTotal = _calculerCoutInvestissementTotal();
    _coutInvestissementController.text = coutTotal.toStringAsFixed(2);
  }

  Future<void> _validateAndExit() async {
    // Sauvegarder le système avec le coût calculé
    if (_systemeId == null) {
      // Pas de système, on ne peut pas valider
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez d\'abord créer le système')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final coutTotal = _calculerCoutInvestissementTotal();
      
      final systeme = Systeme(
        id: _systemeId,
        projetId: widget.projetId,
        nom: _nomController.text,
        coutInvestissementTotal: coutTotal,
      );

      await _db.updateSysteme(systeme);
      
      if (mounted) {
        // Retourner à la page précédente avec succès
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _navigateToPompeForm(int? pompeId) async {
    // Vérifier qu'on a bien un système sauvegardé
    if (_systemeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sauvegarder le système d\'abord')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PompeFormScreen(
          systemeId: _systemeId!,
          pompeId: pompeId,
        ),
      ),
    );

    if (result == true) {
      await _loadData();
      // Mettre à jour le coût total après ajout/modification de pompe
      _updateCoutInvestissement();
    }
  }

  void _showDeletePompeConfirmation(int pompeId) {
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
            onPressed: () {
              Navigator.pop(context);
              _deletePompe(pompeId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esTotal = _calculerEsTotal();
    final showValidateAndQuit = _systemeSaved;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Créer un Système' : 'Modifier le Système'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nom du système
                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du Système',
                        prefixIcon: Icon(Icons.settings),
                        border: OutlineInputBorder(),
                      ),
                      readOnly: widget.nomSysteme != null && _isNew,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Coût d'investissement (calculé automatiquement, non modifiable)
                    TextFormField(
                      controller: _coutInvestissementController,
                      decoration: InputDecoration(
                        labelText: 'Coût d\'investissement Total (€)',
                        prefixIcon: const Icon(Icons.monetization_on),
                        border: const OutlineInputBorder(),
                        suffixText: '€',
                        filled: true,
                        fillColor: Colors.grey[100],
                        helperText: _pompes.isNotEmpty
                            ? 'Calculé automatiquement depuis les pompes'
                            : 'Sauvegardez le système et ajoutez des pompes',
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // Énergie Spécifique totale du système
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Énergie Spécifique Totale (Es)',
                        suffixText: 'kW/m3/h',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[100],
                        helperText: _pompes.isNotEmpty
                            ? 'Somme des Es des pompes'
                            : 'Ajoutez des pompes pour calculer',
                      ),
                      controller: TextEditingController(text: esTotal.toStringAsFixed(4)),
                      readOnly: true,
                    ),
                    const SizedBox(height: 24),

                    // Bouton principal : Créer/Mettre à jour OU Valider & Quitter
                    ElevatedButton.icon(
                      icon: showValidateAndQuit ? const Icon(Icons.check) : const Icon(Icons.save),
                      label: Text(showValidateAndQuit ? 'Valider & Quitter' : (_isNew ? 'Créer le Système' : 'Mettre à jour')),
                      onPressed: _isLoading ? null : (showValidateAndQuit ? _validateAndExit : _saveSysteme),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: showValidateAndQuit ? Colors.green : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Divider(height: 24),
                    const SizedBox(height: 8),

                    // Liste des pompes
                    const Text(
                      'Pompes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    if (_systemeId == null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _systemeSaved
                                ? 'Le système est créé. Ajoutez des pompes.'
                                : 'Sauvegardez le système d\'abord pour ajouter des pompes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontStyle: _systemeSaved ? FontStyle.normal : FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else if (_pompes.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Aucune pompe ajoutée. Appuyez sur + pour en ajouter une.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ..._pompes.map((pompe) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text('${pompe.marque} ${pompe.modele}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Puissance: ${pompe.puissanceNominale} kW'),
                                  Text('Débit: ${pompe.debit} m3/h'),
                                  Text('HMT: ${pompe.hmt} mce'),
                                  Text('P1 Calculée: ${pompe.p1Calculee.toStringAsFixed(2)} kW'),
                                  if (pompe.p1Estimee > 0 && pompe.p1Estimee != pompe.p1Calculee)
                                    Text('P1 Estimée: ${pompe.p1Estimee.toStringAsFixed(2)} kW'),
                                  Text('Es: ${pompe.energieSpecifique.toStringAsFixed(4)} kW/m3/h'),
                                  Text('Coût: ${pompe.coutInvestissement} €'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _navigateToPompeForm(pompe.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeletePompeConfirmation(pompe.id!),
                                  ),
                                ],
                              ),
                              onTap: () => _navigateToPompeForm(pompe.id),
                            ),
                          )),

                    const SizedBox(height: 16),

                    // Bouton pour ajouter une pompe (uniquement si système sauvegardé)
                    if (_systemeSaved)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une Pompe'),
                        onPressed: () => _navigateToPompeForm(null),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _coutInvestissementController.dispose();
    super.dispose();
  }
}
