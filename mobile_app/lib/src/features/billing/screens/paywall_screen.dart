import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_scope.dart';
import '../../../demo/demo_catalog.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../util/format.dart';
import '../../../widgets/common.dart';

/// Subscription paywall. Demo only: "Continue" activates the plan locally without any payment.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _coupon = TextEditingController();
  String? _selectedId;
  Coupon? _applied;
  String? _couponMessage;
  bool _couponError = false;

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  void _applyCoupon() {
    final demo = AppScope.of(context).demo;
    final code = _coupon.text.trim();
    FocusScope.of(context).unfocus();
    if (code.isEmpty) return;
    final coupon = demo.findCoupon(code);
    setState(() {
      if (coupon == null) {
        _applied = null;
        _couponError = true;
        _couponMessage = 'That code isn’t valid.';
      } else if (!coupon.isUsable(demo.now)) {
        _applied = null;
        _couponError = true;
        _couponMessage = coupon.spent ? 'That code has been fully used.' : 'That code has expired.';
      } else {
        _applied = coupon;
        _couponError = false;
        _couponMessage = '${coupon.code} applied · ${coupon.discountLabel} off';
      }
    });
  }

  int? _discounted(int? price) {
    if (price == null || _applied == null) return price;
    if (_applied!.percentOff != null) return (price * (100 - _applied!.percentOff!) / 100).round();
    if (_applied!.flatOff != null) return (price - _applied!.flatOff!).clamp(0, price);
    return price;
  }

  Future<void> _continue(Plan plan) async {
    final demo = AppScope.of(context).demo;
    final price = _discounted(plan.price);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Demo purchase'),
        content: Text('This activates ${plan.name} (${Fmt.price(price)}) for this demo session. '
            'No payment is taken.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    demo.subscribe(plan, coupon: _applied);
    showDemoSnack(context, 'Premium active · every lesson unlocked');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).demo;
    final plans = demo.visiblePlans;
    final selected = plans.where((p) => p.id == _selectedId).firstOrNull ??
        plans.where((p) => p.id == 'annual').firstOrNull ??
        plans.firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(children: [
              IconButton(
                tooltip: 'Close',
                onPressed: () => context.pop(),
                icon: Icon(Icons.close_rounded, color: AppColors.muted),
              ),
              Spacer(),
              TextButton(
                onPressed: () => showDemoSnack(context, 'No previous purchase found for this account (demo).'),
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: Text('Restore'),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              children: [
                SizedBox(height: 6),
                Text('Every domain,\none subscription', style: AppText.display),
                SizedBox(height: 10),
                Text('Full access to all ${DemoCatalog.totalCourses} courses for as long as your plan runs. '
                    'No per-course fees.', style: AppText.bodyMuted),
                SizedBox(height: 18),
                for (final benefit in [
                  'All ${DemoCatalog.domains.length} domains, new courses included',
                  'Offline downloads, 1080p playback',
                  'Resume on any device',
                ])
                  Padding(
                    padding: EdgeInsets.only(bottom: 9),
                    child: Row(children: [
                      Icon(Icons.check_rounded, size: 18, color: AppColors.success),
                      SizedBox(width: 10),
                      Expanded(child: Text(benefit, style: TextStyle(fontSize: 13))),
                    ]),
                  ),
                SizedBox(height: 10),
                if (plans.isEmpty)
                  Text('No plans are available right now.', style: AppText.bodyMuted),
                for (final plan in plans)
                  _PlanOption(
                    plan: plan,
                    selected: plan.id == selected?.id,
                    price: _discounted(plan.price),
                    originalPrice: _applied != null && plan.price != null ? plan.price : null,
                    onTap: () => setState(() => _selectedId = plan.id),
                  ),
                SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextField(
                      key: Key('couponField'),
                      controller: _coupon,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(fontSize: 14, letterSpacing: 0.8),
                      decoration: InputDecoration(
                        hintText: 'Coupon code',
                        prefixIcon: Icon(Icons.confirmation_number_outlined, size: 18, color: AppColors.muted),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border)),
                      ),
                      onSubmitted: (_) => _applyCoupon(),
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: Key('applyCoupon'),
                      style: FilledButton.styleFrom(
                        minimumSize: Size(0, 48),
                        backgroundColor: AppColors.border,
                        foregroundColor: AppColors.text,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: _applyCoupon,
                      child: Text('Apply', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ]),
                if (_couponMessage != null)
                  Padding(
                    padding: EdgeInsets.only(top: 8, left: 4),
                    child: Text(_couponMessage!,
                        style: TextStyle(fontSize: 12, color: _couponError ? AppColors.danger : AppColors.success)),
                  ),
                SizedBox(height: 16),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: Column(children: [
              FilledButton(
                key: Key('paywallContinue'),
                onPressed: selected == null ? null : () => _continue(selected),
                child: Text('Continue'),
              ),
              SizedBox(height: 12),
              Text('Renews automatically. Cancel anytime in your store account. Terms · Privacy',
                  textAlign: TextAlign.center, style: AppText.tiny),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.plan,
    required this.selected,
    required this.price,
    required this.originalPrice,
    required this.onTap,
  });

  final Plan plan;
  final bool selected;
  final int? price;
  final int? originalPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.selectedBg : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: 1.5),
          ),
          child: InkWell(
            key: Key('plan-${plan.id}'),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: Border.all(color: selected ? AppColors.primary : AppColors.disabled, width: 1.5),
                  ),
                  child: selected ? Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plan.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    SizedBox(height: 3),
                    Text(plan.subtitle, style: AppText.small),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Fmt.price(price), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (originalPrice != null && originalPrice != price)
                    Text(Fmt.price(originalPrice),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.muted, decoration: TextDecoration.lineThrough)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
