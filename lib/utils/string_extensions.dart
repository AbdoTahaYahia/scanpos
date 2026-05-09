extension StringNormalization on String {
  /// Normalizes Arabic text for searching by removing diacritics
  /// and standardizing Alef, Yaa, and Taa Marbutah.
  String get normalizedForSearch {
    var text = toLowerCase();
    // Standardize Alef variations to bare Alef
    text = text.replaceAll(RegExp(r'[أإآا]'), 'ا');
    // Standardize Taa Marbutah and Haa to Haa
    text = text.replaceAll(RegExp(r'[ةه]'), 'ه');
    // Standardize Yaa and Alef Maksura to bare Yaa
    text = text.replaceAll(RegExp(r'[يى]'), 'ي');
    // Remove Arabic diacritics (Tashkeel)
    text = text.replaceAll(RegExp(r'[\u064B-\u065F]'), '');
    return text;
  }
}
