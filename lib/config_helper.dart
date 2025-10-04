import 'config.dart';

/// Helper class for configuration management
class ConfigHelper {
  /// Check if the app is in demo mode
  static bool get isDemoMode => Config.useDemoMode;
  
  /// Check if AWS configuration is valid
  static bool get isAwsConfigValid => Config.isLexConfigValid;
  
  /// Check if Amplify configuration is valid
  static bool get isAmplifyConfigValid => Config.isAmplifyConfigValid;
  
  /// Get configuration status for debugging
  static Map<String, dynamic> getConfigStatus() {
    return {
      'demoMode': Config.useDemoMode,
      'useAmplify': Config.useAmplify,
      'awsAccessKeySet': Config.awsAccessKey.isNotEmpty && Config.awsAccessKey != 'YOUR_AWS_ACCESS_KEY_HERE',
      'awsSecretKeySet': Config.awsSecretKey.isNotEmpty && Config.awsSecretKey != 'YOUR_AWS_SECRET_KEY_HERE',
      'botName': Config.lexBotName,
      'botAlias': Config.lexBotAlias,
      'region': Config.awsRegion,
      'googleApiKeySet': Config.googleApiKey.isNotEmpty && Config.googleApiKey != 'YOUR_GOOGLE_API_KEY_HERE',
      'isConfigValid': Config.isLexConfigValid,
      'isAmplifyConfigValid': Config.isAmplifyConfigValid,
      'cognitoUserPoolId': Config.cognitoUserPoolId,
      'cognitoAppClientId': Config.cognitoAppClientId,
      'cognitoIdentityPoolId': Config.cognitoIdentityPoolId,
    };
  }
  
  /// Get setup instructions based on current configuration
  static List<String> getSetupInstructions() {
    final status = getConfigStatus();
    final instructions = <String>[];
    
    if (status['useAmplify']) {
      if (!status['isAmplifyConfigValid']) {
        instructions.add('Configure AWS Amplify: Run "amplify init" and "amplify add auth"');
        instructions.add('Update amplifyconfiguration.dart with your Amplify configuration');
      }
    } else {
      if (!status['awsAccessKeySet']) {
        instructions.add('Set AWS Access Key in config.dart');
      }
      
      if (!status['awsSecretKeySet']) {
        instructions.add('Set AWS Secret Key in config.dart');
      }
    }
    
    if (!status['googleApiKeySet']) {
      instructions.add('Set Google Maps API Key in config.dart');
    }
    
    if (status['demoMode']) {
      instructions.add('Demo mode is enabled. Set useDemoMode = false to use real AWS Lex');
    }
    
    if (instructions.isEmpty) {
      instructions.add('Configuration looks good!');
    }
    
    return instructions;
  }
  
  /// Print configuration status to console
  static void printConfigStatus() {
    print('=== Configuration Status ===');
    final status = getConfigStatus();
    status.forEach((key, value) {
      print('$key: $value');
    });
    
    print('\n=== Setup Instructions ===');
    final instructions = getSetupInstructions();
    for (int i = 0; i < instructions.length; i++) {
      print('${i + 1}. ${instructions[i]}');
    }
    print('===========================');
  }
}

