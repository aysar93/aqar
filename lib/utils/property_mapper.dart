import '../models/property_model.dart';

PropertyModel propertyFromMap(
  Map<String, dynamic> data,
  String id,
) {
  return PropertyModel.fromMap(
    data,
    id,
  );
}
