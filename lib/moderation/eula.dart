import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../bottom_sheets/terms_sheet.dart';
import '../bottom_sheets/contact_sheet.dart';

const eulaVersion = '2026-09-27';
const safetyTerms =
    'لا نتسامح مطلقاً مع المحتوى المسيء أو المستخدمين المسيئين. '
    'يُحظر نشر الإباحة والعنف والتهديد والكراهية والتحرش والاحتيال وانتهاك حقوق الآخرين، '
    'في الإعلانات والصور والتعليقات والتقييمات والرسائل. '
    'نراجع البلاغات خلال 24 ساعة ونزيل المحتوى المخالف ونوقف حسابات المخالفين. '
    'يمكنك الإبلاغ عن المحتوى وحظر ناشره من داخل التطبيق؛ يختفي محتواه عنك فوراً ويصل بلاغ للإدارة. '
    'للتواصل بشأن السلامة: الهاتف أو واتساب +9647838081677.';

class EulaConsent extends StatelessWidget {
  const EulaConsent(
      {super.key, required this.accepted, required this.onChanged});
  final bool accepted;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('اتفاقية ترخيص المستخدم النهائي (EULA)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const Text(safetyTerms),
        Wrap(children: [
          TextButton(
              onPressed: () => showTermsSheet(context),
              child: const Text('شروط الاستخدام')),
          TextButton(
              onPressed: () => showContactSheet(context),
              child: const Text('التواصل مع الإدارة')),
        ]),
        CheckboxListTile(
            value: accepted,
            onChanged: onChanged == null ? null : (v) => onChanged!(v == true),
            title: const Text('قرأت شروط الاستخدام وأوافق عليها صراحة'),
            controlAffinity: ListTileControlAffinity.leading),
      ]);
}

Future<void> recordEulaConsent() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw StateError('يجب تسجيل الدخول');
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('consents')
      .doc(eulaVersion)
      .set({
    'version': eulaVersion,
    'accepted': true,
    'acceptedAt': FieldValue.serverTimestamp(),
  });
}

/// Returning users must accept the current version before using their account.
class SessionConsentGate extends StatefulWidget {
  const SessionConsentGate({super.key, required this.child});
  final Widget child;
  @override
  State<SessionConsentGate> createState() => _SessionConsentGateState();
}

class _SessionConsentGateState extends State<SessionConsentGate> {
  bool loading = true, accepted = false, saved = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        saved = true;
        loading = false;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('consents')
          .doc(eulaVersion)
          .get();
      if (mounted)
        setState(() {
          saved = doc.data()?['accepted'] == true;
          loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'تعذر تحميل الموافقة. يمكنك إعادة الموافقة وحفظها.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (saved) return widget.child;
    return Scaffold(
        appBar: AppBar(title: const Text('شروط الاستخدام')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  EulaConsent(
                      accepted: accepted,
                      onChanged:
                          saving ? null : (v) => setState(() => accepted = v)),
                  if (error != null) Text(error!),
                  FilledButton(
                      onPressed: !accepted || saving
                          ? null
                          : () async {
                              setState(() => saving = true);
                              try {
                                await recordEulaConsent();
                                if (mounted) setState(() => saved = true);
                              } catch (_) {
                                if (mounted)
                                  setState(() => error =
                                      'تعذر حفظ الموافقة. تحقق من الاتصال وأعد المحاولة.');
                              } finally {
                                if (mounted) setState(() => saving = false);
                              }
                            },
                      child: const Text('الموافقة والمتابعة')),
                ])));
  }
}

/// Only used to complete a new federated account, never on app startup.
Future<bool> showNewAccountConsent(BuildContext context) async {
  var accepted = false;
  return await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: const Text('إنشاء حساب جديد'),
                  content: SingleChildScrollView(
                      child: EulaConsent(
                          accepted: accepted,
                          onChanged: (value) =>
                              setState(() => accepted = value))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء')),
                    FilledButton(
                        onPressed: accepted
                            ? () => Navigator.pop(context, true)
                            : null,
                        child: const Text('الموافقة وإنشاء الحساب')),
                  ],
                )),
      ) ??
      false;
}
