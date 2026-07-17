import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/presentation/providers/theme_provider.dart';

class LegalScreen extends ConsumerWidget {
  final String titleKey;
  final String contentKey;

  const LegalScreen({
    super.key,
    required this.titleKey,
    required this.contentKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeData appTheme = ref.watch(themeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: appTheme.gradient),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              title: Text(titleKey.tr()),
              iconTheme: IconThemeData(color: appTheme.primaryTextColor),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(24.0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  contentKey.tr(),
                  style: TextStyle(
                    color: appTheme.primaryTextColor.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.6,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}