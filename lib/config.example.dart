// Example configuration file
// Copy this file to config.dart and replace the placeholder values with your actual API keys

class Config {
  // Google Maps API Key
  // Get your API key from: https://console.cloud.google.com/apis/credentials
  static const String googleApiKey = "YOUR_GOOGLE_API_KEY_HERE";

  // Other API keys can be added here
  // static const String awsApiKey = "YOUR_AWS_API_KEY_HERE";
  // static const String firebaseApiKey = "YOUR_FIREBASE_API_KEY_HERE";

  // Emergency Services API Configuration
  // Replace with your actual emergency services API endpoint
  static const String emergencyApiUrl =
      "https://your-emergency-services-api.com";

  // For demo purposes, we'll simulate the API calls
  static const bool useDemoMode = true;
}
