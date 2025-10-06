# SelamatBot Chatbot Demo Guide

## Overview
This is a comprehensive demonstration of the SelamatBot emergency assistance chatbot integrated with AWS Amplify and Amazon Lex. The demo showcases the chatbot's capabilities in emergency response, flood monitoring, and weather forecasting.

## Demo Features

### 🎯 Demo Mode Indicators
- **Demo Badge**: Orange "DEMO" badge in the app bar
- **Demo Banner**: Prominent orange banner with quick instructions
- **Enhanced Welcome Message**: Clear demo instructions on startup

### 🚨 Emergency Assistance Demo
**Try these commands:**
- `emergency` - General emergency assistance
- `help` - Emergency help options
- `medical emergency` - Medical emergency response
- `fire emergency` - Fire emergency response
- `police emergency` - Police emergency response

**Demo Features:**
- Emergency service connection simulation
- Location sharing demonstration
- Emergency contact notification
- Step-by-step emergency guidance
- Quick action buttons for immediate responses

### 🌊 Flood Information Demo
**Try these commands:**
- `flood` - Current flood status and alerts
- `flooding` - Flood monitoring information
- `flood alerts` - Flood alert system
- `safety tips` - Flood safety recommendations
- `evacuation routes` - Safe evacuation planning

**Demo Features:**
- Real-time flood risk assessment (ORANGE level)
- Location-based flood monitoring (Mukim Badang, Kota Bharu)
- Water level tracking (2.5m above normal)
- Evacuation status updates
- Safety recommendations and emergency kit guidance

### 🌤️ Weather Forecast Demo
**Try these commands:**
- `weather` - Current weather conditions
- `forecast` - Weather forecast information
- `temperature` - Temperature and climate data
- `hourly forecast` - Detailed hourly predictions
- `weather alerts` - Weather warning system

**Demo Features:**
- Real-time weather monitoring (28°C, 85% humidity)
- Severe weather alerts (heavy rainfall expected)
- Detailed meteorological data
- UV index and visibility tracking
- 7-day forecast capabilities

## Demo Scenarios

### Scenario 1: Emergency Response
1. Open the chatbot
2. Type "emergency" or tap "Emergency Help" quick action
3. Explore different emergency types using quick actions
4. See how the system would connect to emergency services
5. Test location sharing and contact notification features

### Scenario 2: Flood Monitoring
1. Type "flood" or tap "Flood Info" quick action
2. Review current flood status and risk levels
3. Explore safety tips and evacuation routes
4. Check emergency kit recommendations
5. View evacuation center information

### Scenario 3: Weather Awareness
1. Type "weather" or tap "Weather Info" quick action
2. Review current weather conditions
3. Check hourly and 7-day forecasts
4. Explore weather alerts and warnings
5. Access storm tracking information

### Scenario 4: Interactive Navigation
1. Use the "Demo Guide" quick action for instructions
2. Navigate through different demo scenarios
3. Test quick action buttons for instant responses
4. Experience the conversational flow
5. Try natural language queries

## Technical Features Demonstrated

### AWS Integration
- **Amazon Lex**: Natural language processing and intent recognition
- **AWS Amplify**: Backend services and authentication
- **Session Management**: Persistent conversation context
- **Error Handling**: Graceful fallback to demo mode

### User Experience
- **Quick Actions**: One-tap access to common functions
- **Typing Indicators**: Real-time response simulation
- **Message Timestamps**: Conversation history tracking
- **Responsive Design**: Mobile-optimized interface
- **Accessibility**: Clear visual indicators and instructions

### Demo Mode Configuration
```dart
// Configuration in lib/config.dart
static const bool useDemoMode = true;
static const bool enableDemoInstructions = true;
static const bool showDemoModeIndicator = true;
```

## Quick Start Guide

1. **Launch the App**: Open MySelamat app
2. **Navigate to Chat**: Tap the "Chat" tab in bottom navigation
3. **See Demo Mode**: Notice the orange "DEMO" badge and banner
4. **Try Commands**: Type any of the demo commands listed above
5. **Use Quick Actions**: Tap the colored buttons for instant responses
6. **Explore Features**: Navigate through different demo scenarios

## Demo Commands Reference

| Command | Description | Example Response |
|---------|-------------|------------------|
| `emergency` | Emergency assistance demo | Emergency response options |
| `flood` | Flood information demo | Flood status and alerts |
| `weather` | Weather forecast demo | Current conditions and forecast |
| `demo guide` | Demo instructions | Complete demo guide |
| `help` | General help | Available demo features |

## Troubleshooting

### Demo Mode Not Active
- Check `Config.useDemoMode = true` in `lib/config.dart`
- Restart the app to refresh configuration
- Clear chat history using the refresh button

### Commands Not Working
- Try typing commands in lowercase
- Use exact command phrases listed above
- Check the debug info using the info button in the app bar

### Quick Actions Not Appearing
- Ensure you've received a bot response first
- Quick actions appear after bot messages
- Try clearing chat and starting fresh

## Production Setup

To move from demo mode to production:

1. **Configure AWS Credentials**: Update `lib/config.dart` with real AWS credentials
2. **Set up Amazon Lex Bot**: Create and configure your Lex bot
3. **Configure Amplify**: Set up AWS Amplify backend
4. **Disable Demo Mode**: Set `Config.useDemoMode = false`
5. **Test Integration**: Verify real AWS service connectivity

## Support

For technical support or questions about the demo:
- Check the debug information in the chatbot (info button)
- Review the configuration status
- Consult the setup instructions in the debug panel

---

**Note**: This is a demonstration system. In a real emergency, always contact emergency services directly (999 in Malaysia) and follow official safety protocols.

