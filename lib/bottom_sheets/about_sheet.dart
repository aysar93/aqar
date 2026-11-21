import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/app_stats_service.dart';
import '../widgets/app_stats/app_stats_card.dart';

/// Uses the existing stats service for properties, but reads the users count
/// directly from Firestore so it cannot remain stuck on a stale public value.
class _DynamicUsersAppStatsService extends AppStatsService {
  final FirebaseFirestore _firestore;

  _DynamicUsersAppStatsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(firestore: firestore);

  @override
  Future<int> getUsersCount() async {
    final snapshot = await _firestore.collection('users').count().get();
    return snapshot.count ?? 0;
  }
}

void showAboutSheet(BuildContext context) {
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
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFC5A16B),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC5A16B).withValues(alpha: 0.18),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "عقارات الانبار",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffC5A16B),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AppStatsCard(
                  service: _DynamicUsersAppStatsService(),
                ),
              ),
              const SizedBox(height: 26),
              Divider(
                height: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "من نحن؟",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "عقارات الانبار هو تطبيق ومنصة رقمية متخصصة في عرض وتسويق العقارات داخل محافظة الأنبار، صُمم لتوفير تجربة سهلة وآمنة تجمع بين المالك، والمكاتب العقارية، والباحثين عن العقارات في مكان واحد.\n\n"
                        "يتيح التطبيق للمستخدمين استعراض العقارات، والبحث عنها باستخدام خيارات متقدمة، ونشر الإعلانات العقارية، والتواصل المباشر مع المعلنين، وإدارة إعلاناتهم بكل سهولة، مما يجعل عمليات البيع والشراء والإيجار أكثر سرعة ووضوحاً",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "رؤيتنا",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "أن نكون المنصة العقارية الرقمية الأولى في محافظة الأنبار، مع التوسع مستقبلاً لتغطية جميع المحافظات العراقية، من خلال تقديم خدمات احترافية تسهّل الوصول إلى العقار المناسب وتعزز الثقة بين جميع الأطراف",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "رسالتنا",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "نسعى إلى تطوير سوق العقارات الرقمي عبر توفير منصة حديثة تعتمد على سهولة الاستخدام، والشفافية، وسرعة الوصول إلى المعلومات، مع الاستمرار في تحسين خدماتنا وتقديم تجربة موثوقة تلبي احتياجات جميع المستخدمين",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "خدماتنا",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xffC5A16B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "عرض العقارات للبيع والإيجار",
                              style:
                                  TextStyle(color: textSecondary, height: 1.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xffC5A16B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "نشر الإعلانات العقارية بسهولة",
                              style:
                                  TextStyle(color: textSecondary, height: 1.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xffC5A16B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "البحث والتصفية حسب المدينة ونوع العقار والسعر",
                              style:
                                  TextStyle(color: textSecondary, height: 1.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xffC5A16B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "حفظ العقارات في قائمة المفضلة",
                              style:
                                  TextStyle(color: textSecondary, height: 1.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xffC5A16B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "التواصل المباشر مع المعلن عبر الهاتف أو واتساب أو الدردشة داخل التطبيق",
                              style:
                                  TextStyle(color: textSecondary, height: 1.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xffC5A16B), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "إدارة الإعلانات الشخصية وتلقي الإشعارات الفورية",
                              style:
                                  TextStyle(color: textSecondary, height: 1.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        "إخلاء المسؤولية",
                        style: TextStyle(
                          color: Color(0xffC5A16B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "يعمل تطبيق عقارات الانبار كمنصة إلكترونية لعرض الإعلانات العقارية وتسهيل التواصل بين المستخدمين. ولا يُعد التطبيق طرفاً في عمليات البيع أو الشراء أو الإيجار، ولا يتحمل أي مسؤولية عن الاتفاقات أو الالتزامات أو النزاعات التي قد تنشأ بين الأطراف.\n\n"
                        "تقع مسؤولية التحقق من صحة بيانات العقار، والأسعار، والوثائق، وحالة العقار على المستخدم قبل إتمام أي معاملة",
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: textSecondary,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    "الإصدار 1.0.5",
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
      );
    },
  );
}
