import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/services.dart';
import 'amplifyconfiguration.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();

  // Force portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const BabhDnevniciteApp());
}

Future<void> _configureAmplify() async {
  final auth = AmplifyAuthCognito();
  final storage = AmplifyStorageS3();
  await Amplify.addPlugins([auth, storage]);
  await Amplify.configure(amplifyconfig);
  safePrint('✅ Amplify configured');
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
      home: const LoginPage(),
    );
  }
}