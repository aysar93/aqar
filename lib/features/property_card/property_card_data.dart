class PropertyCardData {
  const PropertyCardData({
    required this.id,
    required this.number,
    required this.title,
    required this.imageUrl,
    required this.propertyType,
    required this.adType,
    required this.price,
    required this.negotiable,
    required this.location,
    required this.city,
    required this.areaName,
    required this.rooms,
    required this.bathrooms,
    required this.area,
    required this.floors,
    required this.documentType,
    required this.availabilityStatus,
    required this.features,
    required this.contactName,
    required this.contactPhone,
    required this.isOffice,
  });

  final String id;
  final int number;
  final String title;
  final String imageUrl;
  final String propertyType;
  final String adType;
  final double price;
  final bool negotiable;
  final String location;
  final String city;
  final String areaName;
  final int rooms;
  final int bathrooms;
  final int area;
  final int? floors;
  final String documentType;
  final String availabilityStatus;
  final List<dynamic> features;
  final String contactName;
  final String contactPhone;
  final bool isOffice;

  String get publicUrl =>
      'https://aysar93.github.io/aqar-pages/property/?id=${Uri.encodeComponent(id)}';
}
