# discord_feedback

[![Pub Version](https://img.shields.io/pub/v/discord_feedback.svg)](https://pub.dev/packages/discord_feedback)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A drop-in Flutter widget to collect and display user feedback via **Discord Forum Channels**. Creates structured forum posts with tags, device info, screenshots, and real-time updates — styled to match the Discord mobile app.

## Screenshots

| Forum Post List | Post Detail |
| :---: | :---: |
| ![Forum Post List](https://raw.githubusercontent.com/BuiTuanAnh2001/discord_feedback/master/screenshots/feedback_list.png) | ![Post Detail](https://raw.githubusercontent.com/BuiTuanAnh2001/discord_feedback/master/screenshots/reaction_overlay.png) |

### Demo

![Demo](https://raw.githubusercontent.com/BuiTuanAnh2001/discord_feedback/master/screenshots/demo.gif)

## Features

- **Forum Channel support** — creates structured posts (threads) with titles and tags
- **Dynamic tags** — fetched from your Discord forum channel, selectable when posting
- **Custom themes** — 3 built-in presets (Dark, Light, Midnight) + full color customizer with hex input
- **Theme persistence** — user theme choices auto-saved and restored via `shared_preferences`
- **Real-time updates** — via Discord Gateway WebSocket (new posts, messages, reactions)
- **Discord mobile UI** — header, Sort & View, Tags filter bar match the Discord app
- **Screenshots & attachments** — camera + gallery picker, uploaded to Discord
- **Device info** — auto-collects OS, app version, and timestamp

## Getting Started

### 1. Create a Discord Bot

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** → name it → **Create**
3. Go to **Bot** tab → **Reset Token** → copy the token
4. Enable **Privileged Gateway Intents**: ✅ Message Content Intent
5. Go to **OAuth2 → URL Generator**, select `bot` scope with permissions:
   - Read Messages / View Channels
   - Send Messages
   - Add Reactions
   - Attach Files
   - Read Message History
   - Create Public Threads
6. Invite the bot to your server using the generated URL

### 2. Create a Forum Channel

1. In your Discord server, create a **Forum Channel**
2. Add tags (e.g., `Suggestion`, `BUG`, `Feature`, `Submitted`)
3. Right-click the channel → **Copy Channel ID** (enable Developer Mode first)

### 3. Use

```dart
import 'package:discord_feedback/discord_feedback.dart';

DiscordFeedbackView(
  botToken: 'YOUR_BOT_TOKEN',
  channelId: 'YOUR_FORUM_CHANNEL_ID',
  enableRealtime: true,
  appName: 'My App',
  appVersion: '1.0.0',
)
```

## Customization

### Parameters

| Parameter        | Type                               | Default                      | Description                                    |
| ---------------- | ---------------------------------- | ---------------------------- | ---------------------------------------------- |
| `botToken`       | `String`                           | **required**                 | Discord bot token                              |
| `channelId`      | `String`                           | **required**                 | Discord Forum Channel ID                       |
| `title`          | `String`                           | `'bug-and-suggestions'`      | Channel name in header                         |
| `theme`          | `DiscordFeedbackTheme`             | `DiscordFeedbackTheme.dark`  | Visual theme (initial)                         |
| `enableRealtime` | `bool`                             | `false`                      | Enable WebSocket real-time updates             |
| `appName`        | `String?`                          | `null`                       | App name in feedback posts                     |
| `appVersion`     | `String?`                          | `null`                       | App version in feedback info                   |
| `deviceInfo`     | `String?`                          | auto-detected                | Device info string                             |
| `persistTheme`   | `bool`                             | `true`                       | Auto-save theme to local storage               |
| `onThemeChanged` | `ValueChanged<DiscordFeedbackTheme>?` | `null`                    | Callback when theme changes                    |
| `leading`        | `Widget?`                          | back arrow                   | Custom leading widget in header                |
| `channelIcon`    | `Widget?`                          | forum icon                   | Custom channel icon in header                  |
| `channelEmoji`   | `String?`                          | `null`                       | Emoji next to channel name                     |

### Themes

```dart
// Built-in presets
DiscordFeedbackView(theme: DiscordFeedbackTheme.dark)
DiscordFeedbackView(theme: DiscordFeedbackTheme.light)
DiscordFeedbackView(theme: DiscordFeedbackTheme.midnight)

// Custom theme
DiscordFeedbackView(
  theme: DiscordFeedbackTheme.dark.copyWith(
    accent: Colors.pink,
    successColor: Colors.teal,
  ),
)

// Users can also customize the theme at runtime via the built-in
// palette button in the header. Changes are auto-persisted.
```

### Theme Persistence

Theme is automatically saved to `shared_preferences` and restored on next launch. Disable with `persistTheme: false`.

```dart
// Manual save/load
await ThemeStorage.save(myTheme);
final saved = await ThemeStorage.load();
await ThemeStorage.clear();
```

## Real-time Events

When `enableRealtime: true`, the widget connects to Discord Gateway and handles:

| Event                     | Behavior                              |
| ------------------------- | ------------------------------------- |
| `THREAD_CREATE`           | New post appears instantly            |
| `THREAD_UPDATE`           | Post metadata updates in-place        |
| `THREAD_DELETE`           | Post disappears immediately           |
| `MESSAGE_CREATE`          | New message in thread detail view     |
| `MESSAGE_UPDATE`          | Edited message updates in-place       |
| `MESSAGE_DELETE`          | Deleted message disappears            |
| `MESSAGE_REACTION_ADD`    | Reaction count updates in real-time   |
| `MESSAGE_REACTION_REMOVE` | Reaction count decreases              |

Auto-reconnect with exponential backoff if connection drops.

## Advanced Usage

Use services directly for custom integrations:

```dart
import 'package:discord_feedback/discord_feedback.dart';

// HTTP API
final service = DiscordService(botToken: 'TOKEN');
final posts = await service.getForumPosts(channelId: 'CHANNEL_ID');
await service.createForumPost(
  channelId: 'CHANNEL_ID',
  title: '[BUG] App crashes on login',
  content: 'Steps to reproduce...',
  appliedTags: ['tag_id_1', 'tag_id_2'],
);

// WebSocket Gateway
final gateway = DiscordGateway(botToken: 'TOKEN', channelId: 'CHANNEL_ID');
await gateway.connect();
gateway.onThreadCreate.listen((thread) => print(thread.name));
gateway.onMessageCreate.listen((msg) => print(msg.content));
```

## Architecture

```
lib/
├── discord_feedback.dart          # Barrel file
└── src/
    ├── models/                    # Data models (Message, User, Thread, Tag, ...)
    ├── services/
    │   ├── discord_service.dart   # REST API client (Dio)
    │   ├── discord_gateway.dart   # WebSocket real-time events
    │   └── theme_storage.dart     # SharedPreferences persistence
    ├── theme/
    │   └── discord_feedback_theme.dart  # Theme data + presets
    └── widgets/
        ├── discord_feedback_view.dart   # Main entry widget
        ├── forum_post_list_screen.dart  # Post list (uses extracted widgets)
        ├── forum_post_card.dart         # Single post card
        ├── discord_header.dart          # Discord-style header bar
        ├── sort_tag_bar.dart            # Sort & View + Tags filter
        ├── forum_post_detail_screen.dart # Thread detail + messages
        ├── message_bubble.dart          # Single message bubble
        ├── create_feedback_sheet.dart   # New post bottom sheet
        └── theme_customizer_sheet.dart  # Theme picker bottom sheet
```

## Models

| Model                | Key Features                                  |
| -------------------- | --------------------------------------------- |
| `ForumThread`        | `copyWith()`, `appliedTags`, `starterMessage` |
| `ForumChannel`       | `availableTags`, `isForum`                    |
| `ForumTag`           | `emojiName`, `moderated`                      |
| `DiscordMessage`     | `copyWith()`, `hasImages`, `hasReactions`     |
| `DiscordUser`        | `displayName`, `avatarUrl`                    |
| `DiscordAttachment`  | `isImage`, `formattedSize`                    |

## Security Note

**Never hardcode your bot token in source code.** Use environment variables, a secrets manager, or a backend proxy in production.

## Author

**Tuan Anh Bui** — [@BuiTuanAnh2001](https://github.com/BuiTuanAnh2001)

## License

MIT License — see [LICENSE](LICENSE) for details.
