class JapaneseWord {
  final Map<String, dynamic> data;

  JapaneseWord(this.data);

  factory JapaneseWord.fromMap(Map<String, dynamic> map) {
    return JapaneseWord(map);
  }

  // Convenience getters for common fields
  int? get id => data['id'] as int?;
  int? get source => data['source'] as int?;
  String get japanese => data['kanji'] as String? ?? '';
  String? get hiragana => data['reading'] as String?;
  String? get furigana => data['furigana'] as String?;
  String? get romaji => data['romaji'] as String?;
  String get english => data['meaning'] as String? ?? '';
  String? get tags => data['tags'] as String?;
  int? get priPoint => data['pri_point'] as int?;
  int? get rank => data['rank'] as int?;

  // Get any field from the raw data
  dynamic operator [](String key) => data[key];

  // Check if field exists
  bool hasField(String key) => data.containsKey(key);

  @override
  String toString() {
    return 'JapaneseWord{id: $id, japanese: $japanese, data: $data}';
  }
}