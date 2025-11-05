import 'package:flutter/material.dart';
import 'login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BabhDnevniciteApp());
}

class BabhDnevniciteApp extends StatelessWidget {
  const BabhDnevniciteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'БАБХ Дневниците',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      home: LoginPage(),
    );
  }
}