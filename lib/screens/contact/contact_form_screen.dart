import 'package:flutter/material.dart';
import '../../models/contact.dart';
import '../../services/database_service.dart';
import '../../utils/error_handler.dart';

class ContactFormScreen extends StatefulWidget {
  final int? contactId;

  const ContactFormScreen({super.key, this.contactId});

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  bool _isLoading = true;
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    setState(() => _isLoading = true);
    try {
      if (widget.contactId != null) {
        final contact = await _db.getContactById(widget.contactId!);
        if (contact != null) {
          _clientController.text = contact.client;
          _nomController.text = contact.nom;
          _emailController.text = contact.email;
          _mobileController.text = contact.mobile;
          _isNew = false;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Erreur de chargement: $e', error: true);
      }
    }
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final contact = Contact(
        id: widget.contactId,
        client: _clientController.text,
        nom: _nomController.text,
        email: _emailController.text,
        mobile: _mobileController.text,
      );

      if (_isNew) {
        await _db.insertContact(contact);
      } else {
        await _db.updateContact(contact);
      }

      if (mounted) {
        ErrorHandler.showSnackBar(context, _isNew ? 'Contact créé avec succès' : 'Contact mis à jour');
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Erreur de sauvegarde: $e', error: true);
      }
    }
  }

  Future<void> _deleteContact() async {
    if (widget.contactId == null) return;

    try {
      await _db.deleteContact(widget.contactId!);
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Contact supprimé avec succès');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Erreur de suppression: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Créer un Contact' : 'Modifier le Contact'),
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
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _clientController,
                      decoration: const InputDecoration(
                        labelText: 'Client',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nom de client';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du Contact',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nom de contact';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un email';
                        }
                        if (!value.contains('@')) {
                          return 'Veuillez entrer un email valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un numéro de mobile';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text(_isNew ? 'Créer' : 'Mettre à jour'),
                      onPressed: _isLoading ? null : _saveContact,
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
        title: const Text('Supprimer le Contact'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce contact ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteContact();
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
    _clientController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }
}
