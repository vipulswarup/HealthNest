import 'package:flutter/cupertino.dart';
import 'package:sanovault/theme/sv_colors.dart';

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            border: null,
            backgroundColor: SvColors.groupedBackground,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverToBoxAdapter(
              child: Text(
                body,
                style: const TextStyle(fontSize: 17, height: 1.45, color: SvColors.slate),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
