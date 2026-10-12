import 'payment_plan.dart';

enum HomePracticeMode { loading, browsePlans, continuePlan, choosePlan }

class HomePracticeState {
  const HomePracticeState._(
    this.mode, {
    this.subscription,
    this.subscriptions = const [],
  });
  final HomePracticeMode mode;
  final Map<String, dynamic>? subscription;
  final List<Map<String, dynamic>> subscriptions;

  factory HomePracticeState.fromSubscriptions({
    required bool loading,
    required List<Map<String, dynamic>> subscriptions,
  }) {
    if (loading) return const HomePracticeState._(HomePracticeMode.loading);
    final usable = List<Map<String, dynamic>>.unmodifiable(
      subscriptions.where((sub) {
        final plan = sub['planObject'];
        return sub['planId'] != null &&
            sub['planId'].toString().isNotEmpty &&
            (plan is! PaymentPlan || plan.isActive);
      }),
    );
    if (usable.isEmpty) {
      return const HomePracticeState._(HomePracticeMode.browsePlans);
    }
    if (usable.length == 1) {
      return HomePracticeState._(
        HomePracticeMode.continuePlan,
        subscription: usable.single,
        subscriptions: usable,
      );
    }
    return HomePracticeState._(
      HomePracticeMode.choosePlan,
      subscriptions: usable,
    );
  }
}
