import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/property_request_data.dart';
import 'steps/step1_request_type.dart';
import 'steps/step2_property_type.dart';
import 'steps/step3_location.dart';
import 'steps/step4_requirements.dart';
import 'steps/step5_contact.dart';

class PropertyRequestScreen extends StatefulWidget {
  const PropertyRequestScreen({
    super.key,
  });

  @override
  State<PropertyRequestScreen> createState() => _PropertyRequestScreenState();
}

class _PropertyRequestScreenState extends State<PropertyRequestScreen> {
  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);
  static const Color _card = Color(0xff1E293B);

  final PageController _pageController = PageController();

  final PropertyRequestData request = PropertyRequestData();

  static const int totalSteps = 5;

  int currentStep = 0;
  bool isPublishing = false;

  // ==================================================
  // التالي
  // ==================================================

  void nextStep() {
    FocusScope.of(context).unfocus();

    if (!_validateCurrentStep()) {
      return;
    }

    if (currentStep >= totalSteps - 1) {
      return;
    }

    setState(() {
      currentStep++;
    });

    _pageController.animateToPage(
      currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  // ==================================================
  // الرجوع
  // ==================================================

  void previousStep() {
    FocusScope.of(context).unfocus();

    if (currentStep <= 0) {
      return;
    }

    setState(() {
      currentStep--;
    });

    _pageController.animateToPage(
      currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  // ==================================================
  // التحقق من الخطوة الحالية
  // ==================================================

  bool _validateCurrentStep() {
    switch (currentStep) {
      case 0:
        if (request.requestType == null ||
            request.requestType!.trim().isEmpty) {
          _showMessage(
            "اختر نوع الطلب: شراء أو إيجار",
          );
          return false;
        }

        return true;

      case 1:
        if (request.propertyType == null ||
            request.propertyType!.trim().isEmpty) {
          _showMessage(
            "اختر نوع العقار المطلوب",
          );
          return false;
        }

        return true;

      case 2:
        if (request.city.trim().isEmpty) {
          _showMessage(
            "اختر المدينة",
          );
          return false;
        }

        if (request.district.trim().isEmpty) {
          _showMessage(
            "اختر المنطقة",
          );
          return false;
        }

        return true;

      case 3:
        if (!request.hasValidAreaRange) {
          _showMessage(
            "المساحة القصوى يجب أن تكون أكبر من أو تساوي المساحة الدنيا",
          );
          return false;
        }

        if (!request.hasValidPriceRange) {
          _showMessage(
            "الحد الأعلى للميزانية يجب أن يكون أكبر من أو يساوي الحد الأدنى",
          );
          return false;
        }

        return true;

      case 4:
        if (request.phone.trim().isEmpty) {
          _showMessage(
            "أدخل رقم الهاتف",
          );
          return false;
        }

        if (!_isValidPhone(request.phone)) {
          _showMessage(
            "يرجى إدخال رقم هاتف صحيح",
          );
          return false;
        }

        if (request.whatsapp.trim().isNotEmpty &&
            !_isValidPhone(request.whatsapp)) {
          _showMessage(
            "يرجى إدخال رقم واتساب صحيح",
          );
          return false;
        }

        return true;

      default:
        return true;
    }
  }

  // ==================================================
  // نشر الطلب
  // ==================================================

  Future<void> publishRequest() async {
    if (isPublishing) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_validateCurrentStep()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        "يجب تسجيل الدخول لإرسال طلب عقار",
      );
      return;
    }

    request.clearFieldsNotUsedByPropertyType();

    setState(() {
      isPublishing = true;
    });

    try {
      final effectiveWhatsapp = request.whatsapp.trim().isEmpty
          ? request.phone.trim()
          : request.whatsapp.trim();

      final counterRef = FirebaseFirestore.instance
          .collection('settings')
          .doc('property_requests');

      final nextRequestNumber =
          await FirebaseFirestore.instance.runTransaction<int>(
        (transaction) async {
          final snapshot = await transaction.get(counterRef);

          int lastNumber = 0;

          if (snapshot.exists) {
            final storedValue = snapshot.data()?['lastNumber'];

            if (storedValue is num) {
              lastNumber = storedValue.toInt();
            }
          }

          final newNumber = lastNumber + 1;

          transaction.set(
            counterRef,
            {
              'lastNumber': newNumber,
            },
            SetOptions(merge: true),
          );

          return newNumber;
        },
      );

      await FirebaseFirestore.instance.collection("property_requests").add({
        // ==============================================
        // الطلب
        // ==============================================

        "requestType": request.requestType,
        "propertyType": request.propertyType,
        "requestNumber": nextRequestNumber,

        // ==============================================
        // الموقع
        // ==============================================

        "city": request.city.trim(),
        "district": request.district.trim(),
        "landmark": request.landmark.trim(),

        // ==============================================
        // المساحة
        // ==============================================

        "minArea": request.minArea,
        "maxArea": request.maxArea,

        // ==============================================
        // الميزانية
        // ==============================================

        "minPrice": request.minPrice,
        "maxPrice": request.maxPrice,

        // ==============================================
        // المواصفات
        // ==============================================

        "rooms": request.rooms,
        "bathrooms": request.bathrooms,
        "livingRooms": request.livingRooms,
        "parking": request.parking,

        "minFloors": request.minFloors,
        "maxFloors": request.maxFloors,
        "apartmentFloor": request.apartmentFloor,

        "description": request.description.trim(),

        // ==============================================
        // التواصل
        // ==============================================

        "phone": request.phone.trim(),
        "whatsapp": effectiveWhatsapp,

        // ==============================================
        // صاحب الطلب
        // ==============================================

        "userId": user.uid,
        "publisherUid": user.uid,
        "publisherEmail": user.email ?? "",
        "publisherName": user.displayName ?? "",

        // ==============================================
        // حالة الطلب
        // ==============================================

        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        isPublishing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "تم إرسال طلب العقار للمراجعة بنجاح",
          ),
        ),
      );

      await Future.delayed(
        const Duration(milliseconds: 900),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isPublishing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "حدث خطأ أثناء إرسال الطلب: $e",
          ),
        ),
      );
    }
  }

  // ==================================================
  // التحقق من رقم الهاتف
  // ==================================================

  bool _isValidPhone(String value) {
    final phone = value.trim();

    if (RegExp(r'^07\d{9}$').hasMatch(phone)) {
      return true;
    }

    if (RegExp(r'^\+9647\d{9}$').hasMatch(phone)) {
      return true;
    }

    return false;
  }

  // ==================================================
  // رسالة
  // ==================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ==================================================
  // العنوان حسب الخطوة
  // ==================================================

  String get _stepTitle {
    switch (currentStep) {
      case 0:
        return "نوع الطلب";

      case 1:
        return "نوع العقار";

      case 2:
        return "الموقع";

      case 3:
        return "المواصفات";

      case 4:
        return "التواصل";

      default:
        return "اطلب عقارًا";
    }
  }

  // ==================================================
  // الواجهة
  // ==================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isPublishing,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: Colors.white,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "اطلب عقارًا",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _stepTitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ==========================================
              // مؤشر التقدم
              // ==========================================

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: (currentStep + 1) / totalSteps,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _gold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "الخطوة ${currentStep + 1} من $totalSteps",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 6),

              // ==========================================
              // الخطوات
              // ==========================================

              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Step1RequestType(
                      request: request,
                      onChanged: () {
                        setState(() {});
                      },
                    ),
                    Step2PropertyType(
                      request: request,
                      onChanged: () {
                        setState(() {});
                      },
                    ),
                    Step3Location(
                      request: request,
                      onChanged: () {
                        setState(() {});
                      },
                    ),
                    Step4Requirements(
                      request: request,
                      onChanged: () {
                        setState(() {});
                      },
                    ),
                    Step5Contact(
                      request: request,
                      onChanged: () {
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),

              // ==========================================
              // الأزرار السفلية
              // ==========================================

              Container(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  16,
                ),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(
                        alpha: 0.05,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (currentStep > 0)
                      Expanded(
                        child: SizedBox(
                          height: 55,
                          child: OutlinedButton(
                            onPressed: isPublishing ? null : previousStep,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _gold,
                              side: const BorderSide(
                                color: _gold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  18,
                                ),
                              ),
                            ),
                            child: const Text(
                              "رجوع",
                              style: TextStyle(
                                color: _gold,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: isPublishing
                              ? null
                              : () {
                                  if (currentStep == totalSteps - 1) {
                                    publishRequest();
                                  } else {
                                    nextStep();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _background,
                            disabledBackgroundColor: _gold.withValues(
                              alpha: 0.45,
                            ),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                18,
                              ),
                            ),
                          ),
                          child: isPublishing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: _background,
                                  ),
                                )
                              : Text(
                                  currentStep == totalSteps - 1
                                      ? "إرسال الطلب"
                                      : "التالي",
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
