# Flutter Social UI

A Flutter-based social media UI showcase demonstrating common social app patterns: feed/post detail, comments, chat, notifications, search, profile, and a create-post flow. This project focuses on pixel-perfect UI/UX, smooth navigation, and reusable widgets. It is currently UI-first with in-memory demo data models and no backend integration.

## Contents

* [Features](#features)
* [Screens Overview](#screens-overview)
* [Architecture & Code Structure](#architecture--code-structure)
* [Widgets & Reusable Components](#widgets--reusable-components)
* [Data Models (Demo)](#data-models-demo)
* [Theming & Assets](#theming--assets)
* [Getting Started](#getting-started)
* [Running on Platforms](#running-on-platforms)
* [Project Status](#project-status)
* [Contributing](#contributing)
* [License](#license)

---

## Features

* Bottom navigation with custom painter styling
* App shell scaffolding with cross-screen navigation
* Post feed UI with post detail view
* Comments flow (full screen and modal)
* Create post screen (UI-only stub)
* Chat list and conversation screen with day separators and read-state icons
* Notifications and search screens (UI-first)
* Profile screen with header and actions
* Reusable stylized widgets and icon overlays
* SVG-based icon set and bundled images
* Cross-platform: Android, iOS, Web, Windows, macOS, Linux (standard Flutter targets)

---

## Screens Overview

* **App Shell**: `lib/screens/app_shell.dart`

  * Hosts the bottom navigation and routes to primary tabs (Home/Feed, Search, Create, Notifications, Profile).
  * Employs a custom bottom nav painter: `lib/widgets/bottom_nav_painter.dart`.

* **Post Detail**: `lib/screens/post_detail_screen.dart`

  * Detailed view for a single post.
  * Integrates comments access and post actions (like, bookmark, share UI).

* **Comments**:

  * Full Screen: `lib/screens/comments_screen.dart`
  * Bottom Sheet Modal: `lib/widgets/comments_modal.dart`
  * Comment tile UI: `lib/widgets/comment_tile.dart`
  * Backed by a demo Comment model: `lib/models/comment.dart`

* **Create Post**: `lib/screens/create_post_screen.dart`

  * UI for composing a post (text/media placeholders), currently no backend submission.

* **Chat**:

  * Chat Screen (conversation): `lib/screens/chat_screen.dart`
  * Chat bubble UI: `lib/widgets/chat_bubble.dart`
  * Day separators: `lib/widgets/day_separator.dart`
  * Demo ChatMessage model: `lib/models/chat_message.dart`

* **Notifications**: `lib/screens/notifications_screen.dart`

* **Search**: `lib/screens/search_screen.dart`

  * Search bar UI and placeholder result content.

* **Profile**: `lib/screens/profile_screen.dart`

  * Profile header, avatar, stats, and actions.

---

## Architecture & Code Structure

* **Entry Point**: `lib/main.dart` (MaterialApp setup, theme, initial route)
* **Design Tokens**: `lib/constants.dart` (spacing, colors, radii, text styles)
* **Screens**: `lib/screens/` (routeable screens and feature pages)
* **Widgets**: `lib/widgets/` (reusable UI components and custom painters)
* **Models**: `lib/models/` (simple demo data models)

*State is local to widgets with ephemeral controllers. No persistence or API layer.*

---

## Widgets & Reusable Components

* **BottomNavPainter** (`lib/widgets/bottom_nav_painter.dart`): Custom painter for stylized bottom navigation bar and notch.
* **OverlayIcon** (`lib/widgets/overlay_icon.dart`): Utility to overlay action/status icons.
* **PostItem** (`lib/widgets/post_item.dart`): Feed post UI component.
* **CommentTile** (`lib/widgets/comment_tile.dart`): Comment row layout.
* **CommentsModal** (`lib/widgets/comments_modal.dart`): Bottom sheet for comments.
* **ChatBubble** (`lib/widgets/chat_bubble.dart`): Inbound/outbound bubble layout.
* **DaySeparator** (`lib/widgets/day_separator.dart`): Date dividers in chat.

*Uses constants from `lib/constants.dart` for consistent styling.*

---

## Data Models (Demo)

* **Comment** (`lib/models/comment.dart`): Author, text, timestamp, like state.
* **ChatMessage** (`lib/models/chat_message.dart`): Sender, content, sent time, read/delivered state.

*Models are in-memory for UI previews.*

---

## Theming & Assets

* **Theming**: Centralized constants (`lib/constants.dart`). Material 3-friendly patterns in `main.dart`.
* **Assets**:

  * SVG icons: `assets/icons/`
  * Sample images: `assets/images/`
  * Declared in `pubspec.yaml`.

---

## Getting Started

**Prerequisites:**

* Flutter SDK (stable channel)
* Dart SDK (bundled)
* Platform toolchains (Android Studio, Xcode, VS Build Tools)

**Install Dependencies:**

```bash
cd flutter_social_ui
flutter pub get
```

**Run the App:**

```bash
flutter run
# Target device:
flutter run -d chrome
```

**Code Quality:**

```bash
dart format .
flutter analyze
flutter test
```

---

## Running on Platforms

* **Android**: Emulator or device via Android Studio/CLI
* **iOS**: Simulator or device on macOS
* **Web**: `flutter run -d chrome`
* **Desktop:**

  * Windows: `flutter config --enable-windows-desktop` then `flutter run -d windows`
  * macOS: `flutter config --enable-macos-desktop` then `flutter run -d macos`
  * Linux: `flutter config --enable-linux-desktop` then `flutter run -d linux`

---

## Project Status

**Current Focus:**

* UI/UX implementation and reusable components
* Navigation shell and tab flows
* Static demo screens for comments, chat, notifications, search, profile, create post

**Not Yet Included:**

* Backend integrations
* Auth and user sessions
* Media upload/storage
* Push notifications
* Accessibility & i18n beyond defaults

*Builds successfully on supported platforms from a clean clone.*

---

## Contributing

1. Fork and create a feature branch
2. Keep commits atomic with clear messages
3. Follow design constants and widget patterns
4. Add/update tests for core UI logic
5. Run formatters and analyzers before PR

```bash
# Commands
dart format .
flutter analyze
flutter test
```

---

## License

This project is provided for educational/demo purposes. Add an explicit LICENSE file before publishing or distributing.
