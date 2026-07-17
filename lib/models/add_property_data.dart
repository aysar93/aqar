import 'dart:io';
class AddPropertyData {
  // =========================
  // الخطوة 1
  // =========================

  String? adType;

  // =========================
  // الخطوة 2
  // =========================

  String? propertyType;

  // =========================
  // الخطوة 3
  // =========================
String title = "";

  int? rooms;

  int? bathrooms;

  int? livingRooms;

  int? parking;

  double? area;

  int? buildYear;

  String? documentType;

  String? furnitureStatus;

  // =========================
  // الخطوة 4
  // =========================

  String city = "";

  String district = "";

  String landmark = "";


  // =========================
  // الخطوة 5
  // =========================

  double? price;

  bool negotiable = false;

  // =========================
  // الخطوة 6
  // =========================

  List<String> imageUrls = [];
  List<File> selectedImages = [];
  List<String> features = [];

  // =========================
  // الخطوة 7
  // =========================

  String description = "";

  String phone = "";

  String whatsapp = "";
}