// Health records screen for viewing and managing health records

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Health Records'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // Records Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [CupertinoColors.systemGreen, CupertinoColors.systemTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGreen.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.doc_text,
                  size: 60,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'Your Health Records',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                'All your medical documents organized and secure',
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Empty State
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
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        CupertinoIcons.doc_text,
                        color: CupertinoColors.systemGrey,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No records yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start by scanning your first health document',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    CupertinoButton.filled(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Scan Document'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Features
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
                      CupertinoIcons.search,
                      'Search & Filter',
                      'Find records quickly with smart search',
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureRow(
                      CupertinoIcons.folder,
                      'Organized Categories',
                      'Documents automatically categorized',
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureRow(
                      CupertinoIcons.share,
                      'Easy Sharing',
                      'Share records with healthcare providers',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              
              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      onPressed: () {
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text('Coming Soon'),
                            content: const Text('Export functionality will be available soon.'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('OK'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Export'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      onPressed: () {
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text('Coming Soon'),
                            content: const Text('Backup functionality will be available soon.'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('OK'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Backup'),
                    ),
                  ),
                ],
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