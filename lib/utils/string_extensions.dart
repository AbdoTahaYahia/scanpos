extension StringNormalization on String {
  // Pre-compiled regex patterns to avoid recompiling on every call
  static final _alefRegex = RegExp(r'[أإآا]');
  static final _taaRegex = RegExp(r'[ةه]');
  static final _yaaRegex = RegExp(r'[يى]');
  static final _diacriticsRegex = RegExp(r'[\u064B-\u065F]');

  /// Normalizes Arabic text for searching by removing diacritics
  /// and standardizing Alef, Yaa, and Taa Marbutah.
  String get normalizedForSearch {
    var text = toLowerCase();
    // Standardize Alef variations to bare Alef
    text = text.replaceAll(_alefRegex, 'ا');
    // Standardize Taa Marbutah and Haa to Haa
    text = text.replaceAll(_taaRegex, 'ه');
    // Standardize Yaa and Alef Maksura to bare Yaa
    text = text.replaceAll(_yaaRegex, 'ي');
    // Remove Arabic diacritics (Tashkeel)
    text = text.replaceAll(_diacriticsRegex, '');
    return text;
  }
}
