# Secure Configuration Setup Guide

## 🔒 Security Setup Required

To use this project securely, you need to set up your own configuration files with real credentials.

## Step 1: Create Firebase Service Account JSON

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Select your project**: `ferrous-osprey-472705-r2`
3. **Go to Project Settings** → **Service Accounts** tab
4. **Click "Generate new private key"**
5. **Download the JSON file**
6. **Rename and place it**:
   ```
   assets/config/ferrous-osprey-472705-r2-bbf8352be95d.json
   ```

## Step 2: Create AWS Backend Configuration

1. **Copy the template**:
   ```bash
   cp lib/services/backend_config.dart.example lib/services/backend_config.dart
   ```

2. **Update with your AWS credentials**:
   - Replace `YOUR_AWS_ACCESS_KEY_ID` with your actual AWS access key
   - Replace `YOUR_AWS_SECRET_ACCESS_KEY` with your actual AWS secret key
   - Replace `YOUR_ACCOUNT_ID` with your AWS account ID
   - Update the SNS Platform Application ARN

## Step 3: Verify Security

### ✅ **Files that are gitignored (secure):**
- `assets/config/*.json` - Firebase service account files
- `lib/services/backend_config.dart` - AWS credentials
- `*.env` files - Environment variables

### ✅ **Files that are tracked (safe):**
- `lib/services/backend_config.dart.example` - Template file
- `assets/config/firebase-service-account.json.template` - Template file
- `android/app/google-services.json` - Client-side config (safe)

## Step 4: Test Your Setup

1. **Run the app**:
   ```bash
   flutter run
   ```

2. **Check console logs** for:
   ```
   ✅ Firebase service account config loaded from JSON file
   ✅ Firebase configuration is valid
   ```

3. **Use the diagnostic tool**:
   - Navigate to "Notifications" tab
   - Tap "🔍 Run Full Diagnostics"
   - Verify all tests pass

## Security Checklist

- [ ] Firebase service account JSON file created and placed in `assets/config/`
- [ ] AWS backend configuration file created from template
- [ ] Real credentials replaced (no placeholder values)
- [ ] Sensitive files are not committed to git
- [ ] App runs and diagnostics pass
- [ ] FCM token is generated successfully

## Troubleshooting

### "File not found" errors:
- Check if the JSON file exists in `assets/config/`
- Verify the filename matches exactly
- Run `flutter clean && flutter pub get`

### "Configuration invalid" errors:
- Check if placeholder values are replaced with real credentials
- Verify AWS credentials have proper SNS permissions
- Ensure Firebase project ID matches

### Git tracking issues:
- Check `.gitignore` includes sensitive files
- Run `git status` to verify files are untracked
- Never commit `backend_config.dart` or JSON files in `assets/config/`

## Production Security

For production deployment:

1. **Use environment variables** instead of hardcoded credentials
2. **Implement a backend service** to handle Firebase operations
3. **Rotate credentials regularly**
4. **Monitor for credential leaks**
5. **Use AWS IAM roles** instead of access keys when possible

## Files Overview

### 🔒 **Sensitive (gitignored):**
- `assets/config/ferrous-osprey-472705-r2-bbf8352be95d.json`
- `lib/services/backend_config.dart`

### 📄 **Templates (tracked):**
- `lib/services/backend_config.dart.example`
- `assets/config/firebase-service-account.json.template`

### ✅ **Safe (tracked):**
- `android/app/google-services.json`
- `pubspec.yaml`
- All source code files
