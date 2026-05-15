# Evexia Flutter App — with AI Recommendations

A health & wellness Flutter app with 4 screens and **Claude-powered personalized recommendations**.

## How AI Recommendations Work

After the user completes the Goals survey (activity level + weight goal + optional notes), the app:
1. Passes the answers to `AIService.getRecommendations()`
2. Calls the **Anthropic Claude API** (`claude-sonnet-4-20250514`) with a structured prompt
3. Claude returns a JSON array of 3 recommendations (nutrition, exercise, sleep) tailored to that user
4. The Dashboard shows animated skeleton cards while loading, then displays the AI-generated tips

## File Structure
```
lib/
├── main.dart
├── models/
│   └── user_profile.dart          # UserProfile + AIRecommendation data classes
├── services/
│   └── ai_service.dart            # Anthropic API call + JSON parsing
└── screens/
    ├── welcome_screen.dart
    ├── onboarding_screen.dart
    ├── goals_screen.dart          # Passes UserProfile → DashboardScreen
    └── dashboard_screen.dart      # Fetches & displays AI recommendations
```

## Setup

### 1. Add your API key
Open `lib/services/ai_service.dart` and replace:
```dart
static const String _apiKey = 'YOUR_ANTHROPIC_API_KEY';
```
with your real key from https://console.anthropic.com

### 2. Install dependencies & run
```bash
cd evexia_app
flutter pub get
flutter run
```

## Dependencies
- `flutter` SDK
- `http: ^1.2.0` — for Anthropic API calls
- `cupertino_icons: ^1.0.6`

## Security Note
For production, never hardcode API keys in client code.
Use a backend proxy or Flutter's `--dart-define` with a secrets manager instead.
