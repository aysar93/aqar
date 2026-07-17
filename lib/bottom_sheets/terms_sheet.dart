import 'package:flutter/material.dart';

void showTermsSheet(BuildContext context) {
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

            const Text(
              "شروط وأحكام الاستخدام",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xffD4AF37),
              ),
            ),

            const Divider(height: 25),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _term(
                      "١. قبول الشروط:",
                      "باستخدامك لتطبيق عقارات الأنبار، فإنك توافق على الالتزام الكامل بهذه الشروط والأحكام والسياسات المتبعة لدينا.",
                    ),

                    _term(
                      "٢. صحة المعلومات:",
                      "يتعهد المعلن (سواء كان مالكاً أو مكتباً عقارياً) بأن تكون كافة البيانات والصور والأسعار المرفوعة للعقار صحيحة ودقيقة تماماً وعلى مسؤوليته القانونية.",
                    ),

                    _term(
                      "٣. حدود المسؤولية:",
                      "التطبيق هو وسيط رقمي يربط بين البائع والمشتري أو المؤجر والمستأجر، ولا نتحمل أي مسؤولية عن أي خلافات مالية أو قانونية ناتجة عن عمليات التعاقد والبيع.",
                    ),

                    _term(
                      "٤. الاستخدام العادل والمحظور:",
                      "يُحظر نشر أي إعلانات وهمية، أو عقارات مكررة بشكل عشوائي، أو استخدام لغة غير لائقة في وصف العقارات. يحق لإدارة التطبيق حظر أي حساب يخالف ذلك.",
                    ),

                    _term(
                      "٥. التحديثات والتعديلات:",
                      "تمتلك إدارة التطبيق كامل الحق في تعديل هذه الشروط أو تحديث الخدمات والميزات مستقبلاً مع إشعار المستخدمين بذلك.",
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _term(String title, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xffD4AF37),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          body,
          textAlign: TextAlign.justify,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}