import 'package:aqar/office/models/office_subscription_model.dart';
import 'package:aqar/office/services/office_subscription_gift_service.dart';
import 'package:aqar/subscription/models/subscription_package_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 4, 12);
  SubscriptionPackageModel package({bool active = true, int days = 30}) =>
      SubscriptionPackageModel(
        id: 'gold',
        name: 'Gold',
        description: '',
        price: 50000,
        currency: 'IQD',
        durationDays: days,
        isActive: active,
        isFeatured: false,
        sortOrder: 1,
        maxProperties: 50,
        maxFeaturedProperties: 10,
        maxImagesPerProperty: 8,
        features: const [],
        statisticsEnabled: true,
        officeProfileEnabled: true,
        featuredPropertiesEnabled: true,
        featuredOfficeEnabled: true,
        verifiedBadgeEnabled: false,
        createdAt: null,
        updatedAt: null,
      );
  OfficeSubscriptionModel current(
          {String id = 'gold', String status = 'active', DateTime? end}) =>
      OfficeSubscriptionModel(
          id: 'old',
          officeId: 'office',
          ownerId: 'owner',
          packageId: id,
          packageName: id,
          durationDays: 30,
          status: status,
          startDate: now.subtract(const Duration(days: 20)),
          endDate: end ?? now.add(const Duration(days: 10)));
  OfficeSubscriptionModel gift(
          {OfficeSubscriptionModel? previous,
          SubscriptionPackageModel? selected}) =>
      buildGiftSubscription(
          id: 'new',
          officeId: 'office',
          ownerId: 'owner',
          package: selected ?? package(),
          now: now,
          current: previous);

  test('gift activates the selected package at zero cost with its entitlements',
      () {
    final result = gift();
    expect(result.status, 'active');
    expect(result.price, 0);
    expect(result.paymentMethod, 'gift');
    expect(result.paymentStatus, 'paid');
    expect(result.startDate, now);
    expect(result.endDate, now.add(const Duration(days: 30)));
    expect(result.maxProperties, 50);
    expect(result.maxFeaturedProperties, 10);
    expect(result.canFeatureProperties, isTrue);
    expect(result.canAppearInFeaturedOffices, isTrue);
    expect(result.canUseAdvancedStatistics, isTrue);
    expect(result.featuredPropertiesUsed, 0);
    expect(result.ownerId, 'owner');
  });
  test('same active package preserves remaining time', () {
    final result = gift(previous: current());
    expect(result.endDate, now.add(const Duration(days: 40)));
    expect(result.previousSubscriptionId, 'old');
  });
  test('a different package begins now', () {
    expect(gift(previous: current(id: 'silver')).endDate,
        now.add(const Duration(days: 30)));
  });
  test('expired package receives a full fresh duration', () {
    expect(
        gift(previous: current(end: now.subtract(const Duration(days: 3))))
            .endDate,
        now.add(const Duration(days: 30)));
  });
  test('suspended package is replaced without inheriting suspended time', () {
    expect(gift(previous: current(status: 'suspended')).endDate,
        now.add(const Duration(days: 30)));
  });
  test('disabled and invalid packages cannot be gifted', () {
    expect(() => gift(selected: package(active: false)), throwsStateError);
    expect(() => gift(selected: package(days: 0)), throwsStateError);
  });
}
