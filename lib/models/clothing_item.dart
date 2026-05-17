class ClothingItem {

  final int? id;
  final String name;
  final String category;
  final String imagePath;
  final String mood;

  ClothingItem({
    this.id,
    required this.name,
    required this.category,
    required this.imagePath,
    required this.mood,

  });

  Map<String, dynamic> toMap() {

    return {
      'id': id,
      'name': name,
      'category': category,
      'imagePath': imagePath,
      'mood': mood,
    };
  }

  factory ClothingItem.fromMap(Map<String, dynamic> map) {

    return ClothingItem(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      imagePath: map['imagePath'],
      mood: map['mood'],

    );
  }
}