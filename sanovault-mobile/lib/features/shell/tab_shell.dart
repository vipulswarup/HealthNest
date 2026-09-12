import 'package:flutter/cupertino.dart';
import 'package:sanovault/features/home/home_page.dart';
import 'package:sanovault/features/more/more_page.dart';
import 'package:sanovault/features/placeholder/coming_soon_page.dart';
import 'package:sanovault/theme/sv_colors.dart';

class TabShell extends StatelessWidget {
  const TabShell({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
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
                return const ComingSoonPage(
                  title: 'Family',
                  body: 'Person profiles and editing land in Phase 2. Home already shows everyone in this folder.',
                );
              case 2:
                return const ComingSoonPage(
                  title: 'Reports',
                  body: 'Searching, opening, and viewing documents land in Phase 3.',
                );
              case 3:
                return const ComingSoonPage(
                  title: 'Medicines',
                  body: 'Active medicines, photo-from-label, and the printable report land in Phase 5.',
                );
              default:
                return const MorePage();
            }
          },
        );
      },
    );
  }
}
