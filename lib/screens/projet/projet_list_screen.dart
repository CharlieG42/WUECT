import 'package:flutter/material.dart';
import '../../models/projet.dart';
import '../../models/contact.dart';
import '../../services/database_service.dart';
import '../../utils/error_handler.dart';
import 'projet_create_screen.dart';
import 'projet_detail_screen.dart';

class ProjetListScreen extends StatefulWidget {
  const ProjetListScreen({super.key});

  @override
  State<ProjetListScreen> createState() => _ProjetListScreenState();
}

class _ProjetListScreenState extends State<ProjetListScreen> {
  final DatabaseService _db = DatabaseService.instance;
  List<Projet> _projets = [];
  List<Contact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final projets = await _db.getAllProjets();
      final contacts = await _db.getAllContacts();
      setState(() {
        _projets = projets;
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Erreur de chargement: $e', error: true);
      }
    }
  }

  Future<void> _deleteProjet(int projetId) async {
    try {
      await _db.deleteProjetAndRelatedData(projetId);
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Projet supprimé avec succès');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Erreur de suppression: $e', error: true);
      }
    }
  }

  Contact? _getContactById(int contactId) {
    try {
      return _contacts.firstWhere((c) => c.id == contactId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Projets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projets.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun projet trouvé. Appuyez sur + pour en créer un.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _projets.length,
                  itemBuilder: (context, index) {
                    final projet = _projets[index];
                    final contact = _getContactById(projet.contactId);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        title: Text(projet.nomSite),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (contact != null) ...[
                              Text('Client: ${contact.client}'),
                              Text('Contact: ${contact.nom}'),
                            ],
                            Text('Coût énergie: ${projet.coutEnergie} €/kWh'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProjetDetailScreen(projetId: projet.id!),
                                ),
                              ).then((_) => {if (mounted) _loadData()}),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirmation(projet.id!),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProjetDetailScreen(projetId: projet.id!),
                          ),
                        ).then((_) => {if (mounted) _loadData()}),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProjetCreateScreen(),
          ),
        ).then((_) => {if (mounted) _loadData()}),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmation(int projetId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le projet'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce projet ? Toutes les données associées (systèmes, pompes) seront également supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProjet(projetId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
