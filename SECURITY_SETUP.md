# Security Setup Instructions

## ⚠️ IMPORTANT: API Key Security

Your Google API key was previously exposed in the public repository. Follow these steps to secure your application:

### 1. Revoke the Compromised API Key

**IMMEDIATE ACTION REQUIRED:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Find the API key: `AIzaSyDk8dqtce8u62J7rtz5Tt2C1mkeHkJZzCE`
3. **DELETE** this key immediately
4. Create a new API key with proper restrictions

### 2. Create a New Restricted API Key

1. Go to [Google Cloud Console > APIs & Services > Credentials](https://console.cloud.google.com/apis/credentials)
2. Click "Create Credentials" > "API Key"
3. **Configure the new key with these restrictions:**
   - **Application restrictions**: Android apps
   - **Package name**: `com.example.my_selamat_app`
   - **SHA-1 certificate fingerprint**: Get this from your keystore
   - **API restrictions**: Select only the APIs you need (Maps SDK for Android, Geocoding API, etc.)

### 3. Update Local Configuration

1. **Replace the API key in `android/local.properties`:**
   ```properties
   GOOGLE_MAPS_API_KEY=YOUR_NEW_SECURE_API_KEY_HERE
   ```

2. **Replace the API key in `lib/config.dart`:**
   ```dart
   static const String googleApiKey = "YOUR_NEW_SECURE_API_KEY_HERE";
   ```

### 4. Verify Security

- ✅ `config.dart` is in `.gitignore`
- ✅ `android/local.properties` is in `.gitignore`
- ✅ `android/app/google-services.json` is in `.gitignore`
- ✅ No hardcoded API keys in source code
- ✅ Old compromised key is revoked

### 5. Build and Test

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### 6. Security Best Practices

1. **Never commit API keys** to version control
2. **Use environment variables** or local configuration files
3. **Restrict API keys** to specific apps and APIs
4. **Monitor API usage** in Google Cloud Console
5. **Rotate keys regularly** (every 6-12 months)
6. **Use different keys** for development and production

### 7. Emergency Response

If you suspect your API key is being misused:
1. **Immediately revoke** the compromised key
2. **Check API usage** in Google Cloud Console
3. **Monitor billing** for unexpected charges
4. **Create a new restricted key** following the steps above

## Files Modified for Security

- `android/app/src/main/AndroidManifest.xml` - Removed hardcoded API key
- `android/app/build.gradle.kts` - Added secure API key handling
- `android/local.properties` - Added API key configuration
- `lib/config.dart` - Created secure configuration file
- `.gitignore` - Enhanced to exclude sensitive files

## Next Steps

1. ✅ Revoke old API key
2. ✅ Create new restricted API key  
3. ✅ Update local configuration files
4. ✅ Test the application
5. ✅ Monitor API usage

