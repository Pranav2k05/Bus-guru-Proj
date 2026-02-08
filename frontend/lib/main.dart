// lib/main.dart
import 'package:flutter/material.dart';

// import your chatbot screen - update path if you placed it elsewhere
import 'screens/chatbot_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus-Guru — Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFBF8FE),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),

      // Option A: show chatbot directly as the home screen
      home: const ChatbotScreen(),

      // Option B: named routes (we also keep home above; if you prefer route-only,
      // replace 'home' with an initialRoute or remove home)
      routes: {
        '/chat': (context) => const ChatbotScreen(),
        // add other named routes here if you need them
      },

      // Localization basics (so the app can support Kannada/Hindi/Telugu later)
      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi
        Locale('kn'), // Kannada
        Locale('te'), // Telugu
      ],
      locale: const Locale('en'),
    );
  }
}
