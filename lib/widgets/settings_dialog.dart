import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';

// Import des icônes Material (déjà inclus dans material.dart, mais vérification)

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
    final dureeEtudeController = TextEditingController(text: settings.dureeEtudeAnnee.toString());
    final pourcentageAugmentationEnergieController = TextEditingController(text: settings.pourcentageAugmentationEnergieDefault.toString());

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
                const SizedBox(height: 12),
                
                // Study duration
                TextFormField(
                  controller: dureeEtudeController,
                  decoration: const InputDecoration(
                    labelText: 'Durée de l\'étude',
                    suffixText: 'ans',
                    border: OutlineInputBorder(),
                    hintText: 'Nombre d\'années pour les graphiques, ROI et tableau récapitulatif',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requis';
                    final val = int.tryParse(value);
                    if (val == null || val < 1 || val > 30) return 'Nombre entre 1 et 30';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Energy cost annual increase
                TextFormField(
                  controller: pourcentageAugmentationEnergieController,
                  decoration: const InputDecoration(
                    labelText: 'Hausse annuelle du coût de l\'énergie',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    hintText: 'Pourcentage d\'augmentation annuelle du coût de l\'énergie',
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
                const Text('⚠️ Ces paramètres affectent les calculs de projection.', 
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
                const Divider(height: 16),
                
                // Sélecteur de dossier pour l'export PDF
                Row(
                  children: [
                    const Text('Dossier d\'export PDF:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.pdfExportDirectory ?? 'Dossier Documents par défaut',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_open, size: 20),
                      tooltip: 'Choisir le dossier',
                      onPressed: () async {
                        final result = await FilePicker.platform.getDirectoryPath();
                        if (result != null) {
                          setDialogState(() => settings.pdfExportDirectory = result);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Réinitialiser au dossier par défaut', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setDialogState(() => settings.pdfExportDirectory = null);
                  },
                ),
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
                settings.dureeEtudeAnnee = int.tryParse(dureeEtudeController.text) ?? settings.dureeEtudeAnnee;
                settings.pourcentageAugmentationEnergieDefault = double.tryParse(pourcentageAugmentationEnergieController.text.replaceAll(',', '.')) ?? settings.pourcentageAugmentationEnergieDefault;
                
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
