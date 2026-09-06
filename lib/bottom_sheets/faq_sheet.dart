import 'package:flutter/material.dart';

void showFaqSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24),
      ),
    ),
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xff1E293B),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Icon(
                Icons.quiz_rounded,
                color: Color(0xffD4AF37),
                size: 45,
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                "الأسئلة الشائعة",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffD4AF37),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                "إليك أكثر الأسئلة شيوعاً حول استخدام تطبيق عقارات الانبار",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
            ),
            const Divider(height: 30),
            Expanded(
              child: ListView(
                children: const [
                  _FaqTile(
                    question: "كيف أنشر عقارًا؟",
                    answer:
                        "بعد تسجيل الدخول اضغط على زر (اعرض)، ثم أدخل جميع بيانات العقار وأرسل الإعلان ليتم مراجعته قبل نشره",
                  ),
                  _FaqTile(
                    question: "هل نشر الإعلانات مجاني؟",
                    answer:
                        "نعم، يمكن نشر الإعلانات مجاناً وفق سياسة التطبيق، وقد تتم إضافة مزايا مدفوعة مستقبلاً للإعلانات المميزة",
                  ),
                  _FaqTile(
                    question: "متى يظهر إعلاني؟",
                    answer:
                        "بعد إرسال الإعلان تتم مراجعته من قبل إدارة التطبيق، ثم يتم نشره عند الموافقة عليه",
                  ),
                  _FaqTile(
                    question: "كيف أتواصل مع صاحب العقار؟",
                    answer:
                        "يمكنك التواصل من خلال أزرار الاتصال أو واتساب أو الدردشة الموجودة داخل صفحة تفاصيل العقار",
                  ),
                  _FaqTile(
                    question: "هل يمكنني تعديل أو حذف إعلاني؟",
                    answer:
                        "نعم، يمكنك إدارة إعلاناتك من قسم (إعلاناتي) داخل التطبيق، وتعديلها أو حذفها في أي وقت",
                  ),
                  _FaqTile(
                    question: "نسيت كلمة المرور، ماذا أفعل؟",
                    answer:
                        "استخدم خيار (نسيت كلمة المرور) في صفحة تسجيل الدخول واتبع التعليمات لإعادة تعيين كلمة المرور",
                  ),
                  _FaqTile(
                    question: "هل التطبيق مسؤول عن عمليات البيع والشراء؟",
                    answer:
                        "لا، تطبيق عقارات الانبار هو منصة إلكترونية لعرض الإعلانات والتواصل بين المستخدمين، ولا يعد طرفاً في أي عملية بيع أو شراء أو إيجار",
                  ),
                  _FaqTile(
                    question: "كيف أبلغ عن إعلان مخالف؟",
                    answer:
                        "يمكنك التواصل مع إدارة التطبيق من خلال صفحة (تواصل معنا)، وسيتم مراجعة البلاغ واتخاذ الإجراء المناسب",
                  ),
                  _FaqTile(
                    question: "هل بياناتي الشخصية آمنة؟",
                    answer:
                        "نعم، نحافظ على خصوصية بيانات المستخدمين وفق سياسة الخصوصية، ولا تتم مشاركة البيانات إلا عند الضرورة القانونية أو لتقديم الخدمة",
                  ),
                  _FaqTile(
                    question: "كيف أتواصل مع إدارة التطبيق؟",
                    answer:
                        "يمكنك التواصل عبر صفحة (تواصل معنا) باستخدام الاتصال أو واتساب خلال أوقات العمل الرسمية",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                "آخر تحديث: يوليو 2026",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                "© 2026 جميع الحقوق محفوظة - عقارات الانبار",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xff27364A),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          collapsedIconColor: const Color(0xffD4AF37),
          iconColor: const Color(0xffD4AF37),
          title: Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                textAlign: TextAlign.justify,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.7,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
