import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    return ChangeNotifierProvider(
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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.isLoading) {
          return const CupertinoPageScaffold(
            child: Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        if (!userProvider.isInitialized) {
          return const CupertinoPageScaffold(
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