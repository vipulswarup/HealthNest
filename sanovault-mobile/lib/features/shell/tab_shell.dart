import 'package:flutter/cupertino.dart';
import 'package:sanovault/features/family/family_page.dart';
import 'package:sanovault/features/home/home_page.dart';
import 'package:sanovault/features/medicines/medicines_page.dart';
import 'package:sanovault/features/more/more_page.dart';
import 'package:sanovault/features/reports/reports_page.dart';
import 'package:sanovault/theme/sv_colors.dart';

class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  late final CupertinoTabController _tabs = CupertinoTabController(
    initialIndex: 0,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabs,
      backgroundColor: SvColors.groupedBackground,
      tabBar: CupertinoTabBar(
        backgroundColor: SvColors.surface,
        activeColor: SvColors.coral,
        inactiveColor: SvColors.slate,
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_2), label: 'Family'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.doc_text), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: 'Medicines'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.ellipsis), label: 'More'),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return const HomePage();
              case 1:
                return const FamilyPage();
              case 2:
                return const ReportsPage();
              case 3:
                return const MedicinesPage();
              default:
                return const MorePage();
            }
          },
        );
      },
    );
  }
}
