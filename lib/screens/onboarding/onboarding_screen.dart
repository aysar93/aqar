import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController controller = PageController();

  late AnimationController _animationController;

  late Animation<double> _fadeAnimation;

  int currentPage = 0;

  final List<Map<String, String>> pages = [
    {
      "title": "عقارات الانبار ترحب بكم",
      "description": "المكان المناسب لجميع احتياجاتكم العقارية",
      "image": "assets/images/onboarding_1.png",
    },
    {
      "title": "اعرض عقارك للبيع",
      "description":
          "بيع عقارك عن طريق عقارات الأنبار في أسرع وقت وبأسهل طريقة ممكنة",
      "image": "assets/images/onboarding_2.png",
    },
    {
      "title": "تصفح عقارك من مكانك",
      "description": "يمكنك تصفح جميع أنواع العقارات أينما كنت من مكانك",
      "image": "assets/images/onboarding_3.png",
    },
  ];

  Future<void> finishIntro() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      "onboarding_seen",
      true,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });

                  _animationController.reset();

                  _animationController.forward();
                },
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          pages[index]["image"]!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          alignment: Alignment.center,
                        ),

                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.fromARGB(30, 0, 0, 0),
                                Color.fromARGB(120, 0, 0, 0),
                                Color(0xFF0F172A),
                              ],
                            ),
                          ),
                        ),

                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(30, 30, 30, 110),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pages[index]["title"]!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      height: 1.3,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 12,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    pages[index]["description"]!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      height: 1.7,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ), // نهاية Align
                        ), // نهاية SlideTransition
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: currentPage == index ? 28 : 8,
                    decoration: BoxDecoration(
                      color: currentPage == index
                          ? const Color(0xffD4AF37)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Row(
                children: [
                  if (currentPage == 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: finishIntro,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffD4AF37),
                          side: const BorderSide(
                            color: Color(0xffD4AF37),
                            width: 1.5,
                          ),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "تخطي",
                          style: TextStyle(
                            color: Color(0xffD4AF37),
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  if (currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          controller.previousPage(
                            duration: const Duration(milliseconds: 550),
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffD4AF37),
                          side: const BorderSide(
                            color: Color(0xffD4AF37),
                            width: 1.5,
                          ),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "السابق",
                          style: TextStyle(
                            color: Color(0xffD4AF37),
                          ),
                        ),
                      ),
                    ),
                  if (currentPage == 0) const SizedBox(width: 10),
                  if (currentPage > 0) const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (currentPage == pages.length - 1) {
                          finishIntro();
                        } else {
                          controller.nextPage(
                            duration: const Duration(milliseconds: 550),
                            curve: Curves.easeInOutCubic,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffD4AF37),
                        foregroundColor: Colors.black,
                        elevation: 8,
                        shadowColor: const Color(0xffD4AF37),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        currentPage == pages.length - 1 ? "متابعة" : "التالي",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();

    _animationController.dispose();

    super.dispose();
  }
}
