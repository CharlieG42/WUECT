import 'package:hive_flutter/hive_flutter.dart';

Future<void> initHive() async {
  // Web or non-IO platforms: use hive_flutter default initialization
  await Hive.initFlutter();
}

/// Retourne le chemin effectif utilisé par Hive sur cette plateforme.
Future<String> getEffectiveHivePath() async {
  return 'Web: IndexedDB (visible via DevTools F12 → Application → IndexedDB)';
}
