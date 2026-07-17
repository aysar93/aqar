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
                  borderRadius:
                      BorderRadius.circular(10),
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
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Text(
                        "مقدمة",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        "نحرص في تطبيق عقارات الأنبار على حماية خصوصية المستخدمين وتوفير بيئة آمنة لاستخدام التطبيق والخدمات العقارية المقدمة.",
                        textAlign:
                            TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),


                      SizedBox(height: 18),


                      Text(
                        "جمع المعلومات",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        "قد نقوم بجمع بعض المعلومات التي يقدمها المستخدم مثل الاسم ورقم الهاتف والبريد الإلكتروني لغرض تحسين الخدمة وتسهيل التواصل بين المستخدمين.",
                        textAlign:
                            TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),


                      SizedBox(height: 18),


                      Text(
                        "استخدام المعلومات",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        "تستخدم المعلومات لإدارة الحسابات، تحسين تجربة الاستخدام، وتمكين التواصل بين الباحثين عن العقارات والمعلنين.",
                        textAlign:
                            TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),


                      SizedBox(height: 18),


                      Text(
                        "حماية البيانات",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        "نتخذ الإجراءات المناسبة للحفاظ على أمان بيانات المستخدمين وعدم استخدامها خارج نطاق خدمات التطبيق.",
                        textAlign:
                            TextAlign.justify,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),


                      SizedBox(height: 25),


                      Center(
                        child: Text(
                          "جميع الحقوق محفوظة © عقارات الأنبار 2026",
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

            ],
          ),
        ),
      );
    },
  );
}