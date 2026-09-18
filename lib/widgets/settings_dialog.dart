import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Widget utility for showing the application settings dialog
/// This centralizes the settings UI to avoid code duplication
class SettingsDialog {
  /// Shows the settings dialog for application parameters
  /// 
  /// [context] - The build context for showing the dialog
  /// [title] - The title of the dialog (defaults to 'Paramètres de l\'application')
  /// [onSaved] - Optional callback called after settings are saved
  static void show(
    BuildContext context, {
    String title = 'Paramètres de l\'application',
    Function? onSaved,
  }) {
    final settings = SettingsService.instance;
    
    final maxAnneesController = TextEditingController(text: settings.maxAnneesPerteRendement.toString());
    final coutEnergieController = TextEditingController(text: settings.coutEnergieDefault.toString());
    final perteRendementController = TextEditingController(text: settings.perteRendementDefault.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle for using default parameters
                Row(
                  children: [
                    const Text('Utiliser les paramètres par défaut:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Switch(
                      value: settings.useDefaultParams,
                      onChanged: (value) {
                        setDialogState(() => settings.useDefaultParams = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Si activé, les paramètres ci-dessous seront utilisés au lieu de ceux du projet.', 
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 16),
                
                // Max years for efficiency loss
                TextFormField(
                  controller: maxAnneesController,
                  decoration: const InputDecoration(
                    labelText: 'Limite années perte de rendement',
                    suffixText: 'ans',
                    border: OutlineInputBorder(),
                    hintText: 'Nombre max d\'années pour la dégradation du rendement',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requis';
                    final val = int.tryParse(value);
                    if (val == null || val < 0) return 'Nombre valide requis';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Default energy cost
                TextFormField(
                  controller: coutEnergieController,
                  decoration: const InputDecoration(
                    labelText: 'Coût de l\'énergie par défaut',
                    suffixText: 'EUR/kWh',
                    border: OutlineInputBorder(),
                    hintText: 'Coût utilisé si "Utiliser les paramètres par défaut" est activé',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requis';
                    final val = double.tryParse(value.replaceAll(',', '.'));
                    if (val == null || val < 0) return 'Nombre valide requis';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Default efficiency loss
                TextFormField(
                  controller: perteRendementController,
                  decoration: const InputDecoration(
                    labelText: 'Perte de rendement annuelle par défaut',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    hintText: 'Pourcentage de perte de rendement par an',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requis';
                    final val = double.tryParse(value.replaceAll(',', '.'));
                    if (val == null || val < 0) return 'Nombre valide requis';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text('⚠️ Ces paramètres affectent les calculs de projection sur 10 ans.', 
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                // Save settings using SettingsService
                settings.maxAnneesPerteRendement = int.tryParse(maxAnneesController.text) ?? settings.maxAnneesPerteRendement;
                settings.coutEnergieDefault = double.tryParse(coutEnergieController.text.replaceAll(',', '.')) ?? settings.coutEnergieDefault;
                settings.perteRendementDefault = double.tryParse(perteRendementController.text.replaceAll(',', '.')) ?? settings.perteRendementDefault;
                
                Navigator.pop(context);
                // Call the callback if provided
                if (onSaved != null) {
                  onSaved();
                }
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }
}
