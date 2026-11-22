import 'package:flutter/material.dart';

void showPrivacySheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textSecondary = isDark ? Colors.white70 : Colors.black87;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24),
      ),
    ),
    builder: (context) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(
                Icons.security,
                color: Color(0xffC5A16B),
                size: 45,
              ),
              const SizedBox(height: 12),
              const Text(
                "سياسة الخصوصية",
                style: TextStyle(
                  color: Color(0xffC5A16B),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "مقدمة",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "تلتزم منصة عقارات الانبار بحماية خصوصية مستخدميها واحترام سرية بياناتهم الشخصية. توضح هذه السياسة نوع المعلومات التي يتم جمعها، وكيفية استخدامها وحمايتها، والخيارات المتاحة للمستخدم فيما يتعلق ببياناته عند استخدام التطبيق",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "البيانات التي نجمعها",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "قد نجمع المعلومات التي يقدمها المستخدم عند إنشاء الحساب أو نشر إعلان عقاري، مثل الاسم، ورقم الهاتف، والبريد الإلكتروني، وصور العقار، والموقع الجغرافي للعقار، بالإضافة إلى أي معلومات يختار المستخدم إضافتها داخل الإعلان",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "قد نقوم بجمع بعض المعلومات التي يقدمها المستخدم مثل الاسم ورقم الهاتف والبريد الإلكتروني لغرض تحسين الخدمة وتسهيل التواصل بين المستخدمين",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "كيفية استخدام البيانات",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "تُستخدم المعلومات التي يتم جمعها لتحسين تجربة المستخدم، وإدارة الحسابات، وعرض الإعلانات العقارية، وتمكين التواصل بين المعلنين والمهتمين بالعقارات، وإرسال الإشعارات المتعلقة بالخدمات والتحديثات، بالإضافة إلى تحسين أداء التطبيق وتطوير خدماته",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "حماية البيانات",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "نعمل على تطبيق إجراءات أمنية وتقنية مناسبة للمساعدة في حماية بيانات المستخدمين من الوصول غير المصرح به أو الاستخدام أو التعديل أو الإفصاح غير المشروع. ومع ذلك، لا يمكن ضمان الأمان الكامل لأي عملية نقل أو تخزين للبيانات عبر الإنترنت",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "مشاركة البيانات",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "لا نقوم ببيع أو تأجير أو مشاركة البيانات الشخصية للمستخدمين مع أي طرف ثالث لأغراض تجارية. وقد يتم مشاركة بعض المعلومات عند وجود التزام قانوني أو لحماية حقوق التطبيق ومستخدميه، أو عند استخدام خدمات تقنية موثوقة تدعم تشغيل التطبيق",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "حقوق المستخدم",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "يحق للمستخدم مراجعة بياناته الشخصية وتحديثها من خلال التطبيق، كما يمكنه طلب حذف حسابه أو التواصل مع إدارة التطبيق للاستفسار عن كيفية معالجة بياناته، وذلك وفقاً للأنظمة والقوانين المعمول بها",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "حذف الحساب",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "يمكن للمستخدم طلب حذف حسابه نهائياً. وعند تنفيذ طلب الحذف، يتم إزالة بيانات الحساب وفق آلية التطبيق، مع الاحتفاظ فقط بالبيانات التي يتطلب الاحتفاظ بها لأسباب قانونية أو أمنية إن وجدت",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "تحديث سياسة الخصوصية",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "قد يتم تحديث سياسة الخصوصية من وقت لآخر بما يتوافق مع تطوير خدمات التطبيق أو المتطلبات القانونية. وسيتم نشر أي تحديث داخل التطبيق، ويُعد استمرار استخدام التطبيق بعد نشر التعديلات موافقةً على السياسة المحدثة",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 25),
                      Column(
                        children: [
                          Text(
                            "آخر تحديث: يوليو 2026",
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "© 2026 جميع الحقوق محفوظة - عقارات الانبار",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
