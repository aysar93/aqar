class PropertyDefaultImages {
  static String getImage(String? propertyType) {
    switch (propertyType) {
      case "بيت":
        return "assets/images/defaults/house.png";

      case "شقة":
        return "assets/images/defaults/apartment.png";

      case "أرض":
        return "assets/images/defaults/land.png";

      case "محل":
        return "assets/images/defaults/shop.png";

      case "عمارة":
        return "assets/images/defaults/building.png";

      case "مزرعة":
        return "assets/images/defaults/farm.png";

      default:
        return "assets/images/defaults/house.png";
    }
  }
}
