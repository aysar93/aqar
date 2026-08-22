/// يمثل جميع الفلاتر التي يمكن تطبيقها على عقارات الخريطة.
class MapFilter {
  final String searchQuery;

  final String? city;
  final String? district;

  final String? propertyType;
  final String? adType;

  final double? minPrice;
  final double? maxPrice;

  final double? minArea;
  final double? maxArea;

  final int? minRooms;

  final bool featuredOnly;

  const MapFilter({
    this.searchQuery = '',
    this.city,
    this.district,
    this.propertyType,
    this.adType,
    this.minPrice,
    this.maxPrice,
    this.minArea,
    this.maxArea,
    this.minRooms,
    this.featuredOnly = false,
  });

  static const MapFilter empty = MapFilter();

  bool get isEmpty {
    return searchQuery.trim().isEmpty &&
        city == null &&
        district == null &&
        propertyType == null &&
        adType == null &&
        minPrice == null &&
        maxPrice == null &&
        minArea == null &&
        maxArea == null &&
        minRooms == null &&
        !featuredOnly;
  }

  bool get hasLocationFilter {
    return city != null || district != null;
  }

  bool get hasPriceFilter {
    return minPrice != null || maxPrice != null;
  }

  bool get hasAreaFilter {
    return minArea != null || maxArea != null;
  }

  int get activeFiltersCount {
    var count = 0;

    if (searchQuery.trim().isNotEmpty) count++;
    if (city != null) count++;
    if (district != null) count++;
    if (propertyType != null) count++;
    if (adType != null) count++;
    if (hasPriceFilter) count++;
    if (hasAreaFilter) count++;
    if (minRooms != null) count++;
    if (featuredOnly) count++;

    return count;
  }

  MapFilter copyWith({
    String? searchQuery,
    String? city,
    String? district,
    String? propertyType,
    String? adType,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    int? minRooms,
    bool? featuredOnly,
    bool clearCity = false,
    bool clearDistrict = false,
    bool clearPropertyType = false,
    bool clearAdType = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearMinArea = false,
    bool clearMaxArea = false,
    bool clearMinRooms = false,
  }) {
    final nextCity = clearCity ? null : city ?? this.city;

    return MapFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      city: nextCity,
      district: clearCity || clearDistrict ? null : district ?? this.district,
      propertyType:
          clearPropertyType ? null : propertyType ?? this.propertyType,
      adType: clearAdType ? null : adType ?? this.adType,
      minPrice: clearMinPrice ? null : minPrice ?? this.minPrice,
      maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
      minArea: clearMinArea ? null : minArea ?? this.minArea,
      maxArea: clearMaxArea ? null : maxArea ?? this.maxArea,
      minRooms: clearMinRooms ? null : minRooms ?? this.minRooms,
      featuredOnly: featuredOnly ?? this.featuredOnly,
    );
  }

  MapFilter clearLocation() {
    return copyWith(
      clearCity: true,
      clearDistrict: true,
    );
  }

  MapFilter clearPrice() {
    return copyWith(
      clearMinPrice: true,
      clearMaxPrice: true,
    );
  }

  MapFilter clearArea() {
    return copyWith(
      clearMinArea: true,
      clearMaxArea: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'searchQuery': searchQuery,
      'city': city,
      'district': district,
      'propertyType': propertyType,
      'adType': adType,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'minArea': minArea,
      'maxArea': maxArea,
      'minRooms': minRooms,
      'featuredOnly': featuredOnly,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MapFilter &&
            other.searchQuery == searchQuery &&
            other.city == city &&
            other.district == district &&
            other.propertyType == propertyType &&
            other.adType == adType &&
            other.minPrice == minPrice &&
            other.maxPrice == maxPrice &&
            other.minArea == minArea &&
            other.maxArea == maxArea &&
            other.minRooms == minRooms &&
            other.featuredOnly == featuredOnly;
  }

  @override
  int get hashCode {
    return Object.hash(
      searchQuery,
      city,
      district,
      propertyType,
      adType,
      minPrice,
      maxPrice,
      minArea,
      maxArea,
      minRooms,
      featuredOnly,
    );
  }
}
