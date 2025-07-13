import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'providers/user_provider.dart';

void main() {
  runApp(const HealthNestApp());
}

class HealthNestApp extends StatelessWidget {
  const HealthNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserProvider>(
      create: (context) => UserProvider(),
      child: CupertinoApp(
        title: 'HealthNest',
        theme: const CupertinoThemeData(
          primaryColor: CupertinoColors.systemBlue,
          brightness: Brightness.light,
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
          return const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text('Loading'),
            ),
            child: Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        if (!userProvider.isInitialized) {
          return const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text('Initializing'),
            ),
            child: Center(
              child: CupertinoActivityIndicator(),
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