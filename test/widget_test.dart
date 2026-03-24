import 'package:flutter_test/flutter_test.dart';
import 'package:discord_feedback/discord_feedback.dart';

void main() {
  test('DiscordService can be instantiated', () {
    final service = DiscordService(botToken: 'test-token');
    expect(service, isNotNull);
    expect(service.botToken, 'test-token');
  });

  test('DiscordMessage.fromJson parses correctly', () {
    final json = {
      'id': '123',
      'channel_id': '456',
      'content': 'Hello',
      'timestamp': '2026-01-01T00:00:00.000Z',
      'pinned': false,
      'tts': false,
      'mention_everyone': false,
      'author': {
        'id': '789',
        'username': 'testuser',
        'discriminator': '0',
      },
      'attachments': <dynamic>[],
      'embeds': <dynamic>[],
      'reactions': <dynamic>[],
    };

    final msg = DiscordMessage.fromJson(json);
    expect(msg.id, '123');
    expect(msg.content, 'Hello');
    expect(msg.author.username, 'testuser');
    expect(msg.author.displayName, 'testuser');
    expect(msg.hasReactions, false);
    expect(msg.hasImages, false);
  });

  test('DiscordUser.avatarUrl returns default when no avatar', () {
    final user = DiscordUser(
      id: '123',
      username: 'test',
      discriminator: '0',
    );
    expect(user.avatarUrl, contains('embed/avatars'));
  });

  test('DiscordAttachment.isImage works correctly', () {
    final img = DiscordAttachment(
      id: '1',
      filename: 'photo.png',
      size: 1024,
      url: 'https://example.com/photo.png',
      proxyUrl: 'https://example.com/photo.png',
      contentType: 'image/png',
    );
    expect(img.isImage, true);
    expect(img.formattedSize, '1.0 KB');

    final file = DiscordAttachment(
      id: '2',
      filename: 'doc.pdf',
      size: 2048,
      url: 'https://example.com/doc.pdf',
      proxyUrl: 'https://example.com/doc.pdf',
      contentType: 'application/pdf',
    );
    expect(file.isImage, false);
  });

  test('DiscordMessage.copyWith updates reactions', () {
    final msg = DiscordMessage(
      id: '1',
      channelId: '2',
      content: 'test',
      timestamp: DateTime.now(),
      pinned: false,
      tts: false,
      mentionEveryone: false,
      author: DiscordUser(id: '3', username: 'u', discriminator: '0'),
      attachments: [],
      embeds: [],
      reactions: [],
    );

    final updated = msg.copyWith(reactions: [
      DiscordReaction(count: 1, me: true, emoji: DiscordEmoji(name: '👍')),
    ]);

    expect(msg.reactions.length, 0);
    expect(updated.reactions.length, 1);
    expect(updated.content, 'test');
  });
}
