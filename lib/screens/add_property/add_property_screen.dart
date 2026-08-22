import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/add_property_data.dart';
import '../../services/cloudinary_service.dart';
import '../../utils/property_default_images.dart';

import 'step1_ad_type.dart';
import 'step2_property_type.dart';
import 'step3_details.dart';
import 'step4_location.dart';
import 'step5_price.dart';
import 'step6_images.dart';
import 'step7_contact.dart';
import 'package:aqar/office/services/office_service.dart';
import 'package:aqar/office/services/office_subscription_service.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final PageController pageController = PageController();
  final AddPropertyData property = AddPropertyData();

  int currentStep = 0;
  bool isPublishing = false;

  static const int totalSteps = 7;

  Future<void> _notifyOfficeFollowers({
    required String officeId,
    required String propertyId,
    required String officeName,
    required String propertyTitle,
    required String publisherUid,
  }) async {
    try {
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('office_followers')
          .where('officeId', isEqualTo: officeId)
          .where('isActive', isEqualTo: true)
          .get();

      if (followersSnapshot.docs.isEmpty) {
        return;
      }

      // إشعار داخلي فقط: لا نستدعي NotificationService.sendNotification
      // هنا لأنه يرسل Push خارجيًا عبر Railway.
      final notifications =
          FirebaseFirestore.instance.collection('notifications');

      WriteBatch batch = FirebaseFirestore.instance.batch();
      var operations = 0;

      Future<void> commitIfNeeded() async {
        if (operations == 0) return;
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        operations = 0;
      }

      for (final follower in followersSnapshot.docs) {
        final followerData = follower.data();
        final userId = (followerData['userId'] ?? '').toString().trim();

        if (userId.isEmpty || userId == publisherUid) {
          continue;
        }

        final notificationRef = notifications.doc();

        batch.set(notificationRef, {
          'title': 'عقار جديد من $officeName',
          'message': propertyTitle.isEmpty
              ? 'نشر المكتب عقارًا جديدًا.'
              : 'نشر المكتب عقارًا جديدًا: $propertyTitle',
          'type': 'property',
          'target': 'user',
          'userId': userId,
          'propertyId': propertyId,
          'officeId': officeId,
          'isOfficeFollowerNotification': true,
          'readBy': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });

        operations++;

        // Firestore يسمح بحد أقصى 500 عملية في Batch.
        if (operations >= 450) {
          await commitIfNeeded();
        }
      }

      await commitIfNeeded();
    } catch (error) {
      // فشل الإشعار لا يجب أن يمنع نشر العقار الموثق.
      debugPrint(
        'Office follower notification error: $error',
      );
    }
  }

  void _showValidationMessage(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff1E293B),
          elevation: 8,
          margin: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(
              color: Color(0xffD4AF37),
              width: 1,
            ),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  bool _hasPositiveInt(int? value) => value != null && value > 0;

  bool _hasPositiveDouble(double? value) => value != null && value > 0;

  bool _hasValidBuildYear(int? value) {
    if (value == null) return true;
    final currentYear = DateTime.now().year;
    return value >= 1800 && value <= currentYear;
  }

  bool _hasValidPhone(String value) {
    var phone = value.trim();

    const arabicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    arabicDigits.forEach((arabic, english) {
      phone = phone.replaceAll(arabic, english);
    });

    phone = phone
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');

    if (phone.isEmpty) return false;

    return RegExp(
      r'^(?:07[0-9]{9}|\+9647[0-9]{9}|9647[0-9]{9})$',
    ).hasMatch(phone);
  }

  String _normalizePhone(String value) {
    var phone = value.trim();

    const arabicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    arabicDigits.forEach((arabic, english) {
      phone = phone.replaceAll(arabic, english);
    });

    return phone
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
  }

  bool _validateAdType() {
    if (property.adType == null || property.adType!.trim().isEmpty) {
      _showValidationMessage("يرجى اختيار نوع الإعلان");
      return false;
    }
    return true;
  }

  bool _validatePropertyType() {
    if (property.propertyType == null ||
        property.propertyType!.trim().isEmpty) {
      _showValidationMessage("يرجى اختيار نوع العقار");
      return false;
    }
    return true;
  }

  bool _validateDetails() {
    final type = property.propertyType;

    if (type == null || type.trim().isEmpty) {
      _showValidationMessage("يرجى اختيار نوع العقار أولاً");
      return false;
    }

    if (property.title.trim().isEmpty) {
      _showValidationMessage("يرجى إدخال عنوان الإعلان");
      return false;
    }

    if (!_hasPositiveDouble(property.area)) {
      _showValidationMessage("يرجى إدخال مساحة العقار");
      return false;
    }

    if (type == "بيت" || type == "شقة" || type == "مزرعة") {
      if (!_hasPositiveInt(property.rooms)) {
        _showValidationMessage("يرجى إدخال عدد الغرف");
        return false;
      }

      if (!_hasPositiveInt(property.bathrooms)) {
        _showValidationMessage("يرجى إدخال عدد الحمامات");
        return false;
      }
    }

    if (type != "شقة") {
      if (!_hasPositiveDouble(property.frontage)) {
        _showValidationMessage("يرجى إدخال الواجهة");
        return false;
      }

      if (!_hasPositiveDouble(property.depth)) {
        _showValidationMessage("يرجى إدخال النزال");
        return false;
      }
    }
    if (type == "بيت" || type == "محل" || type == "عمارة" || type == "مزرعة") {
      if (!_hasPositiveInt(property.floors)) {
        _showValidationMessage("يرجى إدخال عدد الطوابق");
        return false;
      }
    }

    if (type == "شقة") {
      if (!_hasPositiveInt(property.apartmentFloor)) {
        _showValidationMessage("يرجى تحديد طابق الشقة");
        return false;
      }
    }

    if (type == "عمارة") {
      if (!_hasPositiveInt(property.unitsCount)) {
        _showValidationMessage("يرجى إدخال عدد الشقق / الوحدات");
        return false;
      }
    }

    if (property.documentType == null ||
        property.documentType!.trim().isEmpty) {
      _showValidationMessage("يرجى اختيار نوع السند");
      return false;
    }

    if (!_hasValidBuildYear(property.buildYear)) {
      _showValidationMessage("يرجى إدخال سنة بناء صحيحة");
      return false;
    }

    return true;
  }

  bool _validateLocation() {
    if (property.city.trim().isEmpty) {
      _showValidationMessage("يرجى اختيار المدينة / القضاء");
      return false;
    }

    if (property.district.trim().isEmpty) {
      _showValidationMessage("يرجى اختيار المنطقة / الحي");
      return false;
    }

    if (!property.hasMapLocation) {
      _showValidationMessage("يرجى تحديد موقع العقار على الخريطة");
      return false;
    }

    return true;
  }

  bool _validatePrice() {
    if (!_hasPositiveDouble(property.price)) {
      _showValidationMessage("يرجى إدخال سعر العقار");
      return false;
    }
    return true;
  }

  bool _validateImages() => true;

  bool _validateContact() {
    if (property.phone.trim().isEmpty) {
      _showValidationMessage("يرجى إدخال رقم الهاتف");
      return false;
    }

    if (!_hasValidPhone(property.phone)) {
      _showValidationMessage(
        "يرجى إدخال رقم هاتف عراقي صحيح مثل 07XXXXXXXXX",
      );
      return false;
    }

    if (property.whatsapp.trim().isNotEmpty &&
        !_hasValidPhone(property.whatsapp)) {
      _showValidationMessage(
        "يرجى إدخال رقم واتساب عراقي صحيح مثل 07XXXXXXXXX",
      );
      return false;
    }

    return true;
  }

  bool _validateCurrentStep() {
    switch (currentStep) {
      case 0:
        return _validateAdType();
      case 1:
        return _validatePropertyType();
      case 2:
        return _validateDetails();
      case 3:
        return _validateLocation();
      case 4:
        return _validatePrice();
      case 5:
        return _validateImages();
      case 6:
        return _validateContact();
      default:
        return true;
    }
  }

  bool _validateAllBeforePublish() {
    if (!_validateAdType()) return false;
    if (!_validatePropertyType()) return false;
    if (!_validateDetails()) return false;
    if (!_validateLocation()) return false;
    if (!_validatePrice()) return false;
    if (!_validateContact()) return false;
    return true;
  }

  void nextStep() {
    if (currentStep == totalSteps - 1) return;
    if (!_validateCurrentStep()) return;

    setState(() {
      currentStep++;
    });

    pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void previousStep() {
    if (currentStep == 0) return;

    setState(() {
      currentStep--;
    });

    pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> publishProperty() async {
    if (isPublishing) return;
    if (!_validateAllBeforePublish()) return;

    property.clearFieldsNotUsedByPropertyType();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showValidationMessage("يجب تسجيل الدخول أولاً");
      return;
    }

    setState(() {
      isPublishing = true;
    });

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data() ?? {};

    final publisherName = (userData['name'] ?? '').toString().trim();

    final publisherPhoto = (userData['photoUrl'] ?? '').toString().trim();

    final accountType = (userData['accountType'] ?? 'user').toString();

    final isVerified = userData['isVerified'] == true;

    final myOffice = await OfficeService.getMyOffice(user.uid);
    // A property is tied to an office only while the owner has explicitly
    // switched to office mode; personal listings remain personal.
    final isOfficeMode = myOffice != null &&
        myOffice.status == 'active' &&
        userData['accountMode'] == 'office' &&
        userData['activeOfficeId'] == myOffice.id;
    final activeOffice = isOfficeMode ? myOffice : null;
    final officeId = activeOffice?.id ?? '';
    final officeLogoUrl = activeOffice?.logoUrl ?? '';

    if (!mounted) return;

    try {
      // مكاتب العقارات تستخدم نفس شاشة إضافة العقار، لكن يجب تطبيق
      // حدود الاشتراك على المكتب فقط. المستخدم العادي لا يتأثر.
      if (activeOffice != null && officeId.isNotEmpty) {
        final subscriptionService = OfficeSubscriptionService();
        final subscription =
            await subscriptionService.getOfficeSubscription(officeId);

        final now = DateTime.now();
        final hasActiveSubscription = subscription != null &&
            subscription.status == 'active' &&
            (subscription.endDate == null ||
                subscription.endDate!.isAfter(now));

        if (!hasActiveSubscription) {
          if (mounted) {
            setState(() {
              isPublishing = false;
            });
            _showValidationMessage(
              'لا يمكن للمكتب إضافة عقار حاليًا. يجب أن يكون لديه اشتراك فعال',
            );
          }
          return;
        }

        final officePropertiesSnapshot = await FirebaseFirestore.instance
            .collection('properties')
            .where('officeId', isEqualTo: officeId)
            .get();

        final currentPropertiesCount = officePropertiesSnapshot.docs.length;

        if (!subscription.canAddProperty(currentPropertiesCount)) {
          if (mounted) {
            setState(() {
              isPublishing = false;
            });
            _showValidationMessage(
              'لقد وصل المكتب إلى الحد الأقصى من العقارات المسموح بها في باقته',
            );
          }
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("جاري رفع الصور..."),
        ),
      );

      List<String> imageUrls = [];

      if (property.selectedImages.isNotEmpty) {
        for (final image in property.selectedImages) {
          final url = await uploadToCloudinary(image);
          if (url != null) {
            imageUrls.add(url);
          }
        }
      }

      if (imageUrls.isEmpty) {
        imageUrls.add(
          PropertyDefaultImages.getImage(property.propertyType),
        );
      }

      property.imageUrls = imageUrls;

      final counterRef =
          FirebaseFirestore.instance.collection('settings').doc('properties');

      final nextNumber = await FirebaseFirestore.instance.runTransaction<int>(
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
            {"lastNumber": newNumber},
            SetOptions(merge: true),
          );

          return newNumber;
        },
      );

      final propertyReference =
          FirebaseFirestore.instance.collection('properties').doc();

      final isVerifiedOffice =
          activeOffice != null && activeOffice.isVerified == true;

      final propertyStatus = isVerifiedOffice ? 'approved' : 'pending';

      await propertyReference.set({
        "adType": property.adType,
        "propertyType": property.propertyType,
        "title": property.title.trim(),
        "price": property.price,
        "negotiable": property.negotiable,
        "images": property.imageUrls,
        "imageUrl":
            property.imageUrls.isNotEmpty ? property.imageUrls.first : "",
        "city": property.city.trim(),
        "district": property.district.trim(),
        "landmark": property.landmark.trim(),
        "latitude": property.latitude,
        "longitude": property.longitude,
        "hasMapLocation": property.hasMapLocation,
        "rooms": property.rooms,
        "bathrooms": property.bathrooms,
        "livingRooms": property.livingRooms,
        "parking": property.parking,
        "area": property.area,
        "frontage": property.frontage,
        "depth": property.depth,
        "floors": property.floors,
        "apartmentFloor": property.apartmentFloor,
        "unitsCount": property.unitsCount,
        "buildYear": property.buildYear,
        "documentType": property.documentType,
        "furnitureStatus": property.furnitureStatus,
        "description": property.description.trim(),
        "features": property.features,
        "ownerPhone": _normalizePhone(property.phone),
        "ownerWhatsapp": property.whatsapp.trim().isEmpty
            ? ""
            : _normalizePhone(property.whatsapp),
        "adNumber": nextNumber,
        "userId": user.uid,
        "publisherUid": user.uid,
        "officeId": officeId,
        "officeName": activeOffice?.name ?? "",
        "officeLogoUrl": officeLogoUrl,
        "isOfficeProperty": activeOffice != null,
        "publisherEmail": user.email ?? "",
        "publisherName": publisherName,
        "publisherPhotoUrl": publisherPhoto,
        "publisherPhoto": publisherPhoto,
        "publisherAccountType": accountType,
        "publisherVerified": isVerified,
        "status": propertyStatus,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // المكتب الموثق ينشر مباشرة دون انتظار الإدارة.
      // بعد النشر المباشر نرسل إشعارًا داخليًا فقط لمتابعي المكتب.
      if (isVerifiedOffice && officeId.isNotEmpty) {
        await _notifyOfficeFollowers(
          officeId: officeId,
          propertyId: propertyReference.id,
          officeName: activeOffice?.name ?? 'المكتب',
          propertyTitle: property.title.trim(),
          publisherUid: user.uid,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVerifiedOffice
                ? "تم نشر العقار بنجاح، وسيظهر مباشرة لمستخدمي التطبيق"
                : "تم إرسال العقار للمراجعة بنجاح",
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() {
          isPublishing = false;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isPublishing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("حدث خطأ أثناء الرفع: $e"),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F172A),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xff0F172A),
        title: const Text(
          "إضافة عقار",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: (currentStep + 1) / totalSteps,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(
                    Color(0xffD4AF37),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "الخطوة ${currentStep + 1} من $totalSteps",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: PageView(
                controller: pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Step1AdType(
                    property: property,
                    onChanged: () => setState(() {}),
                  ),
                  Step2PropertyType(
                    property: property,
                    onChanged: () => setState(() {}),
                  ),
                  Step3Details(
                    property: property,
                    onChanged: () => setState(() {}),
                  ),
                  Step4Location(
                    property: property,
                    onChanged: () => setState(() {}),
                  ),
                  Step5Price(
                    property: property,
                    onChanged: () => setState(() {}),
                  ),
                  Step6Images(
                    property: property,
                    onChanged: () => setState(() {}),
                  ),
                  Step7Contact(
                    property: property,
                    onChanged: () => setState(() {}),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xff1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
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
                            side: const BorderSide(
                              color: Color(0xffD4AF37),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            "رجوع",
                            style: TextStyle(
                              color: Color(0xffD4AF37),
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
                                  publishProperty();
                                } else {
                                  nextStep();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffD4AF37),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: isPublishing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                currentStep == totalSteps - 1
                                    ? "نشر العقار"
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
    );
  }
}
