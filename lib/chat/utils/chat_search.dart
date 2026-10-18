String normalizeChatSearch(String value) {
  var text = value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[ً-ٰٟـ]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll(',', '');
  const localized = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < localized.length; i++) {
    text = text.replaceAll(localized[i], '$i');
  }
  return text;
}
