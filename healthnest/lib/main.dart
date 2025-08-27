import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'providers/user_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database for desktop platforms
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || 
                  defaultTargetPlatform == TargetPlatform.windows || 
                  defaultTargetPlatform == TargetPlatform.linux)) {
    // Initialize sqflite_common_ffi for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // For web, we'll use a different storage approach
  // The app will handle this gracefully by showing appropriate UI
  
  runApp(const HealthNestApp());
}

class HealthNestApp extends StatelessWidget {
  const HealthNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserProvider>(
      create: (context) => UserProvider(),
      child: MaterialApp(
        title: 'HealthNest',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.light,
          useMaterial3: true,
        ),
        home: const AppRouter(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  @override
  void initState() {
    super.initState();
    debugPrint('AppRouter: initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('AppRouter: post frame callback');
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    debugPrint('Initializing userProvider...');
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.initialize();
    debugPrint('UserProvider initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        debugPrint('AppRouter build: isLoading=${userProvider.isLoading}, isInitialized=${userProvider.isInitialized}');
        
        if (userProvider.isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!userProvider.isInitialized) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Initializing'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!userProvider.hasUser) {
          return const WelcomeScreen();
        }

        if (!userProvider.onboardingCompleted) {
          return const WelcomeScreen();
        }

        return const DashboardScreen();
      },
    );
  }
} 