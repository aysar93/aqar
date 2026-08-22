import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../screens/publisher_properties_screen.dart';

import '../../models/office_review_model.dart';
import '../../services/office_review_service.dart';

class OfficeReviewsScreen extends StatefulWidget {
  const OfficeReviewsScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
  });

  final String officeId;
  final String ownerUid;

  @override
  State<OfficeReviewsScreen> createState() => _OfficeReviewsScreenState();
}

class _OfficeReviewsScreenState extends State<OfficeReviewsScreen> {
  final OfficeReviewService _service = OfficeReviewService();

  final ValueNotifier<String> _queryNotifier = ValueNotifier<String>('');
  int? _ratingFilter;

  @override
  void dispose() {
    _queryNotifier.dispose();
    super.dispose();
  }

  List<OfficeReviewModel> _filterReviews(
    List<OfficeReviewModel> reviews,
    String queryText,
  ) {
    final query = queryText.trim().toLowerCase();

    return reviews.where((review) {
      final matchesRating =
          _ratingFilter == null || review.rating.round() == _ratingFilter;

      if (!matchesRating) return false;
      if (query.isEmpty) return true;

      final userName = review.userName.toLowerCase();
      final comment = review.comment.toLowerCase();

      return userName.contains(query) || comment.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.ownerUid;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          title: const Text(
            'تقييمات المكتب',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        body: !isOwner
            ? const _ReviewMessage(
                icon: Icons.lock_outline_rounded,
                message: 'ليس لديك صلاحية لإدارة تقييمات هذا المكتب',
              )
            : StreamBuilder<List<OfficeReviewModel>>(
                stream: _service.watchOfficeReviews(
                  widget.officeId,
                  includeHidden: true,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return _ReviewMessage(
                      icon: Icons.error_outline_rounded,
                      message: 'تعذر تحميل التقييمات',
                      action: TextButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    );
                  }

                  final allReviews = snapshot.data ?? const [];

                  return ValueListenableBuilder<String>(
                    valueListenable: _queryNotifier,
                    builder: (context, query, _) {
                      final visibleReviews = _filterReviews(allReviews, query);

                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() {});
                          await Future<void>.delayed(
                            const Duration(milliseconds: 250),
                          );
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  10,
                                ),
                                child: _RatingSummary(reviews: allReviews),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  10,
                                ),
                                child: _ReviewSearchBar(
                                  query: query,
                                  onChanged: (value) {
                                    _queryNotifier.value = value;
                                  },
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _RatingFilters(
                                selectedRating: _ratingFilter,
                                onChanged: (value) {
                                  setState(() {
                                    _ratingFilter = value;
                                  });
                                },
                              ),
                            ),
                            if (visibleReviews.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _ReviewMessage(
                                  icon: allReviews.isEmpty
                                      ? Icons.rate_review_outlined
                                      : Icons.search_off_rounded,
                                  message: allReviews.isEmpty
                                      ? 'لا توجد تقييمات بعد.'
                                      : 'لا توجد تقييمات مطابقة للبحث الحالي',
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  6,
                                  16,
                                  28,
                                ),
                                sliver: SliverList.separated(
                                  itemCount: visibleReviews.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, index) {
                                    return _ReviewTile(
                                      review: visibleReviews[index],
                                      service: _service,
                                      ownerUid: widget.ownerUid,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.reviews});

  final List<OfficeReviewModel> reviews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final average = reviews.isEmpty
        ? 0.0
        : reviews.map((review) => review.rating).reduce((a, b) => a + b) /
            reviews.length;

    final counts = <int, int>{
      5: reviews.where((r) => r.rating.round() == 5).length,
      4: reviews.where((r) => r.rating.round() == 4).length,
      3: reviews.where((r) => r.rating.round() == 3).length,
      2: reviews.where((r) => r.rating.round() == 2).length,
      1: reviews.where((r) => r.rating.round() == 1).length,
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: 36,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'متوسط تقييم المكتب',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          average.toStringAsFixed(1),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'من 5',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${reviews.length} تقييم',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final star in [5, 4, 3, 2, 1])
            _RatingDistributionRow(
              rating: star,
              count: counts[star] ?? 0,
              total: reviews.length,
            ),
        ],
      ),
    );
  }
}

class _RatingDistributionRow extends StatelessWidget {
  const _RatingDistributionRow({
    required this.rating,
    required this.count,
    required this.total,
  });

  final int rating;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rating',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.star_rounded,
            size: 16,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSearchBar extends StatefulWidget {
  const _ReviewSearchBar({
    required this.query,
    required this.onChanged,
  });

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_ReviewSearchBar> createState() => _ReviewSearchBarState();
}

class _ReviewSearchBarState extends State<_ReviewSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      key: const ValueKey('office_reviews_search'),
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, size: 21),
        suffixIcon: widget.query.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح البحث',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  _focusNode.requestFocus();
                },
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
        hintText: 'ابحث باسم المستخدم أو نص التقييم',
        hintStyle: const TextStyle(fontSize: 12.5),
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}

class _RatingFilters extends StatelessWidget {
  const _RatingFilters({
    required this.selectedRating,
    required this.onChanged,
  });

  final int? selectedRating;
  final ValueChanged<int?> onChanged;

  String _label() {
    if (selectedRating == null) return 'كل التقييمات';
    return 'تقييم $selectedRating نجوم';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: PopupMenuButton<String>(
        tooltip: 'فلترة التقييمات',
        onSelected: (value) {
          // String values are used intentionally because PopupMenuButton
          // does not reliably deliver a null value through onSelected.
          onChanged(value == 'all' ? null : int.parse(value));
        },
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: 'all',
            child: _RatingMenuItem(
              label: 'كل التقييمات',
              icon: Icons.all_inclusive_rounded,
            ),
          ),
          for (final rating in [5, 4, 3, 2, 1])
            PopupMenuItem<String>(
              value: '$rating',
              child: _RatingMenuItem(
                label: 'تقييم $rating نجوم',
                icon: Icons.star_rounded,
              ),
            ),
        ],
        child: Container(
          height: 44,
          width: double.infinity,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 10, 0),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _label(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingMenuItem extends StatelessWidget {
  const _RatingMenuItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.service,
    required this.ownerUid,
  });

  final OfficeReviewModel review;
  final OfficeReviewService service;
  final String ownerUid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final userName =
        review.userName.trim().isEmpty ? 'مستخدم عقار' : review.userName.trim();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: review.userId.trim().isEmpty
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(review.userId.trim())
                    .get(),
            builder: (context, userSnapshot) {
              final userData = userSnapshot.data?.data() ?? const {};

              final imageUrl = _firstNonEmpty([
                review.userImageUrl,
                userData['photoUrl'],
                userData['photoURL'],
                userData['imageUrl'],
                userData['profileImageUrl'],
                userData['avatarUrl'],
              ]);

              final email =
                  (userData['email'] ?? userData['emailAddress'] ?? '')
                      .toString()
                      .trim();

              final phone = (userData['phone'] ??
                      userData['phoneNumber'] ??
                      userData['mobile'] ??
                      '')
                  .toString()
                  .trim();

              return InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: review.userId.trim().isEmpty
                    ? null
                    : () => _openUserProperties(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewerAvatar(
                        imageUrl: imageUrl,
                        name: userName,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 5),
                            _Stars(rating: review.rating),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              review.rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                review.comment.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                ),
              ),
            ),
          ],
          if (review.hasOwnerReply) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(15),
                border: BorderDirectional(
                  start: BorderSide(
                    color: scheme.primary,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: 17,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'رد المكتب',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    review.ownerReply,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => _reply(context),
              icon: Icon(
                review.hasOwnerReply
                    ? Icons.edit_outlined
                    : Icons.reply_outlined,
                size: 17,
              ),
              label: Text(
                review.hasOwnerReply ? 'تعديل الرد' : 'الرد على التقييم',
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Future<void> _openUserProperties(BuildContext context) async {
    final userId = review.userId.trim();
    if (userId.isEmpty) return;

    final userName =
        review.userName.trim().isEmpty ? 'مستخدم عقار' : review.userName.trim();

    String imageUrl = review.userImageUrl.trim();

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final data = userDoc.data() ?? const <String, dynamic>{};

      for (final key in [
        'photoUrl',
        'photoURL',
        'imageUrl',
        'profileImageUrl',
        'avatarUrl',
      ]) {
        final value = (data[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          imageUrl = value;
          break;
        }
      }
    } catch (_) {
      // Use the image stored with the review if the profile cannot be read.
    }

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublisherPropertiesScreen(
          publisherUid: userId,
          publisherName: userName,
          publisherPhotoUrl: imageUrl,
        ),
      ),
    );
  }

  Future<void> _reply(BuildContext context) async {
    final reply = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _OfficeReplyDialog(
        initialReply: review.ownerReply,
        isEditing: review.hasOwnerReply,
      ),
    );

    if (reply == null || reply.trim().isEmpty) return;

    try {
      await service.addOwnerReply(
        reviewId: review.id,
        officeId: review.officeId,
        ownerId: ownerUid,
        reply: reply.trim(),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('تعذر حفظ الرد: $e')),
        );
    }
  }
}

class _ReviewerAvatar extends StatelessWidget {
  const _ReviewerAvatar({
    required this.imageUrl,
    required this.name,
  });

  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = name.trim().isEmpty ? 'م' : name.trim().characters.first;

    return SizedBox(
      width: 46,
      height: 46,
      child: ClipOval(
        child: imageUrl.isEmpty
            ? Container(
                color: scheme.primary.withValues(alpha: 0.11),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              )
            : Image.network(
                imageUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Container(
                  color: scheme.primary.withValues(alpha: 0.11),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: scheme.primary.withValues(alpha: 0.06),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _OfficeReplyDialog extends StatefulWidget {
  const _OfficeReplyDialog({
    required this.initialReply,
    required this.isEditing,
  });

  final String initialReply;
  final bool isEditing;

  @override
  State<_OfficeReplyDialog> createState() => _OfficeReplyDialogState();
}

class _OfficeReplyDialogState extends State<_OfficeReplyDialog> {
  late final TextEditingController _controller;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialReply);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close([String? value]) {
    if (_isClosing || !mounted) return;
    setState(() => _isClosing = true);
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                widget.isEditing ? Icons.edit_outlined : Icons.reply_rounded,
                color: scheme.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.isEditing ? 'تعديل رد المكتب' : 'الرد على التقييم',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.sentences,
          enabled: !_isClosing,
          decoration: InputDecoration(
            hintText: 'اكتب ردًا مهذبًا واحترافيًا',
            filled: true,
            fillColor: scheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: _isClosing ? null : () => _close(),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: _isClosing
                ? null
                : () {
                    final value = _controller.text.trim();
                    if (value.isEmpty) return;
                    _close(value);
                  },
            icon: _isClosing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 17),
            label: Text(widget.isEditing ? 'حفظ التعديل' : 'حفظ الرد'),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rounded = rating.round().clamp(0, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rounded ? Icons.star_rounded : Icons.star_border_rounded,
            size: 16,
            color: i <= rounded
                ? scheme.primary
                : scheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
      ],
    );
  }
}

class _ReviewMessage extends StatelessWidget {
  const _ReviewMessage({
    required this.message,
    required this.icon,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
