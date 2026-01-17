import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/analyzing_screen.dart';
import 'screens/result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

String globalUserName = "";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  globalUserName = prefs.getString("userName") ?? "";

  runApp(MyApp(hasName: globalUserName.isNotEmpty));
}

class MyApp extends StatelessWidget {
  final bool hasName;
  const MyApp({super.key, required this.hasName});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CekPadi',
      initialRoute: hasName ? '/home' : '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/analyzing': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as AnalyzingArgs;
          return AnalyzingScreen(args: args);
        },
        '/result': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as ResultArgs;
          return ResultScreen(args: args);
        },
      },
    );
  }
}