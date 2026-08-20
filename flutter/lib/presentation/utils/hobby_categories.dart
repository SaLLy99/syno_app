/// Hobby categories for Bumble-style grouped display.
/// Maps category keys to lists of hobby translation_key suffixes.
class HobbyCategories {
  HobbyCategories._();

  static const Map<String, String> categoryLabels = {
    'popular': 'Popular',
    'fitness': 'Fitness',
    'creative': 'Creative',
    'outdoor': 'Outdoors',
    'food': 'Food & Drink',
    'social': 'Social',
    'wellness': 'Wellness',
    'mind': 'Mind & Spirit',
    'tech': 'Tech',
    'gaming': 'Gaming',
    'travel': 'Travel',
    'music': 'Music & Dance',
    'pets': 'Pets & Nature',
    'sports': 'Sports',
    'adventure': 'Adventure',
    'lifestyle': 'Lifestyle',
  };

  static const Map<String, List<String>> categories = {
    'fitness': [
      'yoga', 'meditation', 'gym', 'running', 'jogging', 'walking',
      'cycling', 'swimming', 'crossfit', 'pilates', 'dance_fitness',
      'personal_trainer', 'rock_climbing', 'boxing', 'martial_arts',
    ],
    'creative': [
      'painting', 'drawing', 'writing', 'photography', 'filmmaking',
      'pottery', 'knitting', 'sewing', 'crochet', 'embroidery',
      'sculpture', 'digital_art', 'pixel_art', 'nft_art', 'ai_art',
      'calligraphy', 'origami', 'scrapbooking', 'diy', 'woodworking',
      'leatherworking', 'jewelry_making', 'macram', 'tie_dye',
      'screen_printing', 'printmaking', 'mural_painting', 'street_art',
      'glassblowing', 'nail_art', 'makeup', 'skincare', 'fashion',
      'interior_design', 'home_decor', '3d_printing', 'animation',
      'poetry', 'blogging', 'vlogging',
    ],
    'outdoor': [
      'hiking', 'camping', 'gardening', 'bird_watching', 'fishing',
      'hunting', 'foraging', 'mushroom_hunting', 'geocaching',
      'urban_farming', 'hydroponics', 'houseplants', 'bonsai',
      'terrariums', 'park_ranger', 'conservation_officer',
    ],
    'food': [
      'cooking', 'baking', 'wine_tasting', 'craft_beer', 'coffee',
      'tea', 'bbq_and_grilling', 'grilling', 'smoking', 'wine_making',
      'coffee_roasting', 'tea_blending', 'cheese_making',
      'chocolate_making', 'sushi_making', 'vegan_cooking',
      'home_brewing', 'kombucha_making', 'fermenting', 'meal_prep',
      'cooking_classes', 'food_trucks', 'restaurant_hopping',
    ],
    'social': [
      'volunteering', 'board_games', 'chess', 'poker', 'billiards',
      'darts', 'bowling', 'book_club', 'networking', 'parenting',
      'debate', 'stand_up_comedy', 'improv', 'podcasting',
      'podcast_hosting', 'karaoke', 'laser_tag', 'paintball',
      'axe_throwing',
    ],
    'wellness': [
      'spa', 'cold_plunge', 'breathwork', 'aromatherapy',
      'crystal_healing', 'sound_healing', 'qigong',
      'meditation_retreats', 'gratitude_practice', 'wellness',
    ],
    'mind': [
      'astrology', 'tarot', 'crystals', 'spiritual_practices',
      'astronomy', 'space', 'dream_journaling', 'lucid_dreaming',
      'chanting',
    ],
    'tech': [
      'gaming', 'coding', 'robotics', '3d_printing', 'crypto',
      'streaming', 'app_development', 'game_development',
      'board_game_design', 'drone_racing', 'rc_cars', 'model_rockets',
      'retro_gaming', 'ham_radio', 'speedcubing', 'lockpicking',
    ],
    'travel': [
      'traveling', 'backpacking', 'solo_travel', 'van_life', 'rv_life',
      'digital_nomad', 'language_learning', 'thrift_shopping',
      'antiques', 'vinyl_collecting', 'sneaker_collecting',
    ],
    'music': [
      'music', 'djing', 'songwriting', 'karaoke', 'dancing',
      'belly_dancing', 'folk_dancing', 'ballroom_dancing',
      'salsa_dancing', 'tango', 'swing_dancing', 'breakdancing',
      'ballet', 'fire_spinning', 'hula_hooping', 'slacklining',
    ],
    'pets': [
      'pets', 'cats', 'bird_watching', 'zookeeper', 'animal_trainer',
      'pet_groomer', 'beekeeping',
    ],
    'sports': [
      'tennis', 'basketball', 'football', 'volleyball', 'golf',
      'skiing', 'snowboarding', 'surfing', 'table_tennis', 'badminton',
      'squash', 'rugby', 'cricket', 'wrestling', 'judo', 'karate',
      'taekwondo', 'fencing', 'roller_skating', 'pickleball',
    ],
    'adventure': [
      'skydiving', 'paragliding', 'ziplining', 'bungee_jumping',
      'go_karting', 'parkour', 'paddleboarding', 'snorkeling',
      'rowing', 'snowshoeing', 'magic_tricks', 'juggling',
    ],
    'lifestyle': [
      'collecting', 'walking', 'podcasting', 'vlogging', 'blogging',
      'writing', 'reading', 'watching_tv_shows', 'movies',
      'volunteering', 'real_estate',
    ],
  };

  /// Get hobbies for a category by matching translation_key suffixes.
  static List<T> filterByCategory<T>(
    List<T> items,
    String category,
    String Function(T) keyExtractor,
  ) {
    if (category == 'popular') return items;
    final List<String>? suffixes = categories[category];
    if (suffixes == null) return items;
    return items.where((T item) {
      final String key = keyExtractor(item).split('.').last;
      return suffixes.contains(key);
    }).toList();
  }

  /// Get the first N popular items (items that appear in multiple categories).
  static List<T> getPopular<T>(List<T> items, String Function(T) keyExtractor) {
    // Popular = items in the first category definition (fitness first)
    final Set<String> popularKeys = {
      'yoga', 'meditation', 'hiking', 'traveling', 'reading', 'cooking',
      'painting', 'photography', 'music', 'gaming', 'dancing', 'swimming',
      'cycling', 'running', 'gym', 'surfing', 'camping', 'gardening',
      'board_games', 'chess', 'coffee', 'wine_tasting', 'pets',
      'astrology', 'volunteering', 'writing', 'knitting', 'pottery',
      'photography', 'movies', 'podcasts',
    };
    return items.where((T item) {
      final String key = keyExtractor(item).split('.').last;
      return popularKeys.contains(key);
    }).toList();
  }
}
