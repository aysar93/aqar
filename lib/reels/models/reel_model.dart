import 'package:cloud_firestore/cloud_firestore.dart';

enum ReelStatus { draft, scheduled, published, hidden, archived, expired }

enum ReelTargetType { property, office, general }

class ReelModel {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final Map<String, String> qualityUrls;
  final ReelStatus status;
  final ReelTargetType targetType;
  final String? propertyId;
  final String? officeId;
  final String category;
  final List<String> tags;
  final String externalUrl;
  final String ctaLabel;
  final bool isPinned;
  final bool isFeatured;
  final bool isSponsored;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final int sortOrder;
  final int views;
  final int completions;
  final int likes;
  final int saves;
  final int shares;
  final int propertyClicks;
  final int externalClicks;
  final int reports;
  final Map<String, dynamic> propertySnapshot;
  final Map<String, dynamic> officeSnapshot;

  const ReelModel({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.qualityUrls,
    required this.status,
    required this.targetType,
    this.propertyId,
    this.officeId,
    required this.category,
    required this.tags,
    required this.externalUrl,
    required this.ctaLabel,
    required this.isPinned,
    required this.isFeatured,
    required this.isSponsored,
    this.publishAt,
    this.expiresAt,
    required this.sortOrder,
    required this.views,
    required this.completions,
    required this.likes,
    required this.saves,
    required this.shares,
    required this.propertyClicks,
    required this.externalClicks,
    required this.reports,
    required this.propertySnapshot,
    required this.officeSnapshot,
  });

  bool get isCurrentlyVisible {
    final now = DateTime.now();
    return (status == ReelStatus.published || status == ReelStatus.scheduled) &&
        (publishAt == null || !publishAt!.isAfter(now)) &&
        (expiresAt == null || expiresAt!.isAfter(now));
  }

  factory ReelModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    ReelStatus parseStatus() => ReelStatus.values.firstWhere(
          (value) => value.name == data['status'],
          orElse: () => ReelStatus.draft,
        );
    ReelTargetType parseTarget() => ReelTargetType.values.firstWhere(
          (value) => value.name == data['targetType'],
          orElse: () => ReelTargetType.general,
        );
    int number(String key) => (data[key] as num?)?.toInt() ?? 0;
    DateTime? date(String key) => (data[key] as Timestamp?)?.toDate();
    return ReelModel(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      videoUrl: (data['videoUrl'] ?? '').toString(),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString(),
      qualityUrls: Map<String, String>.from(data['qualityUrls'] ?? const {}),
      status: parseStatus(),
      targetType: parseTarget(),
      propertyId: data['propertyId']?.toString(),
      officeId: data['officeId']?.toString(),
      category: (data['category'] ?? 'عام').toString(),
      tags: List<String>.from(data['tags'] ?? const []),
      externalUrl: (data['externalUrl'] ?? '').toString(),
      ctaLabel: (data['ctaLabel'] ?? 'معرفة المزيد').toString(),
      isPinned: data['isPinned'] == true,
      isFeatured: data['isFeatured'] == true,
      isSponsored: data['isSponsored'] == true,
      publishAt: date('publishAt'),
      expiresAt: date('expiresAt'),
      sortOrder: number('sortOrder'),
      views: number('views'),
      completions: number('completions'),
      likes: number('likes'),
      saves: number('saves'),
      shares: number('shares'),
      propertyClicks: number('propertyClicks'),
      externalClicks: number('externalClicks'),
      reports: number('reports'),
      propertySnapshot:
          Map<String, dynamic>.from(data['propertySnapshot'] ?? const {}),
      officeSnapshot:
          Map<String, dynamic>.from(data['officeSnapshot'] ?? const {}),
    );
  }

  factory ReelModel.fromBanner(Map<String, dynamic> data, String id) {
    final type = data['type']?.toString() ?? 'general';
    final targetId = data['targetId']?.toString();
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'إعلان ممول';
    final subtitle = data['subtitle']?.toString() ?? '';

    // Support both 'external' (admin dashboard) and legacy 'url'
    final isProperty = type == 'property';
    final isOffice = type == 'office';
    final isExternal = type == 'external' || type == 'url';

    // Strict URL validation: must be http/https with valid host
    String validExternalUrl = '';
    if (isExternal && targetId != null && targetId.trim().isNotEmpty) {
      final trimmed = targetId.trim();
      final uri = Uri.tryParse(trimmed);
      if (uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        validExternalUrl = trimmed;
      }
    }

    final ctaLabel = isProperty
        ? 'عرض العقار'
        : (isOffice
            ? 'زيارة المكتب'
            : (validExternalUrl.isNotEmpty ? 'معرفة المزيد' : ''));

    return ReelModel(
      id: 'banner_$id',
      title: title,
      description: subtitle,
      videoUrl: imageUrl,
      thumbnailUrl: imageUrl,
      qualityUrls: {'auto': imageUrl},
      status: ReelStatus.published,
      targetType: isProperty
          ? ReelTargetType.property
          : (isOffice ? ReelTargetType.office : ReelTargetType.general),
      propertyId: isProperty ? targetId : null,
      officeId: isOffice ? targetId : null,
      category: 'إعلان',
      tags: const ['إعلان', 'ممول'],
      externalUrl: validExternalUrl,
      ctaLabel: ctaLabel,
      isPinned: false,
      isFeatured: false,
      isSponsored: true,
      publishAt: null,
      expiresAt: null,
      sortOrder: (data['order'] as num?)?.toInt() ?? 0,
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
  }
}
