import 'dart:io';
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wu_ect/utils/app_config.dart';

Future<void> initHive() async {
  // Try to load hive path from config or environment
  final configuredPath = await loadHivePathFromConfig();

    // Fallback default path — build dynamically using OneDriveCommercial env when available
    final oneDriveBase = Platform.environment['OneDriveCommercial'] ?? Platform.environment['OneDrive'];
    final computedDefaultWindowsPath = (oneDriveBase != null && oneDriveBase.isNotEmpty)
      ? '$oneDriveBase${Platform.pathSeparator}1 - Service${Platform.pathSeparator}2 - OPTIMISATIONS${Platform.pathSeparator}_Template & Tools${Platform.pathSeparator}WUECT${Platform.pathSeparator}assets'
      : r'C:\Users\72904\OneDrive - Grundfos\1 - Service\2 - OPTIMISATIONS\_Template & Tools\WUECT\assets';

  String hivePath;

  if (Platform.isWindows) {
    hivePath = configuredPath ?? computedDefaultWindowsPath;
  } else {
    // For non-windows IO platforms (Android/iOS/macOS), use app documents dir
    final appDocDir = await getApplicationDocumentsDirectory();
    hivePath = configuredPath ?? '${appDocDir.path}${Platform.pathSeparator}wu_ect_hive';
  }

  final dir = Directory(hivePath);
  try {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    Hive.init(hivePath);
  } catch (e, st) {
    // Rethrow after printing to help debugging during development
    // In production you may want to handle this more gracefully.
    // ignore: avoid_print
    print('Failed to initialize Hive at path: $hivePath\n$e\n$st');
    rethrow;
  }
}

/// Retourne le chemin effectif utilisé par Hive sur cette plateforme.
Future<String> getEffectiveHivePath() async {
  final configuredPath = await loadHivePathFromConfig();
  final oneDriveBase = Platform.environment['OneDriveCommercial'] ?? Platform.environment['OneDrive'];
    final computedDefaultWindowsPath = (oneDriveBase != null && oneDriveBase.isNotEmpty)
      ? '$oneDriveBase${Platform.pathSeparator}1 - Service${Platform.pathSeparator}2 - OPTIMISATIONS${Platform.pathSeparator}_Template & Tools${Platform.pathSeparator}WUECT${Platform.pathSeparator}assets'
      : r'C:\Users\72904\OneDrive - Grundfos\1 - Service\2 - OPTIMISATIONS\_Template & Tools\WUECT\assets';

  if (Platform.isWindows) {
    return configuredPath ?? computedDefaultWindowsPath;
  }

  final appDocDir = await getApplicationDocumentsDirectory();
  return configuredPath ?? '${appDocDir.path}${Platform.pathSeparator}wu_ect_hive';
}
