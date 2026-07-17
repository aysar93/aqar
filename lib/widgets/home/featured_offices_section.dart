import 'package:flutter/material.dart';

import '../../models/office_model.dart';
import '../../services/office_service.dart';

class FeaturedOfficesSection extends StatelessWidget {
  const FeaturedOfficesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OfficeModel>>(
      stream: OfficeService.featuredOffices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 185,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final offices = snapshot.data ?? [];

        if (offices.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "🏢 المكاتب العقارية",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: شاشة جميع المكاتب
                  },
                  child: const Text(
                    "عرض الكل",
                    style: TextStyle(
                      color: Color(0xffD4AF37),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            SizedBox(
              height: 185,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: offices.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final office = offices[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      // TODO: الانتقال إلى صفحة المكتب
                    },
                    child: Container(
                      width: 175,
                      decoration: BoxDecoration(
                        color: const Color(0xff1E293B),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white10,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      const Color(0xffD4AF37),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 34,
                                backgroundColor:
                                    const Color(0xffD4AF37),
                                backgroundImage:
                                    office.logo.isNotEmpty
                                        ? NetworkImage(
                                            office.logo,
                                          )
                                        : null,
                                child: office.logo.isEmpty
                                    ? const Icon(
                                        Icons.business,
                                        color: Colors.black,
                                        size: 34,
                                      )
                                    : null,
                              ),
                            ),

                            const SizedBox(height: 14),

                            Text(
                              office.name,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              "${office.propertyCount} عقار",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: office.verified
                                    ? const Color(
                                        0xffD4AF37,
                                      )
                                    : Colors.grey,
                                borderRadius:
                                    BorderRadius.circular(
                                  30,
                                ),
                              ),
                              child: Text(
                                office.verified
                                    ? "موثق"
                                    : "غير موثق",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),
          ],
        );
      },
    );
  }
}