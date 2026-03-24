## 3.0.0

**Breaking**: Migrated to `flutter_discord_client` package. Requires Dart SDK `^3.10.0` / Flutter `>=3.38.0`.

### Changed
- `DiscordService` now uses `FlutterDiscordClient` (OpenAPI-generated Discord v10 client) internally
- Exposes `DiscordService.api` for advanced access to the full generated `DefaultApi`
- Exposes `DiscordService.dio` for raw HTTP access via the pre-configured Dio instance
- Re-exports `FlutterDiscordClient` and `DefaultApi` from barrel file
- Minimum SDK: Dart `^3.10.0`, Flutter `>=3.38.0`
- Removed deprecated `null-aware-elements` experiment flag

## 2.1.0

### Added
- `showCreateButton` parameter to show/hide the floating create feedback button

### Changed
- All UI strings changed from Vietnamese to English
- Separated `views/` (full-screen pages) from `widgets/` (reusable components)
- Removed `lib/main.dart` from package (was development-only)

## 2.0.2

- Fixed README images: use absolute GitHub raw URLs so screenshots display on pub.dev

## 2.0.1

- Updated README: removed redundant install section, added screenshots and demo gif

## 2.0.0

**Breaking**: Full rewrite from chat-style to Discord Forum Channel architecture.

### Added
- **Forum Channel support** — creates forum posts (threads) with titles, tags, and structured content
- **`DiscordFeedbackTheme`** — full custom theme system with 3 presets (Dark, Light, Midnight)
- **Theme customizer UI** — built-in palette button with preset selector, accent color picker, hex input, and advanced color overrides
- **Theme persistence** — auto-save/load via `shared_preferences` (`ThemeStorage`)
- **Dynamic tags** — tags fetched from Discord forum channel and selectable when creating posts
- **Sort & View** — sort posts by creation time or last message, newest/oldest first
- **Tag filter** — filter posts by tags with multi-select
- **Discord mobile UI** — header with channel name, dots, emoji, chevron matching Discord app

### Changed
- `DiscordFeedbackView` now targets forum channels instead of regular text channels
- `accentColor` parameter replaced by full `DiscordFeedbackTheme` object
- `title` default changed to `'bug-and-suggestions'`
- Removed `quickEmojis` and `enableImagePicker` parameters

### Refactored
- Extracted `ForumPostCard`, `DiscordHeader`, `SortTagBar`, `MessageBubble` into separate widget files
- `ForumPostListScreen` reduced from ~1000 to ~300 lines
- `ForumPostDetailScreen` reduced from ~700 to ~400 lines

## 1.0.0

- Initial release
- `DiscordFeedbackView` — drop-in widget to display Discord channel messages
- `DiscordService` — full Discord Bot API client (messages, reactions, file uploads)
- Long-press reaction overlay with animated emoji picker
- Reply to messages with text and image attachments
- Pull-to-refresh and infinite scroll pagination
- Customizable accent color, title, and emoji set
- Message detail screen with quick-react, embeds, and file previews
