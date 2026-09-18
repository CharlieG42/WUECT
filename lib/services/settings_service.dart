import 'package:hive/hive.dart';

/// Service de gestion des paramètres globaux de l'application
/// Utilise Hive pour la persistance des paramètres
class SettingsService {
  static final SettingsService instance = SettingsService._init();
  
  // Nom de la box Hive pour les paramètres
  static const String _settingsBoxName = 'app_settings';
  
  // Clés des paramètres
  static const String _keyMaxAnneesPerteRendement = 'max_annees_perte_rendement';
  static const String _keyCoutEnergieDefault = 'cout_energie_default';
  static const String _keyPerteRendementDefault = 'perte_rendement_default';
  static const String _keyUseDefaultParams = 'use_default_params';
  
  // Box Hive
  late final Box _settingsBox;
  
  // Valeurs actuelles (chargées depuis Hive)
  int _maxAnneesPerteRendement = 15;
  double _coutEnergieDefault = 0.15;
  double _perteRendementDefault = 1.0;
  bool _useDefaultParams = false;
  
  SettingsService._init();
  
  /// Initialisation de la box Hive
  static Future<void> init() async {
    instance._settingsBox = await Hive.openBox(_settingsBoxName);
    await instance._loadSettings();
  }
  
  /// Chargement des paramètres depuis Hive
  Future<void> _loadSettings() async {
    _maxAnneesPerteRendement = _settingsBox.get(_keyMaxAnneesPerteRendement, defaultValue: 15);
    _coutEnergieDefault = _settingsBox.get(_keyCoutEnergieDefault, defaultValue: 0.15);
    _perteRendementDefault = _settingsBox.get(_keyPerteRendementDefault, defaultValue: 1.0);
    _useDefaultParams = _settingsBox.get(_keyUseDefaultParams, defaultValue: false);
  }
  
  /// Sauvegarde des paramètres dans Hive
  Future<void> _saveSettings() async {
    await _settingsBox.put(_keyMaxAnneesPerteRendement, _maxAnneesPerteRendement);
    await _settingsBox.put(_keyCoutEnergieDefault, _coutEnergieDefault);
    await _settingsBox.put(_keyPerteRendementDefault, _perteRendementDefault);
    await _settingsBox.put(_keyUseDefaultParams, _useDefaultParams);
  }
  
  // Getters
  int get maxAnneesPerteRendement => _maxAnneesPerteRendement;
  double get coutEnergieDefault => _coutEnergieDefault;
  double get perteRendementDefault => _perteRendementDefault;
  bool get useDefaultParams => _useDefaultParams;
  
  // Setters (avec sauvegarde automatique)
  set maxAnneesPerteRendement(int value) {
    _maxAnneesPerteRendement = value;
    _settingsBox.put(_keyMaxAnneesPerteRendement, value);
  }
  
  set coutEnergieDefault(double value) {
    _coutEnergieDefault = value;
    _settingsBox.put(_keyCoutEnergieDefault, value);
  }
  
  set perteRendementDefault(double value) {
    _perteRendementDefault = value;
    _settingsBox.put(_keyPerteRendementDefault, value);
  }
  
  set useDefaultParams(bool value) {
    _useDefaultParams = value;
    _settingsBox.put(_keyUseDefaultParams, value);
  }
  
  /// Sauvegarde toutes les paramètres
  Future<void> saveAllSettings({
    int? maxAnneesPerteRendement,
    double? coutEnergieDefault,
    double? perteRendementDefault,
    bool? useDefaultParams,
  }) async {
    if (maxAnneesPerteRendement != null) {
      _maxAnneesPerteRendement = maxAnneesPerteRendement;
    }
    if (coutEnergieDefault != null) {
      _coutEnergieDefault = coutEnergieDefault;
    }
    if (perteRendementDefault != null) {
      _perteRendementDefault = perteRendementDefault;
    }
    if (useDefaultParams != null) {
      _useDefaultParams = useDefaultParams;
    }
    await _saveSettings();
  }
  
  /// Réinitialise les paramètres aux valeurs par défaut
  Future<void> resetToDefaults() async {
    _maxAnneesPerteRendement = 15;
    _coutEnergieDefault = 0.15;
    _perteRendementDefault = 1.0;
    _useDefaultParams = false;
    await _saveSettings();
  }
  
  /// Fermeture de la box
  Future<void> close() async {
    await _settingsBox.close();
  }
}
