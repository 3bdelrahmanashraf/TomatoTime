import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomato_time/providers/app_state.dart';
import 'package:tomato_time/screens/home_screen.dart';
import 'package:tomato_time/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const TomatoTimeApp(),
    ),
  );
}

class TomatoTimeApp extends StatelessWidget {
  const TomatoTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'TomatoTime',
          debugShowCheckedModeBanner: false,
          themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.black,
              brightness: Brightness.light,
              background: const Color(0xFFF3F4F6),
            ),
            scaffoldBackgroundColor: const Color(0xFFF3F4F6),
            fontFamily: 'Inter', // Assuming Inter or system font
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.white,
              brightness: Brightness.dark,
              background: const Color(0xFF111827),
            ),
            scaffoldBackgroundColor: const Color(0xFF111827),
          ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _checkPersistence();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  Future<void> _checkPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    final staySignedIn = prefs.getBool('stay_signed_in') ?? true;
    if (!staySignedIn && FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
      // We don't reset the flag here because we want it to apply to the NEXT session too if they don't check it again.
      // Actually, once they log in, the flag is updated in login_screen.dart.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
