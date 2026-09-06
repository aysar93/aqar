import 'package:aqar/reels/models/reel_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('published reel is visible inside its schedule window', () {
    final reel = ReelModel(
      id: 'reel-id',
      title: 'ريل تجريبي',
      description: '',
      videoUrl: 'https://cdn.example.com/video.mp4',
      thumbnailUrl: '',
      qualityUrls: const {},
      status: ReelStatus.published,
      targetType: ReelTargetType.general,
      category: 'عام',
      tags: const [],
      externalUrl: '',
      ctaLabel: '',
      isPinned: false,
      isFeatured: false,
      isSponsored: false,
      publishAt: DateTime.now().subtract(const Duration(minutes: 1)),
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      sortOrder: 0,
      views: 0,
      completions: 0,
      likes: 0,
      saves: 0,
      shares: 0,
      propertyClicks: 0,
      externalClicks: 0,
      reports: 0,
      propertySnapshot: const {},
      officeSnapshot: const {},
    );
    expect(reel.isCurrentlyVisible, isTrue);
  });

  test('timestamp remains usable by reel scheduling', () {
    expect(Timestamp.fromDate(DateTime(2026)).toDate().year, 2026);
  });
}
