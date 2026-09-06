import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../models/office_model.dart';
import '../models/office_review_model.dart';
import '../services/office_follower_service.dart';
import '../services/office_review_service.dart';
import '../services/office_service.dart';
import '../services/office_statistics_service.dart';
import '../../models/property_model.dart';
import '../../screens/all_properties_screen.dart';
import '../../screens/property_details.dart';
import '../screens/edit/edit_office_screen.dart';
import '../../utils/property_default_images.dart';
import '../widgets/office_gallery.dart';

Future<void> _open(BuildContext context, Uri uri) async {
  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح الرابط'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح الرابط'),
        ),
      );
    }
  }
}

class OfficeProfileScreen extends StatefulWidget {
  final String officeId;

  const OfficeProfileScreen({
    super.key,
    required this.officeId,
  });

  static const gold = Color(0xFFD4AF37);
  static const background = Color(0xFF0F172A);
  static const card = Color(0xFF111C2B);
  static const field = Color(0xFF162334);

  @override
  State<OfficeProfileScreen> createState() => _OfficeProfileScreenState();
}

class _OfficeProfileScreenState extends State<OfficeProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<String> _tabs = const [
    'نظرة عامة',
    'العقارات',
    'الخدمات',
    'التقييمات',
    'عن المكتب',
  ];

  @override
  void initState() {
    super.initState();
    _recordOfficeView(widget.officeId);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: OfficeProfileScreen.background,
        body: StreamBuilder<OfficeModel?>(
          stream: OfficeService.officeStream(widget.officeId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: OfficeProfileScreen.gold,
                ),
              );
            }

            if (snapshot.hasError) {
              return _ErrorView(
                message: 'تعذر تحميل بيانات المكتب',
                onRetry: () => Navigator.pop(context),
              );
            }

            final office = snapshot.data;

            if (office == null) {
              return const _ErrorView(
                message: 'المكتب غير موجود',
              );
            }

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildHeroAppBar(context, office),
                  SliverToBoxAdapter(
                    child: _buildHeaderInfo(context, office),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      child: _buildTabBar(),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(
                    office: office,
                    officeId: widget.officeId,
                  ),
                  _PropertiesTab(
                    officeId: widget.officeId,
                  ),
                  _ServicesTab(
                    office: office,
                  ),
                  _ReviewsTab(
                    office: office,
                    officeId: widget.officeId,
                  ),
                  _AboutTab(
                    office: office,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context, OfficeModel office) {
    return Container(
      color: OfficeProfileScreen.background,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: StreamBuilder<List<OfficeReviewModel>>(
        stream: OfficeReviewService().watchOfficeReviews(office.id),
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? const <OfficeReviewModel>[];
          final published =
              reviews.where((review) => review.isPublished).toList();
          final liveRating = published.isEmpty
              ? office.rating
              : published
                      .map((review) => review.rating)
                      .reduce((a, b) => a + b) /
                  published.length;
          final liveReviews =
              published.isEmpty ? office.reviewsCount : published.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IdentityBlock(
                office: office,
                ratingOverride: liveRating,
                reviewsCountOverride: liveReviews,
              ),
              const SizedBox(height: 10),
              _ContactActions(office: office),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildHeroAppBar(
    BuildContext context,
    OfficeModel office,
  ) {
    return SliverAppBar(
      expandedHeight: 330,
      pinned: true,
      backgroundColor: OfficeProfileScreen.background,
      foregroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 52,
      leading: IconButton(
        tooltip: 'رجوع',
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      actions: [
        _CircleButton(
          icon: Icons.share_rounded,
          onTap: () => _shareOffice(context, office),
        ),
        const SizedBox(width: 4),
        _CircleButton(
          icon: Icons.more_vert_rounded,
          onTap: () => _showOfficeMenu(context, office),
        ),
        const SizedBox(width: 7),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsetsDirectional.only(
          start: 58,
          end: 58,
          bottom: 14,
        ),
        background: _HeroCover(office: office),
      ),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(46),
      child: Material(
        color: OfficeProfileScreen.background,
        child: TabBar(
          controller: _tabController,
          isScrollable: false,
          padding: EdgeInsets.zero,
          labelPadding: EdgeInsets.zero,
          tabAlignment: TabAlignment.fill,
          dividerColor: Colors.transparent,
          indicator: const BoxDecoration(),
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          labelColor: OfficeProfileScreen.gold,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 10,
          ),
          tabs: _tabs.map((title) => Tab(text: title)).toList(),
        ),
      ),
    );
  }

  void _showOfficeMenu(
    BuildContext context,
    OfficeModel office,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == office.ownerId;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OfficeProfileScreen.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              if (isOwner)
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: OfficeProfileScreen.gold,
                  ),
                  title: const Text(
                    'تعديل المكتب',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditOfficeScreen(
                          officeId: office.id,
                          ownerUid: office.ownerId,
                        ),
                      ),
                    );
                  },
                ),
              if (!isOwner)
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: OfficeProfileScreen.gold,
                  ),
                  title: const Text(
                    'الإبلاغ عن المكتب',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب تسجيل الدخول للإبلاغ عن مكتب.'),
                        ),
                      );
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance
                          .collection('office_reports')
                          .add({
                        'officeId': office.id,
                        'officeOwnerId': office.ownerId,
                        'userId': currentUser.uid,
                        'createdAt': FieldValue.serverTimestamp(),
                        'status': 'pending',
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم الإبلاغ عن المكتب بنجاح.'),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تعذر إرسال البلاغ حاليًا.'),
                          ),
                        );
                      }
                    }
                  },
                ),
              if (office.email.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: OfficeProfileScreen.gold,
                  ),
                  title: const Text(
                    'إرسال بريد إلكتروني',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openExternal(
                      context,
                      Uri.parse('mailto:${office.email.trim()}'),
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _recordOfficeView(String officeId) async {
    try {
      await OfficeStatisticsService().recordView(
        officeId: officeId,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
    } catch (e) {
      debugPrint('Error recording office view: $e');
    }
  }

  Future<void> _shareOffice(
    BuildContext context,
    OfficeModel office,
  ) async {
    final name = office.name.trim().isEmpty ? 'مكتب عقاري' : office.name.trim();

    final location = _locationText(office);

    final text = [
      'مكتب $name',
      if (location.isNotEmpty) 'الموقع: $location',
      'يمكنك مشاهدة صفحة المكتب داخل تطبيق عقارات الانبار',
    ].join('\n');

    try {
      await Share.share(
        text,
        subject: name,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح نافذة المشاركة.'),
          ),
        );
      }
    }
  }

  static Future<void> _openExternal(
    BuildContext context,
    Uri uri,
  ) async {
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح الرابط'),
        ),
      );
    }
  }
}

class _HeroCover extends StatelessWidget {
  final OfficeModel office;

  const _HeroCover({
    required this.office,
  });

  @override
  Widget build(BuildContext context) {
    final cover = office.coverImageUrl.trim();
    final logo = office.logoUrl.trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover.isNotEmpty)
          CachedNetworkImage(
            imageUrl: cover,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorWidget: (_, __, ___) => _placeholder(),
          )
        else
          _placeholder(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .08),
                Colors.black.withValues(alpha: .20),
                OfficeProfileScreen.background.withValues(alpha: .96),
              ],
              stops: const [0, .45, 1],
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HeroLogo(
                url: logo,
              ),
              if (office.isVerified) ...[
                const SizedBox(width: 8),
                _VerifiedBadge(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF263548),
      alignment: Alignment.center,
      child: const Icon(
        Icons.business_rounded,
        color: OfficeProfileScreen.gold,
        size: 76,
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: OfficeProfileScreen.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: OfficeProfileScreen.gold.withValues(alpha: .35),
                  width: 1,
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: OfficeProfileScreen.gold,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'مكتب موثّق',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              content: RichText(
                textAlign: TextAlign.right,
                text: const TextSpan(
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.8,
                  ),
                  children: [
                    TextSpan(
                      text: 'تم التحقق من بيانات المكتب واعتماد ملفه من قبل ',
                    ),
                    TextSpan(
                      text: 'منصة عقارات الانبار',
                      style: TextStyle(
                        color: OfficeProfileScreen.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: '',
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'حسنًا',
                    style: TextStyle(
                      color: OfficeProfileScreen.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 45),
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: OfficeProfileScreen.gold,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_rounded,
              color: Colors.black,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'موثق',
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroLogo extends StatelessWidget {
  final String url;

  const _HeroLogo({
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF101A28),
        border: Border.all(
          color: OfficeProfileScreen.gold,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(
              Icons.business_rounded,
              color: OfficeProfileScreen.gold,
              size: 40,
            )
          : Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.business_rounded,
                    color: OfficeProfileScreen.gold,
                    size: 40,
                  ),
                ),
              ),
            ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final OfficeModel office;
  final String officeId;

  const _OverviewTab({
    required this.office,
    required this.officeId,
  });

  @override
  Widget build(BuildContext context) {
    final location = _locationText(office);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      children: [
        const SizedBox(height: 4),
        _Card(
          title: 'نبذة عن المكتب',
          icon: Icons.business_outlined,
          child: _DescriptionPreview(
            description: office.description,
          ),
        ),
        const SizedBox(height: 14),
        _CompactInfoCard(
          office: office,
          location: location,
        ),
        const SizedBox(height: 14),
        _StatisticsCard(
          office: office,
          officeId: officeId,
        ),
        const SizedBox(height: 14),
        _LatestProperties(
          officeId: officeId,
          showHeader: true,
        ),
      ],
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  final OfficeModel office;
  final double? ratingOverride;
  final int? reviewsCountOverride;

  const _IdentityBlock({
    required this.office,
    this.ratingOverride,
    this.reviewsCountOverride,
  });

  @override
  Widget build(BuildContext context) {
    final location = _locationText(office);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  office.name.trim().isEmpty
                      ? 'مكتب عقاري'
                      : office.name.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FollowButton(office: office),
            ],
          ),
          const SizedBox(height: 9),
          _RatingSummary(
            rating: ratingOverride ?? office.rating,
            reviewsCount: reviewsCountOverride ?? office.reviewsCount,
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 15,
            runSpacing: 8,
            children: [
              if (office.licenseNumber.trim().isNotEmpty)
                _InlineInfo(
                  icon: Icons.verified_user_outlined,
                  text: 'رقم الترخيص: ${office.licenseNumber.trim()}',
                ),
              if (office.establishedYear != null)
                _InlineInfo(
                  icon: Icons.calendar_month_outlined,
                  text: 'تأسس عام ${office.establishedYear}',
                ),
              if (location.isNotEmpty)
                _InlineInfo(
                  icon: Icons.location_on_outlined,
                  text: location,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final double rating;
  final int reviewsCount;

  const _RatingSummary({
    required this.rating,
    required this.reviewsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color: OfficeProfileScreen.gold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 7),
        ...List.generate(
          5,
          (index) => Icon(
            index < rating.round()
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            color: OfficeProfileScreen.gold,
            size: 20,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '($reviewsCount تقييم)',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .62),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: OfficeProfileScreen.gold,
          size: 18,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .72),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ContactActions extends StatefulWidget {
  final OfficeModel office;

  const _ContactActions({required this.office});

  @override
  State<_ContactActions> createState() => _ContactActionsState();
}

class _ContactActionsState extends State<_ContactActions> {
  bool _showSocial = false;

  final OfficeStatisticsService _statisticsService = OfficeStatisticsService();

  @override
  Widget build(BuildContext context) {
    final office = widget.office;
    final actions = <Widget>[];

    if (office.phone.trim().isNotEmpty) {
      actions.add(
        _SmallActionButton(
          icon: Icons.phone_in_talk_rounded,
          label: 'اتصال',
          iconColor: const Color(0xFF64B5F6),
          onTap: () async {
            await _statisticsService.recordPhoneClick(
              officeId: office.id,
              userId: FirebaseAuth.instance.currentUser?.uid,
            );
            await _open(
              context,
              Uri.parse('tel:${office.phone.trim()}'),
            );
          },
        ),
      );
    }

    if (office.whatsapp.trim().isNotEmpty) {
      final number = office.whatsapp.replaceAll(RegExp(r'[^0-9+]'), '');
      actions.add(
        _SmallActionButton(
          icon: Icons.chat_rounded,
          label: 'واتساب',
          iconColor: const Color(0xFF25D366),
          onTap: () async {
            await _statisticsService.recordWhatsappClick(
              officeId: office.id,
              userId: FirebaseAuth.instance.currentUser?.uid,
            );
            await _open(
              context,
              Uri.parse('https://wa.me/${number.replaceFirst('+', '')}'),
            );
          },
        ),
      );
    }

    actions.add(
      _SmallActionButton(
        icon: Icons.location_on_rounded,
        label: 'الموقع',
        iconColor: OfficeProfileScreen.gold,
        onTap: () async {
          final lat = office.latitude;
          final lng = office.longitude;
          if (lat == 0 || lng == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('لم يتم تحديد موقع المكتب على الخريطة.')),
            );
            return;
          }

          await _statisticsService.recordLocationClick(
            officeId: office.id,
            userId: FirebaseAuth.instance.currentUser?.uid,
          );

          await _open(
            context,
            Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
            ),
          );
        },
      ),
    );

    actions.add(
      _SmallActionButton(
        icon: _showSocial ? Icons.close_rounded : Icons.share_outlined,
        label: 'التواصل',
        iconColor: OfficeProfileScreen.gold,
        filled: _showSocial,
        onTap: () async {
          await _statisticsService.recordContactClick(
            officeId: office.id,
            userId: FirebaseAuth.instance.currentUser?.uid,
          );

          if (mounted) {
            setState(() => _showSocial = !_showSocial);
          }
        },
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(child: actions[i]),
            ],
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _showSocial
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _SocialLinksCard(office: office),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  final OfficeModel office;

  const _FollowButton({
    required this.office,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.uid == office.ownerId) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: OfficeFollowerService().watchFollowingStatus(
        officeId: office.id,
        userId: user.uid,
      ),
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;

        return _SmallActionButton(
          icon: following
              ? Icons.person_remove_alt_1_rounded
              : Icons.person_add_alt_1_rounded,
          label: following ? 'الغاء المتابعة' : 'متابعة',
          filled: following,
          iconColor: OfficeProfileScreen.gold,
          onTap: () async {
            try {
              final userName = (user.displayName ?? '').trim().isNotEmpty
                  ? user.displayName!.trim()
                  : 'مستخدم عقار';

              await OfficeFollowerService().toggleFollow(
                officeId: office.id,
                userId: user.uid,
                userName: userName,
                userImageUrl: user.photoURL ?? '',
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تعذر تحديث المتابعة',
                    ),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}

class _SocialLinksCard extends StatelessWidget {
  final OfficeModel office;

  const _SocialLinksCard({required this.office});

  @override
  Widget build(BuildContext context) {
    final links = <_SocialLink>[
      _SocialLink('Facebook', office.facebook, Icons.facebook_rounded),
      _SocialLink('Instagram', office.instagram, Icons.camera_alt_outlined),
      _SocialLink('Telegram', office.telegram, Icons.send_rounded),
      _SocialLink('TikTok', office.tiktok, Icons.music_note_rounded),
      _SocialLink('YouTube', office.youtube, Icons.play_circle_outline_rounded),
      _SocialLink('الموقع', office.website, Icons.language_rounded),
    ].where((link) => link.url.trim().isNotEmpty).toList();

    if (links.isEmpty) return const SizedBox.shrink();

    return _Card(
      title: 'التواصل الاجتماعي',
      icon: Icons.share_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: links.map((link) {
          return OutlinedButton.icon(
            onPressed: () => _open(context, _normalizeUrl(link.url)),
            icon: Icon(
              link.icon,
              size: 17,
              color: OfficeProfileScreen.gold,
            ),
            label: Text(
              link.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              side: BorderSide(
                color: OfficeProfileScreen.gold.withValues(alpha: .22),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Uri _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    return Uri.parse('https://$trimmed');
  }
}

class _SocialLink {
  final String label;
  final String url;
  final IconData icon;

  const _SocialLink(this.label, this.url, this.icon);
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? iconColor;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          backgroundColor:
              filled ? OfficeProfileScreen.gold : OfficeProfileScreen.field,
          side: BorderSide(
            color: OfficeProfileScreen.gold.withValues(alpha: .20),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: filled
                    ? Colors.black
                    : (iconColor ?? OfficeProfileScreen.gold),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: filled ? Colors.black : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DescriptionPreview extends StatelessWidget {
  final String description;

  const _DescriptionPreview({
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final text = description.trim().isEmpty
        ? 'لا توجد نبذة مضافة عن المكتب حاليًا.'
        : description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: 4,
          overflow: TextOverflow.fade,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .72),
            fontSize: 13,
            height: 1.75,
          ),
        ),
        if (description.trim().isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => _showFullDescription(
                context,
                description,
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 4,
                ),
              ),
              child: const Text(
                'عرض المزيد',
                style: TextStyle(
                  color: OfficeProfileScreen.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFullDescription(
    BuildContext context,
    String text,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OfficeProfileScreen.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .62,
          minChildSize: .35,
          maxChildSize: .9,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                20,
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Row(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        color: OfficeProfileScreen.gold,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'عن المكتب',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      child: Text(
                        text,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          fontSize: 14,
                          height: 1.9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CompactInfoCard extends StatelessWidget {
  final OfficeModel office;
  final String location;

  const _CompactInfoCard({
    required this.office,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'معلومات المكتب',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          if (office.establishedYear != null ||
              office.licenseNumber.trim().isNotEmpty)
            Row(
              children: [
                if (office.establishedYear != null)
                  Expanded(
                    child: _DetailTile(
                      icon: Icons.calendar_month_outlined,
                      label: 'سنة التأسيس',
                      value: '${office.establishedYear}',
                    ),
                  ),
                if (office.establishedYear != null &&
                    office.licenseNumber.trim().isNotEmpty)
                  _VerticalDivider(),
                if (office.licenseNumber.trim().isNotEmpty)
                  Expanded(
                    child: _DetailTile(
                      icon: Icons.verified_user_outlined,
                      label: 'رقم الترخيص',
                      value: office.licenseNumber.trim(),
                    ),
                  ),
              ],
            ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailTile(
              icon: Icons.location_on_outlined,
              label: 'العنوان',
              value: office.address.trim().isNotEmpty
                  ? '${location} - ${office.address.trim()}'
                  : location,
              fullWidth: true,
            ),
          ],
          if (office.workingHours.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 7),
            _WorkingHoursPreview(
              hours: office.workingHours,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: OfficeProfileScreen.gold,
          size: 21,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .50),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: fullWidth ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkingHoursPreview extends StatelessWidget {
  final Map<String, String> hours;

  const _WorkingHoursPreview({
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    const order = <String>[
      'saturday',
      'الأحد',
      'sunday',
      'الاثنين',
      'الإثنين',
      'monday',
      'الثلاثاء',
      'tuesday',
      'الأربعاء',
      'wednesday',
      'الخميس',
      'thursday',
      'الجمعة',
      'friday',
      'السبت',
    ];

    int dayIndex(String key) {
      final normalized = key.trim().toLowerCase();
      if (normalized == 'السبت' || normalized == 'saturday') return 0;
      if (normalized == 'الأحد' ||
          normalized == 'الاحد' ||
          normalized == 'sunday') return 1;
      if (normalized == 'الإثنين' ||
          normalized == 'الاثنين' ||
          normalized == 'monday') return 2;
      if (normalized == 'الثلاثاء' || normalized == 'tuesday') return 3;
      if (normalized == 'الأربعاء' ||
          normalized == 'الاربعاء' ||
          normalized == 'wednesday') return 4;
      if (normalized == 'الخميس' || normalized == 'thursday') return 5;
      if (normalized == 'الجمعة' || normalized == 'friday') return 6;
      return 99;
    }

    final entries = hours.entries.toList()
      ..sort((a, b) => dayIndex(a.key).compareTo(dayIndex(b.key)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              color: OfficeProfileScreen.gold,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'أوقات العمل',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...entries.map(
          (entry) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: OfficeProfileScreen.field.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dayName(entry.key),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .70),
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  entry.value.trim().isEmpty ? 'مغلق' : entry.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _dayName(String key) {
    switch (key.trim().toLowerCase()) {
      case 'saturday':
      case 'السبت':
        return 'السبت';
      case 'sunday':
      case 'الأحد':
      case 'الاحد':
        return 'الأحد';
      case 'monday':
      case 'الاثنين':
      case 'الإثنين':
        return 'الإثنين';
      case 'tuesday':
      case 'الثلاثاء':
        return 'الثلاثاء';
      case 'wednesday':
      case 'الأربعاء':
        return 'الأربعاء';
      case 'thursday':
      case 'الخميس':
        return 'الخميس';
      case 'friday':
      case 'الجمعة':
        return 'الجمعة';
      default:
        return key;
    }
  }
}

class _StatisticsCard extends StatelessWidget {
  final OfficeModel office;
  final String officeId;

  const _StatisticsCard({
    required this.office,
    required this.officeId,
  });

  @override
  Widget build(BuildContext context) {
    // العقارات
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .where('officeId', isEqualTo: officeId)
          .snapshots(),
      builder: (context, propertySnapshot) {
        final propertyDocs = propertySnapshot.data?.docs ?? const [];

        final activeProperties = propertyDocs.where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().toLowerCase();

          return status == 'approved' || status == 'active';
        }).length;

        // إذا لم نستطع قراءة العقارات أو لم توجد نتائج،
        // لا نصفر الرقم المخزن في المكتب.
        final propertyCount =
            activeProperties > 0 ? activeProperties : office.propertiesCount;

        // التقييمات
        return StreamBuilder<List<OfficeReviewModel>>(
          stream: OfficeReviewService().watchOfficeReviews(officeId),
          builder: (context, reviewSnapshot) {
            final reviews = reviewSnapshot.data ?? const <OfficeReviewModel>[];

            final published = reviews.where((r) => r.isPublished).toList();

            final rating = published.isNotEmpty
                ? published.map((r) => r.rating).reduce((a, b) => a + b) /
                    published.length
                : office.rating;

            final reviewCount =
                published.isNotEmpty ? published.length : office.reviewsCount;

            // المتابعون
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('office_followers')
                  .where('officeId', isEqualTo: officeId)
                  .snapshots(),
              builder: (context, followerSnapshot) {
                final followerDocs = followerSnapshot.data?.docs ?? const [];

                final activeFollowers = followerDocs.where((doc) {
                  final data = doc.data();

                  // إذا كان isActive غير موجود نعتبر المتابعة فعالة
                  // حتى لا يتم تصفير العدد بسبب مستندات قديمة.
                  return data['isActive'] == null || data['isActive'] == true;
                }).length;

                final followersCount = activeFollowers > 0
                    ? activeFollowers
                    : office.followersCount;

                // المشاهدات
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('office_events')
                      .where('officeId', isEqualTo: officeId)
                      .snapshots(),
                  builder: (context, viewsSnapshot) {
                    final viewDocs = viewsSnapshot.data?.docs ?? const [];

                    // نرشح type=view داخل Dart لتجنب الحاجة إلى
                    // Composite Index في Firestore.
                    final viewsCount = viewDocs.where((doc) {
                      final data = doc.data();
                      return (data['type'] ?? '').toString() == 'view';
                    }).length;

                    final totalViews =
                        viewsCount > 0 ? viewsCount : office.viewsCount;

                    return _Card(
                      title: 'إحصائيات المكتب',
                      icon: Icons.bar_chart_rounded,
                      child: Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              icon: Icons.star_rounded,
                              value: rating.toStringAsFixed(1),
                              label: 'التقييم',
                            ),
                          ),
                          _MetricDivider(),
                          Expanded(
                            child: _Metric(
                              icon: Icons.star_outline_rounded,
                              value: '$reviewCount',
                              label: 'تقييم',
                            ),
                          ),
                          _MetricDivider(),
                          Expanded(
                            child: _Metric(
                              icon: Icons.home_work_outlined,
                              value: '$propertyCount',
                              label: 'عقار',
                            ),
                          ),
                          _MetricDivider(),
                          Expanded(
                            child: _Metric(
                              icon: Icons.people_outline_rounded,
                              value: '$followersCount',
                              label: 'متابع',
                            ),
                          ),
                          _MetricDivider(),
                          Expanded(
                            child: _Metric(
                              icon: Icons.visibility_outlined,
                              value: '$totalViews',
                              label: 'مشاهدة',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: OfficeProfileScreen.gold,
          size: 21,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: OfficeProfileScreen.gold,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .62),
            fontSize: 8.5,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      width: 1,
      color: Colors.white.withValues(alpha: .08),
    );
  }
}

class _ServicesTab extends StatelessWidget {
  final OfficeModel office;

  const _ServicesTab({
    required this.office,
  });

  @override
  Widget build(BuildContext context) {
    final services = office.services;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        _Card(
          title: 'خدمات المكتب',
          icon: Icons.grid_view_rounded,
          child: services.isEmpty
              ? const _EmptyMessage(
                  text: 'لم تتم إضافة خدمات المكتب بعد',
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: services
                      .map(
                        (service) => _ServiceTile(
                          title: service,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String title;

  const _ServiceTile({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 88,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: OfficeProfileScreen.field,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: OfficeProfileScreen.gold.withValues(alpha: .28),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.home_work_outlined,
            color: OfficeProfileScreen.gold,
            size: 25,
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertiesTab extends StatelessWidget {
  final String officeId;

  const _PropertiesTab({
    required this.officeId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        _LatestProperties(
          officeId: officeId,
          showHeader: true,
          showAllButton: true,
        ),
      ],
    );
  }
}

class _LatestProperties extends StatefulWidget {
  final String officeId;
  final bool showHeader;
  final bool showAllButton;

  const _LatestProperties({
    required this.officeId,
    this.showHeader = true,
    this.showAllButton = false,
  });

  @override
  State<_LatestProperties> createState() => _LatestPropertiesState();
}

class _LatestPropertiesState extends State<_LatestProperties> {
  final PageController _controller = PageController(
    viewportFraction: .84,
  );

  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .where('officeId', isEqualTo: widget.officeId)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Card(
            title: 'أحدث العقارات',
            icon: Icons.home_work_outlined,
            child: const _EmptyMessage(
              text: 'تعذر تحميل عقارات المكتب',
            ),
          );
        }

        if (!snapshot.hasData) {
          return _Card(
            title: 'أحدث العقارات',
            icon: Icons.home_work_outlined,
            child: const SizedBox(
              height: 170,
              child: Center(
                child: CircularProgressIndicator(
                  color: OfficeProfileScreen.gold,
                ),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final status = (doc.data()['status'] ?? '').toString();
          return status.isEmpty || status == 'approved';
        }).toList();

        docs.sort((a, b) {
          final aDate = _dateOf(a.data()['createdAt']);
          final bDate = _dateOf(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        final latest = docs.take(8).toList();

        return _Card(
          title: 'أحدث العقارات',
          icon: Icons.home_work_outlined,
          trailing: widget.showAllButton || latest.isNotEmpty
              ? TextButton(
                  onPressed: () => _openAll(context),
                  child: const Text(
                    'عرض الكل',
                    style: TextStyle(
                      color: OfficeProfileScreen.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          child: latest.isEmpty
              ? const SizedBox(
                  height: 100,
                  child: _EmptyMessage(
                    text: 'لا توجد عقارات منشورة لهذا المكتب حاليًا',
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 245,
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: PageView.builder(
                          controller: _controller,
                          reverse: false,
                          itemCount: latest.length,
                          onPageChanged: (index) {
                            if (mounted) {
                              setState(() => _page = index);
                            }
                          },
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 4,
                                end: 4,
                              ),
                              child: _PropertyCard(
                                data: latest[index].data(),
                                onTap: () => _openProperty(
                                  context,
                                  latest[index],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (latest.length > 1) ...[
                      const SizedBox(height: 10),
                      _PageIndicator(
                        count: latest.length,
                        activeIndex: _page,
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (!widget.showAllButton)
                      OutlinedButton.icon(
                        onPressed: () => _openAll(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: OfficeProfileScreen.gold,
                        ),
                        label: const Text(
                          'استعراض جميع عقارات المكتب',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          side: BorderSide(
                            color:
                                OfficeProfileScreen.gold.withValues(alpha: .25),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _openProperty(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    try {
      final data = document.data();
      final property = PropertyModel.fromMap(
        data,
        document.id,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PropertyDetails(
            property: property,
            imageUrl: property.imageUrl,
            title: property.title,
            location: property.location,
            price: property.price.toString(),
            rooms: property.rooms,
            bathrooms: property.bathrooms,
            area: property.area,
            livingRooms: property.livingRooms,
            parking: property.parking,
            description: property.description,
            ownerPhone: property.ownerPhone,
            ownerWhatsapp: property.ownerWhatsapp,
            publisherUid: property.publisherUid,
            publisherName: property.publisherName,
            publisherEmail: property.publisherEmail,
            publisherPhone: property.publisherPhone,
            publisherWhatsapp: property.publisherWhatsapp,
            images: property.images,
            features: property.features,
            documentType: property.documentType,
            furnitureStatus: property.furnitureStatus,
            propertyType: property.propertyType,
            adType: property.adType,
            city: property.city,
            areaName: property.areaName,
            landmark: property.landmark,
            latitude: property.latitude,
            longitude: property.longitude,
            isVerified: property.isVerified,
            isFeatured: property.isFeatured,
            availabilityStatus: property.availabilityStatus,
            views: property.views,
            createdAt: property.createdAt,
            buildYear: property.buildYear,
            propertyNumber: property.propertyNumber,
            docId: property.id,
            isFavorite: property.isFavorite,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح العقار: $e'),
          ),
        );
      }
    }
  }

  void _openAll(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllPropertiesScreen(
          mode: 'all',
          officeId: widget.officeId,
        ),
      ),
    );
  }

  static DateTime _dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _PropertyCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = _firstImage(data);
    final title = (data['title'] ?? 'عقار').toString().trim();
    final type = (data['propertyType'] ?? '').toString().trim();
    final adType = (data['adType'] ?? '').toString().trim();
    final city = (data['city'] ?? '').toString().trim();
    final area = (data['areaName'] ?? '').toString().trim();
    final price = data['price'];

    final location = [
      city,
      area,
    ].where((e) => e.isNotEmpty).join(' - ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1724),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: OfficeProfileScreen.gold.withValues(alpha: .20),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _imagePlaceholder(),
                      )
                    else
                      _imagePlaceholder(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .48),
                          ],
                        ),
                      ),
                    ),
                    if (adType.isNotEmpty)
                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _isRent(adType)
                                ? const Color(0xFF6751A8)
                                : const Color(0xFF238B62),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _isRent(adType) ? 'للإيجار' : 'للبيع',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  11,
                  9,
                  11,
                  10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _priceText(price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            type.isEmpty ? title : type,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .55),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
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

  Widget _imagePlaceholder() {
    final propertyType = (data['propertyType'] ?? '').toString();
    final fallback = PropertyDefaultImages.getImage(propertyType);

    if (fallback.startsWith('assets/')) {
      return Image.asset(
        fallback,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _iconPlaceholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: fallback,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => _iconPlaceholder(),
    );
  }

  Widget _iconPlaceholder() {
    return Container(
      color: const Color(0xFF263548),
      alignment: Alignment.center,
      child: const Icon(
        Icons.home_work_outlined,
        color: OfficeProfileScreen.gold,
        size: 44,
      ),
    );
  }

  static String _firstImage(Map<String, dynamic> data) {
    final images = data['images'];

    if (images is List) {
      for (final item in images) {
        final value = item.toString().trim();
        if (value.isNotEmpty) return value;
      }
    }

    return (data['imageUrl'] ?? '').toString().trim();
  }

  static bool _isRent(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('rent') ||
        value.contains('إيجار') ||
        value.contains('للايجار') ||
        value.contains('للإيجار');
  }

  static String _priceText(dynamic value) {
    if (value is num) {
      return '${value.toStringAsFixed(0)} د.ع';
    }

    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'السعر عند الطلب' : '$text د.ع';
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _PageIndicator({
    required this.count,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) {
          final active = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? OfficeProfileScreen.gold : Colors.white24,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  final OfficeModel office;
  final String officeId;

  const _ReviewsTab({
    required this.office,
    required this.officeId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OfficeReviewModel>>(
      stream: OfficeReviewService().watchOfficeReviews(officeId),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? [];
        final published =
            reviews.where((review) => review.isPublished).toList();
        final liveAverage = published.isEmpty
            ? 0.0
            : published.map((review) => review.rating).reduce((a, b) => a + b) /
                published.length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
          children: [
            _ReviewSummaryCard(
              rating: liveAverage,
              count: published.length,
            ),
            const SizedBox(height: 12),
            _AddReviewButton(
              office: office,
              officeId: officeId,
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(
                    color: OfficeProfileScreen.gold,
                  ),
                ),
              )
            else if (reviews.isEmpty)
              const _Card(
                title: 'التقييمات',
                icon: Icons.rate_review_outlined,
                child: _EmptyMessage(
                  text: 'لا توجد تقييمات منشورة حتى الآن',
                ),
              )
            else
              ...reviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewCard(
                    review: review,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  final double rating;
  final int count;

  const _ReviewSummaryCard({
    required this.rating,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'تقييمات المكتب',
      icon: Icons.star_rounded,
      child: Row(
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: OfficeProfileScreen.gold,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < rating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: OfficeProfileScreen.gold,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$count تقييم',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .60),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddReviewButton extends StatelessWidget {
  final OfficeModel office;
  final String officeId;

  const _AddReviewButton({
    required this.office,
    required this.officeId,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.uid == office.ownerId) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: () => _openReviewDialog(context, user),
        icon: const Icon(
          Icons.rate_review_rounded,
          color: OfficeProfileScreen.gold,
          size: 18,
        ),
        label: const Text(
          'قيّم المكتب',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: OfficeProfileScreen.gold.withValues(alpha: .25),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Future<void> _openReviewDialog(
    BuildContext context,
    User user,
  ) async {
    final service = OfficeReviewService();

    try {
      final existing = await service.getUserReview(
        officeId: officeId,
        userId: user.uid,
      );

      if (!context.mounted) return;

      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لقد قيّمت هذا المكتب مسبقًا.'),
          ),
        );
        return;
      }

      final profile = await _loadReviewUserProfile(user);

      if (!context.mounted) return;

      final submitted = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        builder: (_) => _ReviewDialog(
          service: service,
          officeId: officeId,
          userId: user.uid,
          userName: profile.name,
          userImageUrl: profile.imageUrl,
        ),
      );

      if (submitted == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال تقييمك بنجاح'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح التقييم: $e'),
          ),
        );
      }
    }
  }
}

class _ReviewUserProfile {
  final String name;
  final String imageUrl;

  const _ReviewUserProfile({
    required this.name,
    required this.imageUrl,
  });
}

Future<_ReviewUserProfile> _loadReviewUserProfile(User user) async {
  String name = (user.displayName ?? '').trim();
  String imageUrl = (user.photoURL ?? '').trim();

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data != null) {
      final candidates = [
        data['name'],
        data['displayName'],
        data['fullName'],
        data['userName'],
        data['username'],
      ];

      for (final value in candidates) {
        final valueText = (value ?? '').toString().trim();
        if (valueText.isNotEmpty) {
          name = valueText;
          break;
        }
      }

      final imageCandidates = [
        data['imageUrl'],
        data['profileImageUrl'],
        data['photoURL'],
        data['avatarUrl'],
        data['photoUrl'],
      ];

      for (final value in imageCandidates) {
        final valueText = (value ?? '').toString().trim();
        if (valueText.isNotEmpty) {
          imageUrl = valueText;
          break;
        }
      }
    }
  } catch (_) {
    // نستخدم بيانات Firebase Auth إذا تعذر قراءة ملف المستخدم.
  }

  // لا نعرض البريد الإلكتروني كاسم في التقييمات.
  if (name.isEmpty || name.contains('@')) {
    name = 'مستخدم عقار';
  }

  return _ReviewUserProfile(
    name: name,
    imageUrl: imageUrl,
  );
}

class _ReviewDialog extends StatefulWidget {
  final OfficeReviewService service;
  final String officeId;
  final String userId;
  final String userName;
  final String userImageUrl;

  const _ReviewDialog({
    required this.service,
    required this.officeId,
    required this.userId,
    required this.userName,
    required this.userImageUrl,
  });

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final TextEditingController _commentController = TextEditingController();

  double _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      await widget.service.addReview(
        officeId: widget.officeId,
        userId: widget.userId,
        rating: _rating,
        userName: widget.userName,
        userImageUrl: widget.userImageUrl,
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال التقييم: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: OfficeProfileScreen.card,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 24,
        ),
        titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: OfficeProfileScreen.field,
              backgroundImage: widget.userImageUrl.isNotEmpty
                  ? CachedNetworkImageProvider(widget.userImageUrl)
                  : null,
              child: widget.userImageUrl.isEmpty
                  ? const Icon(
                      Icons.person_rounded,
                      color: OfficeProfileScreen.gold,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'كيف تقيّم تجربتك مع المكتب؟',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: _submitting
                        ? null
                        : () {
                            setState(() {
                              _rating = index + 1.0;
                            });
                          },
                    icon: Icon(
                      index < _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: OfficeProfileScreen.gold,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                minLines: 2,
                maxLines: 4,
                enabled: !_submitting,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقك (اختياري)',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: OfficeProfileScreen.field,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pop(false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: OfficeProfileScreen.gold,
              foregroundColor: Colors.black,
              minimumSize: const Size(92, 40),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    size: 16,
                  ),
            label: Text(
              _submitting ? 'جارٍ الإرسال' : 'إرسال',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final OfficeReviewModel review;

  const _ReviewCard({
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    final userName =
        review.userName.trim().isEmpty || review.userName.trim().contains('@')
            ? 'مستخدم عقار'
            : review.userName.trim();
    final imageUrl = review.userImageUrl.trim();

    return _Card(
      title: userName,
      icon: Icons.person_outline_rounded,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: OfficeProfileScreen.field,
        backgroundImage:
            imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
        child: imageUrl.isEmpty
            ? const Icon(
                Icons.person_rounded,
                color: OfficeProfileScreen.gold,
                size: 17,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  index < review.rating.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: OfficeProfileScreen.gold,
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                review.rating.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .60),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment.trim(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: .75),
                fontSize: 12,
                height: 1.7,
              ),
            ),
          ],
          if (review.hasOwnerReply && review.ownerReply.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OfficeProfileScreen.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'رد المكتب: ${review.ownerReply.trim()}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  final OfficeModel office;

  const _AboutTab({
    required this.office,
  });

  @override
  Widget build(BuildContext context) {
    final location = _locationText(office);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        _Card(
          title: 'عن المكتب',
          icon: Icons.business_outlined,
          child: Text(
            office.description.trim().isEmpty
                ? 'لا توجد نبذة مضافة عن المكتب حاليًا.'
                : office.description.trim(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 13,
              height: 1.9,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _CompactInfoCard(
          office: office,
          location: location,
        ),
        if (office.galleryImages.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Card(
            title: 'صور المكتب',
            icon: Icons.photo_library_outlined,
            child: OfficeGallery(
              images: office.galleryImages,
              height: 230,
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final Widget? leading;

  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: OfficeProfileScreen.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: OfficeProfileScreen.gold.withValues(alpha: .10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null)
                leading!
              else
                Icon(
                  icon,
                  color: OfficeProfileScreen.gold,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: OfficeProfileScreen.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: 1,
      color: Colors.white.withValues(alpha: .08),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String text;

  const _EmptyMessage({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .55),
            fontSize: 12,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .38),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 23,
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final PreferredSizeWidget child;

  _TabBarDelegate({
    required this.child,
  });

  @override
  double get minExtent => child.preferredSize.height;

  @override
  double get maxExtent => child.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return false;
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OfficeProfileScreen.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_outlined,
                size: 64,
                color: OfficeProfileScreen.gold.withValues(alpha: .65),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('رجوع'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _locationText(OfficeModel office) {
  return [
    office.city,
    office.district,
    office.areaName,
  ].where((e) => e.trim().isNotEmpty).join(' - ');
}
