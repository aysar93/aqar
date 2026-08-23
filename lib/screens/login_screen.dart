import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/user_provider.dart';
import '../services/apple_auth_service.dart';
import '../services/facebook_auth_service.dart';
import '../services/google_auth_service.dart';
import '../services/password_auth_service.dart';
import '../services/user_service.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _rememberKey = 'remember_login_identifier';
  static const _identifierKey = 'saved_login_identifier';
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = false;
  bool _showRecovery = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _restoreRememberedIdentifier();
  }

  Future<void> _restoreRememberedIdentifier() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rememberMe = preferences.getBool(_rememberKey) ?? false;
      if (_rememberMe) {
        _identifierController.text =
            preferences.getString(_identifierKey) ?? '';
      }
    });
  }

  Future<void> _saveRememberPreference() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberKey, _rememberMe);
    if (_rememberMe) {
      await preferences.setString(
        _identifierKey,
        _identifierController.text.trim(),
      );
    } else {
      await preferences.remove(_identifierKey);
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = '';
      _showRecovery = false;
    });
    try {
      final credential = await PasswordAuthService.signIn(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
      if (credential.user != null) {
        await UserService.completeSignIn(credential.user!);
      }
      await _saveRememberPreference();
      if (!mounted) return;
      await context.read<UserProvider>().refresh();
      if (!mounted) return;
      _openApp();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.message;
        _showRecovery = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _socialLogin(
    Future<dynamic> Function() signIn,
    String provider,
  ) async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final result = await signIn();
      if (result == null) return;
      await UserService.createOrUpdateSocialUser(result.user!);
      await UserService.completeSignIn(result.user!);
      if (!mounted) return;
      await context.read<UserProvider>().refresh();
      if (!mounted) return;
      _openApp();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تسجيل الدخول بواسطة $provider');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openApp() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  Future<void> _contactSupport() async {
    final identifier = _identifierController.text.trim().isEmpty
        ? 'غير مذكور'
        : _identifierController.text.trim();
    final message = '''السلام عليكم، فريق إدارة تطبيق عقارات الأنبار.

أواجه مشكلة في تسجيل الدخول، ويبدو أنني نسيت كلمة المرور.

بيانات الحساب التي استخدمتها:
رقم الهاتف أو البريد الإلكتروني: $identifier

أرجو مساعدتي في التحقق من ملكية الحساب واستعادة إمكانية الدخول إليه. وأنا مستعد لتقديم المعلومات اللازمة للتحقق من هويتي.

شكرًا لكم.''';
    final uri = Uri.parse(
      'https://wa.me/9647838081677?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح واتساب. تواصل مع الإدارة على 07838081677'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset('assets/images/logo.png', height: 112),
                          const SizedBox(height: 16),
                          Text(
                            'مرحبا بعودتك',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'سجّل الدخول لمتابعة حسابك العقاري',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _identifierController,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف أو البريد الإلكتروني',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) => (value?.trim().isEmpty ??
                                    true)
                                ? 'يرجى إدخال رقم الهاتف أو البريد الإلكتروني'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) {
                              if (!_loading) _login();
                            },
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'إظهار كلمة المرور'
                                    : 'إخفاء كلمة المرور',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: (value) => (value?.isEmpty ?? true)
                                ? 'يرجى إدخال كلمة المرور'
                                : null,
                          ),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: _loading
                                    ? null
                                    : (value) {
                                        setState(
                                          () => _rememberMe = value ?? false,
                                        );
                                      },
                              ),
                              const Text('تذكرني'),
                              const Spacer(),
                              TextButton(
                                onPressed: _contactSupport,
                                child: const Text('هل نسيت كلمة المرور؟'),
                              ),
                            ],
                          ),
                          if (_error.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(alpha: .5),
                                ),
                              ),
                              child: Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),
                            if (_showRecovery)
                              TextButton.icon(
                                onPressed: _contactSupport,
                                icon: const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  size: 18,
                                ),
                                label: const Text('استعادة الحساب عبر الإدارة'),
                              ),
                          ],
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    'تسجيل الدخول',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                            child: const Text('إنشاء حساب جديد'),
                          ),
                          TextButton.icon(
                            onPressed: _loading ? null : _openApp,
                            icon: const Icon(Icons.person_outline),
                            label: const Text('الدخول كضيف'),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('أو تابع بواسطة'),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : () => _socialLogin(
                                            GoogleAuthService.signInWithGoogle,
                                            'Google',
                                          ),
                                  icon: const FaIcon(
                                    FontAwesomeIcons.google,
                                    size: 18,
                                  ),
                                  label: const Text('Google'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : () => _socialLogin(
                                            FacebookAuthService
                                                .signInWithFacebook,
                                            'Facebook',
                                          ),
                                  icon: const FaIcon(
                                    FontAwesomeIcons.facebook,
                                    size: 18,
                                  ),
                                  label: const Text('Facebook'),
                                ),
                              ),
                            ],
                          ),
                          if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _socialLogin(
                                        AppleAuthService.signInWithApple,
                                        'Apple',
                                      ),
                              icon: const FaIcon(
                                FontAwesomeIcons.apple,
                                size: 20,
                              ),
                              label: const Text('المتابعة باستخدام Apple'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
