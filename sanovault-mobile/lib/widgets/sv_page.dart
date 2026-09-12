import 'package:flutter/cupertino.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/sv_controls.dart';

class SvLargePage extends StatelessWidget {
  const SvLargePage({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onRefresh,
    this.error,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: SvColors.groupedBackground,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            trailing: trailing,
            border: null,
            backgroundColor: SvColors.groupedBackground,
          ),
          if (onRefresh != null) CupertinoSliverRefreshControl(onRefresh: onRefresh),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: SvErrorBanner(message: error!),
                    ),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
