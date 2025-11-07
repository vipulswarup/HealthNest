import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/error_screen.dart';
import 'providers/user_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  print('HealthNest: Starting application initialization...');
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    print('HealthNest: Loading environment variables...');
    await dotenv.load(fileName: ".env");
    print('HealthNest: Environment variables loaded successfully');
  } catch (e) {
    // If .env file is not found, we'll use the fallback values
    print('HealthNest: Warning: .env file not found, using fallback configuration');
    print('HealthNest: Error details: $e');
  }
  
    // Initialize database for desktop platforms (fallback)
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS ||
                  defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.linux)) {
    print('HealthNest: Initializing SQLite for desktop platform...');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print('HealthNest: SQLite initialization complete');
  }

  // Note: Supabase initialization will be handled by AppRouter with proper error handling
  
  print('HealthNest: Starting Flutter app...');
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
  String? _errorMessage;
  String? _errorDetails;

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
    try {
      debugPrint('Initializing userProvider...');
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.initialize();
      debugPrint('UserProvider initialized');
    } catch (e) {
      debugPrint('Error during initialization: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _errorDetails = e.toString();
        });
      }
    }
  }

  void _retryInitialization() {
    setState(() {
      _errorMessage = null;
      _errorDetails = null;
    });
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if there's an error
    if (_errorMessage != null) {
      return ErrorScreen(
        title: 'Configuration Error',
        message: 'Failed to load application configuration. Please check your environment variables and database connection.',
        details: _errorDetails,
        onRetry: _retryInitialization,
      );
    }

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