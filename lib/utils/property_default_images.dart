class PropertyDefaultImages {


  static String getImage(
    String? propertyType,
  ) {


    switch(propertyType) {


      case "بيت":

        return
        "ضع_هنا_رابط_صورة_البيت";


      case "شقة":

        return
        "ضع_هنا_رابط_صورة_الشقة";


      case "أرض":

        return
        "ضع_هنا_رابط_صورة_الأرض";


      case "محل":

        return
        "ضع_هنا_رابط_صورة_المحل";


      case "عمارة":

        return
        "ضع_هنا_رابط_صورة_العمارة";


      case "مزرعة":

        return
        "ضع_هنا_رابط_صورة_المزرعة";


      default:

        return
        "ضع_هنا_رابط_صورة_افتراضية";

    }

  }

}