// lib/models/food_model.dart

class Food {
  final String id;
  final String name;
  final String description;
  final double price;
  final String image;
  final String category;
  final double rating;
  final int preparationTime;
  final List<String> ingredients;
  final bool isAvailable;

  Food({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.category,
    required this.rating,
    required this.preparationTime,
    required this.ingredients,
    this.isAvailable = true,
  });

  Food copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? image,
    String? category,
    double? rating,
    int? preparationTime,
    List<String>? ingredients,
    bool? isAvailable,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      image: image ?? this.image,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      preparationTime: preparationTime ?? this.preparationTime,
      ingredients: ingredients ?? this.ingredients,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

/// Liste des plats disponibles (données fictives)
List<Food> foodList = [
  Food(
    id: 'food_1',
    name: 'Assiette de fruits',
    description: 'Une délicieuse assiette de fruits frais et variés pour bien commencer la journée.',
    price: 3500,
    image: 'assets/images/category/1.png',
    category: 'Petit-déjeuner',
    rating: 4.5,
    preparationTime: 10,
    ingredients: ['Pomme', 'Banane', 'Orange', 'Fraise', 'Raisin'],
    isAvailable: true,
  ),
  Food(
    id: 'food_2',
    name: 'Pâtes à l\'omelette',
    description: 'Des pâtes fraîches accompagnées d\'une omelette moelleuse et savoureuse.',
    price: 3500,
    image: 'assets/images/category/5.png',
    category: 'Plat principal',
    rating: 4.7,
    preparationTime: 20,
    ingredients: ['Pâtes', 'Œufs', 'Fromage', 'Persil', 'Huile d\'olive'],
    isAvailable: true,
  ),
  Food(
    id: 'food_3',
    name: 'Pancakes',
    description: 'De délicieux pancakes moelleux servis avec du sirop d\'érable et du beurre.',
    price: 2300,
    image: 'assets/images/category/7.png',
    category: 'Petit-déjeuner',
    rating: 4.8,
    preparationTime: 15,
    ingredients: ['Farine', 'Lait', 'Œufs', 'Sucre', 'Sirop d\'érable'],
    isAvailable: true,
  ),
  Food(
    id: 'food_4',
    name: 'Assiette de fruits avec œuf',
    description: 'Une combinaison équilibrée de fruits frais et d\'œuf pour un petit-déjeuner complet.',
    price: 4500,
    image: 'assets/images/category/2.png',
    category: 'Petit-déjeuner',
    rating: 4.6,
    preparationTime: 12,
    ingredients: ['Fruits mixtes', 'Œuf', 'Pain grillé', 'Miel'],
    isAvailable: true,
  ),
  Food(
    id: 'food_5',
    name: 'Salade composée',
    description: 'Une salade fraîche et croquante avec une vinaigrette maison.',
    price: 2800,
    image: 'assets/images/category/3.png',
    category: 'Entrée',
    rating: 4.4,
    preparationTime: 8,
    ingredients: ['Laitue', 'Tomate', 'Concombre', 'Vinaigrette', 'Croûtons'],
    isAvailable: true,
  ),
  Food(
    id: 'food_6',
    name: 'Bol de maïs',
    description: 'Un bol de maïs doux et savoureux, parfait comme accompagnement.',
    price: 3500,
    image: 'assets/images/category/4.png',
    category: 'Accompagnement',
    rating: 4.3,
    preparationTime: 10,
    ingredients: ['Maïs', 'Beurre', 'Sel', 'Poivre'],
    isAvailable: false, // Exemple de plat indisponible
  ),
  Food(
    id: 'food_7',
    name: 'Nouilles aux crevettes',
    description: 'Des nouilles sautées avec des crevettes fraîches et des légumes croquants.',
    price: 4500,
    image: 'assets/images/category/6.png',
    category: 'Plat principal',
    rating: 4.9,
    preparationTime: 25,
    ingredients: ['Nouilles', 'Crevettes', 'Légumes', 'Sauce soja', 'Gingembre'],
    isAvailable: true,
  ),
];
