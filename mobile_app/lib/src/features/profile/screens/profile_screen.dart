import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_scope.dart';
import '../../../auth/models.dart';
import '../../../demo/demo_state.dart';
import '../../../router.dart';
import '../../../theme/app_colors.dart';
import '../../../util/format.dart';
import '../../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<AppUser>? _user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _user ??= AppScope.of(context).repository.me();
  }

  Future<void> _deleteAccount() async {
    final scope = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete account?'),
        content: Text('Your progress, downloads and subscription details will be removed. '
            'In this demo, the account is only signed out.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await scope.auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final demo = scope.demo;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: demo,
          builder: (context, _) => ListView(
            padding: EdgeInsets.only(bottom: 20),
            children: [
              ScreenHeader(title: 'Profile'),
              FutureBuilder<AppUser>(
                future: _user,
                builder: (context, snap) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 29,
                      backgroundColor: AppColors.border,
                      child: Text(Fmt.initials(demo.learnerName),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(demo.learnerName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text(
                          snap.hasData
                              ? Fmt.phone(snap.data!.phone)
                              : (snap.hasError ? 'Couldn’t load your number' : ' '),
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
              demo.isPremium ? _PremiumCard(demo: demo) : _FreePlanCard(),
              SectionLabel('LEARNING'),
              SettingsRow(
                icon: Icons.bookmark_border_rounded,
                label: 'Saved courses',
                value: '${demo.bookmarkedCourses.length}',
                onTap: () => context.go(Routes.learning),
              ),
              SettingsRow(
                icon: Icons.download_rounded,
                label: 'Downloads',
                value: demo.downloadCount == 0 ? 'None' : '${demo.downloadsGb.toStringAsFixed(1)} GB',
                onTap: () => showDemoSnack(
                    context,
                    demo.downloadCount == 0
                        ? 'Use “Save offline” in the player to download lessons.'
                        : '${demo.downloadCount} lessons saved offline'),
              ),
              SectionLabel('ACCOUNT', padding: EdgeInsets.fromLTRB(20, 20, 20, 10)),
              SettingsRow(
                key: Key('adminPanel'),
                icon: Icons.upload_rounded,
                iconColor: AppColors.cyan,
                label: 'Admin panel',
                color: AppColors.cyan,
                value: 'admin only',
                chevron: false,
                onTap: () => context.push(Routes.adminUpload),
              ),
              SettingsRow(
                icon: Icons.help_outline_rounded,
                label: 'Help & support',
                onTap: () => showDemoSnack(context, 'Support: help@ramintellect.example (placeholder)'),
              ),
              SettingsRow(
                key: Key('signOut'),
                icon: Icons.logout_rounded,
                label: 'Sign out',
                chevron: false,
                onTap: () => scope.auth.logout(),
              ),
              SettingsRow(
                icon: Icons.delete_outline_rounded,
                iconColor: AppColors.destructive,
                label: 'Delete account',
                color: AppColors.destructive,
                chevron: false,
                divider: false,
                onTap: _deleteAccount,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text('Ram Intellect LLP · Bangalore · v1.0.0 (demo)',
                    style: TextStyle(fontSize: 11, color: AppColors.faint)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.demo});

  final DemoState demo;

  @override
  Widget build(BuildContext context) {
    Widget button(String label, {required bool filled, required VoidCallback onTap}) => Expanded(
          child: SizedBox(
            height: 42,
            child: filled
                ? FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: Size(0, 42),
                        backgroundColor: AppColors.premium,
                        foregroundColor: AppColors.ink),
                    onPressed: onTap,
                    child: Text(label, style: TextStyle(fontSize: 13)),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.premium,
                      side: BorderSide(color: AppColors.premiumBorder),
                      shape: StadiumBorder(),
                    ),
                    onPressed: onTap,
                    child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
          ),
        );

    return Container(
      key: Key('premiumCard'),
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.premiumBg,
        border: Border.all(color: AppColors.premiumBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.workspace_premium_outlined, size: 20, color: AppColors.premium),
          SizedBox(width: 9),
          Expanded(
            child: Text('Premium · ${demo.activePlan!.name}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          Tag('ACTIVE', color: AppColors.success, background: AppColors.ink),
        ]),
        SizedBox(height: 14),
        GradientProgress(value: demo.planUsed, height: 5, background: AppColors.ink, color: AppColors.premium),
        SizedBox(height: 6),
        Text('Renews ${Fmt.date(demo.renewsOn!)} · ${demo.daysLeft} days left',
            style: TextStyle(fontSize: 12, color: AppColors.premiumText)),
        SizedBox(height: 14),
        Row(children: [
          button('Change plan', filled: true, onTap: () => context.push(Routes.paywall)),
          SizedBox(width: 10),
          button('Manage in store', filled: false, onTap: () async {
            final cancel = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Manage subscription'),
                content: Text('On a real device this opens Google Play or the App Store. '
                    'In the demo you can end the subscription here.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: Text('End subscription')),
                ],
              ),
            );
            if (cancel == true) demo.cancelSubscription();
          }),
        ]),
      ]),
    );
  }
}

class _FreePlanCard extends StatelessWidget {
  const _FreePlanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          LockIcon(size: 18),
          SizedBox(width: 9),
          Expanded(child: Text('Free plan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          Tag('FREE', color: AppColors.muted, background: AppColors.ink),
        ]),
        SizedBox(height: 10),
        Text('Free previews and free courses only. Premium unlocks every lesson in every domain.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.45)),
        SizedBox(height: 14),
        FilledButton(
          key: Key('seePlans'),
          style: FilledButton.styleFrom(minimumSize: Size.fromHeight(44)),
          onPressed: () => context.push(Routes.paywall),
          child: Text('See plans', style: TextStyle(fontSize: 14)),
        ),
      ]),
    );
  }
}
