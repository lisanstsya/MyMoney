import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:suksesges/article.dart';
import 'package:suksesges/wallet.dart';
import 'package:suksesges/report.dart';
import 'package:suksesges/splash_screen.dart';
import 'package:suksesges/register_screen.dart';
import 'package:suksesges/login_screen.dart';
import 'package:suksesges/homepagemain.dart';
import 'package:suksesges/target.dart';

// Untuk state management
import 'package:provider/provider.dart';
import 'package:suksesges/budget_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi notifikasi
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'daily_channel',
        channelName: 'Daily Notifications',
        channelDescription: 'Daily reminder to manage money',
        defaultColor: const Color(0xFF9D50DD),
        importance: NotificationImportance.High,
        channelShowBadge: true,
      ),
    ],
    debug: true,
  );

  // Minta izin notifikasi
  bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
  if (!isAllowed) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  // Jadwalkan notifikasi harian
  scheduleDailyReminder(9, 0, 'Waktunya cek keuangan kamu di MyMoney 📊');
  scheduleDailyReminder(15, 0, 'Jangan lupa catat pemasukan/pengeluaran hari ini!');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BudgetData()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyMoney',
      initialRoute: '/',
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) {
            switch (settings.name) {
              case '/':
                return const SplashScreen();
              case '/home':
                return const HomeScreen();
              case '/register':
                return const RegisterScreen();
              case '/login':
                return const LoginScreen();
              case '/homemain':
                return const HomePageMainScreen();
              case '/report':
                return const ReportPage();
              case '/target':
                return const TargetPage();
              case '/articles':
                return const ArticlesPage();
              case '/wallet':
                return const MyWalletPage();
              default:
                return const Scaffold(body: Text('Page Not Found'));
            }
          },
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD700),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 100),
              const SizedBox(height: 12),
              Image.asset('assets/uangkoin.png', width: 250),
              const SizedBox(height: 10),
              Text(
                'WELCOME',
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 2,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF058240),
                  padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Register',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.green, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 93, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Colors.white,
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 20, color: Colors.green),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fungsi penjadwalan notifikasi
void scheduleDailyReminder(int hour, int minute, String message) async {
  final id = hour * 100 + minute;

  // Cek apakah notifikasi sudah dijadwalkan
  final scheduled = await AwesomeNotifications().listScheduledNotifications();
  bool alreadyScheduled = scheduled.any((n) => n.content?.id == id);

  if (!alreadyScheduled) {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'daily_channel',
        title: 'MyMoney Reminder',
        body: message,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: hour,
        minute: minute,
        second: 0,
        millisecond: 0,
        repeats: true,
        timeZone: await AwesomeNotifications().getLocalTimeZoneIdentifier(),
      ),
    );
  }
}
