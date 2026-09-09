import 'dart:io';
import 'dart:convert';

/// Try loading hivePath from environment or a local config file.
Future<String?> loadHivePathFromConfig() async {
  // 1) Env var override
  final env = Platform.environment['WUECT_HIVE_PATH'];
  if (env != null && env.isNotEmpty) return env;

  // 1.b) If there is a OneDriveCommercial env var, prefer it for expansion if config uses placeholder
  final oneDriveEnv = Platform.environment['OneDriveCommercial'] ?? Platform.environment['OneDrive'];

  // 2) Look for config file in common development locations
  final candidates = [
    File('config/app_config.json'),
    File('${Directory.current.path}${Platform.pathSeparator}config${Platform.pathSeparator}app_config.json'),
  ];

  for (final f in candidates) {
    if (await f.exists()) {
      try {
        final data = jsonDecode(await f.readAsString());
        if (data is Map && data['hivePath'] is String) {
          var path = data['hivePath'] as String;
          if (path.isNotEmpty) {
            // Support placeholder ${OneDriveCommercial}
            if ((path.contains(r'${OneDriveCommercial}') || path.contains(r"${OneDriveCommercial}")) && oneDriveEnv != null && oneDriveEnv.isNotEmpty) {
              path = path.replaceAll(r'${OneDriveCommercial}', oneDriveEnv);
              path = path.replaceAll(r"${OneDriveCommercial}", oneDriveEnv);
            }
            return path;
          }
        }
      } catch (_) {
        // ignore parse errors and try next candidate
      }
    }
  }

  return null;
}
