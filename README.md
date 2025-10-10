# MySelamat App

A Flutter emergency response application with flood risk mapping and SOS functionality.

## Features

- **Flood Risk Map**: Interactive map showing flood risk levels with Google Maps integration
- **SOS Emergency**: 3-second hold mechanism with category selection and AWS integration
- **Location Tracking**: Real-time location updates during emergencies
- **Safe Zone Routing**: Calculate safe routes to evacuation centers

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code
- Google Maps API key

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd my_selamat_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API Keys**
   
   The app requires a Google Maps API key for map functionality. To set this up:
   
   a. Copy the example config file:
   ```bash
   cp lib/config.example.dart lib/config.dart
   ```
   
   b. Get your Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   
   c. Edit `lib/config.dart` and replace `YOUR_GOOGLE_API_KEY_HERE` with your actual API key:
   ```dart
   static const String googleApiKey = "your_actual_api_key_here";
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

- `lib/main.dart` - Main app entry point with navigation
- `lib/sos-button.dart` - SOS emergency functionality
- `lib/flood-map.dart` - Flood risk mapping with Google Maps
- `lib/config.dart` - API keys and configuration (gitignored)
- `lib/config.example.dart` - Example configuration template

