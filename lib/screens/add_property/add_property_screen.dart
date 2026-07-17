import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/add_property_data.dart';
import '../../services/cloudinary_service.dart';
import 'step1_ad_type.dart';
import 'step2_property_type.dart';
import 'step3_details.dart';
import 'step4_location.dart';
import 'step5_price.dart';
import 'step6_images.dart';
import 'step7_contact.dart';
import '../../utils/property_default_images.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() =>
      _AddPropertyScreenState();
}

class _AddPropertyScreenState
    extends State<AddPropertyScreen> {

  final PageController pageController =
      PageController();

  final AddPropertyData property =
      AddPropertyData();

  int currentStep = 0;
  bool isPublishing = false;

  static const int totalSteps = 7;

  void nextStep() {
    if (currentStep == totalSteps - 1) return;

    setState(() {
      currentStep++;
    });

    pageController.nextPage(
      duration:
          const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void previousStep() {
    if (currentStep == 0) return;

    setState(() {
      currentStep--;
    });

    pageController.previousPage(
      duration:
          const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

Future<void> publishProperty() async {

  if (isPublishing) return;

setState(() {
  isPublishing = true;
});

  if (property.adType == null ||
      property.propertyType == null) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "يرجى إكمال البيانات الأساسية",
        ),
      ),
    );

    return;
  }


  try {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "جاري رفع الصور...",
        ),
      ),
    );


    List<String> imageUrls = [];


if (property.selectedImages.isNotEmpty) {


  for (final image in property.selectedImages) {


    final url =
        await uploadToCloudinary(
          image,
        );


    if (url != null) {

      imageUrls.add(url);

    }

  }


} else {


  imageUrls.add(
    PropertyDefaultImages.getImage(
      property.propertyType,
    ),
  );


}





    property.imageUrls =
        imageUrls;

final user =
    FirebaseAuth.instance.currentUser;


if (user == null) {

  if (!mounted) return;

  ScaffoldMessenger.of(context)
      .showSnackBar(
    const SnackBar(
      content: Text(
        "يجب تسجيل الدخول أولاً",
      ),
    ),
  );

  return;

}

final counterRef = FirebaseFirestore.instance
    .collection('settings')
    .doc('properties');

final nextNumber =
    await FirebaseFirestore.instance.runTransaction<int>(
  (transaction) async {

    final snapshot =
        await transaction.get(counterRef);

    int lastNumber = 0;

    if (snapshot.exists) {
      lastNumber =
          snapshot.data()?['lastNumber'] ?? 0;
    }

    final newNumber = lastNumber + 1;

    transaction.set(
      counterRef,
      {
        "lastNumber": newNumber,
      },
      SetOptions(merge: true),
    );

    return newNumber;
  },
);

await FirebaseFirestore.instance
    .collection('properties')
    .add({

  "adType":
      property.adType,

  "propertyType":
      property.propertyType,

"title":
    property.title,

  "price":
      property.price,


  "images":
      property.imageUrls,


  "imageUrl":
      property.imageUrls.isNotEmpty
          ? property.imageUrls.first
          : "",



  "city":
      property.city,


  "district":
      property.district,


  "landmark":
      property.landmark,



  "rooms":
      property.rooms,


  "bathrooms":
      property.bathrooms,


  "livingRooms":
      property.livingRooms,


  "parking":
      property.parking,


  "area":
      property.area,


  "buildYear":
      property.buildYear,


  "documentType":
      property.documentType,


  "furnitureStatus":
      property.furnitureStatus,



  "description":
      property.description,


  "features":
      property.features,



  "ownerPhone":
      property.phone,


  "ownerWhatsapp":
      property.whatsapp,



  "negotiable":
      property.negotiable,


"adNumber":
    nextNumber,

  "userId":
    user.uid,

"publisherUid":
    user.uid,

"publisherEmail":
    user.email ?? "",

"publisherName":
    user.displayName ?? "",

"status":
    "pending",


  "createdAt":
      FieldValue.serverTimestamp(),

});

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text(
      "تم إرسال العقار للمراجعة بنجاح",
    ),
  ),
);


await Future.delayed(
  const Duration(seconds: 1),
);


if (mounted) {

setState(() {
  isPublishing = false;
});

  Navigator.pop(context);

}


  } catch (e) {

  setState(() {
    isPublishing = false;
  });

  if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      "حدث خطأ أثناء الرفع: $e",
    ),
  ),
);

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

      backgroundColor:
          const Color(0xff0F172A),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor:
            const Color(0xff0F172A),

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
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
              ),

              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(25),

                child:
                    LinearProgressIndicator(
                  minHeight: 9,

                  value:
                      (currentStep + 1) /
                          totalSteps,

                  backgroundColor:
                      Colors.white10,

                  valueColor:
                      const AlwaysStoppedAnimation(
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

                physics:
                    const NeverScrollableScrollPhysics(),

                children: [
                                    Step1AdType(
                    property: property,
                    onChanged: () {
                      setState(() {});
                    },
                  ),

                  Step2PropertyType(
                    property: property,
                    onChanged: () {
                      setState(() {});
                    },
                  ),

                  Step3Details(
                    property: property,
                    onChanged: () {
                      setState(() {});
                    },
                  ),

                  Step4Location(
                    property: property,
                    onChanged: () {
                      setState(() {});
                    },
                  ),

                  Step5Price(
                    property: property,
                    onChanged: () {
                      setState(() {});
                    },
                  ),

                  Step6Images(
                    property: property,
                    onChanged: () {
                      setState(() {});
                    },
                  ),

                  Step7Contact(
                    property: property,
                    onChanged: () {
                      setState(() {});
                    },
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
                          onPressed: previousStep,

                          style:
                              OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xffD4AF37),
                            ),

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(18),
                            ),
                          ),

                          child: const Text(
                            "رجوع",

                            style: TextStyle(
                              color:
                                  Color(0xffD4AF37),

                              fontSize: 17,

                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),


                  if (currentStep > 0)
                    const SizedBox(width: 12),


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

                        style:
                            ElevatedButton.styleFrom(

                          backgroundColor:
                              const Color(0xffD4AF37),

                          foregroundColor:
                              Colors.white,

                          elevation: 8,

                          shape:
                              RoundedRectangleBorder(

                            borderRadius:
                                BorderRadius.circular(18),

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
