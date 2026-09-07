import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../models/property_model.dart';
import '../../office/screens/office_profile_screen.dart';
import '../../screens/login_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/property_navigator.dart';
import '../models/reel_model.dart';
import '../services/reel_service.dart';

class ReelsScreen extends StatefulWidget {
  final String? initialReelId;
  const ReelsScreen({super.key, this.initialReelId});
  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  int _index = 0;
  String _category = 'الكل';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: StreamBuilder<List<ReelModel>>(
          stream: ReelService.instance.publicReels(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _message('تعذر تحميل الريلز');
            if (!snapshot.hasData) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryColor));
            }
            final all = [...snapshot.data!];
            if (widget.initialReelId != null) {
              all.sort((a, b) {
                if (a.id == widget.initialReelId) return -1;
                if (b.id == widget.initialReelId) return 1;
                return 0;
              });
            }
            final categories = [
              'الكل',
              ...{for (final reel in all) reel.category}
            ];
            final reels = _category == 'الكل'
                ? all
                : all.where((r) => r.category == _category).toList();
            if (reels.isEmpty) return _message('لا توجد ريلز منشورة الآن');
            return Stack(
              children: [
                PageView.builder(
                  scrollDirection: Axis.vertical,
                  allowImplicitScrolling: true,
                  itemCount: reels.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (_, index) => ReelPlayerCard(
                      reel: reels[index], active: index == _index),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ريلز العقارات',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20)),
                                Text('عقارات الأنبار',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ]),
                        ),
                        PopupMenuButton<String>(
                          initialValue: _category,
                          color: AppTheme.cardColor,
                          icon: const Icon(Icons.tune_rounded,
                              color: Colors.white),
                          onSelected: (value) => setState(() {
                            _category = value;
                            _index = 0;
                          }),
                          itemBuilder: (_) => categories
                              .map((value) => PopupMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _message(String text) =>
      Center(child: Text(text, style: const TextStyle(color: Colors.white70)));
}

class ReelPlayerCard extends StatefulWidget {
  final ReelModel reel;
  final bool active;
  const ReelPlayerCard({super.key, required this.reel, required this.active});
  @override
  State<ReelPlayerCard> createState() => _ReelPlayerCardState();
}

class _ReelPlayerCardState extends State<ReelPlayerCard> {
  VideoPlayerController? _controller;
  bool _muted = false;
  bool _ended = false;
  bool _trackedView = false;
  String _quality = 'auto';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool('reels_muted') ?? false;
    _quality = prefs.getString('reels_quality') ?? 'auto';
    final url = widget.reel.qualityUrls[_quality] ?? widget.reel.videoUrl;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.addListener(_listen);
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(_muted ? 0 : 1);
      if (widget.active) await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _listen() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!_trackedView &&
        controller.value.position > const Duration(milliseconds: 500)) {
      _trackedView = true;
      ReelService.instance.track(widget.reel.id, 'view');
    }
    if (!_ended &&
        controller.value.duration > Duration.zero &&
        controller.value.position >=
            controller.value.duration - const Duration(milliseconds: 250)) {
      _ended = true;
      ReelService.instance.track(widget.reel.id, 'completion');
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant ReelPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller?.play();
    } else if (!widget.active && oldWidget.active) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_listen);
    _controller?.dispose();
    super.dispose();
  }

  Future<bool> _requireLogin() async {
    if (FirebaseAuth.instance.currentUser != null) return true;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    return FirebaseAuth.instance.currentUser != null;
  }

  Future<void> _toggleSound() async {
    _muted = !_muted;
    await _controller?.setVolume(_muted ? 0 : 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reels_muted', _muted);
    if (mounted) setState(() {});
  }

  Future<void> _selectQuality() async {
    final qualities =
        <String>{'auto', ...widget.reel.qualityUrls.keys}.toList();
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: qualities
                .map((quality) => ListTile(
                      leading: Icon(quality == _quality
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off),
                      title: Text(quality == 'auto' ? 'تلقائي' : quality),
                      onTap: () => Navigator.pop(context, quality),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (selected == null || selected == _quality) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reels_quality', selected);
    await _controller?.dispose();
    _quality = selected;
    _controller = null;
    _ended = false;
    _trackedView = false;
    if (mounted) setState(() {});
    await _prepare();
  }

  Future<void> _openProperty() async {
    final id = widget.reel.propertyId;
    if (id == null || id.isEmpty) return;
    ReelService.instance.track(widget.reel.id, 'propertyClick');
    final doc =
        await FirebaseFirestore.instance.collection('properties').doc(id).get();
    if (doc.exists && mounted) {
      PropertyNavigator.open(
          context, PropertyModel.fromMap(doc.data()!, doc.id));
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.reel.externalUrl);
    if (uri == null) return;
    ReelService.instance.track(widget.reel.id, 'externalClick');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openOffice() {
    final id = widget.reel.officeId;
    if (id == null || id.isEmpty) return;
    ReelService.instance.track(widget.reel.id, 'officeClick');
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => OfficeProfileScreen(officeId: id)));
  }

  void _share() {
    final details = <String>[
      widget.reel.title,
      if (widget.reel.description.isNotEmpty) widget.reel.description,
      if (widget.reel.propertySnapshot['location'] != null)
        'الموقع: ${widget.reel.propertySnapshot['location']}',
      if (widget.reel.propertySnapshot['price'] != null)
        'السعر: ${widget.reel.propertySnapshot['price']} د.ع',
      '',
      widget.reel.externalUrl.isNotEmpty
          ? widget.reel.externalUrl
          : widget.reel.videoUrl,
      '',
      'عقارات الأنبار',
    ];
    ReelService.instance.track(widget.reel.id, 'share');
    Share.share(details.join('\n'), subject: widget.reel.title);
  }

  Future<void> _report() async {
    if (!await _requireLogin() || !mounted) return;
    String reason = 'محتوى غير مناسب';
    final details = TextEditingController();
    final sent = await showDialog<bool>(
        context: context,
        builder: (context) =>
            StatefulBuilder(builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('الإبلاغ عن الريل'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                      initialValue: reason,
                      decoration:
                          const InputDecoration(labelText: 'سبب البلاغ'),
                      items: const [
                        'محتوى غير مناسب',
                        'معلومات مضللة',
                        'عقار غير متاح',
                        'حقوق ملكية',
                        'سبب آخر'
                      ]
                          .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => reason = v ?? reason)),
                  if (reason == 'سبب آخر') ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: details,
                      autofocus: true,
                      maxLines: 3,
                      maxLength: 500,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'اكتب سبب البلاغ',
                          hintText: 'وضّح المشكلة حتى يستطيع المشرف مراجعتها'),
                    ),
                  ],
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed:
                          reason == 'سبب آخر' && details.text.trim().isEmpty
                              ? null
                              : () => Navigator.pop(context, true),
                      child: const Text('إرسال'))
                ],
              );
            }));
    if (sent == true) {
      await ReelService.instance.report(widget.reel, reason, details.text);
    }
    details.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return GestureDetector(
      onTap: () {
        if (controller == null) return;
        setState(() {
          _ended = false;
          controller.value.isPlaying ? controller.pause() : controller.play();
        });
      },
      child: Stack(fit: StackFit.expand, children: [
        if (controller?.value.isInitialized == true)
          FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller)))
        else
          const ColoredBox(
              color: Colors.black,
              child: Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryColor))),
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
              Colors.black38,
              Colors.transparent,
              Colors.black87
            ],
                    stops: [
              0,
              .45,
              1
            ]))),
        Positioned(
            top: MediaQuery.paddingOf(context).top + 62,
            left: 12,
            child: GestureDetector(
                onLongPress: _selectQuality,
                child: IconButton.filledTonal(
                    tooltip: 'الصوت (ضغط مطول للجودة)',
                    onPressed: _toggleSound,
                    icon: Icon(_muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded)))),
        Positioned(
            left: 12,
            bottom: 110,
            child: Column(children: [
              StreamBuilder<bool>(
                stream: ReelService.instance.liked(widget.reel.id),
                builder: (_, s) => _action(
                    Icons.favorite_rounded, widget.reel.likes, () async {
                  if (await _requireLogin()) {
                    await ReelService.instance.toggleLike(widget.reel.id);
                  }
                }, active: s.data == true),
              ),
              StreamBuilder<bool>(
                stream: ReelService.instance.saved(widget.reel.id),
                builder: (_, s) => _action(
                    Icons.bookmark_rounded, widget.reel.saves, () async {
                  if (await _requireLogin()) {
                    await ReelService.instance.toggleSave(widget.reel.id);
                  }
                }, active: s.data == true),
              ),
              _action(Icons.share_rounded, widget.reel.shares, _share),
              _action(Icons.flag_outlined, 0, _report),
            ])),
        Positioned(
            right: 16,
            left: 78,
            bottom: 30,
            child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.reel.propertyId?.isNotEmpty == true
                    ? _openProperty
                    : widget.reel.officeId?.isNotEmpty == true
                        ? _openOffice
                        : null,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(spacing: 6, children: [
                        if (widget.reel.isSponsored) _badge('ممول'),
                        if (widget.reel.isFeatured) _badge('مميز'),
                        _badge(widget.reel.category)
                      ]),
                      const SizedBox(height: 8),
                      Text(widget.reel.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      if (widget.reel.propertyId?.isNotEmpty == true ||
                          widget.reel.officeId?.isNotEmpty == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.touch_app_rounded,
                                size: 15, color: AppTheme.primaryColor),
                            SizedBox(width: 4),
                            Text('اضغط لعرض التفاصيل',
                                style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12)),
                          ]),
                        ),
                      if (widget.reel.description.isNotEmpty)
                        Text(widget.reel.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70)),
                      if (widget.reel.propertySnapshot.isNotEmpty)
                        Text(
                            '${widget.reel.propertySnapshot['location'] ?? ''}  •  ${widget.reel.propertySnapshot['area'] ?? ''} م²  •  ${widget.reel.propertySnapshot['price'] ?? ''}',
                            style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600)),
                    ]))),
        if (_ended) _endOverlay(),
      ]),
    );
  }

  Widget _action(IconData icon, int count, VoidCallback onTap,
          {bool active = false}) =>
      Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(children: [
            IconButton.filled(
                onPressed: onTap,
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                icon: Icon(icon,
                    color: active ? AppTheme.primaryColor : Colors.white)),
            if (count > 0)
              Text('$count',
                  style: const TextStyle(color: Colors.white, fontSize: 11))
          ]));
  Widget _badge(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black54,
          border: Border.all(color: AppTheme.primaryColor),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11)));
  Widget _endOverlay() => ColoredBox(
      color: Colors.black.withValues(alpha: .72),
      child: SafeArea(
          child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(14, 24, 14, 18),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: .65)),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 26)
                      ]),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 15),
                    Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: .14),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.play_circle_fill_rounded,
                            color: AppTheme.primaryColor, size: 34)),
                    const SizedBox(height: 10),
                    Text(
                        widget.reel.propertyId?.isNotEmpty == true
                            ? 'هل أعجبك هذا العقار؟'
                            : 'هل أعجبك هذا الفيديو؟',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22)),
                    const SizedBox(height: 5),
                    Text(widget.reel.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 16),
                    if (widget.reel.propertyId?.isNotEmpty == true)
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                              onPressed: _openProperty,
                              icon: const Icon(Icons.home_work_rounded),
                              label: const Text('مشاهدة العقار'))),
                    if (widget.reel.officeId?.isNotEmpty == true)
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                              onPressed: _openOffice,
                              icon: const Icon(Icons.business_rounded),
                              label: const Text('مشاهدة المكتب'))),
                    if (widget.reel.externalUrl.isNotEmpty)
                      SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                              onPressed: _openExternal,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(widget.reel.ctaLabel.isEmpty
                                  ? 'مشاهدة الفيديو كاملاً'
                                  : widget.reel.ctaLabel))),
                    TextButton.icon(
                        onPressed: () async {
                          setState(() => _ended = false);
                          await _controller?.seekTo(Duration.zero);
                          await _controller?.play();
                        },
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('إعادة المشاهدة')),
                  ])))));
}
