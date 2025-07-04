import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../dashboard_screen.dart';

class OnboardingCompleteScreen extends StatelessWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // Success Animation
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [CupertinoColors.systemGreen, CupertinoColors.systemTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGreen.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 60,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(height: 32),
              
              // Success Message
              const Text(
                'Setup Complete!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                'Your HealthNest is ready to use',
                style: TextStyle(
                  fontSize: 18,
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Features Overview
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      CupertinoIcons.doc_text,
                      'Add Health Records',
                      'Scan and organize medical documents',
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureRow(
                      CupertinoIcons.person_2,
                      'Manage Family',
                      'Add more family members to your account',
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureRow(
                      CupertinoIcons.cloud_upload,
                      'Sync Across Devices',
                      'Access your records on all your devices',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Privacy Reminder
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.systemBlue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.lock_shield,
                      color: CupertinoColors.systemBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your data is stored locally and encrypted',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              
              // Get Started Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () async {
                    try {
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      await userProvider.completeOnboarding();
                      
                      Navigator.pushAndRemoveUntil(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const DashboardScreen(),
                        ),
                        (route) => false,
                      );
                    } catch (e) {
                      showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Error'),
                          content: Text('Error completing setup: $e'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('OK'),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Help Text
              Text(
                'You can always change settings later',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.tertiaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: CupertinoColors.systemGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 