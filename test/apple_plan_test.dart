import 'package:agtiaz/models/payment_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple product mapping is separate and survives serialization', () {
    final plan = PaymentPlan.fromJson({
      '_id': 'gold',
      'name': 'Gold',
      'price': 200,
      'googlePlayProductId': 'android_gold',
      'appleProductId': 'golden_p',
    });
    expect(plan.googlePlayProductId, 'android_gold');
    expect(plan.appleProductId, 'golden_p');
    expect(PaymentPlan.fromJson(plan.toJson()).appleProductId, 'golden_p');
    expect(plan.copyWith(name: 'Updated').appleProductId, 'golden_p');
  });

  test('existing Android plans do not silently become Apple products', () {
    final plan = PaymentPlan.fromJson({
      '_id': 'gold',
      'price': 200,
      'googlePlayProductId': 'golden_p',
    });
    expect(plan.appleProductId, isNull);
    expect(plan.googlePlayProductId, 'golden_p');
  });
}
