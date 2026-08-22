import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../screens/publisher_properties_screen.dart';

import '../../models/office_follower_model.dart';
import '../../services/office_follower_service.dart';

class OfficeFollowersScreen extends StatefulWidget {
  const OfficeFollowersScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
  });

  final String officeId;
  final String ownerUid;

  @override
  State<OfficeFollowersScreen> createState() => _OfficeFollowersScreenState();
}

class _OfficeFollowersScreenState extends State<OfficeFollowersScreen> {
  final OfficeFollowerService _service = OfficeFollowerService();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _queryNotifier = ValueNotifier<String>('');

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _queryNotifier.dispose();
    super.dispose();
  }

  void _openFollowerProperties(
    BuildContext context,
    OfficeFollowerModel follower,
  ) {
    final uid = follower.userId.trim();
    if (uid.isEmpty) return;

    final name = follower.userName.trim().isEmpty
        ? 'مستخدم عقار'
        : follower.userName.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublisherPropertiesScreen(
          publisherUid: uid,
          publisherName: name,
          publisherPhotoUrl: follower.userImageUrl.trim(),
          isVerified: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.ownerUid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'متابعو المكتب',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
        ),
        body: !isOwner
            ? const _FollowerMessage(
                icon: Icons.lock_outline_rounded,
                title: 'الوصول غير متاح',
                message: 'ليس لديك صلاحية لعرض المتابعين',
              )
            : StreamBuilder<List<OfficeFollowerModel>>(
                stream: _service.watchOfficeFollowers(widget.officeId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _FollowersLoading();
                  }

                  if (snapshot.hasError) {
                    return _FollowerMessage(
                      icon: Icons.error_outline_rounded,
                      title: 'تعذر تحميل المتابعين',
                      message: 'حدث خطأ أثناء تحميل قائمة متابعي المكتب',
                      onRetry: () => setState(() {}),
                    );
                  }

                  final allFollowers = snapshot.data ?? const [];
                  return ValueListenableBuilder<String>(
                    valueListenable: _queryNotifier,
                    builder: (context, queryValue, _) {
                      final query = queryValue.trim().toLowerCase();

                      final followers = allFollowers.where((item) {
                        if (query.isEmpty) {
                          return true;
                        }

                        return item.userName.toLowerCase().contains(query);
                      }).toList();

                      return Column(
                        children: [
                          _FollowersHeader(
                            totalCount: allFollowers.length,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              14,
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (value) {
                                _queryNotifier.value = value;
                              },
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 21,
                                ),
                                suffixIcon: queryValue.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'مسح البحث',
                                        onPressed: () {
                                          _searchController.clear();
                                          _queryNotifier.value = '';
                                          _searchFocusNode.requestFocus();
                                        },
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 20,
                                        ),
                                      ),
                                hintText: 'ابحث باسم المتابع',
                                helperText: allFollowers.isEmpty
                                    ? 'لا يوجد متابعون حتى الآن'
                                    : 'عرض ${followers.length} من ${allFollowers.length} متابع',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: followers.isEmpty
                                ? _EmptyFollowers(
                                    hasSearch: queryValue.trim().isNotEmpty,
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      28,
                                    ),
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    itemCount: followers.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, index) {
                                      final follower = followers[index];

                                      return _FollowerCard(
                                        follower: follower,
                                        onTap: () => _openFollowerProperties(
                                          context,
                                          follower,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _FollowersHeader extends StatelessWidget {
  const _FollowersHeader({
    required this.totalCount,
  });

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              colorScheme.primary.withValues(alpha: 0.16),
              colorScheme.primary.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.people_alt_rounded,
                size: 23,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'جمهور المكتب',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'متابعو المكتب الحاليون',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$totalCount',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'متابع',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowerCard extends StatelessWidget {
  const _FollowerCard({
    required this.follower,
    required this.onTap,
  });

  final OfficeFollowerModel follower;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = follower.userName.trim().isEmpty
        ? 'مستخدم عقار'
        : follower.userName.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              _FollowerAvatar(
                imageUrl: follower.userImageUrl,
                userId: follower.userId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'متابع للمكتب',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowerAvatar extends StatelessWidget {
  const _FollowerAvatar({
    required this.imageUrl,
    required this.userId,
  });

  final String imageUrl;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initialUrl = imageUrl.trim();

    return FutureBuilder<String>(
      future: _resolveUserImageUrl(
        userId: userId,
        fallbackUrl: initialUrl,
      ),
      builder: (context, snapshot) {
        final resolvedUrl = (snapshot.data ?? initialUrl).trim();

        return Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.30),
            ),
          ),
          child: CircleAvatar(
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: ClipOval(
              child: resolvedUrl.isEmpty
                  ? Icon(
                      Icons.person_outline_rounded,
                      size: 24,
                      color: colorScheme.onSurfaceVariant,
                    )
                  : Image.network(
                      resolvedUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Icon(
                          Icons.person_outline_rounded,
                          size: 24,
                          color: colorScheme.onSurfaceVariant,
                        );
                      },
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

Future<String> _resolveUserImageUrl({
  required String userId,
  required String fallbackUrl,
}) async {
  if (userId.trim().isEmpty) {
    return fallbackUrl.trim();
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId.trim())
        .get();

    final data = doc.data();
    if (data != null) {
      final photoUrl = (data['photoUrl'] ?? '').toString().trim();
      if (photoUrl.isNotEmpty) return photoUrl;

      final photo = (data['photo'] ?? '').toString().trim();
      if (photo.isNotEmpty) return photo;
    }
  } catch (_) {}

  return fallbackUrl.trim();
}

class _EmptyFollowers extends StatelessWidget {
  const _EmptyFollowers({
    required this.hasSearch,
  });

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.people_outline_rounded,
                size: 34,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'لا توجد نتائج' : 'لا يوجد متابعون بعد',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              hasSearch
                  ? 'جرّب البحث باسم مختلف.'
                  : 'سيظهر المتابعون هنا عند بدء المستخدمين بمتابعة المكتب',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowersLoading extends StatelessWidget {
  const _FollowersLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _FollowerSkeleton(),
    );
  }
}

class _FollowerSkeleton extends StatelessWidget {
  const _FollowerSkeleton();

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);

    Widget block({
      double? width,
      required double height,
      double radius = 8,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          block(width: 50, height: 50, radius: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(width: 120, height: 14),
                const SizedBox(height: 9),
                block(width: 95, height: 10),
              ],
            ),
          ),
          block(width: 42, height: 28, radius: 10),
        ],
      ),
    );
  }
}

class _FollowerMessage extends StatelessWidget {
  const _FollowerMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                ),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
