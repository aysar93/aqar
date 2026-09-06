import 'package:flutter/material.dart';

void showPrivacySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xff1E293B),
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
                color: Color(0xffD4AF37),
                size: 45,
              ),
              const SizedBox(height: 12),
              const Text(
                "سياسة الخصوصية",
                style: TextStyle(
                  color: Color(0xffD4AF37),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "مقدمة",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "تلتزم منصة عقارات الانبار بحماية خصوصية مستخدميها واحترام سرية بياناتهم الشخصية. توضح هذه السياسة نوع المعلومات التي يتم جمعها، وكيفية استخدامها وحمايتها، والخيارات المتاحة للمستخدم فيما يتعلق ببياناته عند استخدام التطبيق",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.8,
                        ),
                      ),
                      SizedBox(height: 22),
                      Text(
                        "البيانات التي نجمعها",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "قد نجمع المعلومات التي يقدمها المستخدم عند إنشاء الحساب أو نشر إعلان عقاري، مثل الاسم، ورقم الهاتف، والبريد الإلكتروني، وصور العقار، والموقع الجغرافي للعقار، بالإضافة إلى أي معلومات يختار المستخدم إضافتها داخل الإعلان",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.8,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "قد نقوم بجمع بعض المعلومات التي يقدمها المستخدم مثل الاسم ورقم الهاتف والبريد الإلكتروني لغرض تحسين الخدمة وتسهيل التواصل بين المستخدمين",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: 22),
                      Text(
                        "كيفية استخدام البيانات",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "تُستخدم المعلومات التي يتم جمعها لتحسين تجربة المستخدم، وإدارة الحسابات، وعرض الإعلانات العقارية، وتمكين التواصل بين المعلنين والمهتمين بالعقارات، وإرسال الإشعارات المتعلقة بالخدمات والتحديثات، بالإضافة إلى تحسين أداء التطبيق وتطوير خدماته",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.8,
                        ),
                      ),
                      SizedBox(height: 22),
                      Text(
                        "حماية البيانات",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "نعمل على تطبيق إجراءات أمنية وتقنية مناسبة للمساعدة في حماية بيانات المستخدمين من الوصول غير المصرح به أو الاستخدام أو التعديل أو الإفصاح غير المشروع. ومع ذلك، لا يمكن ضمان الأمان الكامل لأي عملية نقل أو تخزين للبيانات عبر الإنترنت",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.8,
                        ),
                      ),
                      SizedBox(height: 22),
                      Text(
                        "مشاركة البيانات",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "لا نقوم ببيع أو تأجير أو مشاركة البيانات الشخصية للمستخدمين مع أي طرف ثالث لأغراض تجارية. وقد يتم مشاركة بعض المعلومات عند وجود التزام قانوني أو لحماية حقوق التطبيق ومستخدميه، أو عند استخدام خدمات تقنية موثوقة تدعم تشغيل التطبيق",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.8,
                        ),
                      ),
                      SizedBox(height: 22),
                      Text(
                        "حقوق المستخدم",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "يحق للمستخدم مراجعة بياناته الشخصية وتحديثها من خلال التطبيق، كما يمكنه طلب حذف حسابه أو التواصل مع إدارة التطبيق للاستفسار عن كيفية معالجة بياناته، وذلك وفقاً للأنظمة والقوانين المعمول بها",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.8,
                        ),
                      ),
                      SizedBox(height: 22),
                      Text(
                        "حذف الحساب",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "يمكن للمستخدم طلب حذف حسابه نهائياً. وعند تنفيذ طلب الحذف، يتم إزالة بيانات الحساب وفق آلية التطبيق، مع الاحتفاظ فقط بالبيانات التي يتطلب الاحتفاظ بها لأسباب قانونية أو أمنية إن وجدت",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.8,
                        ),
                      ),
                      SizedBox(height: 22),
                      Text(
                        "تحديث سياسة الخصوصية",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "قد يتم تحديث سياسة الخصوصية من وقت لآخر بما يتوافق مع تطوير خدمات التطبيق أو المتطلبات القانونية. وسيتم نشر أي تحديث داخل التطبيق، ويُعد استمرار استخدام التطبيق بعد نشر التعديلات موافقةً على السياسة المحدثة",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.8,
                        ),
                      ),
                      SizedBox(height: 25),
                      Column(
                        children: [
                          Text(
                            "آخر تحديث: يوليو 2026",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
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
