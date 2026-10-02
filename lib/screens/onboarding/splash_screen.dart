import '../../analytics/services/app_activity_service.dart';
import 'dart:async';
import 'premium_splash.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';
import '../main_shell.dart';
import 'onboarding_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../app_updates/app_update_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _started = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller =
        AnimationController(vsync: this, duration: PremiumSplash.duration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) unawaited(_finish());
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    await precacheImage(const AssetImage('assets/images/logo.png'), context);
    if (!mounted) return;
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          android:
              const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
        ),
      );
      await _audioPlayer.setVolume(.32);
      await _audioPlayer.setSource(AssetSource('audio/premium_splash.wav'));
    } catch (_) {
      /* Audio is optional; never block startup on audio failure. */
    }
    if (!mounted) return;
    _controller.forward();
    unawaited(_audioPlayer.resume().catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _started && !_navigating) {
      if (_controller.value > 0 && !_controller.isCompleted) {
        _controller.forward();
        unawaited(
          _audioPlayer
              .seek(Duration(milliseconds: (_controller.value * 4600).round()))
              .then((_) => _audioPlayer.resume())
              .catchError((Object _) {}),
        );
      }
    } else if (state != AppLifecycleState.resumed) {
      _controller.stop();
      unawaited(_audioPlayer.pause().catchError((Object _) {}));
    }
  }

  Future<void> _finish() async {
    if (_navigating || !mounted) return;
    _navigating = true;
    bool seen = false;
    try {
      seen =
          (await SharedPreferences.getInstance()).getBool('onboarding_seen') ??
              false;
    } catch (_) {
      /* Default to onboarding when preferences are unavailable. */
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) =>
            seen ? const AuthGate() : const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PremiumSplash.background,
        body: PremiumSplash(animation: _controller),
      );
}

// بوابة الدخول الحالية
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges().where(
            (user) => user == null || !LoginScreen.completingSocialSignIn,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get()
                .then((document) => document.data()),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (userSnapshot.data?['isBlocked'] == true) {
                AppActivityService.instance.signOut();
                return const LoginScreen();
              }
              return const AppUpdateGate(child: MainShell());
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}
