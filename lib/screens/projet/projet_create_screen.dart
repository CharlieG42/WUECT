import 'package:flutter/material.dart';
import '../../models/projet.dart';
import '../../models/contact.dart';
import '../../services/database_service.dart';
import '../../utils/decimal_input_formatter.dart';
import '../../utils/error_handler.dart';
import '../contact/contact_form_screen.dart';

class ProjetCreateScreen extends StatefulWidget {
  const ProjetCreateScreen({super.key});

  @override
  State<ProjetCreateScreen> createState() => _ProjetCreateScreenState();
}

class _ProjetCreateScreenState extends State<ProjetCreateScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final _formKey = GlobalKey<FormState>();
  
  List<Contact> _contacts = [];
  int? _selectedContactId;
  
  final TextEditingController _nomSiteController = TextEditingController();
  final TextEditingController _coutEnergieController = TextEditingController();
  final TextEditingController _pourcentageAugmentationEnergieController = TextEditingController();
  final TextEditingController _percentagePerteRendementController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await _db.getAllContacts();
      setState(() {
        _contacts = contacts;
        if (_contacts.isNotEmpty) {
          // Conserver la sélection actuelle si le contact existe toujours
          if (_selectedContactId == null || 
              !_contacts.any((c) => c.id == _selectedContactId)) {
            // Si aucun contact sélectionné ou si le contact n'existe plus,
            // sélectionner le premier contact
            _selectedContactId = _contacts.first.id;
          }
          // Sinon, conserver le contact sélectionné
        } else {
          _selectedContactId = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Erreur de chargement des contacts: $e', error: true);
      }
    }
  }

  Future<void> _saveProjet() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedContactId == null) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Veuillez sélectionner un contact', error: true);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cout = double.tryParse(_coutEnergieController.text.replaceAll(',', '.'));
      final aug = double.tryParse(_pourcentageAugmentationEnergieController.text.replaceAll(',', '.'));
      final perte = double.tryParse(_percentagePerteRendementController.text.replaceAll(',', '.'));

      if (cout == null || aug == null || perte == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ErrorHandler.showSnackBar(context, 'Veuillez vérifier les valeurs numériques', error: true);
        }
        return;
      }

      final projet = Projet(
        nomSite: _nomSiteController.text,
        contactId: _selectedContactId!,
        coutEnergie: cout,
        pourcentageAugmentationEnergie: aug,
        percentagePerteRendement: perte,
      );

      await _db.insertProjet(projet);

      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Projet créé avec succès');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Erreur de sauvegarde: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un Projet'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nomSiteController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du Site / Projet',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nom de site';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Sélection du contact
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Contact',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      child: _contacts.isEmpty
                          ? ListTile(
                              title: const Text('Aucun contact disponible'),
                              subtitle: const Text('Appuyez pour en créer un'),
                              onTap: () => _navigateToContactForm(),
                            )
                          : () {
                              // Vérifier que la valeur sélectionnée existe toujours dans la liste
                              final effectiveSelectedId = _selectedContactId != null && 
                                  _contacts.any((c) => c.id == _selectedContactId)
                                  ? _selectedContactId
                                  : _contacts.first.id;
                              
                              return DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: effectiveSelectedId,
                                  isExpanded: true,
                                  items: _contacts.map((contact) {
                                    return DropdownMenuItem<int>(
                                      value: contact.id,
                                      child: Text('${contact.client} - ${contact.nom}'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedContactId = value);
                                  },
                                ),
                              );
                            }(),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un contact'),
                      onPressed: _navigateToContactForm,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _coutEnergieController,
                      decoration: const InputDecoration(
                        labelText: 'Coût de l\'énergie (€/kWh)',
                        prefixIcon: Icon(Icons.electrical_services),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [DecimalTextInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un coût';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _pourcentageAugmentationEnergieController,
                      decoration: const InputDecoration(
                        labelText: 'Augmentation énergie par an (%)',
                        prefixIcon: Icon(Icons.trending_up),
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [DecimalTextInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un pourcentage';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _percentagePerteRendementController,
                      decoration: const InputDecoration(
                        labelText: 'Perte de rendement par an (µCoef %)',
                        prefixIcon: Icon(Icons.analytics),
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [DecimalTextInputFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un pourcentage';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Sauvegarder'),
                      onPressed: _isLoading ? null : _saveProjet,
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

  Future<void> _navigateToContactForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactFormScreen(),
      ),
    );
    
    if (result == true && mounted) {
      await _loadContacts();
    }
  }

  @override
  void dispose() {
    _nomSiteController.dispose();
    _coutEnergieController.dispose();
    _pourcentageAugmentationEnergieController.dispose();
    _percentagePerteRendementController.dispose();
    super.dispose();
  }
}
