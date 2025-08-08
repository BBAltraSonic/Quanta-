# Quanta Setup Guide

This guide will help you set up the Quanta AI Avatar Platform for development.

## Prerequisites

- Flutter SDK (3.8.1 or later)
- Dart SDK
- A Supabase account
- An OpenRouter account (for AI chat features)
- Git

## 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd flutter_social_ui
flutter pub get
```

## 2. Set Up Supabase Backend

### Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Sign up or log in
3. Click "New Project"
4. Choose your organization and create the project
5. Wait for the project to be ready

### Configure Database

1. In your Supabase dashboard, go to the **SQL Editor**
2. Copy the contents of `supabase_schema.sql` from the project root
3. Paste it into the SQL Editor and run it
4. This will create all necessary tables, policies, and storage buckets

### Get API Keys

1. Go to **Project Settings** > **API**
2. Copy your **Project URL**
3. Copy your **anon/public key**

## 3. Configure Environment

### Option A: Using Environment Variables (Recommended)

Set the following environment variables in your development environment:

```bash
export SUPABASE_URL="https://your-project-id.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key-here"
export OPENROUTER_API_KEY="your-openrouter-key-here"  # Optional for now
export HUGGINGFACE_API_KEY="your-huggingface-key-here"  # Optional for now
```

### Option B: Modify Environment Class (Not Recommended for Production)

Edit `lib/utils/environment.dart` and replace the default values:

```dart
static const String supabaseUrl = 'https://your-project-id.supabase.co';
static const String supabaseAnonKey = 'your-actual-anon-key';
```

**⚠️ Warning: Never commit real API keys to version control!**

## 4. Set Up AI Services (Optional)

### OpenRouter (for AI chat)

1. Sign up at [https://openrouter.ai](https://openrouter.ai)
2. Get your API key from the dashboard
3. Add it to your environment variables

### Hugging Face (alternative AI service)

1. Sign up at [https://huggingface.co](https://huggingface.co)
2. Go to Settings > Access Tokens
3. Create a new token
4. Add it to your environment variables

## 5. Test the Setup

### Run the App

```bash
flutter run
```

### Expected Behavior

1. App should start with the Quanta loading screen
2. If properly configured, you'll see the login screen
3. If not configured, you'll see a helpful error screen with setup instructions

### Test Authentication

1. Try creating a new account using the signup flow
2. Verify that you can log in with your credentials
3. Check your Supabase dashboard to see if the user was created

## 6. Troubleshooting

### Common Issues

#### "Environment not configured properly" Error

- Double-check your Supabase URL and anon key
- Make sure environment variables are set correctly
- Verify the Supabase project is active and accessible

#### Database Connection Errors

- Ensure you've run the `supabase_schema.sql` script
- Check that Row Level Security (RLS) is properly configured
- Verify your anon key has the correct permissions

#### Build Errors

- Run `flutter clean && flutter pub get`
- Check that all dependencies are compatible
- Ensure you're using Flutter 3.8.1 or later

#### Authentication Errors

- Verify email confirmation is disabled in Supabase Auth settings (for development)
- Check Supabase Auth logs for detailed error messages
- Ensure your database tables match the schema exactly

### Debugging Tips

1. **Enable debug mode**: Set `debug: true` in the Supabase initialize call
2. **Check logs**: Look at both Flutter console and Supabase logs
3. **Test database**: Use Supabase's table editor to verify data
4. **Verify environment**: Print environment values (but don't commit them!)

## 7. Development Workflow

### Project Structure

```
lib/
├── constants.dart              # App constants and themes
├── main.dart                   # App entry point
├── models/                     # Data models
│   ├── user_model.dart
│   └── avatar_model.dart
├── services/                   # Business logic and API calls
│   └── auth_service.dart
├── screens/                    # UI screens
│   ├── auth/                   # Authentication screens
│   ├── onboarding/            # User onboarding
│   └── app_shell.dart         # Main app container
├── widgets/                    # Reusable UI components
│   ├── custom_button.dart
│   └── custom_text_field.dart
└── utils/                      # Utility functions
    └── environment.dart
```

### Adding New Features

1. Create models in `/models`
2. Add services in `/services`
3. Build UI screens in `/screens`
4. Create reusable widgets in `/widgets`
5. Update database schema as needed
6. Test thoroughly before committing

## 8. Production Deployment

### Security Checklist

- [ ] Use proper environment variable management
- [ ] Enable Row Level Security on all tables
- [ ] Set up proper API rate limiting
- [ ] Configure CORS policies
- [ ] Enable email confirmation for production
- [ ] Set up proper logging and monitoring

### Database Migration

- Keep `supabase_schema.sql` updated
- Create migration scripts for schema changes
- Test migrations on staging environment first

## 9. Next Steps

Once you have the basic setup working:

1. **Phase 2**: Implement avatar creation wizard
2. **Phase 3**: Add AI chat functionality
3. **Phase 4**: Build content upload and management
4. **Phase 5**: Integrate social features

## Support

If you run into issues:

1. Check the troubleshooting section above
2. Review Supabase documentation
3. Check Flutter/Dart documentation
4. Look for similar issues in the project's issue tracker

---

## Quick Start Checklist

- [ ] Flutter SDK installed
- [ ] Supabase project created
- [ ] Database schema deployed
- [ ] Environment variables configured
- [ ] App runs without errors
- [ ] Can create and log in users
- [ ] Ready to start development!

Happy coding! 🚀
