// Main dashboard screen for HealthNest
// Shows overview of health records, recent activities, and quick actions

import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthNest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Dashboard - Coming Soon'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new health record
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 