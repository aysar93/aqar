import 'package:flutter/material.dart';

import 'models/edit_property_data.dart';
import 'services/edit_property_service.dart';

import 'steps/edit_step1_ad_type.dart';
import 'steps/edit_step2_property_type.dart';
import 'steps/edit_step3_details.dart';
import 'steps/edit_step4_location.dart';
import 'steps/edit_step5_price.dart';
import 'steps/edit_step6_images.dart';
import 'steps/edit_step7_contact.dart';

class EditPropertyScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditPropertyScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  static const int totalSteps = 7;

  late EditPropertyData property;

  final EditPropertyService service = EditPropertyService();

  int currentStep = 0;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    property = EditPropertyData.fromMap(
      docId: widget.docId,
      map: widget.data,
    );
  }

  // =========================
  // تحديث الواجهة
  // =========================

  void propertyChanged() {
    if (!mounted) return;

    setState(() {});
  }

  // =========================
  // الانتقال للخطوة التالية
  // =========================

  void nextStep() {
    if (!_validateCurrentStep()) {
      return;
    }

    if (currentStep < totalSteps - 1) {
      setState(() {
        currentStep++;
      });
    }
  }

  // =========================
  // الرجوع للخطوة السابقة
  // =========================

  void previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });

      return;
    }

    Navigator.pop(context);
  }

  // =========================
  // التحقق من الخطوة الحالية
  // =========================

  bool _validateCurrentStep() {
    switch (currentStep) {
      // نوع الإعلان
      case 0:
        if (property.adType == null || property.adType!.trim().isEmpty) {
          _showMessage(
            'يرجى اختيار نوع الإعلان',
          );

          return false;
        }

        break;

      // نوع العقار
      case 1:
        if (property.propertyType == null ||
            property.propertyType!.trim().isEmpty) {
          _showMessage(
            'يرجى اختيار نوع العقار',
          );

          return false;
        }

        break;

      // التفاصيل
      case 2:
        if (property.title.trim().isEmpty) {
          _showMessage(
            'يرجى كتابة عنوان العقار',
          );

          return false;
        }

        if (property.area == null || property.area! <= 0) {
          _showMessage(
            'يرجى إدخال مساحة العقار',
          );

          return false;
        }

        break;

      // الموقع
      case 3:
        if (property.city.trim().isEmpty) {
          _showMessage(
            'يرجى إدخال المدينة',
          );

          return false;
        }

        if (property.district.trim().isEmpty) {
          _showMessage(
            'يرجى إدخال المنطقة',
          );

          return false;
        }

        break;

      // السعر
      case 4:
        if (property.price == null || property.price! <= 0) {
          _showMessage(
            'يرجى إدخال سعر صحيح',
          );

          return false;
        }

        break;

      // الصور
      case 5:
        final imageCount =
            property.existingImages.length + property.newImages.length;

        if (imageCount == 0) {
          _showMessage(
            'يرجى إضافة صورة واحدة على الأقل',
          );

          return false;
        }

        break;

      // الوصف والتواصل
      case 6:
        if (property.description.trim().isEmpty) {
          _showMessage(
            'يرجى كتابة وصف العقار',
          );

          return false;
        }

        if (property.phone.trim().isEmpty) {
          _showMessage(
            'يرجى إدخال رقم الهاتف',
          );

          return false;
        }

        break;
    }

    return true;
  }

  // =========================
  // حفظ التعديلات
  // =========================

  Future<void> saveChanges() async {
    if (!_validateCurrentStep()) {
      return;
    }

    if (saving) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await service.updateProperty(
        property,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ التعديلات وإرسال العقار للمراجعة',
            textAlign: TextAlign.right,
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      _showMessage(
        'حدث خطأ أثناء حفظ التعديلات',
      );
    }
  }

  // =========================
  // الرسائل
  // =========================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
        ),
      ),
    );
  }

  // =========================
  // محتوى الخطوة
  // =========================

  Widget _buildStep() {
    switch (currentStep) {
      case 0:
        return EditStep1AdType(
          property: property,
          onChanged: propertyChanged,
        );

      case 1:
        return EditStep2PropertyType(
          property: property,
          onChanged: propertyChanged,
        );

      case 2:
        return EditStep3Details(
          property: property,
          onChanged: propertyChanged,
        );

      case 3:
        return EditStep4Location(
          property: property,
          onChanged: propertyChanged,
        );

      case 4:
        return EditStep5Price(
          property: property,
          onChanged: propertyChanged,
        );

      case 5:
        return EditStep6Images(
          property: property,
          onChanged: propertyChanged,
        );

      case 6:
        return EditStep7Contact(
          property: property,
          onChanged: propertyChanged,
        );

      default:
        return const SizedBox();
    }
  }

  // =========================
  // عنوان الخطوة
  // =========================

  String get stepTitle {
    switch (currentStep) {
      case 0:
        return 'نوع الإعلان';

      case 1:
        return 'نوع العقار';

      case 2:
        return 'التفاصيل';

      case 3:
        return 'الموقع';

      case 4:
        return 'السعر';

      case 5:
        return 'الصور';

      case 6:
        return 'الوصف والتواصل';

      default:
        return '';
    }
  }

  // =========================
  // Build
  // =========================

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;

    return PopScope(
      canPop: !saving,
      child: Scaffold(
        backgroundColor: const Color(0xff0F172A),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: const Color(0xff0F172A),
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: saving ? null : previousStep,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
          ),
          title: Column(
            children: [
              const Text(
                'تعديل العقار',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stepTitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(
                right: 16,
              ),
              child: Center(
                child: Text(
                  '${currentStep + 1}/$totalSteps',
                  style: const TextStyle(
                    color: Color(0xffD4AF37),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // =========================
              // مؤشر التقدم
              // =========================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  4,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xffD4AF37),
                    ),
                  ),
                ),
              ),

              // =========================
              // الخطوة
              // =========================

              Expanded(
                child: AbsorbPointer(
                  absorbing: saving,
                  child: _buildStep(),
                ),
              ),

              // =========================
              // أزرار التنقل
              // =========================

              _bottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // شريط التنقل السفلي
  // =========================

  Widget _bottomNavigation() {
    final isLastStep = currentStep == totalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: .06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .20),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // =========================
            // السابق
            // =========================

            SizedBox(
              width: 110,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: saving ? null : previousStep,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 19,
                ),
                label: Text(
                  currentStep == 0 ? 'إلغاء' : 'السابق',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(
                    color: Colors.white24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // =========================
            // التالي / الحفظ
            // =========================

            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : isLastStep
                          ? saveChanges
                          : nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffD4AF37),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        const Color(0xffD4AF37).withValues(alpha: .45),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isLastStep
                                  ? Icons.save_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(
                              isLastStep ? 'حفظ التعديلات' : 'التالي',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
