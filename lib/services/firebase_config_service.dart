import 'dart:convert';
import 'package:flutter/services.dart';

/// Service to load Firebase configuration from JSON file
class FirebaseConfigService {
  static Map<String, dynamic>? _config;
  
  /// Load Firebase service account configuration from assets
  static Future<Map<String, dynamic>> loadConfig() async {
    if (_config != null) return _config!;
    
    try {
      // Load JSON file from assets
      final String jsonString = await rootBundle.loadString('assets/config/ferrous-osprey-472705-r2-bbf8352be95d.json');
      
      // Parse JSON
      _config = json.decode(jsonString) as Map<String, dynamic>;
      
      print('✅ Firebase service account config loaded from JSON file');
      print('📋 Project ID: ${_config!['project_id']}');
      print('📧 Client Email: ${_config!['client_email']}');
      
      return _config!;
    } catch (e) {
      print('❌ Failed to load Firebase config from JSON file: $e');
      throw Exception('Failed to load Firebase configuration: $e');
    }
  }
  
  /// Get specific config value
  static Future<String?> getConfigValue(String key) async {
    final config = await loadConfig();
    return config[key]?.toString();
  }
  
  /// Get project ID
  static Future<String?> getProjectId() async {
    return await getConfigValue('project_id');
  }
  
  /// Get client email
  static Future<String?> getClientEmail() async {
    return await getConfigValue('client_email');
  }
  
  /// Get private key
  static Future<String?> getPrivateKey() async {
    return await getConfigValue('private_key');
  }
  
  /// Check if config is properly loaded
  static Future<bool> isConfigValid() async {
    try {
      final config = await loadConfig();
      return config['project_id'] != null && 
             config['client_email'] != null && 
             config['private_key'] != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Get full config as JSON string (for AWS SNS usage)
  static Future<String> getConfigAsJsonString() async {
    final config = await loadConfig();
    return json.encode(config);
  }
}
