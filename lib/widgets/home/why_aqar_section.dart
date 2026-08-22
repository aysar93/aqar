import 'dart:math' as math;

import 'package:flutter/material.dart';

class WhyAqarSection extends StatefulWidget {
  const WhyAqarSection({super.key});

  @override
  State<WhyAqarSection> createState() => _WhyAqarSectionState();
}

class _WhyAqarSectionState extends State<WhyAqarSection>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xffD4AF37);
  static const _lightGold = Color(0xffF8D86B);

  static const _features = <_FeatureData>[
    _FeatureData(
      icon: Icons.verified_rounded,
      title: 'موثوق',
      description:
          'نراجع الإعلانات قبل نشرها لضمان جودة المحتوى وتقليل الإعلانات غير الدقيقة.',
    ),
    _FeatureData(
      icon: Icons.support_agent_rounded,
      title: 'تواصل',
      description:
          'تواصل مباشرة مع المالك أو المكتب عبر الهاتف أو واتساب بسهولة.',
    ),
    _FeatureData(
      icon: Icons.rocket_launch_rounded,
      title: 'سريع',
      description:
          'ابحث حسب المدينة أو نوع العقار أو رقم الإعلان للوصول إلى النتائج بسرعة.',
    ),
    _FeatureData(
      icon: Icons.stars_rounded,
      title: 'مميز',
      description:
          'اكتشف العقارات المميزة والأحدث لتتمكن من المقارنة والاختيار بثقة.',
    ),
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth >= 700 ? 24.0 : 16.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          24,
          horizontalPadding,
          38,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PremiumHeading(),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 6.0;
                final cellWidth =
                    (constraints.maxWidth - gap * (_features.length - 1)) /
                        _features.length;
                final iconSize = (cellWidth - 12).clamp(48.0, 70.0).toDouble();

                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(_features.length, (index) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: index == _features.length - 1 ? 0 : gap,
                            ),
                            child: _AnimatedFeature(
                              data: _features[index],
                              progress: _controller.value,
                              phase: index / _features.length,
                              iconSize: iconSize,
                              onTap: () => _showFeatureDialog(
                                context,
                                _features[index],
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 34),
            const _PremiumFooter(),
          ],
        ),
      ),
    );
  }

  void _showFeatureDialog(BuildContext context, _FeatureData feature) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withValues(alpha: .68),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, _, __) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Center(
              child: Builder(
                builder: (context) {
                  final diameter = math.min(
                    MediaQuery.sizeOf(context).width - 70,
                    260.0,
                  );

                  return Material(
                    color: Colors.transparent,
                    child: Container(
                      width: diameter,
                      height: diameter,
                      padding: EdgeInsets.all(diameter * .10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xff0F172A),
                        border: Border.all(
                          color: _gold.withValues(alpha: .45),
                          width: 1.4,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: diameter * .18,
                            height: diameter * .18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_lightGold, _gold],
                              ),
                            ),
                            child: Icon(
                              feature.icon,
                              color: const Color(0xff111827),
                              size: diameter * .085,
                            ),
                          ),
                          SizedBox(height: diameter * .035),
                          Text(
                            feature.title,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: diameter * .055,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: diameter * .018),
                          Flexible(
                            child: Text(
                              feature.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                          SizedBox(height: diameter * .025),
                          SizedBox(
                            width: diameter * .32,
                            height: diameter * .105,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: FilledButton.styleFrom(
                                backgroundColor: _gold,
                                foregroundColor: Colors.black,
                                shape: const StadiumBorder(),
                              ),
                              child: const Text(
                                'حسنًا',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }
}

class _PremiumHeading extends StatelessWidget {
  const _PremiumHeading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3.5,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xffF8D86B), Color(0xffD4AF37)],
                ),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Text(
                'لماذا عقارات الانبار؟',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.only(right: 15),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              'منصة عقارية موثوقة وسريعة، صُممت لتجعل رحلتك أسهل.',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedFeature extends StatelessWidget {
  final _FeatureData data;
  final double progress;
  final double phase;
  final double iconSize;
  final VoidCallback onTap;

  const _AnimatedFeature({
    required this.data,
    required this.progress,
    required this.phase,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cycle = (progress + phase) % 1.0;
    final wave = math.sin(cycle * math.pi * 2);
    final lift = wave * 2.2;
    final shineX = -iconSize + cycle * iconSize * 2.4;

    return Semantics(
      button: true,
      label: data.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: _WhyAqarSectionState._gold.withValues(alpha: .10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, lift),
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  padding: const EdgeInsets.all(1.4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _WhyAqarSectionState._lightGold,
                        _WhyAqarSectionState._gold,
                        Color(0xff705817),
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xff293A52), Color(0xff121C2D)],
                              ),
                            ),
                          ),
                        ),
                        Icon(
                          data.icon,
                          color: _WhyAqarSectionState._lightGold,
                          size: iconSize * .43,
                        ),
                        Transform.translate(
                          offset: Offset(shineX, 0),
                          child: Transform.rotate(
                            angle: -.35,
                            child: Container(
                              width: iconSize * .13,
                              height: iconSize * 1.2,
                              color: Colors.white.withValues(alpha: .13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: iconSize < 56 ? 12 : 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumFooter extends StatelessWidget {
  const _PremiumFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: Colors.white.withValues(alpha: .10)),
        const SizedBox(height: 15),
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'عقارات الانبار • لأن العثور على العقار المناسب يجب أن يكون أسهل',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12.5,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '© 2026 Aqar Al-Anbar',
          style: TextStyle(color: Colors.white30, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
