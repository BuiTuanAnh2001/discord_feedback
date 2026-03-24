import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:discord_feedback/discord_feedback.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Discord Feedback Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: DiscordFeedbackView(
        botToken: dotenv.env['DISCORD_BOT_TOKEN'] ?? '',
        channelId: dotenv.env['DISCORD_CHANNEL_ID'] ?? '',
        enableRealtime: true,
        appName: 'My App',
        appVersion: '1.0.0',
        title: 'bug-and-suggestions',
        channelEmoji: '\uD83D\uDCA1',
        // Theme auto-saved & restored from local storage.
        // Change the initial theme or let users customize via the palette button.
        theme: DiscordFeedbackTheme.dark,
        persistTheme: true,
        showCreateButton: false,
      ),
    );
  }
}
