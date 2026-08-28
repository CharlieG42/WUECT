import 'package:flutter/material.dart';
import '../../models/pompe.dart';
import '../../services/database_service.dart';
import '../../utils/decimal_input_formatter.dart';

class PompeFormScreen extends StatefulWidget {
  final int systemeId;
  final int? pompeId;

  const PompeFormScreen({
    super.key,
    required this.systemeId,
    this.pompeId,
  });

  @override
  State<PompeFormScreen> createState() => _PompeFormScreenState();
}

class _PompeFormScreenState extends State<PompeFormScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _marqueController = TextEditingController();
  final TextEditingController _modeleController = TextEditingController();
  final TextEditingController _puissanceNominaleController = TextEditingController();
  final TextEditingController _debitController = TextEditingController();
  final TextEditingController _hmtController = TextEditingController();
  final TextEditingController _rendementInitialPompeController = TextEditingController();
  final TextEditingController _rendementInitialMoteurController = TextEditingController();
  final TextEditingController _anneeInstallationController = TextEditingController();
  final TextEditingController _heuresFonctionnementController = TextEditingController();
  final TextEditingController _coutInvestissementController = TextEditingController();
  final TextEditingController _p1EstimeeController = TextEditingController();

  bool _isLoading = true;
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    _loadPompe();
  }

  Future<void> _loadPompe() async {
    setState(() => _isLoading = true);
    try {
      if (widget.pompeId != null) {
        final pompe = await _db.getPompeById(widget.pompeId!);
        if (pompe != null) {
          _marqueController.text = pompe.marque;
          _modeleController.text = pompe.modele;
          _puissanceNominaleController.text = pompe.puissanceNominale.toString();
          _debitController.text = pompe.debit.toString();
          _hmtController.text = pompe.hmt.toString();
          _rendementInitialPompeController.text = pompe.rendementInitialPompe.toString();
          _rendementInitialMoteurController.text = pompe.rendementInitialMoteur.toString();
          _anneeInstallationController.text = pompe.anneeInstallation.toString();
          _heuresFonctionnementController.text = pompe.heuresFonctionnement.toString();
          _coutInvestissementController.text = pompe.coutInvestissement.toString();
          _p1EstimeeController.text = pompe.p1Estimee.toString();
          _isNew = false;
        }
      } else {
        // Valeurs par défaut pour une nouvelle pompe
        _anneeInstallationController.text = DateTime.now().year.toString();
        _heuresFonctionnementController.text = '8760'; // 24h * 365j
        _rendementInitialPompeController.text = '85.0';
        _rendementInitialMoteurController.text = '90.0';
        _p1EstimeeController.text = '0.0';
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

  // Calculer P1 à partir des valeurs actuelles du formulaire
  double _calculerP1() {
    final debit = double.tryParse(_debitController.text) ?? 0.0;
    final hmt = double.tryParse(_hmtController.text) ?? 0.0;
    final rendementPompe = double.tryParse(_rendementInitialPompeController.text) ?? 0.0;
    final rendementMoteur = double.tryParse(_rendementInitialMoteurController.text) ?? 0.0;
    
    if (debit <= 0 || hmt <= 0 || rendementPompe <= 0 || rendementMoteur <= 0) {
      return 0.0;
    }
    return (debit * hmt) / (367 * (rendementPompe / 100) * (rendementMoteur / 100));
  }

  // Calculer Es à partir des valeurs actuelles
  double _calculerEs() {
    final p1Calculee = _calculerP1();
    final debit = double.tryParse(_debitController.text) ?? 0.0;
    final p1Estimee = double.tryParse(_p1EstimeeController.text) ?? 0.0;
    
    final puissanceUtilisee = (p1Estimee > 0 && p1Estimee != p1Calculee) ? p1Estimee : p1Calculee;
    
    if (debit <= 0) return 0.0;
    return puissanceUtilisee / debit;
  }

  // Vérifier si P1 Estimée est différente de P1 Calculée
  bool _p1EstimeeDiffere() {
    final p1Calculee = _calculerP1();
    final p1Estimee = double.tryParse(_p1EstimeeController.text) ?? 0.0;
    return p1Estimee > 0 && p1Estimee != p1Calculee;
  }

  Future<void> _savePompe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final pompe = Pompe(
        id: widget.pompeId,
        systemeId: widget.systemeId,
        marque: _marqueController.text,
        modele: _modeleController.text,
        puissanceNominale: double.parse(_puissanceNominaleController.text),
        debit: double.parse(_debitController.text),
        hmt: double.parse(_hmtController.text),
        rendementInitialPompe: double.parse(_rendementInitialPompeController.text),
        rendementInitialMoteur: double.parse(_rendementInitialMoteurController.text),
        anneeInstallation: int.parse(_anneeInstallationController.text),
        heuresFonctionnement: int.parse(_heuresFonctionnementController.text),
        coutInvestissement: double.parse(_coutInvestissementController.text),
        p1Estimee: double.parse(_p1EstimeeController.text),
      );

      if (_isNew) {
        await _db.insertPompe(pompe);
      } else {
        await _db.updatePompe(pompe);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isNew ? 'Pompe créée avec succès' : 'Pompe mise à jour'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de sauvegarde: $e')),
        );
      }
    }
  }

  Future<void> _deletePompe() async {
    if (widget.pompeId == null) return;

    try {
      await _db.deletePompe(widget.pompeId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pompe supprimée avec succès')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de suppression: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1Calculee = _calculerP1();
    final es = _calculerEs();
    final utiliseP1Estimee = _p1EstimeeDiffere();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Créer une Pompe' : 'Modifier la Pompe'),
        actions: _isNew
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(),
                ),
              ],
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
                    // Informations générales
                    const Text(
                      'Informations Générales',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _marqueController,
                      decoration: const InputDecoration(
                        labelText: 'Marque',
                        prefixIcon: Icon(Icons.branding_watermark),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer une marque';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _modeleController,
                      decoration: const InputDecoration(
                        labelText: 'Modèle',
                        prefixIcon: Icon(Icons.model_training),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un modèle';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Caractéristiques techniques
                    const SizedBox(height: 24),
                    const Text(
                      'Caractéristiques Techniques',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _puissanceNominaleController,
                            decoration: const InputDecoration(
                              labelText: 'Puissance Nominale',
                              suffixText: 'kW',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [DecimalTextInputFormatter()],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Requis';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Nombre invalide';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _debitController,
                            decoration: const InputDecoration(
                              labelText: 'Débit',
                              suffixText: 'm3/h',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [DecimalTextInputFormatter()],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Requis';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Nombre invalide';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _hmtController,
                      decoration: const InputDecoration(
                        labelText: 'HMT',
                        suffixText: 'mce',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [DecimalTextInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer une HMT';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Nombre invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // P1 Calculée et Estimée
                    const Text(
                      'Puissance P1',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // P1 Calculée (affichage seule)
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'P1 Calculée',
                        suffixText: 'kW',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      controller: TextEditingController(text: p1Calculee.toStringAsFixed(2)),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // P1 Estimée (modifiable)
                    TextFormField(
                      controller: _p1EstimeeController,
                      decoration: InputDecoration(
                        labelText: 'P1 Estimée',
                        suffixText: 'kW',
                        border: const OutlineInputBorder(),
                        helperText: utiliseP1Estimee 
                            ? 'Les calculs utiliseront cette valeur' 
                            : 'Laisser à 0 pour utiliser P1 Calculée',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [DecimalTextInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requis';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Nombre invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Énergie Spécifique (affichage seule)
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Énergie Spécifique (Es)',
                        suffixText: 'kW/m3/h',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      controller: TextEditingController(text: es.toStringAsFixed(4)),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    // Rendements
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rendementInitialPompeController,
                            decoration: const InputDecoration(
                              labelText: 'Rendement Pompe',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [DecimalTextInputFormatter()],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Requis';
                              }
                              final val = double.tryParse(value);
                              if (val == null || val <= 0 || val > 100) {
                                return 'Valeur entre 0 et 100';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _rendementInitialMoteurController,
                            decoration: const InputDecoration(
                              labelText: 'Rendement Moteur',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [DecimalTextInputFormatter()],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Requis';
                              }
                              final val = double.tryParse(value);
                              if (val == null || val <= 0 || val > 100) {
                                return 'Valeur entre 0 et 100';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Autres informations
                    const Text(
                      'Autres Informations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _anneeInstallationController,
                            decoration: const InputDecoration(
                              labelText: 'Année Installation',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Requis';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Année invalide';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _heuresFonctionnementController,
                            decoration: const InputDecoration(
                              labelText: 'Heures Fonctionnement',
                              suffixText: 'h/an',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Requis';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Nombre invalide';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _coutInvestissementController,
                      decoration: const InputDecoration(
                        labelText: 'Coût d\'investissement',
                        prefixIcon: Icon(Icons.monetization_on),
                        suffixText: '€',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [DecimalTextInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un coût';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Nombre invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text(_isNew ? 'Créer' : 'Mettre à jour'),
                      onPressed: _isLoading ? null : _savePompe,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showDeleteConfirmation() {
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
              _deletePompe();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _marqueController.dispose();
    _modeleController.dispose();
    _puissanceNominaleController.dispose();
    _debitController.dispose();
    _hmtController.dispose();
    _rendementInitialPompeController.dispose();
    _rendementInitialMoteurController.dispose();
    _anneeInstallationController.dispose();
    _heuresFonctionnementController.dispose();
    _coutInvestissementController.dispose();
    _p1EstimeeController.dispose();
    super.dispose();
  }
}
