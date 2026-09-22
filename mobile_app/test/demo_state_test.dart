import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/src/demo/demo_catalog.dart';
import 'package:learning_app/src/demo/demo_state.dart';
import 'package:learning_app/src/util/format.dart';

void main() {
  final today = DateTime(2026, 9, 23);
  late DemoState demo;

  setUp(() => demo = DemoState(clock: () => today));
  tearDown(() => demo.dispose());

  test('free lessons are watchable, premium ones need a plan', () {
    final signals = DemoCatalog.course('signals');
    expect(demo.canWatch(signals, signals.lessons[0]), isTrue);
    expect(demo.canWatch(signals, signals.lessons[2]), isFalse);
    expect(signals.lockedCount, 22);

    demo.subscribe(demo.plans.firstWhere((p) => p.id == 'annual'));
    expect(demo.canWatch(signals, signals.lessons[2]), isTrue);
    expect(demo.renewsOn, today.add(const Duration(days: 365)));
    expect(demo.daysLeft, 365);
  });

  test('coupons: lookup is case-insensitive and spent/expired codes are unusable', () {
    expect(demo.findCoupon('launch40')!.isUsable(today), isTrue);
    expect(demo.findCoupon('EARLY100')!.isUsable(today), isFalse); // spent and expired
    expect(demo.findCoupon('nope'), isNull);
  });

  test('new coupons are validated', () {
    expect(demo.addCoupon(code: 'x', value: '10', maxUses: '5'), 'Use 3–20 letters or digits');
    expect(demo.addCoupon(code: 'LAUNCH40', value: '10', maxUses: '5'), 'That code already exists');
    expect(demo.addCoupon(code: 'DIWALI25', value: '150', maxUses: '5'), contains('percentage'));
    expect(demo.addCoupon(code: 'DIWALI25', value: '25', maxUses: '0'), contains('Max uses'));
    expect(demo.addCoupon(code: 'diwali25', value: '25%', maxUses: '500'), isNull);
    expect(demo.coupons.first.code, 'DIWALI25');
    expect(demo.coupons.first.percentOff, 25);
  });

  test('admin price changes reach the paywall plans', () {
    final monthly = demo.plans.firstWhere((p) => p.id == 'monthly');
    demo.updatePlan(monthly, price: 299);
    expect(demo.visiblePlans.firstWhere((p) => p.id == 'monthly').price, 299);
    demo.updatePlan(monthly, visible: false);
    expect(demo.visiblePlans.any((p) => p.id == 'monthly'), isFalse);
    expect(demo.visiblePlans.any((p) => p.id == 'trial'), isFalse, reason: 'hidden and free');
  });

  test('reset clears learner data', () {
    demo.subscribe(demo.visiblePlans.first);
    demo.toggleDownload('signals', 1);
    demo.reset();
    expect(demo.isPremium, isFalse);
    expect(demo.downloadCount, 0);
    expect(demo.continueWatching!.lesson.title, "Bayes' theorem in practice");
  });

  test('formatting', () {
    expect(Fmt.price(null), '₹[PRICE]');
    expect(Fmt.price(299), '₹299');
    expect(Fmt.price(2499), '₹2,499');
    expect(Fmt.price(1234567), '₹12,34,567');
    expect(Fmt.phone('+919876543210'), '+91 98765 43210');
    expect(Fmt.clock(const Duration(minutes: 14, seconds: 5)), '14:05');
    expect(Fmt.length(const Duration(hours: 6, minutes: 10)), '6h 10m');
    expect(Fmt.countdown(24), '0:24');
    expect(Fmt.initials('Demo Learner'), 'DL');
    expect(Fmt.date(DateTime(2027, 6, 14)), '14 Jun 2027');
  });
}
