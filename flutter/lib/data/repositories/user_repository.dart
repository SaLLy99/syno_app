import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syno_app/domain/entities/user.dart';

class UserRepository {
  static const String _usersKey = 'users';
  static const String _currentUserIdKey = 'current_user_id';

  Future<List<User>> getAllUsers() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? usersJson = prefs.getString(_usersKey);
      
      if (usersJson == null || usersJson.isEmpty) {
        final List<User> demoUsers = _getDemoUsers();
        await saveUsers(demoUsers);
        return demoUsers;
      }
      
      final List<dynamic> usersList = jsonDecode(usersJson);
      return usersList.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading users: $e');
      final List<User> demoUsers = _getDemoUsers();
      await saveUsers(demoUsers);
      return demoUsers;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt(_currentUserIdKey);
      
      if (userId == null) return null;
      
      final List<User> users = await getAllUsers();
      return users.cast<User?>().firstWhere((u) => u?.userId == userId, orElse: () => null);
    } catch (e) {
      debugPrint('Error loading current user: $e');
      return null;
    }
  }

  Future<void> setCurrentUser(int userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, userId.toString());
  }

  Future<void> saveUsers(List<User> users) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String usersJson = jsonEncode(users.map((User u) => u.toJson()).toList());
      await prefs.setString(_usersKey, usersJson);
    } catch (e) {
      debugPrint('Error saving users: $e');
    }
  }

  Future<User> createUser(User user) async {
    final List<User> users = await getAllUsers();
    users.add(user);
    await saveUsers(users);
    return user;
  }

  Future<User> updateUser(User user) async {
    final List<User> users = await getAllUsers();
    final int index = users.indexWhere((User u) => u.id == user.id);
    if (index != -1) {
      users[index] = user;
      await saveUsers(users);
      return users[index];
    }
    throw Exception('User not found');
  }

List<User> _getDemoUsers() {
  return [
    User(
        id: 1,
        userId: 1,
        name: 'Emma',
        bio: 'Yoga instructor & cosmic explorer. Looking for someone to stargaze with 🌟',
        photos: [Photo(id: 101, url: 'https://picsum.photos/400/600?random=1', isPrimary: true)],
        birthDate: DateTime(1997, 3, 15),
        birthTime: '14:30',
        location: Location(
          id: 1,
          name: 'New York',
          type: 'city',
          parent: LocationParent(id: 2, name: 'USA')
        ),
        intentions: [Intentions(id:3,key:"exploring",translationKey:"register.options.intentions.exploring")],
        coreValues: [CoreValue(id: 1, key: "Empathy", translationKey: "profile.core_values.empathy")],
        sex: Sex(id: 2, name: 'Female'),
        orientation: OrientationModel (id: 1, name: 'Straight'),
        hobbies: [
          Hobby(id: 1, name: 'Yoga'),
          Hobby(id: 2, name: 'Meditation')
        ],
        personalityTraits: const {
          'openness': 85,
          'conscientiousness': 70,
          'extraversion': 75,
          'agreeableness': 90,
          'emotionalStability': 80,
          'adventurous': 75,
          'romantic': 85,
          'intellectual': 70,
        },
        preferences: UserPreferences(minAge: 24, maxAge: 35, maxDistance: 50, interestedIn: ['men'])),
    User(
        id: 2,
        userId: 2,
        name: 'Alex',
        bio: 'Software engineer by day, amateur astronomer by night. Let\'s explore the universe together 🚀',
        photos: [Photo(id: 102, url: 'https://picsum.photos/400/600?random=2', isPrimary: true)],
        birthDate: DateTime(1995, 7, 22),
        birthTime: '09:15',
        location: Location(id: 1, name: 'New York', parent: LocationParent(id: 2, name: 'USA')),
        intentions: [Intentions(id:4,key:"friendship",translationKey:"register.options.intentions.exploring")],
        coreValues: [CoreValue(id:2,key:"Honesty",translationKey:"profile.core_values.honesty")],
        sex: Sex(id: 1, name: 'Male'),
        orientation: OrientationModel (id: 1, name: 'Straight'),
        hobbies: [Hobby(id: 3, name: 'Astrology')],
        personalityTraits: const {
          'openness': 90,
          'conscientiousness': 85,
          'extraversion': 60,
          'agreeableness': 75,
          'emotionalStability': 85,
          'adventurous': 80,
          'romantic': 70,
          'intellectual': 95,
        },
        preferences: UserPreferences(minAge: 23, maxAge: 32, maxDistance: 40, interestedIn: ['women'])),
    User(
        id: 3,
        userId: 3,
        name: 'Luna',
        bio: 'Artist & dreamer. Believer in magic and meaningful connections ✨',
        photos: [Photo(id: 103, url: 'https://picsum.photos/400/600?random=3', isPrimary: true)],
        birthDate: DateTime(1998, 11, 8),
        birthTime: '22:45',
        location: Location(id: 3, name: 'London', parent: LocationParent(id: 4, name: 'UK')),
        intentions: [Intentions(id:4,key:"friendship",translationKey:"register.options.intentions.exploring")],
        coreValues: [CoreValue(id:3,key:"Spontaniety",translationKey:"profile.core_values.spontaniety")],
        sex: Sex(id: 2, name: 'Female'),
        orientation: OrientationModel (id: 3, name: 'Bisexual'),
        hobbies: [
          Hobby(id: 4, name: 'Painting'),
          Hobby(id: 5, name: 'Music')
        ],
        personalityTraits: const {
          'openness': 95,
          'conscientiousness': 60,
          'extraversion': 70,
          'agreeableness': 85,
          'emotionalStability': 65,
          'adventurous': 90,
          'romantic': 95,
          'intellectual': 80,
        },
        preferences: UserPreferences(minAge: 24, maxAge: 33, maxDistance: 60, interestedIn: ['all'])),
    User(
        id: 4,
        userId: 4,
        name: 'Marcus',
        bio: 'Entrepreneur & adventure seeker. Life\'s too short for boring conversations 🌍',
        photos: [Photo(id: 104, url: 'https://picsum.photos/400/600?random=4', isPrimary: true)],
        birthDate: DateTime(1993, 5, 3),
        location: Location(id: 5, name: 'Tokyo', parent: LocationParent(id: 6, name: 'Japan')),
        birthTime: '06:20',
        intentions: [Intentions(id:4,key:"casual_relationship",translationKey:"register.options.intentions.casual_relationship")],
        coreValues: [CoreValue(id: 4, key: "growth", translationKey: "profile.core_values.growth")],
        sex: Sex(id: 1, name: 'Male'),
        orientation: OrientationModel (id: 1, name: 'Straight'),
        hobbies: [
          Hobby(id: 6, name: 'Hiking'),
          Hobby(id: 7, name: 'Traveling')
        ],
        personalityTraits: const {
          'openness': 80,
          'conscientiousness': 75,
          'extraversion': 90,
          'agreeableness': 70,
          'emotionalStability': 90,
          'adventurous': 95,
          'romantic': 65,
          'intellectual': 75,
        },
        preferences: UserPreferences(minAge: 25, maxAge: 35, maxDistance: 70, interestedIn: ['women'])),
    User(
        id: 5,
        userId: 5,
        name: 'Sophia',
        bio: 'Writer & philosopher. Searching for deep conversations and cosmic connections 📚',
        photos: [Photo(id: 105, url: 'https://picsum.photos/400/600?random=5', isPrimary: true)],
        birthDate: DateTime(1996, 9, 17),
        birthTime: '18:00',
        location: Location(id: 7, name: 'Sydney', parent: LocationParent(id: 8, name: 'Australia')),
        intentions: [Intentions(id:4,key:"friendship",translationKey:"register.options.intentions.exploring")],
        coreValues: [CoreValue(id: 5, key: "creativity", translationKey: "profile.core_values.creativity")],
        sex: Sex(id: 2, name: 'Female'),
        orientation: OrientationModel (id: 2, name: 'Gay'),
        hobbies: [
          Hobby(id: 8, name: 'Reading'),
          Hobby(id: 3, name: 'Astrology')
        ],
        personalityTraits: const {
          'openness': 90,
          'conscientiousness': 80,
          'extraversion': 55,
          'agreeableness': 85,
          'emotionalStability': 75,
          'adventurous': 70,
          'romantic': 90,
          'intellectual': 95,
        },
        preferences: UserPreferences(minAge: 26, maxAge: 36, maxDistance: 45, interestedIn: ['men'])),
  ];
}
}
