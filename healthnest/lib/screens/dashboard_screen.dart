// Main dashboard screen for HealthNest
// Shows overview of health records, recent activities, and quick actions

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/patient.dart';
import '../models/health_record.dart';
import 'records_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('HealthNest'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.settings),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final user = userProvider.currentUser;
            final patients = userProvider.patients;
            
            if (user == null) {
              return const Center(
                child: CupertinoActivityIndicator(),
              );
            }

            return CustomScrollView(
              slivers: [
                // Header Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Message
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [CupertinoColors.systemBlue, CupertinoColors.systemTeal],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.systemBlue.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Icon(
                                  CupertinoIcons.person_circle_fill,
                                  color: CupertinoColors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back,',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: CupertinoColors.white.withOpacity(0.8),
                                      ),
                                    ),
                                    Text(
                                      user.displayName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Quick Actions
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.label,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionCard(
                                icon: CupertinoIcons.camera,
                                title: 'Scan Record',
                                subtitle: 'Add new document',
                                color: CupertinoColors.systemBlue,
                                onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => const ScanScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildQuickActionCard(
                                icon: CupertinoIcons.doc_text,
                                title: 'View Records',
                                subtitle: 'Browse documents',
                                color: CupertinoColors.systemGreen,
                                onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => const RecordsScreen(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Patients Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Family Members',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.label,
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: const Icon(
                                CupertinoIcons.add_circled,
                                color: CupertinoColors.systemBlue,
                              ),
                              onPressed: () {
                                // TODO: Add new patient functionality
                                showCupertinoDialog(
                                  context: context,
                                  builder: (context) => CupertinoAlertDialog(
                                    title: const Text('Coming Soon'),
                                    content: const Text('Adding new family members will be available soon.'),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: const Text('OK'),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                
                // Patients List
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final patient = patients[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                        child: _buildPatientCard(patient, context),
                      );
                    },
                    childCount: patients.length,
                  ),
                ),
                
                // Recent Records Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Records',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.label,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              _buildEmptyState(
                                icon: CupertinoIcons.doc_text,
                                title: 'No records yet',
                                subtitle: 'Start by scanning your first health document',
                                actionText: 'Scan Document',
                                onAction: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => const ScanScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: color,
                size: 25,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(Patient patient, BuildContext context) {
    final age = DateTime.now().year - patient.dateOfBirth.year;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              CupertinoIcons.person_fill,
              color: CupertinoColors.systemBlue,
              size: 25,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${patient.gender} • $age years',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                if (patient.bloodGroup != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Blood Group: ${patient.bloodGroup}',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.tertiaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
            ),
            onPressed: () {
              // TODO: Navigate to patient details
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(
            icon,
            color: CupertinoColors.systemGrey,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: CupertinoColors.secondaryLabel,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        CupertinoButton.filled(
          onPressed: onAction,
          child: Text(actionText),
        ),
      ],
    );
  }
} 