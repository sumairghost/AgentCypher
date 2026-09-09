import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:url_launcher/url_launcher.dart';

class AppLauncherService {
  List<AppInfo>? _cachedApps;

  /// Get all installed apps (cached), including system apps!
  Future<List<AppInfo>> getInstalledApps() async {
    _cachedApps ??= await InstalledApps.getInstalledApps(false, false);
    return _cachedApps!;
  }

  /// Clear app cache
  void clearCache() {
    _cachedApps = null;
  }

  /// Find apps matching a query
  Future<List<AppInfo>> searchApps(String query) async {
    final apps = await getInstalledApps();
    final lowerQuery = query.toLowerCase();
    return apps.where((app) {
      return app.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Open an app by name (fuzzy match)
  Future<String> openApp(String appName) async {
    final matches = await searchApps(appName);

    if (matches.isEmpty) {
      return 'Could not find app "$appName". It may not be installed.';
    }

    // Prefer an exact (case-insensitive) name match...
    AppInfo? target;
    for (final app in matches) {
      if (app.name.toLowerCase() == appName.toLowerCase()) {
        target = app;
        break;
      }
    }

    // ...otherwise require the query to be unambiguous before guessing.
    if (target == null && matches.length > 1) {
      final names = matches
          .take(3)
          .map((app) => '"${app.name}"')
          .join(', ');
      return 'Multiple apps match "$appName": $names. '
          'Specify which one to open.';
    }
    target ??= matches.first;

    try {
      final launched = await InstalledApps.startApp(target.packageName);
      if (launched == true) {
        return 'Opened ${target.name}';
      }
      // Android refused or the plugin could not confirm the launch — never
      // claim success without evidence.
      return 'Could not launch ${target.name} '
          '(package ${target.packageName}). Android refused the launch '
          'request or returned no confirmation.';
    } catch (e) {
      return 'Error opening ${target.name}: $e';
    }
  }

  /// Open an app by exact package name
  Future<String> openPackage(String packageName) async {
    try {
      final launched = await InstalledApps.startApp(packageName);
      if (launched == true) {
        return 'Launched $packageName';
      }
      return 'Could not launch $packageName. The package may not be '
          'installed, or Android refused the launch request.';
    } catch (e) {
      return 'Error launching $packageName: $e';
    }
  }

  /// Open a URL
  Future<String> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return 'Opened $url';
      }
      return 'Cannot open $url';
    } catch (e) {
      return 'Error opening URL: $e';
    }
  }
}
