# Bulkr

**Nutrition tracking with a social side, built for people who are trying to gain weight.**

Most calorie apps are made for cutting. Bulkr is made for bulking: it sets a calorie
surplus and macro targets from your body and goals, makes logging meals quick, and keeps
you consistent through friends, groups, and challenges.

## ✨ Features

**Tracking**
- Personalised plan from your biometrics, activity level, and target pace
- Meal logging with food search, calories, and macros
- Separate targets for training and rest days

**Community**
- Social feed with posts, comments, and saved posts
- Friends, groups, and direct messages
- Challenges with live leaderboards
- Push notifications, plus server-side image moderation to keep the feed clean

**Product**
- Email, password, and Google sign-in
- Premium subscription with free trial (App Store & Google Play), purchases verified server-side
- Ads with consent handling for free users
- Full English and Arabic support

## 🛠️ Tech stack

| Layer | Tools |
|---|---|
| App | Flutter, Dart, Bloc/Cubit, GoRouter |
| Backend | Supabase: Postgres, Auth, Storage, Edge Functions (Deno/TypeScript) |
| Services | Firebase Cloud Messaging, AdMob, in-app purchases, AWS Rekognition |
| Delivery | Codemagic CI, Shorebird |

## 🚀 Running it locally

```bash
flutter pub get
flutter run
```

The app connects to its Supabase project by default. Database setup and Edge Functions live in [`supabase/`](supabase/), and release notes in [`docs/`](docs/).

## 👤 Author

**Ali Mahmoud** · [GitHub](https://github.com/asweddrtt) · [LinkedIn](https://www.linkedin.com/in/ali-mahmoud-26b89b22b/)

Built with help from Claude Code for refactoring and polish.
