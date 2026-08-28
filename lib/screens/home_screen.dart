import 'package:flutter/material.dart';
import 'projet/projet_list_screen.dart';
import 'debug/debug_database_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WU ECT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Debug BDD',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DebugDatabaseScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bienvenue dans WU ECT',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Application de comparatifs énergétiques entre systèmes de pompage',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            Text(
              'Version: 0.0.002',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProjetListScreen(),
            ),
          );
        },
        tooltip: 'Gérer les projets',
        child: const Icon(Icons.folder_open),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'WU ECT',
      applicationVersion: '0.0.002',
      applicationIcon: const Icon(Icons.energy_savings_leaf, size: 64),
      children: [
        const Text(
          'Application de comparatifs énergétiques entre systèmes de pompage.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Développé avec Flutter et SQLite.',
        ),
      ],
    );
  }
}
