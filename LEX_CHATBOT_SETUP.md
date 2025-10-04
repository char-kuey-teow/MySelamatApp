# Amazon Lex Chatbot Setup Guide

This guide will help you set up and configure the Amazon Lex chatbot integration in your SelamatApp Flutter application.

## Overview

The SelamatApp includes a sophisticated chatbot powered by Amazon Lex that provides:
- Emergency assistance and SOS functionality
- Flood information and alerts
- Evacuation routes and shelter information
- Weather updates and safety tips
- Multi-turn conversation support
- Quick action buttons for common tasks

## Prerequisites

1. **AWS Account**: You need an active AWS account with appropriate permissions
2. **Amazon Lex Bot**: A configured Lex bot in the AWS Console
3. **AWS Credentials**: Access key and secret key with Lex permissions
4. **Flutter Environment**: Flutter SDK installed and configured

## Step 1: Create Amazon Lex Bot

### 1.1 Access AWS Lex Console
1. Log in to your AWS Console
2. Navigate to Amazon Lex service
3. Choose your preferred region (e.g., us-east-1)

### 1.2 Create a New Bot
1. Click "Create Bot"
2. Choose "Create a blank bot"
3. Configure the bot:
   - **Bot name**: `botSelamat` (or your preferred name)
   - **IAM role**: Create new role or use existing
   - **COPPA compliance**: Select as appropriate

### 1.3 Create Intents
Create the following intents for emergency assistance:

#### EmergencyIntent
- **Intent name**: `EmergencyIntent`
- **Sample utterances**:
  - "I need emergency help"
  - "Help me"
  - "Emergency"
  - "SOS"
  - "I'm in danger"

#### FloodInfoIntent
- **Intent name**: `FloodInfoIntent`
- **Sample utterances**:
  - "What is the flood status?"
  - "Is there flooding?"
  - "Flood information"
  - "Water levels"
  - "Rain forecast"

#### ShelterInfoIntent
- **Intent name**: `ShelterInfoIntent`
- **Sample utterances**:
  - "Where are evacuation centers?"
  - "Show me shelters"
  - "Evacuation centers"
  - "Safe places"

#### RouteInfoIntent
- **Intent name**: `RouteInfoIntent`
- **Sample utterances**:
  - "Safe routes"
  - "Evacuation routes"
  - "How to get to safety"
  - "Directions to shelter"

#### WeatherInfoIntent
- **Intent name**: `WeatherInfoIntent`
- **Sample utterances**:
  - "Weather forecast"
  - "Rain update"
  - "Weather conditions"
  - "Storm information"

### 1.4 Configure Bot Alias
1. Go to "Aliases" in your bot
2. Create a new alias:
   - **Alias name**: `TSTALIASID` (for testing) or `LIVE` (for production)
   - **Bot version**: Latest version

## Step 2: Configure AWS Credentials

### 2.1 Create IAM User
1. Go to IAM Console
2. Create a new user with programmatic access
3. Attach the following policies:
   - `AmazonLexRuntimeFullAccess`
   - `AmazonLexFullAccess` (if you need to modify the bot)

### 2.2 Update Configuration
Edit `lib/config.dart`:

```dart
class Config {
  // AWS Configuration
  static const String awsAccessKey = "YOUR_ACCESS_KEY_HERE";
  static const String awsSecretKey = "YOUR_SECRET_KEY_HERE";
  static const String awsRegion = "us-east-1"; // Your bot's region
  
  // Amazon Lex Bot Configuration
  static const String lexBotName = "botSelamat";
  static const String lexBotAlias = "TSTALIASID"; // or "LIVE"
  
  // Enable real Lex integration
  static const bool useDemoMode = false;
}
```

## Step 3: Test the Integration

### 3.1 Run the Test App
```bash
cd lib
dart lex_test_main.dart
```

### 3.2 Test Different Scenarios
1. **Emergency messages**: "I need help", "Emergency", "SOS"
2. **Flood information**: "What's the flood status?", "Is it flooding?"
3. **Shelter info**: "Where are the evacuation centers?"
4. **Route info**: "Show me safe routes"
5. **Weather info**: "What's the weather like?"

### 3.3 Run Unit Tests
```bash
flutter test test/lex_service_test.dart
```

## Step 4: Integration with Main App

### 4.1 Initialize the Service
In your main app, initialize the chatbot service:

```dart
import 'package:my_selamat_app/chatbot.dart';

// Initialize the chatbot
ChatbotService.initialize(userId: 'unique_user_id');
```

### 4.2 Use the Chatbot UI
```dart
import 'package:my_selamat_app/text_chatbot.dart';

// Navigate to chatbot screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const TextChatbotScreen(),
  ),
);
```

## Step 5: Customization

### 5.1 Modify Mock Responses
Edit the `_getMockResponse` method in `lib/lex_service.dart` to customize responses for your region and emergency services.

### 5.2 Add New Intents
1. Create new intents in your Lex bot
2. Add corresponding handling in the mock response method
3. Update the quick actions and UI accordingly

### 5.3 Styling and UI
Modify `lib/text_chatbot.dart` to customize:
- Colors and theme
- Message bubble styling
- Quick action buttons
- Typing indicators

## Troubleshooting

### Common Issues

#### 1. Authentication Errors (401/403)
- Verify your AWS credentials are correct
- Check IAM permissions for Lex access
- Ensure the region matches your bot's region

#### 2. Bot Not Found (404)
- Verify bot name and alias in config
- Check that the bot is published and has an alias
- Ensure you're using the correct region

#### 3. Network/Timeout Errors
- Check internet connection
- Verify AWS service availability
- Consider increasing timeout values

#### 4. Demo Mode Issues
- Set `useDemoMode = true` for testing without AWS
- Verify mock responses are working correctly

### Debug Information

Enable debug logging by checking the console output for:
- Session IDs and user IDs
- Request/response details
- Error messages and stack traces

## Security Considerations

1. **Never commit AWS credentials** to version control
2. **Use environment variables** for production
3. **Implement proper IAM policies** with minimal required permissions
4. **Consider using AWS Cognito** for user authentication
5. **Enable CloudTrail** for audit logging

## Production Deployment

### 1. Environment Configuration
- Use separate AWS accounts for development and production
- Configure different bot aliases for each environment
- Implement proper secrets management

### 2. Monitoring
- Set up CloudWatch alarms for Lex API errors
- Monitor conversation logs and user interactions
- Track response times and success rates

### 3. Scaling
- Consider using Lex's built-in scaling capabilities
- Implement caching for frequently requested information
- Monitor AWS service limits and quotas

## API Reference

### LexService Methods

#### `initialize({String? userId})`
Initialize the Lex service with an optional user ID.

#### `sendMessage(String message)`
Send a message to the Lex bot and return a response.

#### `resetSession()`
Reset the current session and start a new conversation.

#### `testConnection()`
Test the connection to the Lex API.

### LexResponse Properties

- `message`: The bot's response text
- `intentName`: The detected intent name
- `slots`: Extracted slot values from the message
- `sessionId`: Current session identifier
- `isComplete`: Whether the conversation is complete
- `quickActions`: Available quick action buttons

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review AWS Lex documentation
3. Check Flutter and Dart documentation for HTTP and async handling
4. Consider AWS support for Lex-specific issues

## License

This implementation is part of the SelamatApp project. Please refer to the main project license for usage terms.

