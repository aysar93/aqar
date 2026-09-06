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
            const Center(
              child: Icon(
                Icons.gavel_rounded,
                color: Color(0xffD4AF37),
                size: 45,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "شروط الاستخدام",
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
                      "١. قبول الشروط",
                      "باستخدامك لتطبيق عقارات الانبار فإنك تقر بقراءة هذه الشروط والأحكام وتوافق على الالتزام بها. وإذا كنت لا توافق على أي جزء منها، فيرجى عدم استخدام التطبيق أو خدماته",
                    ),
                    _term(
                      "٢. مسؤولية المستخدم",
                      "يتحمل المستخدم كامل المسؤولية عن صحة المعلومات والصور والأسعار ووسائل التواصل التي يقوم بإدخالها، ويقر بأن جميع البيانات المنشورة صحيحة ولا تنتهك حقوق الآخرين",
                    ),
                    _term(
                      "٣. الإعلانات العقارية",
                      "يجب أن تكون جميع الإعلانات المنشورة حقيقية وتعبر عن العقار المعروض بدقة، ويمنع نشر أي إعلان مضلل أو يحتوي على معلومات غير صحيحة أو صور لا تعود للعقار",
                    ),
                    _term(
                      "٤. الاستخدام الممنوع",
                      "يُمنع استخدام التطبيق لنشر محتوى مخالف للقانون أو الآداب العامة، أو نشر إعلانات وهمية أو مكررة بشكل متعمد، أو استخدام التطبيق للإساءة إلى الآخرين أو محاولة تعطيل خدماته",
                    ),
                    _term(
                      "٥. تعديل الشروط",
                      "تحتفظ إدارة التطبيق بحق تعديل شروط الاستخدام أو إضافة بنود جديدة في أي وقت بما يتوافق مع تطوير الخدمات أو المتطلبات القانونية، ويُعد استمرار استخدام التطبيق بعد نشر التعديلات موافقة عليها",
                    ),
                    _term(
                      "٦. صلاحيات إدارة التطبيق",
                      "تحتفظ إدارة التطبيق بحق مراجعة الإعلانات المنشورة وتعديلها أو إخفائها أو حذفها إذا تبين أنها تخالف شروط الاستخدام أو القوانين النافذة، كما يحق لها اتخاذ الإجراءات المناسبة للحفاظ على جودة المحتوى وسلامة المستخدمين",
                    ),
                    _term(
                      "٧. تعليق أو حذف الحساب",
                      "يجوز لإدارة التطبيق تعليق أو إيقاف أو حذف أي حساب يثبت استخدامه للتطبيق بصورة مخالفة لشروط الاستخدام أو لأغراض احتيالية أو غير قانونية، دون الإخلال بأي حقوق قانونية أخرى",
                    ),
                    _term(
                      "٨. حدود المسؤولية",
                      "يعمل تطبيق عقارات الانبار كمنصة إلكترونية لعرض الإعلانات العقارية والتواصل بين المستخدمين، ولا يكون طرفاً في عمليات البيع أو الشراء أو الإيجار، ولا يتحمل أي مسؤولية عن الاتفاقات أو النزاعات أو الخسائر التي قد تنشأ بين الأطراف",
                    ),
                    _term(
                      "٩. الملكية الفكرية",
                      "جميع حقوق التطبيق، بما في ذلك التصميم والبرمجيات والشعار والمحتوى الذي تنتجه إدارة التطبيق، محفوظة. ولا يجوز نسخها أو إعادة استخدامها أو توزيعها دون الحصول على موافقة خطية مسبقة",
                    ),
                    _term(
                      "١٠. القانون المطبق",
                      "تخضع هذه الشروط وتفسر وفقاً للقوانين النافذة في جمهورية العراق، وتكون المحاكم العراقية المختصة هي الجهة المختصة بالنظر في أي نزاع ينشأ عن استخدام التطبيق، ما لم ينص القانون على خلاف ذلك",
                    ),
                  ],
                ),
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
