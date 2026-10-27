import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'booking_screen.dart';
import 'booking_widgets.dart';

/// Data model representing a single vertical reel item for a bookable venue.
class BookingReelItem {
  final String id;
  final String venueId;
  final String ownerId;
  final String venueName;
  final String category;
  final String location;
  final int price;
  final int? deposit;
  final String videoUrl;
  final String? thumbnailUrl;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final DateTime createdAt;
  final Map<String, dynamic> rawVenue;

  const BookingReelItem({
    required this.id,
    required this.venueId,
    required this.ownerId,
    required this.venueName,
    required this.category,
    required this.location,
    required this.price,
    this.deposit,
    required this.videoUrl,
    this.thumbnailUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    required this.createdAt,
    this.rawVenue = const {},
  });

  factory BookingReelItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BookingReelItem(
      id: doc.id,
      venueId: data['venueId']?.toString() ?? '',
      ownerId: data['ownerId']?.toString() ?? '',
      venueName: data['venueName']?.toString() ?? 'مكان مميز',
      category: data['category']?.toString() ?? 'chalet',
      location: data['location']?.toString() ?? 'الأنبار',
      price: (data['price'] as num?)?.toInt() ?? 0,
      deposit: (data['deposit'] as num?)?.toInt(),
      videoUrl: data['videoUrl']?.toString() ?? '',
      thumbnailUrl: data['thumbnailUrl']?.toString(),
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      sharesCount: (data['sharesCount'] as num?)?.toInt() ?? 0,
      viewsCount: (data['viewsCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rawVenue: data['rawVenue'] as Map<String, dynamic>? ?? {},
    );
  }

  factory BookingReelItem.fromVenueDoc(DocumentSnapshot<Map<String, dynamic>> doc, String videoUrl) {
    final data = doc.data() ?? {};
    return BookingReelItem(
      id: 'venue_${doc.id}',
      venueId: doc.id,
      ownerId: data['ownerId']?.toString() ?? '',
      venueName: data['name']?.toString() ?? 'مكان للإيجار',
      category: data['category']?.toString() ?? 'chalet',
      location: data['location']?.toString() ?? 'الأنبار',
      price: (data['price'] as num?)?.toInt() ?? 0,
      deposit: (data['deposit'] as num?)?.toInt(),
      videoUrl: videoUrl,
      thumbnailUrl: (data['mediaPaths'] as List?)?.isNotEmpty == true ? data['mediaPaths'][0]?.toString() : null,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: 0,
      sharesCount: 0,
      viewsCount: 0,
      createdAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rawVenue: data,
    );
  }
}

/// Recommendation and Feed Ranking service for booking reels.
/// Prioritizes user category affinity, engagement, freshness, and venue diversity.
class BookingReelRecommendationService {
  static const String _prefCatKey = 'booking_reels_fav_category';

  static Future<void> recordCategoryEngagement(String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCatKey, category);
    } catch (_) {}
  }

  static Future<List<BookingReelItem>> rankFeed(List<BookingReelItem> rawList) async {
    if (rawList.isEmpty) return [];
    String favCat = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      favCat = prefs.getString(_prefCatKey) ?? '';
    } catch (_) {}
    final now = DateTime.now();

    final scored = rawList.map((item) {
      double score = 0;
      // Engagement weight
      score += item.likesCount * 3.0;
      score += item.commentsCount * 2.5;
      score += item.sharesCount * 4.0;
      score += item.viewsCount * 0.5;

      // Category affinity bonus
      if (favCat.isNotEmpty && item.category == favCat) {
        score += 20.0;
      }

      // Freshness bonus (decays after 7 days)
      final ageHours = now.difference(item.createdAt).inHours;
      if (ageHours < 24) {
        score += 30.0;
      } else if (ageHours < 168) {
        score += 15.0;
      }

      return MapEntry(item, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    // Enforce diversity: avoid 2 consecutive reels from same venue or owner
    final diverse = <BookingReelItem>[];
    final remaining = scored.map((e) => e.key).toList();

    while (remaining.isNotEmpty) {
      int nextIdx = 0;
      if (diverse.isNotEmpty) {
        final last = diverse.last;
        final candidate = remaining.indexWhere((r) => r.venueId != last.venueId && r.ownerId != last.ownerId);
        if (candidate != -1) nextIdx = candidate;
      }
      diverse.add(remaining.removeAt(nextIdx));
    }

    return diverse;
  }
}

/// Main vertical reels viewer dedicated exclusively to booking venues.
class BookingReelsScreen extends StatefulWidget {
  final List<BookingReelItem>? initialReels;
  final VoidCallback? onBack;
  final bool admin;

  const BookingReelsScreen({
    super.key,
    this.initialReels,
    this.onBack,
    this.admin = false,
  });

  @override
  State<BookingReelsScreen> createState() => _BookingReelsScreenState();
}

class _BookingReelsScreenState extends State<BookingReelsScreen> {
  final PageController _pageController = PageController();
  List<BookingReelItem> _reels = [];
  bool _loading = true;
  int _currentIndex = 0;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _loadMutePreference();
    if (widget.initialReels != null) {
      _reels = widget.initialReels!;
      _loading = false;
    } else {
      _fetchBookingReels();
    }
  }

  Future<void> _loadMutePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _isMuted = prefs.getBool('booking_reels_muted') ?? false);
      }
    } catch (_) {}
  }

  Future<void> _toggleMute() async {
    final next = !_isMuted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('booking_reels_muted', next);
    } catch (_) {}
    if (mounted) setState(() => _isMuted = next);
  }

  Future<void> _fetchBookingReels() async {
    try {
      final items = <BookingReelItem>[];

      // 1. Fetch from booking_reels collection
      final snap = await FirebaseFirestore.instance
          .collection('booking_reels')
          .where('active', isEqualTo: true)
          .limit(25)
          .get();

      for (final doc in snap.docs) {
        items.add(BookingReelItem.fromFirestore(doc));
      }

      // 2. Fetch venues that have video in media
      if (items.isEmpty) {
        final venuesSnap = await FirebaseFirestore.instance
            .collection('booking_venues')
            .where('active', isEqualTo: true)
            .limit(15)
            .get();

        for (final vDoc in venuesSnap.docs) {
          final data = vDoc.data();
          final media = (data['mediaPaths'] as List?) ?? [];
          for (final path in media) {
            final pStr = path.toString();
            if (pStr.endsWith('.mp4') || pStr.contains('/videos/')) {
              items.add(BookingReelItem.fromVenueDoc(vDoc, pStr));
              break;
            }
          }
        }
      }

      final ranked = await BookingReelRecommendationService.rankFeed(items);
      if (mounted) {
        setState(() {
          _reels = ranked;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: bookingGold),
        ),
      );
    }

    if (_reels.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('ريلز الحجوزات'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.video_collection_outlined, size: 64, color: bookingGold.withValues(alpha: .6)),
                const SizedBox(height: 10),
                const Text(
                  'لا توجد مقاطع ريلز للحجوزات حالياً',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ستظهر هنا مقاطع الفيديو الخاصة بالشاليهات والمزارع والقاعات فور نشرها من الملاك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _fetchBookingReels,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: FilledButton.styleFrom(backgroundColor: bookingGold, foregroundColor: bookingNavy),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _reels.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              BookingReelRecommendationService.recordCategoryEngagement(_reels[index].category);
            },
            itemBuilder: (context, index) {
              return BookingReelCard(
                key: ValueKey(_reels[index].id),
                reel: _reels[index],
                isActive: index == _currentIndex,
                isMuted: _isMuted,
                onToggleMute: _toggleMute,
              );
            },
          ),
          // Top Bar Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                    )
                  else
                    const SizedBox.shrink(),
                  IconButton(
                    onPressed: _toggleMute,
                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single vertical video card component.
class BookingReelCard extends StatefulWidget {
  final BookingReelItem reel;
  final bool isActive;
  final bool isMuted;
  final VoidCallback onToggleMute;

  const BookingReelCard({
    super.key,
    required this.reel,
    required this.isActive,
    required this.isMuted,
    required this.onToggleMute,
  });

  @override
  State<BookingReelCard> createState() => _BookingReelCardState();
}

class _BookingReelCardState extends State<BookingReelCard> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isPlaying = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isLikeInProgress = false;
  bool _isSaveInProgress = false;
  int _likesCount = 0;
  bool _showHeartAnimation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _likesCount = widget.reel.likesCount;
    _checkUserInteractions();
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_controller != null && _controller!.value.isInitialized && _isPlaying) {
        _controller!.pause();
        if (mounted) setState(() => _isPlaying = false);
      }
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      if (_controller != null && _controller!.value.isInitialized && !_isPlaying) {
        _controller!.play();
        if (mounted) setState(() => _isPlaying = true);
      }
    }
  }

  void _checkUserInteractions() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Check like
    FirebaseFirestore.instance
        .collection('booking_reels')
        .doc(widget.reel.id)
        .collection('likes')
        .doc(uid)
        .get()
        .then((doc) {
      if (mounted && doc.exists) setState(() => _isLiked = true);
    }).catchError((_) {});

    // Check save
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('saved_booking_reels')
        .doc(widget.reel.id)
        .get()
        .then((doc) {
      if (mounted && doc.exists) setState(() => _isSaved = true);
    }).catchError((_) {});
  }

  Future<void> _initializeVideo() async {
    if (mounted) {
      setState(() {
        _hasError = false;
        _errorMessage = '';
        _initialized = false;
      });
    }
    try {
      final url = widget.reel.videoUrl;
      if (url.isEmpty) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'رابط الفيديو غير متوفر';
          });
        }
        return;
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.isMuted ? 0 : 1);

      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
          _isPlaying = widget.isActive;
        });
        if (widget.isActive) {
          controller.play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialized = false;
          _hasError = true;
          _errorMessage = 'تعذر تشغيل الفيديو';
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant BookingReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (widget.isActive && !oldWidget.isActive) {
      _controller!.play();
      setState(() => _isPlaying = true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller!.pause();
      setState(() => _isPlaying = false);
    }

    if (widget.isMuted != oldWidget.isMuted) {
      _controller!.setVolume(widget.isMuted ? 0 : 1);
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _toggleLike() async {
    if (_isLikeInProgress) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول للإعجاب بالمقطع')),
      );
      return;
    }

    _isLikeInProgress = true;
    final newLiked = !_isLiked;
    setState(() {
      _isLiked = newLiked;
      _likesCount += newLiked ? 1 : -1;
      if (newLiked) _showHeartAnimation = true;
    });

    if (newLiked) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _showHeartAnimation = false);
      });
    }

    final likeRef = FirebaseFirestore.instance
        .collection('booking_reels')
        .doc(widget.reel.id)
        .collection('likes')
        .doc(uid);

    final reelRef = FirebaseFirestore.instance.collection('booking_reels').doc(widget.reel.id);

    try {
      if (newLiked) {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp(), 'userId': uid});
        await reelRef.update({'likesCount': FieldValue.increment(1)}).catchError((_) {});
      } else {
        await likeRef.delete();
        await reelRef.update({'likesCount': FieldValue.increment(-1)}).catchError((_) {});
      }
    } catch (_) {
      // Revert if error occurs
      if (mounted) {
        setState(() {
          _isLiked = !newLiked;
          _likesCount += !newLiked ? 1 : -1;
        });
      }
    } finally {
      _isLikeInProgress = false;
    }
  }

  Future<void> _toggleSave() async {
    if (_isSaveInProgress) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول لحفظ المقطع')),
      );
      return;
    }

    _isSaveInProgress = true;
    final newSaved = !_isSaved;
    setState(() => _isSaved = newSaved);

    final saveRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('saved_booking_reels')
        .doc(widget.reel.id);

    try {
      if (newSaved) {
        await saveRef.set({
          'savedAt': FieldValue.serverTimestamp(),
          'reelId': widget.reel.id,
          'venueId': widget.reel.venueId,
          'venueName': widget.reel.venueName,
          'videoUrl': widget.reel.videoUrl,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إضافة المقطع إلى المحفوظات')),
          );
        }
      } else {
        await saveRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إزالة المقطع من المحفوظات')),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isSaved = !newSaved);
    } finally {
      _isSaveInProgress = false;
    }
  }

  void _shareReel() {
    final shareUrl = 'https://aqar.app/booking/venue/${widget.reel.venueId}';
    Share.share(
      'شاهد هذا المكان المميز في عقارات الأنبار:\n${widget.reel.venueName} — ${widget.reel.location}\nالسعر: ${widget.reel.price} د.ع\n\nاحجز الآن عبر الرابط:\n$shareUrl',
      subject: widget.reel.venueName,
    );
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingReelCommentsSheet(reelId: widget.reel.id),
    );
  }

  void _openReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الإبلاغ عن المحتوى'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in ['محتوى مضلل أو غير دقيق', 'انتهاك حقوق الملكية', 'محتوى غير لائق', 'مكان غير موجود'])
              ListTile(
                title: Text(r, style: const TextStyle(fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    try {
                      await FirebaseFirestore.instance.collection('booking_reel_reports').add({
                        'reelId': widget.reel.id,
                        'venueId': widget.reel.venueId,
                        'reporterId': uid,
                        'reason': r,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } catch (_) {}
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('شكراً لمساعدتنا، تم إرسال البلاغ للإدارة.')),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToBooking() async {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.pause();
      setState(() => _isPlaying = false);
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingRequestScreen(
          venueId: widget.reel.venueId,
          venue: widget.reel.rawVenue.isNotEmpty
              ? widget.reel.rawVenue
              : {
                  'id': widget.reel.venueId,
                  'name': widget.reel.venueName,
                  'location': widget.reel.location,
                  'category': widget.reel.category,
                  'price': widget.reel.price,
                  'deposit': widget.reel.deposit,
                  'active': true,
                },
        ),
      ),
    );

    if (mounted && widget.isActive && _controller != null && _controller!.value.isInitialized) {
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _toggleLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player or Loading / Error Fallback
          if (_initialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (_hasError)
            Container(
              color: const Color(0xFF131B2E),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 54),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage.isNotEmpty ? _errorMessage : 'تعذر تشغيل المقطع',
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _initializeVideo,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('إعادة المحاولة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: bookingGold,
                          side: const BorderSide(color: bookingGold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              color: const Color(0xFF131B2E),
              child: const Center(
                child: CircularProgressIndicator(color: bookingGold),
              ),
            ),

          // Subtle Dark Gradient Vignette for bottom third only
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .75),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Animated Play/Pause indicator
          if (!_isPlaying && _initialized)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30, width: 2),
                ),
                child: const Icon(Icons.play_arrow, size: 54, color: Colors.white),
              ),
            ),

          // Double Tap Big Heart Animation
          if (_showHeartAnimation)
            const Center(
              child: Icon(Icons.favorite, size: 100, color: Colors.redAccent),
            ),

          // Right Side Action Bar (Likes, Comments, Share, Save, Report)
          Positioned(
            left: 16,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Like Button
                _actionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  iconColor: _isLiked ? Colors.redAccent : Colors.white,
                  label: _likesCount > 0 ? '$_likesCount' : '',
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 10),
                // Comments Button
                _actionButton(
                  icon: Icons.chat_bubble_outline,
                  iconColor: Colors.white,
                  label: widget.reel.commentsCount > 0 ? '${widget.reel.commentsCount}' : '',
                  onTap: _openComments,
                ),
                const SizedBox(height: 10),
                // Share Button (Clean icon without text label)
                _actionButton(
                  icon: Icons.share_outlined,
                  iconColor: Colors.white,
                  label: '',
                  onTap: _shareReel,
                ),
                const SizedBox(height: 10),
                // Save / Bookmark (Clean icon without text label)
                _actionButton(
                  icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  iconColor: _isSaved ? bookingGold : Colors.white,
                  label: '',
                  onTap: _toggleSave,
                ),
                const SizedBox(height: 10),
                // Report (Clean icon without text label)
                _actionButton(
                  icon: Icons.flag_outlined,
                  iconColor: Colors.white70,
                  label: '',
                  onTap: _openReportDialog,
                ),
              ],
            ),
          ),

          // Bottom Left Venue Information & «احجز الآن» Button
          Positioned(
            right: 16,
            left: 76,
            bottom: 32,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.reel.venueName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _navigateToBooking,
                  icon: const Icon(Icons.calendar_month, size: 15),
                  label: const Text(
                    'احجز',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: bookingGold,
                    foregroundColor: bookingNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(80, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ],
            ),          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .45),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

}

/// Comments Sheet for a booking reel.
class BookingReelCommentsSheet extends StatefulWidget {
  final String reelId;
  final bool admin;
  const BookingReelCommentsSheet({super.key, required this.reelId, this.admin = false});

  @override
  State<BookingReelCommentsSheet> createState() => _BookingReelCommentsSheetState();
}

class _BookingReelCommentsSheetState extends State<BookingReelCommentsSheet> {
  void _editComment(DocumentSnapshot<Map<String, dynamic>> doc) {
    final controller = TextEditingController(text: doc.data()?['text'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل التعليق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'اكتب تعديلك هنا...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: bookingGold, foregroundColor: bookingNavy),
              onPressed: () async {
                final newText = controller.text.trim();
                if (newText.isNotEmpty) {
                  await doc.reference.update({
                    'text': newText,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول لكتابة تعليق')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance
          .collection('booking_reels')
          .doc(widget.reelId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'userName': user.displayName ?? 'مستخدم',
        'userPhoto': user.photoURL ?? '',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('booking_reels')
          .doc(widget.reelId)
          .update({'commentsCount': FieldValue.increment(1)}).catchError((_) {});

      _commentController.clear();
    } catch (_) {}
    if (mounted) setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2638) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text(
                  'التعليقات',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('booking_reels')
                  .doc(widget.reelId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('تعذر تحميل التعليقات'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: bookingGold));
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('كن أول من يكتب تعليقاً على هذا المكان!'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final author = data['userName']?.toString() ?? 'مستخدم';
                    final userPhoto = data['userPhoto']?.toString() ?? '';
                    final comment = data['text']?.toString() ?? '';
                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    final isAuthor = currentUid != null && currentUid == data['userId'];
                    final canDelete = isAuthor || widget.admin;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: bookingGold.withValues(alpha: .2),
                          backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                          child: userPhoto.isEmpty
                              ? Text(
                                  author.isNotEmpty ? author[0] : '؟',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: bookingGold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(comment, style: const TextStyle(fontSize: 14, height: 1.4)),
                            ],
                          ),
                        ),
                        if (isAuthor)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: bookingGold),
                            onPressed: () => _editComment(docs[index]),
                          ),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () async {
                              await docs[index].reference.delete();
                              await FirebaseFirestore.instance
                                  .collection('booking_reels')
                                  .doc(widget.reelId)
                                  .update({'commentsCount': FieldValue.increment(-1)}).catchError((_) {});
                            },
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // New Comment Input
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'اكتب تعليقك...',
                      filled: true,
                      fillColor: dark ? const Color(0xFF131B2E) : const Color(0xFFF0F4F8),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _submitting ? null : _submitComment,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  style: IconButton.styleFrom(backgroundColor: bookingGold, foregroundColor: bookingNavy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

