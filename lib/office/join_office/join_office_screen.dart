import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/join_office_data.dart';
import '../../services/cloudinary_service.dart';
import 'step1_office_info.dart';
import 'step2_contact.dart';
import 'step3_location.dart';
import 'step4_description.dart';
import 'step5_review.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JoinOfficeScreen extends StatefulWidget {
  const JoinOfficeScreen({super.key});

  @override
  State<JoinOfficeScreen> createState() => _JoinOfficeScreenState();
}

class _JoinOfficeScreenState extends State<JoinOfficeScreen> {
  final PageController _pageController = PageController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final JoinOfficeData _data;

  int _currentStep = 0;
  bool _isSubmitting = false;

  static const int _totalSteps = 5;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    _data = JoinOfficeData(
      ownerId: user?.uid ?? '',
      email: user?.email ?? '',
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _nextStep() async {
    if (_isSubmitting) return;

    if (!_validateCurrentStep()) {
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      if (mounted) {
        setState(() {
          _currentStep++;
        });
      }

      return;
    }

    await _submitRequest();
  }

  Future<void> _previousStep() async {
    if (_isSubmitting) return;

    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
      return;
    }

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    if (mounted) {
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_data.name.trim().isEmpty) {
          _showMessage(
            'يرجى إدخال اسم المكتب',
          );
          return false;
        }

        if (_data.name.trim().length < 3) {
          _showMessage(
            'اسم المكتب قصير جدًا',
          );
          return false;
        }

        return true;

      case 1:
        if (_data.phone.trim().isEmpty && _data.whatsapp.trim().isEmpty) {
          _showMessage(
            'يرجى إدخال رقم الهاتف أو رقم واتساب',
          );
          return false;
        }

        return true;

      case 2:
        if (_data.city.trim().isEmpty) {
          _showMessage(
            'يرجى إدخال المدينة',
          );
          return false;
        }

        if (_data.address.trim().isEmpty) {
          _showMessage(
            'يرجى إدخال عنوان المكتب',
          );
          return false;
        }

        return true;

      case 3:
        if (_data.description.trim().isEmpty) {
          _showMessage(
            'يرجى كتابة وصف المكتب',
          );
          return false;
        }

        if (_data.description.trim().length < 20) {
          _showMessage(
            'يرجى كتابة وصف أكثر تفصيلًا',
          );
          return false;
        }

        return true;

      case 4:
        return true;

      default:
        return false;
    }
  }

  Future<void> _submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('يجب تسجيل الدخول أولاً');
      return;
    }

    if (_data.ownerId.isEmpty) {
      _data.ownerId = user.uid;
    }

    if (!_data.isReadyForSubmission) {
      _showMessage(
        'يرجى إكمال بيانات المكتب المطلوبة',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // إنشاء رقم طلب جديد
      final requestRef =
          FirebaseFirestore.instance.collection('officeRequests').doc();

      // =========================================================
// رفع صورة الترخيص إلى Cloudinary قبل حفظ الطلب
// =========================================================
      final licenseImagePath = _data.licenseImageUrl.trim();

      if (licenseImagePath.isNotEmpty &&
          !licenseImagePath.startsWith('http://') &&
          !licenseImagePath.startsWith('https://')) {
        final licenseFile = File(licenseImagePath);

        if (!await licenseFile.exists()) {
          throw Exception('لم يتم العثور على صورة الترخيص');
        }

        final uploadedLicenseUrl = await uploadToCloudinary(
          licenseFile,
        );

        if (uploadedLicenseUrl == null || uploadedLicenseUrl.trim().isEmpty) {
          throw Exception('فشل رفع صورة الترخيص');
        }

        // استبدال المسار المحلي برابط Cloudinary
        _data.licenseImageUrl = uploadedLicenseUrl;
      }

// تجهيز بيانات الطلب بعد رفع الصورة
      final data = _data.toFirestore();

// بيانات إضافية خاصة بطلب الانضمام
      data.addAll({
        'userId': user.uid,
        'ownerId': user.uid,
        'ownerName': user.displayName ?? '',
        'ownerEmail': user.email ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // إرسال الطلب إلى Firestore
      await requestRef.set(data);

      if (!mounted) return;

      _showMessage(
        'تم إرسال طلب المكتب بنجاح، وسيتم مراجعته من الإدارة',
      );

      // إغلاق شاشة طلب المكتب
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('❌ OFFICE REQUEST ERROR: $e');

      if (!mounted) return;

      _showMessage(
        'حدث خطأ أثناء إرسال طلب المكتب',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  String get _buttonText {
    if (_isSubmitting) {
      return 'جاري الإرسال...';
    }

    if (_currentStep == _totalSteps - 1) {
      return 'إرسال الطلب';
    }

    return 'التالي';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'طلب الانضمام كمكتب',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProgress(context),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Step1OfficeInfo(
                      data: _data,
                      onChanged: _onDataChanged,
                    ),
                    Step2Contact(
                      data: _data,
                      onChanged: _onDataChanged,
                    ),
                    Step3Location(
                      data: _data,
                      onChanged: _onDataChanged,
                    ),
                    Step4Description(
                      data: _data,
                      onChanged: _onDataChanged,
                    ),
                    Step5Review(
                      data: _data,
                    ),
                  ],
                ),
              ),
              _buildBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final progress = (_currentStep + 1) / _totalSteps;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'الخطوة ${_currentStep + 1} من $_totalSteps',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        18,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, -5),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(
                    0,
                    52,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
                child: const Text(
                  'السابق',
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _nextStep,
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  0,
                  52,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    16,
                  ),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                      ),
                    )
                  : Text(
                      _buttonText,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
