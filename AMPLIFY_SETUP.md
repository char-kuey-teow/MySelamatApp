# AWS Amplify + Amazon Lex Integration Setup

This guide will help you set up AWS Amplify with Amazon Lex for your SelamatBot chatbot.

## Prerequisites

1. AWS Account with appropriate permissions
2. Node.js and npm installed
3. AWS CLI configured
4. Flutter development environment

## Step 1: Install AWS Amplify CLI

```bash
npm install -g @aws-amplify/cli
```

## Step 2: Configure AWS Amplify CLI

```bash
amplify configure
```

Follow the prompts to:
- Select your AWS region
- Create a new IAM user or use existing one
- Configure the user with appropriate permissions

## Step 3: Initialize Amplify in Your Project

```bash
cd your-flutter-project
amplify init
```

Follow the prompts:
- Project name: `my-selamat-app`
- Environment: `dev`
- Default editor: Your preferred editor
- App type: `flutter`
- Source directory: `lib`
- Distribution directory: `build/web`
- Build command: `flutter build web`
- Start command: `flutter run -d web-server --web-port 3000`

## Step 4: Add Authentication

```bash
amplify add auth
```

Select:
- Default configuration: `Default configuration with Social Provider (Federation)`
- How do you want users to sign in: `Username`
- Do you want to configure advanced settings: `No, I am done.`

## Step 5: Add Analytics (Optional)

```bash
amplify add analytics
```

Select:
- Analytics provider: `Amazon Pinpoint`
- App name: `MySelamatApp`
- Environment: `dev`

## Step 6: Deploy the Backend

```bash
amplify push
```

This will create the necessary AWS resources and update your `amplifyconfiguration.dart` file.

## Step 7: Configure Amazon Lex Bot

1. Go to the Amazon Lex console
2. Create a new bot or use existing `botSelamat`
3. Configure intents for:
   - Emergency assistance
   - Flood information
   - Shelter information
   - Route information
   - Weather information

## Step 8: Update Configuration Files

### Update `lib/config.dart`:

```dart
// AWS Amplify Configuration
static const String amplifyRegion = "us-east-1";
static const String cognitoUserPoolId = "us-east-1_YOUR_ACTUAL_POOL_ID";
static const String cognitoAppClientId = "YOUR_ACTUAL_APP_CLIENT_ID";
static const String cognitoIdentityPoolId = "us-east-1:YOUR_ACTUAL_POOL_ID";
static const String pinpointAppId = "YOUR_ACTUAL_PINPOINT_APP_ID";

// Use AWS Amplify for authentication and services
static const bool useAmplify = true;
```

### Update `amplifyconfiguration.dart`:

Replace the placeholder values with the actual values from your Amplify deployment.

## Step 9: Test the Integration

1. Run your Flutter app
2. Navigate to the chatbot screen
3. Test various intents to ensure Lex is working correctly
4. Check the debug info to verify configuration

## Step 10: Production Deployment

For production:

1. Create a production environment:
```bash
amplify env add prod
```

2. Deploy to production:
```bash
amplify push --env prod
```

3. Update your Lex bot alias to `LIVE` in production

## Troubleshooting

### Common Issues:

1. **Authentication Errors**: Ensure your Cognito configuration is correct
2. **Lex Bot Not Found**: Verify bot name and alias in config
3. **Network Errors**: Check internet connection and AWS region settings
4. **Permission Errors**: Ensure IAM user has necessary permissions

### Debug Information:

Use the debug info button in the chatbot to check:
- Session information
- Configuration status
- Setup instructions

### Fallback to Demo Mode:

If Amplify setup fails, the app will automatically fall back to demo mode with mock responses.

## Security Considerations

1. Never commit AWS credentials to version control
2. Use environment variables for sensitive configuration
3. Implement proper IAM roles and policies
4. Enable MFA for AWS accounts
5. Regularly rotate access keys

## Cost Optimization

1. Use appropriate Lex bot aliases (TSTALIASID for testing, LIVE for production)
2. Monitor AWS usage and set up billing alerts
3. Consider using Lex pricing tiers based on your usage

## Support

For issues with:
- AWS Amplify: Check [Amplify Documentation](https://docs.amplify.aws/)
- Amazon Lex: Check [Lex Documentation](https://docs.aws.amazon.com/lex/)
- Flutter: Check [Flutter Documentation](https://flutter.dev/docs)

## Next Steps

After successful setup:
1. Customize your Lex bot with domain-specific intents
2. Add more sophisticated conversation flows
3. Implement user authentication and personalization
4. Add analytics and monitoring
5. Scale your deployment for production use
