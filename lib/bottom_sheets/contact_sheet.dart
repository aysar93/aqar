import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _openUrl(
  BuildContext context,
  String urlString,
) async {
  final Uri url = Uri.parse(urlString);

  if (await canLaunchUrl(url)) {
    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "عذراً، لم نتمكن من فتح الرابط",
          ),
        ),
      );
    }
  }
}


void showContactSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xff1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24),
      ),
    ),
    builder: (context) {

      return Directionality(
        textDirection: TextDirection.rtl,

        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

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


              const Text(
                "يسعدنا تواصلك معنا",
                style: TextStyle(
                  color: Color(0xffD4AF37),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),


              const SizedBox(height: 25),


              Row(
                children: [


                  Expanded(
                    child: ElevatedButton.icon(
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.green,
                        foregroundColor:
                            Colors.white,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  16),
                        ),
                      ),

                      icon:
                          const Icon(Icons.chat),

                      label:
                          const Text(
                        "واتساب",
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),


                      onPressed: () {

                        _openUrl(
                          context,
                          "https://wa.me/9647838081677",
                        );

                      },
                    ),
                  ),


                  const SizedBox(width: 15),


                  Expanded(
                    child: ElevatedButton.icon(
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(
                                0xffD4AF37),

                        foregroundColor:
                            Colors.black,

                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  16),
                        ),
                      ),


                      icon:
                          const Icon(Icons.call),


                      label:
                          const Text(
                        "اتصال",
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),


                      onPressed: () {

                        _openUrl(
                          context,
                          "tel:07838081677",
                        );

                      },
                    ),
                  ),


                ],
              ),


              const SizedBox(height: 20),


              const Text(
                "مكتب الأندلس للعقارات\nالأنبار - الرمادي",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),


              const SizedBox(height: 10),

            ],
          ),

        ),
      );
    },
  );
}