import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'target.dart'; // Halaman utama MyTarget
import 'homepagemain.dart';
import 'wallet.dart';
import 'report.dart';
import 'article.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi AwesomeNotifications
  await AwesomeNotifications().initialize(
    'resource://drawable/app_icon',
    [
      NotificationChannel(
        channelKey: 'target_channel',
        channelName: 'Target Notifications',
        channelDescription: 'Notifications for income and expense targets',
        defaultColor: const Color(0xFF058240),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        defaultPrivacy: NotificationPrivacy.Private,
      ),
      NotificationChannel(
        channelKey: 'reminder_channel',
        channelName: 'Reminder Notifications',
        channelDescription: 'Daily reminders for income and expense targets',
        defaultColor: const Color(0xFF058240),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        defaultPrivacy: NotificationPrivacy.Private,
      ),
    ],
  );

  bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
  if (!isAllowed) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyTarget',
      initialRoute: '/target',
      routes: {
        '/target': (context) => const TargetPage(),
        '/homemain': (context) => const HomePageMainScreen(),
        '/report': (context) => const ReportPage(),
        '/wallet': (context) => const MyWalletPage(),
        '/articles': (context) => const ArticlesPage(),
      },
    );
  }
}
