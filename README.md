# discord_feedback

[![Pub Version](https://img.shields.io/pub/v/discord_feedback.svg)](https://pub.dev/packages/discord_feedback)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A drop-in Flutter widget to display, react, and reply to feedback messages from a Discord channel — powered by the Discord Bot API with **real-time WebSocket** support.

<p align="center">
  <img src="https://raw.githubusercontent.com/tuananhbui89/discord_feedback/main/screenshots/feedback_list.png" width="280" alt="Feedback List" />
  <img src="https://raw.githubusercontent.com/tuananhbui89/discord_feedback/main/screenshots/reaction_overlay.png" width="280" alt="Reaction Overlay" />
  <img src="https://raw.githubusercontent.com/tuananhbui89/discord_feedback/main/screenshots/message_detail.png" width="280" alt="Message Detail" />
</p>

## Features

- **View messages** from any Discord channel in a modern, professional UI
- **React to messages** with emoji (long-press for quick reactions, Facebook-style)
- **Reply to messages** directly from the app
- **Send images & files** as attachments (camera + gallery picker)
- **Real-time updates** via Discord Gateway WebSocket — new messages, reactions, edits, deletes
- **Live indicator** shows connection status (green dot = connected)
- **Pull-to-refresh** and infinite scroll pagination
- **Auto-categorize** feedback as Bug / Feature / Improve
- **Fully customizable** accent color, title, emoji set, and more

## Demo

<!-- Replace with your actual demo GIF/video after recording -->
<p align="center">
  <img src="https://raw.githubusercontent.com/tuananhbui89/discord_feedback/main/screenshots/demo.gif" width="300" alt="Demo" />
</p>

## Getting Started

### 1. Create a Discord Bot

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** → name it → **Create**
3. Go to **Bot** tab → **Reset Token** → copy the token
4. Enable under **Privileged Gateway Intents**:
   - ✅ Message Content Intent
5. Go to **OAuth2 → URL Generator**, select `bot` scope with permissions:
   - Read Messages / View Channels
   - Send Messages
   - Add Reactions
   - Attach Files
   - Read Message History
6. Use the generated URL to invite the bot to your server

### 2. Get Channel ID

1. In Discord: **User Settings → Advanced → Enable Developer Mode**
2. Right-click the channel → **Copy Channel ID**

### 3. Install

```yaml
dependencies:
  discord_feedback: ^1.0.0
```

### 4. Use

```dart
import 'package:discord_feedback/discord_feedback.dart';

DiscordFeedbackView(
  botToken: 'YOUR_BOT_TOKEN',
  channelId: 'YOUR_CHANNEL_ID',
  enableRealtime: true, // real-time via WebSocket
)
```

## Full Example

```dart
import 'package:flutter/material.dart';
import 'package:discord_feedback/discord_feedback.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DiscordFeedbackView(
        botToken: 'YOUR_BOT_TOKEN',
        channelId: 'YOUR_CHANNEL_ID',
        title: 'User Feedback',
        accentColor: Color(0xFF5865F2),
        quickEmojis: ['👍', '👎', '❤️', '🔥', '👀', '✅'],
        enableImagePicker: true,
        enableRealtime: true,
      ),
    );
  }
}
```

## Customization

| Parameter           | Type           | Default                                | Description                          |
| ------------------- | -------------- | -------------------------------------- | ------------------------------------ |
| `botToken`          | `String`       | **required**                           | Discord bot token                    |
| `channelId`         | `String`       | **required**                           | Discord channel ID                   |
| `title`             | `String`       | `'Feedback'`                           | App bar title                        |
| `accentColor`       | `Color`        | `Color(0xFF5865F2)` (Discord Blurple)  | Primary accent color                 |
| `quickEmojis`       | `List<String>` | `['👍','👎','❤️','🔥','👀','✅']`      | Emojis in quick-react bar            |
| `enableImagePicker` | `bool`         | `true`                                 | Show attach image button             |
| `enableRealtime`    | `bool`         | `false`                                | Enable WebSocket real-time updates   |

## Real-time Events

When `enableRealtime: true`, the package connects to Discord Gateway WebSocket and handles:

| Event                    | Behavior                                    |
| ------------------------ | ------------------------------------------- |
| `MESSAGE_CREATE`         | New message appears at top instantly         |
| `MESSAGE_UPDATE`         | Edited message updates in-place              |
| `MESSAGE_DELETE`         | Deleted message disappears immediately       |
| `MESSAGE_REACTION_ADD`   | Reaction count updates in real-time          |
| `MESSAGE_REACTION_REMOVE`| Reaction count decreases in real-time        |

Auto-reconnect with exponential backoff if connection drops.

## Advanced Usage

Use `DiscordService` and `DiscordGateway` directly for custom integrations:

```dart
import 'package:discord_feedback/discord_feedback.dart';

// HTTP API
final service = DiscordService(botToken: 'TOKEN');
final messages = await service.getMessages(channelId: 'CH_ID');
await service.sendMessage(channelId: 'CH_ID', content: 'Hello!');
await service.addReaction(channelId: 'CH_ID', messageId: 'MSG_ID', emoji: '👍');

// WebSocket Gateway
final gateway = DiscordGateway(botToken: 'TOKEN', channelId: 'CH_ID');
await gateway.connect();
gateway.onMessageCreate.listen((msg) => print(msg.content));
gateway.onReactionAdd.listen((event) => print(event.emoji.name));
```

## Models

| Model               | Helpers                                  |
| -------------------- | ---------------------------------------- |
| `DiscordMessage`     | `copyWith()`, `hasImages`, `hasReactions` |
| `DiscordUser`        | `displayName`, `avatarUrl`               |
| `DiscordAttachment`  | `isImage`, `formattedSize`               |
| `DiscordEmbed`       | Embedded content (links, rich previews)  |
| `DiscordReaction`    | Reaction with count and `me` flag        |
| `DiscordEmoji`       | Unicode or custom emoji data             |

## Security Note

**Never hardcode your bot token in source code.** Use environment variables, a secrets manager, or a backend proxy in production.

## Author

**Tuan Anh Bui**

- GitHub: [@tuananhbui89](https://github.com/tuananhbui89)

## License

MIT License — see [LICENSE](LICENSE) for details.
