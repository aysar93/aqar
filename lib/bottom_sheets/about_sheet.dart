import 'package:flutter/material.dart';

void showAboutSheet(BuildContext context) {
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

              const CircleAvatar(
                radius: 35,
                backgroundColor: Color(0xffD4AF37),
                child: Icon(
                  Icons.home_work,
                  color: Colors.white,
                  size: 35,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "عقارات الأنبار",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffD4AF37),
                ),
              ),

              const Text(
                "الإصدار 1.0.0",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const Divider(height: 30),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: const [

                      Text(
                        "من نحن؟",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        "تطبيق عقارات الأنبار هو المنصة الرقمية المتخصصة في سوق العقارات داخل محافظة الأنبار، يربط بين الباحثين عن العقارات والملاك والمكاتب العقارية بطريقة سهلة وآمنة.",
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.justify,
                      ),

                      SizedBox(height: 20),

                      Text(
                        "رؤيتنا",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        "أن نكون المنصة العقارية الأولى في الأنبار ونساهم في تطوير السوق العقاري الرقمي.",
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),

                    ],
                  ),
                ),
              ),

              const Text(
                "جميع الحقوق محفوظة © عقارات الأنبار 2026",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}