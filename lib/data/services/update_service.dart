import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/app_strings.dart';
import 'notification_service.dart';

class UpdateService {
  static const String _repoOwner = "yassinehachali";
  static const String _repoName = "expense-tracker-flutter";
  
  // Checks if a new version is available
  Future<Map<String, dynamic>?> checkForUpdate() async {
    if (kIsWeb) return null; // Web updates automatically
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      final url = Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String tagName = data['tag_name'] ?? "";
        
        // Remove 'v' and build numbers for comparison
        final cleanTag = tagName.replaceAll('v', '').split('+')[0];
        final cleanCurrent = currentVersion.split('+')[0];
        
        if (_isNewer(cleanTag, cleanCurrent)) {
          final List assets = data['assets'];
          final apkAsset = assets.firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
            orElse: () => null,
          );
          
          if (apkAsset != null) {
            return {
              'updateAvailable': true,
              'version': tagName,
              'localVersion': currentVersion,
              'url': apkAsset['browser_download_url'],
              'changelog': data['body'] ?? 'No changelog available.',
            };
          }
        } else {
           // Debug: Return versions even if not newer
           return {
             'updateAvailable': false,
             'version': tagName,
             'localVersion': currentVersion,
             'remoteDebug': cleanTag,
             'localDebug': cleanCurrent,
           };
        }
      } else {
        // Handle API errors (like 404 for private repos)
        return {
          'error': 'GitHub API returned ${response.statusCode}. (Is the repo Private?)'
        };
      }
    } catch (e) {
      print("Error checking for updates: $e");
      return {'error': e.toString()};
    }
    return null;
  }

  bool _isNewer(String remote, String current) {
    List<int> r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    for (int i = 0; i < 3; i++) {
        int rPart = i < r.length ? r[i] : 0;
        int cPart = i < c.length ? c[i] : 0;
        if (rPart > cPart) return true;
        if (rPart < cPart) return false;
    }
    return false;
  }

  // Downloads the APK and returns the file path
  Future<String?> downloadUpdate(String url, Function(double progress) onProgress) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = "${dir.path}/update.apk";
      
      await Dio().download(
        url, 
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
             onProgress(received / total);
          }
        }
      );
      return filePath;
    } catch (e) {
      print("Download error: $e");
      return null;
    }
  }

  // Triggers the installation
  Future<String?> installUpdate(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      return result.message; // Return the error message
    }
    return null; // Success
  }

  // --- Background Helper ---
  
  static Future<void> checkAndNotify({bool manualCheck = false, BuildContext? context}) async {
    print("Background Update Check Started (Manual: $manualCheck)");
    try {
      // Ensure initialized in background isolate
      await NotificationService().init(null);

      final service = UpdateService();
      final result = await service.checkForUpdate();
      
      if (result != null && result['updateAvailable'] == true) {
        final version = result['version'];
        final changelog = result['changelog']; // Can be long, maybe truncate
        
        if (manualCheck && context != null) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.updateTitle}v$version")));
        }

        await NotificationService().showUpdateNotification(
          version,
          AppStrings.updateBody
        );
      } else if (manualCheck && context != null) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.upToDate)));
      }
    } catch (e) {
      print("Update check failed: $e");
      if (manualCheck && context != null) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.checkFailed}: $e")));
      }
    }
  }
}

