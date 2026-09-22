import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_scope.dart';
import '../../../demo/demo_catalog.dart';
import '../../../demo/demo_state.dart';
import '../../../theme/app_colors.dart';
import '../../../util/format.dart';
import '../../../widgets/common.dart';
import '../widgets/admin_shell.dart';

/// Admin — pricing & coupons. Prices set here drive the paywall in this demo.
class AdminPricingScreen extends StatelessWidget {
  const AdminPricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).demo;
    final wide = MediaQuery.sizeOf(context).width >= AdminShell.wideBreakpoint;
    return AdminShell(
      section: AdminSection.pricing,
      title: 'Pricing & coupons',
      subtitle: 'These prices drive the web checkout and the numbers shown in the app.',
      body: ListenableBuilder(
        listenable: demo,
        builder: (context, _) => ListView(
          padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 20, vertical: 24),
          children: [
            AdminNote(
              warning: true,
              text: 'Editing a price here does not change what Apple or Google charge. Update the matching '
                  'product in App Store Connect and Play Console too.',
            ),
            SizedBox(height: 22),
            Row(children: [
              Expanded(child: AdminLabel('SUBSCRIPTION PLANS')),
              OutlinedButton(
                style: _secondaryButton,
                onPressed: () => _addPlan(context, demo),
                child: Text('Add plan'),
              ),
            ]),
            SizedBox(height: 12),
            _PlansTable(demo: demo, wide: wide),
            SizedBox(height: 22),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _CouponsTable(demo: demo)),
                SizedBox(width: 22),
                SizedBox(width: 330, child: _NewCouponForm(demo: demo)),
              ])
            else ...[
              _CouponsTable(demo: demo),
              SizedBox(height: 22),
              _NewCouponForm(demo: demo),
            ],
          ],
        ),
      ),
    );
  }

  static final _secondaryButton = OutlinedButton.styleFrom(
    foregroundColor: AppColors.text,
    backgroundColor: AppColors.surface,
    side: BorderSide(color: AppColors.border),
    minimumSize: Size(0, 38),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  Future<void> _addPlan(BuildContext context, DemoState demo) async {
    final result = await showDialog<(String, int)>(context: context, builder: (_) => const _AddPlanDialog());
    if (result == null) return;
    final (name, days) = result;
    demo.addPlan(Plan(
      id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      days: days,
      subtitle: '$days days of full access',
      storeProductId: 'sub_custom_$days',
    ));
  }
}

// --- Plans -------------------------------------------------------------------------------------------------

class _PlansTable extends StatelessWidget {
  const _PlansTable({required this.demo, required this.wide});

  final DemoState demo;
  final bool wide;

  static const _flex = [14, 10, 10, 13, 8];

  Future<void> _editPrice(BuildContext context, Plan plan) async {
    final result = await showDialog<String>(context: context, builder: (_) => _PriceDialog(plan: plan));
    if (result == null) return;
    final price = int.tryParse(result);
    demo.updatePlan(plan, price: price, clearPrice: price == null);
  }

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(children: [
        for (final plan in demo.plans)
          Opacity(
            opacity: plan.visible ? 1 : 0.55,
            child: Container(
              margin: EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plan.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(height: 3),
                    Text('${plan.days} days · ${plan.storeProductId}',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                TextButton(
                  onPressed: () => _editPrice(context, plan),
                  style: TextButton.styleFrom(foregroundColor: AppColors.text),
                  child: Text(Fmt.price(plan.price), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Switch(value: plan.visible, onChanged: (v) => demo.updatePlan(plan, visible: v)),
              ]),
            ),
          ),
        Text('Tap a price to edit it.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);
    }

    Widget cells(List<Widget> children, {bool header = false, double opacity = 1}) => Opacity(
          opacity: opacity,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: header ? AppColors.surfaceRaised : null,
              border: header ? null : Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              for (var i = 0; i < children.length; i++)
                Expanded(flex: _flex[i], child: Align(alignment: Alignment.centerLeft, child: children[i])),
            ]),
          ),
        );
    final headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: AppColors.muted);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: AppColors.surface,
        child: Column(children: [
          cells(header: true, [
            Text('PLAN', style: headerStyle),
            Text('DURATION', style: headerStyle),
            Text('PRICE (INR)', style: headerStyle),
            Text('STORE PRODUCT ID', style: headerStyle),
            Text('VISIBLE', style: headerStyle),
          ]),
          for (final plan in demo.plans)
            cells(opacity: plan.visible ? 1 : 0.55, [
              Text(plan.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${plan.days} days', style: TextStyle(fontSize: 14, color: AppColors.muted)),
              InkWell(
                onTap: () => _editPrice(context, plan),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(Fmt.price(plan.price), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(width: 6),
                    Icon(Icons.edit_outlined, size: 14, color: AppColors.muted),
                  ]),
                ),
              ),
              Text(plan.storeProductId, style: TextStyle(fontSize: 13, color: AppColors.muted)),
              Switch(value: plan.visible, onChanged: (v) => demo.updatePlan(plan, visible: v)),
            ]),
        ]),
      ),
    );
  }
}

// --- Coupons -----------------------------------------------------------------------------------------------

class _CouponsTable extends StatelessWidget {
  const _CouponsTable({required this.demo});

  final DemoState demo;

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: AppColors.muted);
    Widget row(List<Widget> children, {bool header = false, double opacity = 1}) => Opacity(
          opacity: opacity,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: header ? AppColors.surfaceRaised : null,
              border: header ? null : Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              for (var i = 0; i < children.length; i++)
                Expanded(flex: [11, 9, 10, 10][i], child: children[i]),
            ]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminLabel('COUPONS · WEB CHECKOUT ONLY'),
      SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: AppColors.surface,
          child: Column(children: [
            row(header: true, [
              Text('CODE', style: headerStyle),
              Text('DISCOUNT', style: headerStyle),
              Text('USED', style: headerStyle),
              Text('EXPIRES', style: headerStyle),
            ]),
            for (final c in demo.coupons)
              row(opacity: c.isUsable(demo.now) ? 1 : 0.55, [
                Text(c.code, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                Text(c.discountLabel, style: TextStyle(fontSize: 14)),
                Text('${c.used} of ${c.maxUses}${c.spent ? ' · spent' : ''}',
                    style: TextStyle(fontSize: 14, color: AppColors.muted)),
                Text(c.isExpired(demo.now) ? 'expired' : Fmt.date(c.expires),
                    style: TextStyle(fontSize: 14, color: AppColors.muted)),
              ]),
          ]),
        ),
      ),
    ]);
  }
}

class _NewCouponForm extends StatefulWidget {
  const _NewCouponForm({required this.demo});

  final DemoState demo;

  @override
  State<_NewCouponForm> createState() => _NewCouponFormState();
}

class _NewCouponFormState extends State<_NewCouponForm> {
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _max = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _max.dispose();
    super.dispose();
  }

  void _create() {
    final error = widget.demo.addCoupon(code: _code.text, value: _value.text, maxUses: _max.text);
    setState(() => _error = error);
    if (error == null) {
      showDemoSnack(context, 'Coupon ${_code.text.trim().toUpperCase()} created · valid for 30 days');
      _code.clear();
      _value.clear();
      _max.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          fillColor: AppColors.ink,
          contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        );
    final label = TextStyle(fontSize: 12, color: AppColors.muted);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('New coupon', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        SizedBox(height: 14),
        Text('Code', style: label),
        SizedBox(height: 7),
        TextField(
          key: Key('couponCode'),
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: deco('DIWALI25'),
        ),
        SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Value (% off)', style: label),
              SizedBox(height: 7),
              TextField(
                key: Key('couponValue'),
                controller: _value,
                keyboardType: TextInputType.number,
                decoration: deco('25'),
              ),
            ]),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Max uses', style: label),
              SizedBox(height: 7),
              TextField(
                key: Key('couponMax'),
                controller: _max,
                keyboardType: TextInputType.number,
                decoration: deco('500'),
              ),
            ]),
          ),
        ]),
        if (_error != null) ...[
          SizedBox(height: 10),
          Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.danger)),
        ],
        SizedBox(height: 16),
        FilledButton(
          key: Key('createCoupon'),
          style: FilledButton.styleFrom(minimumSize: Size.fromHeight(46)),
          onPressed: _create,
          child: Text('Create coupon', style: TextStyle(fontSize: 14)),
        ),
        SizedBox(height: 12),
        Text(
          'For iOS purchases, create an Offer Code in App Store Connect instead. Your own codes cannot unlock '
          'content there.',
          style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.5),
        ),
      ]),
    );
  }
}

// --- Dialogs -----------------------------------------------------------------------------------------------
// Each dialog owns its text controllers so they are disposed only after the closing animation.

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.plan});

  final Plan plan;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  late final _controller = TextEditingController(text: widget.plan.price?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Price for ${widget.plan.name}'),
      content: TextField(
        key: const Key('priceField'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Leave empty for [PRICE]'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Save')),
      ],
    );
  }
}

class _AddPlanDialog extends StatefulWidget {
  const _AddPlanDialog();

  @override
  State<_AddPlanDialog> createState() => _AddPlanDialogState();
}

class _AddPlanDialogState extends State<_AddPlanDialog> {
  final _name = TextEditingController();
  final _days = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    super.dispose();
  }

  void _submit() {
    final days = int.tryParse(_days.text);
    final name = _name.text.trim();
    if (name.isEmpty || days == null || days <= 0) return;
    Navigator.pop(context, (name, days));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add plan'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name, e.g. 6 months')),
        const SizedBox(height: 12),
        TextField(
          controller: _days,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Duration in days'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
