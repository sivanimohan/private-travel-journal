import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Utility to force Dart-native types
dynamic forceDartTypes(dynamic input) {
  if (input == null) return null;
  if (input is List) return input.map(forceDartTypes).toList();
  if (input is Map) {
    return input
        .map((key, value) => MapEntry(key.toString(), forceDartTypes(value)));
  }
  if (input is String || input is num || input is bool) return input;
  return input.toString();
}

class InsightPage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const InsightPage({
    Key? key,
    required this.userId,
    required this.userData,
  }) : super(key: key);

  @override
  _InsightPageState createState() => _InsightPageState();
}

class _InsightPageState extends State<InsightPage>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> insights = {};
  bool isLoading = true;
  String? error;
  late ConfettiController _confettiController;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  late Client client;
  late Databases databases;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    client = Client()
        .setEndpoint('https://cloud.appwrite.io/v1')
        .setProject('67c329590010d80b983c');
    databases = Databases(client);
    _fetchAndProcessInsights();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndProcessInsights() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await databases.listDocuments(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67eab72f0030b02f1623',
        queries: [Query.equal('userId', widget.userId)],
      );

      List<Map<String, String>> allPages = response.documents.map((doc) {
        return {
          'location': doc.data['location']?.toString() ?? '',
          'textData': doc.data['textData']?.toString() ?? '',
        };
      }).toList();

      final combinedAllPages = [
        ...(widget.userData['allPages'] as List? ?? []),
        ...allPages
      ];
      final data = {'allPages': combinedAllPages, 'userId': widget.userId};

      insights = forceDartTypes({
        'travel_recommendations': await _travelRecommendations(data),
        'mood_mapping': await _moodMapping(data),
        'activity_recommendations': await _activityRecommendations(data),
        'travel_style': await _travelStyle(data),
        'travel_culture_and_cuisine': await _travelCultureAndCuisine(data),
        'travel_dna': await _travelDNA(data),
        'travel_fun_fact': await _travelFunFact(data),
        'status': 'success',
      }) as Map<String, dynamic>;

      setState(() {
        isLoading = false;
        _confettiController.play();
      });
    } catch (e) {
      setState(() {
        error = 'Failed to fetch insights: $e';
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _travelRecommendations(
      Map<String, dynamic> data) async {
    const String apiKey = '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';
    const String apiUrl = 'https://api-inference.huggingface.co/models/facebook/bart-large-mnli';
    final locations = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['location']?.toString() ?? '')
            .where((loc) => loc.isNotEmpty)
            .toList() ??
        [];
    final allText = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['textData']?.toString() ?? '')
            .where((text) => text.isNotEmpty)
            .join(' ') ??
        '';

    if (locations.isEmpty) return _basicTravelRecommendations(data);

    int attempt = 0;
    while (true) {
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'inputs':
                'Based on my travel history to ${locations.join(', ')} and detailed experiences like "$allText", recommend specific destinations I’d enjoy.',
            'parameters': {
              'candidate_labels': [
                'Paris',
                'Tokyo',
                'New York',
                'Rome',
                'London',
                'Bali',
                'Sydney',
                'Cape Town',
                'Santorini',
                'Dubai'
              ]
            }
          }),
        );
        print(
            '----- TRAVEL RECOMMENDATIONS RAW RESPONSE (Attempt $attempt) -----');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
        print('----------------------------------------------');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json is Map<String, dynamic>) {
            final labels = (json['labels'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final scores = (json['scores'] as List<dynamic>?)
                    ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
                    .toList() ??
                [];
            if (labels.isNotEmpty && scores.isNotEmpty) {
              List<Map<String, String>> recommendations = labels
                  .asMap()
                  .entries
                  .where((e) => scores[e.key] > 0.1)
                  .map((e) => {
                        'destination': e.value,
                        'reason': _getRecommendationReason(e.value)
                      })
                  .toList();
              return {'recommendations': recommendations.take(5).toList()};
            }
          }
          return _basicTravelRecommendations(data);
        }
      } catch (e) {
        print('Error in travel recommendations (Attempt $attempt): $e');
        attempt++;
        await Future.delayed(Duration(seconds: 1));
        continue;
      }
      break;
    }
    return _basicTravelRecommendations(data);
  }

  Map<String, dynamic> _basicTravelRecommendations(Map<String, dynamic> data,
      {String? preferredType}) {
    Map<String, int> locationVisits = {};
    for (var page in (data['allPages'] as List<dynamic>? ?? [])) {
      String? loc = page['location']?.toString();
      if (loc != null) locationVisits[loc] = (locationVisits[loc] ?? 0) + 1;
    }
    List<Map<String, String>> pool = [
      {'destination': 'Paris', 'reason': 'Art and romance'},
      {'destination': 'Tokyo', 'reason': 'Tech and tradition'},
      {'destination': 'New York', 'reason': 'Urban energy'},
      {'destination': 'Rome', 'reason': 'Ancient history'},
      {'destination': 'London', 'reason': 'Historical charm'},
      {'destination': 'Bali', 'reason': 'Tropical relaxation'},
      {'destination': 'Sydney', 'reason': 'Coastal beauty'},
      {'destination': 'Cape Town', 'reason': 'Scenic diversity'},
      {'destination': 'Santorini', 'reason': 'Stunning views'},
      {'destination': 'Dubai', 'reason': 'Modern luxury'},
    ];
    List<Map<String, String>> recommendations = pool
        .where((rec) => !locationVisits.containsKey(rec['destination']))
        .toList()
      ..shuffle();
    return {'recommendations': recommendations.take(5).toList()};
  }

  String _getRecommendationReason(String destination) {
    switch (destination) {
      case 'Paris':
        return 'Art and romance';
      case 'Tokyo':
        return 'Tech and tradition';
      case 'New York':
        return 'Urban energy';
      case 'Rome':
        return 'Ancient history';
      case 'London':
        return 'Historical charm';
      case 'Bali':
        return 'Tropical relaxation';
      case 'Sydney':
        return 'Coastal beauty';
      case 'Cape Town':
        return 'Scenic diversity';
      case 'Santorini':
        return 'Stunning views';
      case 'Dubai':
        return 'Modern luxury';
      default:
        return 'Unique experience';
    }
  }

  Future<Map<String, dynamic>> _moodMapping(Map<String, dynamic> data) async {
    const String apiKey = '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';
    const String apiUrl =
        'https://api-inference.huggingface.co/models/distilbert-base-uncased-finetuned-sst-2-english';
    Map<String, List<double>> locationSentiments = {};

    for (var page in (data['allPages'] as List<dynamic>? ?? [])) {
      String? text = page['textData']?.toString();
      String? loc = page['location']?.toString();
      if (text != null && loc != null && text.isNotEmpty) {
        int attempt = 0;
        while (true) {
          try {
            final response = await http.post(
              Uri.parse(apiUrl),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json'
              },
              body: jsonEncode({
                'inputs':
                    'Evaluate my emotions from my trip to $loc described as: "$text"'
              }),
            );
            print(
                '----- MOOD MAPPING RAW RESPONSE ($loc, Attempt $attempt) -----');
            print('Status: ${response.statusCode}');
            print('Body: ${response.body}');
            print('----------------------------------------------');
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              List<dynamic> results = json is List ? json : [json];
              for (var result in results) {
                if (result is List) {
                  for (var sentiment in result) {
                    _processSentiment(sentiment, loc, locationSentiments);
                  }
                } else if (result is Map) {
                  _processSentiment(result, loc, locationSentiments);
                }
              }
              break;
            }
          } catch (e) {
            print('Error in mood mapping (Attempt $attempt): $e');
            attempt++;
            await Future.delayed(Duration(seconds: 1));
            continue;
          }
        }
      }
    }

    if (locationSentiments.isEmpty) {
      return {
        'happiest_places': [
          {'location': 'Paris', 'score': 0.8},
          {'location': 'Hawaii', 'score': 0.75}
        ],
        'mood_map': {'Paris': 'positive', 'Hawaii': 'positive'}
      };
    }

    var happiest = locationSentiments.entries
        .map((e) => {
              'location': e.key,
              'score': e.value.isEmpty
                  ? 0.0
                  : e.value.reduce((a, b) => a + b) / e.value.length
            })
        .toList()
      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    var moodMap = locationSentiments.map((loc, sents) => MapEntry(
        loc,
        sents.isEmpty
            ? 'neutral'
            : (sents.reduce((a, b) => a + b) / sents.length > 0
                ? 'positive'
                : 'negative')));
    return {'happiest_places': happiest.take(5).toList(), 'mood_map': moodMap};
  }

  void _processSentiment(dynamic sentiment, String loc,
      Map<String, List<double>> locationSentiments) {
    if (sentiment is Map<String, dynamic>) {
      final label = sentiment['label']?.toString() ?? '';
      final score =
          double.tryParse(sentiment['score']?.toString() ?? '0.0') ?? 0.0;
      if (label == 'POSITIVE') {
        locationSentiments.putIfAbsent(loc, () => []).add(score);
      } else if (label == 'NEGATIVE') {
        locationSentiments.putIfAbsent(loc, () => []).add(-score);
      }
    }
  }

  Future<Map<String, dynamic>> _activityRecommendations(
      Map<String, dynamic> data) async {
    const String apiKey = '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';
    const String apiUrl =
        'https://api-inference.huggingface.co/models/facebook/bart-large-mnli';
    final allText = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['textData']?.toString() ?? '')
            .where((text) => text.isNotEmpty)
            .join(' ') ??
        '';
    final locations = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['location']?.toString() ?? '')
            .where((loc) => loc.isNotEmpty)
            .join(', ') ??
        '';

    if (allText.isEmpty) return _basicActivityRecommendations(data);

    int attempt = 0;
    while (true) {
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'inputs':
                'From my trips to $locations with experiences "$allText", suggest specific activities I’d love.',
            'parameters': {
              'candidate_labels': [
                'hiking',
                'museum visits',
                'beach lounging',
                'shopping',
                'fine dining',
                'sightseeing',
                'wine tasting',
                'photography tours',
                'snorkeling',
                'cultural festivals'
              ]
            }
          }),
        );
        print(
            '----- ACTIVITY RECOMMENDATIONS RAW RESPONSE (Attempt $attempt) -----');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
        print('----------------------------------------------');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json is Map<String, dynamic>) {
            final labels = (json['labels'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final scores = (json['scores'] as List<dynamic>?)
                    ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
                    .toList() ??
                [];
            if (labels.isNotEmpty && scores.isNotEmpty) {
              List<String> recommendations = labels
                  .asMap()
                  .entries
                  .where((e) => scores[e.key] > 0.1)
                  .map((e) => 'Try ${e.value}')
                  .toList();
              return {'recommendations': recommendations.take(5).toList()};
            }
          }
          return _basicActivityRecommendations(data);
        }
      } catch (e) {
        print('Error in activity recommendations (Attempt $attempt): $e');
        attempt++;
        await Future.delayed(Duration(seconds: 1));
        continue;
      }
      break;
    }
    return _basicActivityRecommendations(data);
  }

  Map<String, dynamic> _basicActivityRecommendations(
      Map<String, dynamic> data) {
    Map<String, int> activityKeywords = {
      'hiking': 0,
      'museum visits': 0,
      'beach lounging': 0,
      'shopping': 0,
      'fine dining': 0,
      'sightseeing': 0,
      'wine tasting': 0,
      'photography tours': 0,
      'snorkeling': 0,
      'cultural festivals': 0
    };
    for (var page in (data['allPages'] as List<dynamic>? ?? [])) {
      String? text = page['textData']?.toString()?.toLowerCase();
      if (text != null) {
        activityKeywords.forEach((key, value) {
          if (text.contains(key.split(' ').first))
            activityKeywords[key] = activityKeywords[key]! + 1;
        });
      }
    }
    var topActivities = activityKeywords.entries
        .map((e) => {'activity': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return {
      'recommendations':
          topActivities.take(5).map((e) => 'Try ${e['activity']}').toList()
    };
  }

  Future<Map<String, dynamic>> _travelStyle(Map<String, dynamic> data) async {
    const String apiKey = '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';
    const String apiUrl =
        'https://api-inference.huggingface.co/models/facebook/bart-large-mnli';
    final allText = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['textData']?.toString() ?? '')
            .where((text) => text.isNotEmpty)
            .join(' ') ??
        '';
    final locations = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['location']?.toString() ?? '')
            .where((loc) => loc.isNotEmpty)
            .join(', ') ??
        '';

    if (allText.isEmpty) return _basicTravelStyle(data);

    int attempt = 0;
    while (true) {
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'inputs':
                'Analyze my travel style from my trips to $locations with notes: "$allText".',
            'parameters': {
              'candidate_labels': [
                'adventurous',
                'relaxed',
                'cultural',
                'luxury',
                'budget',
                'solo',
                'group',
                'nature lover',
                'food-focused',
                'urban explorer'
              ]
            }
          }),
        );
        print('----- TRAVEL STYLE RAW RESPONSE (Attempt $attempt) -----');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
        print('----------------------------------------------');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json is Map<String, dynamic>) {
            final labels = (json['labels'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final scores = (json['scores'] as List<dynamic>?)
                    ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
                    .toList() ??
                [];
            if (labels.isNotEmpty && scores.isNotEmpty) {
              final topIndex = scores.indexOf(scores.reduce(max));
              return {'travel_style': labels[topIndex]};
            }
          }
          return _basicTravelStyle(data);
        }
      } catch (e) {
        print('Error in travel style (Attempt $attempt): $e');
        attempt++;
        await Future.delayed(Duration(seconds: 1));
        continue;
      }
      break;
    }
    return _basicTravelStyle(data);
  }

  Map<String, dynamic> _basicTravelStyle(Map<String, dynamic> data) {
    Map<String, int> styleCounts = {
      'adventurous': 0,
      'relaxed': 0,
      'cultural': 0,
      'luxury': 0,
      'budget': 0,
      'solo': 0,
      'group': 0,
      'nature lover': 0,
      'food-focused': 0,
      'urban explorer': 0
    };
    for (var page in (data['allPages'] as List<dynamic>? ?? [])) {
      String? text = page['textData']?.toString()?.toLowerCase();
      if (text != null) {
        if (['adventure', 'hiking'].any((w) => text.contains(w)))
          styleCounts['adventurous'] = styleCounts['adventurous']! + 1;
        if (['relax', 'spa'].any((w) => text.contains(w)))
          styleCounts['relaxed'] = styleCounts['relaxed']! + 1;
        if (['museum', 'culture'].any((w) => text.contains(w)))
          styleCounts['cultural'] = styleCounts['cultural']! + 1;
        if (['luxury', 'resort'].any((w) => text.contains(w)))
          styleCounts['luxury'] = styleCounts['luxury']! + 1;
        if (['budget', 'cheap'].any((w) => text.contains(w)))
          styleCounts['budget'] = styleCounts['budget']! + 1;
        if (['solo', 'alone'].any((w) => text.contains(w)))
          styleCounts['solo'] = styleCounts['solo']! + 1;
        if (['group', 'friends'].any((w) => text.contains(w)))
          styleCounts['group'] = styleCounts['group']! + 1;
        if (['nature', 'forest'].any((w) => text.contains(w)))
          styleCounts['nature lover'] = styleCounts['nature lover']! + 1;
        if (['food', 'cuisine'].any((w) => text.contains(w)))
          styleCounts['food-focused'] = styleCounts['food-focused']! + 1;
        if (['city', 'urban'].any((w) => text.contains(w)))
          styleCounts['urban explorer'] = styleCounts['urban explorer']! + 1;
      }
    }
    return {
      'travel_style':
          styleCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
    };
  }

  Future<Map<String, dynamic>> _travelCultureAndCuisine(
      Map<String, dynamic> data) async {
    const String apiKey = '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';
    const String apiUrl =
        'https://api-inference.huggingface.co/models/facebook/bart-large-mnli';
    Map<String, int> cultureCounts = {
      'museum': 0,
      'park': 0,
      'gallery': 0,
      'monument': 0,
      'castle': 0,
      'temple': 0,
      'market': 0,
      'festival': 0,
      'ruins': 0,
      'palace': 0
    };
    Map<String, int> cuisineCounts = {
      'Italian': 0,
      'Japanese': 0,
      'Mexican': 0,
      'Indian': 0,
      'French': 0,
      'Thai': 0,
      'Chinese': 0,
      'Spanish': 0,
      'Greek': 0,
      'Vietnamese': 0
    };
    final allText = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['textData']?.toString() ?? '')
            .where((text) => text.isNotEmpty)
            .join(' ') ??
        '';
    final locations = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['location']?.toString() ?? '')
            .where((loc) => loc.isNotEmpty)
            .join(', ') ??
        '';

    for (var page in (data['allPages'] as List<dynamic>? ?? [])) {
      String? text = page['textData']?.toString()?.toLowerCase();
      if (text != null) {
        cultureCounts.forEach((key, value) {
          if (text.contains(key)) cultureCounts[key] = cultureCounts[key]! + 1;
        });
        if (['pasta', 'pizza'].any((w) => text.contains(w)))
          cuisineCounts['Italian'] = cuisineCounts['Italian']! + 1;
        if (['sushi', 'ramen'].any((w) => text.contains(w)))
          cuisineCounts['Japanese'] = cuisineCounts['Japanese']! + 1;
        if (['tacos', 'salsa'].any((w) => text.contains(w)))
          cuisineCounts['Mexican'] = cuisineCounts['Mexican']! + 1;
        if (['curry', 'naan'].any((w) => text.contains(w)))
          cuisineCounts['Indian'] = cuisineCounts['Indian']! + 1;
        if (['croissant', 'baguette'].any((w) => text.contains(w)))
          cuisineCounts['French'] = cuisineCounts['French']! + 1;
        if (['pad thai', 'tom yum'].any((w) => text.contains(w)))
          cuisineCounts['Thai'] = cuisineCounts['Thai']! + 1;
        if (['dumpling', 'noodle'].any((w) => text.contains(w)))
          cuisineCounts['Chinese'] = cuisineCounts['Chinese']! + 1;
        if (['paella', 'tapas'].any((w) => text.contains(w)))
          cuisineCounts['Spanish'] = cuisineCounts['Spanish']! + 1;
        if (['gyro', 'feta'].any((w) => text.contains(w)))
          cuisineCounts['Greek'] = cuisineCounts['Greek']! + 1;
        if (['pho', 'banh mi'].any((w) => text.contains(w)))
          cuisineCounts['Vietnamese'] = cuisineCounts['Vietnamese']! + 1;
      }
    }

    if (allText.isNotEmpty) {
      int attempt = 0;
      while (true) {
        try {
          final response = await http.post(
            Uri.parse(apiUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({
              'inputs':
                  'From my travels to $locations with notes "$allText", identify my favorite cuisines.',
              'parameters': {'candidate_labels': cuisineCounts.keys.toList()}
            }),
          );
          print(
              '----- TRAVEL CULTURE AND CUISINE RAW RESPONSE (Attempt $attempt) -----');
          print('Status: ${response.statusCode}');
          print('Body: ${response.body}');
          print('----------------------------------------------');
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json is Map<String, dynamic>) {
              final labels = (json['labels'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];
              final scores = (json['scores'] as List<dynamic>?)
                      ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
                      .toList() ??
                  [];
              if (labels.isNotEmpty && scores.isNotEmpty) {
                double total = scores.reduce((a, b) => a + b);
                cuisineCounts = Map.fromIterables(
                    labels,
                    labels
                        .asMap()
                        .entries
                        .map((e) => ((scores[e.key] / total) * 100).round()));
              }
            }
            break;
          }
        } catch (e) {
          print('Error in travel culture and cuisine (Attempt $attempt): $e');
          attempt++;
          await Future.delayed(Duration(seconds: 1));
          if (attempt > 3) break;
          continue;
        }
      }
    }

    List<Map<String, dynamic>> culturePrefs = cultureCounts.entries
        .where((e) => e.value > 0)
        .map((e) => {'type': e.key, 'mentions': e.value})
        .toList()
      ..sort((a, b) => (b['mentions'] as int).compareTo(a['mentions'] as int));

    List<Map<String, dynamic>> cuisinePrefs = cuisineCounts.entries
        .where((e) => e.value > 0)
        .map((e) => {
              'cuisine': e.key,
              'preference': e.value,
              'restaurant': _getTopRestaurant(e.key),
            })
        .toList()
      ..sort(
          (a, b) => (b['preference'] as int).compareTo(a['preference'] as int));

    if (culturePrefs.isEmpty && cuisinePrefs.isEmpty) {
      return {
        'cultural_preferences': [
          {'type': 'museum', 'mentions': 1}
        ],
        'cuisine_preferences': [
          {
            'cuisine': 'Italian',
            'preference': 100,
            'restaurant': 'Osteria Francescana (Modena, Italy)'
          }
        ]
      };
    }

    return {
      'cultural_preferences': culturePrefs.take(5).toList(),
      'cuisine_preferences': cuisinePrefs.take(5).toList(),
    };
  }

  String _getTopRestaurant(String cuisine) {
    switch (cuisine) {
      case 'Italian':
        return 'Osteria Francescana (Modena, Italy)';
      case 'Japanese':
        return 'Sukiyabashi Jiro (Tokyo, Japan)';
      case 'Mexican':
        return 'Pujol (Mexico City, Mexico)';
      case 'Indian':
        return 'Gaggan (Bangkok, Thailand)';
      case 'French':
        return 'Mirazur (Menton, France)';
      case 'Thai':
        return 'Nahm (Bangkok, Thailand)';
      case 'Chinese':
        return 'Din Tai Fung (Taipei, Taiwan)';
      case 'Spanish':
        return 'El Celler de Can Roca (Girona, Spain)';
      case 'Greek':
        return 'Funky Gourmet (Athens, Greece)';
      case 'Vietnamese':
        return 'The Lunch Lady (Ho Chi Minh City, Vietnam)';
      default:
        return 'Local Favorite';
    }
  }

  Future<Map<String, dynamic>> _travelDNA(Map<String, dynamic> data) async {
    const String apiKey = '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';
    const String apiUrl =
        'https://api-inference.huggingface.co/models/facebook/bart-large-mnli';
    final allText = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['textData']?.toString() ?? '')
            .where((text) => text.isNotEmpty)
            .join(' ') ??
        '';
    final locations = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['location']?.toString() ?? '')
            .where((loc) => loc.isNotEmpty)
            .join(', ') ??
        '';

    if (allText.isEmpty) return _basicTravelDNA(data);

    int attempt = 0;
    while (true) {
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'inputs':
                'Profile my unique travel traits from my trips to $locations with experiences: "$allText".',
            'parameters': {
              'candidate_labels': [
                'Explorer',
                'Foodie',
                'Culture Seeker',
                'Relaxer',
                'Thrill Seeker',
                'Nature Lover',
                'City Dweller',
                'Budget Traveler',
                'Luxury Seeker',
                'Solo Adventurer'
              ]
            }
          }),
        );
        print('----- TRAVEL DNA RAW RESPONSE (Attempt $attempt) -----');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
        print('----------------------------------------------');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json is Map<String, dynamic>) {
            final labels = (json['labels'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final scores = (json['scores'] as List<dynamic>?)
                    ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
                    .toList() ??
                [];
            if (labels.isNotEmpty && scores.isNotEmpty) {
              double total = scores.reduce((a, b) => a + b);
              return {
                'dna': labels
                    .asMap()
                    .entries
                    .map((e) => {
                          'trait': e.value,
                          'percentage': ((scores[e.key] / total) * 100).round()
                        })
                    .where((e) => (e['percentage'] as int) > 5)
                    .toList()
              };
            }
          }
          return _basicTravelDNA(data);
        }
      } catch (e) {
        print('Error in travel DNA (Attempt $attempt): $e');
        attempt++;
        await Future.delayed(Duration(seconds: 1));
        continue;
      }
      break;
    }
    return _basicTravelDNA(data);
  }

  Map<String, dynamic> _basicTravelDNA(Map<String, dynamic> data) {
    Map<String, int> dnaTraits = {
      'Explorer': 0,
      'Foodie': 0,
      'Culture Seeker': 0,
      'Relaxer': 0,
      'Thrill Seeker': 0,
      'Nature Lover': 0,
      'City Dweller': 0,
      'Budget Traveler': 0,
      'Luxury Seeker': 0,
      'Solo Adventurer': 0
    };
    for (var page in (data['allPages'] as List<dynamic>? ?? [])) {
      String? text = page['textData']?.toString()?.toLowerCase();
      if (text != null) {
        if (['explore', 'discover'].any((w) => text.contains(w)))
          dnaTraits['Explorer'] = dnaTraits['Explorer']! + 1;
        if (['food', 'cuisine'].any((w) => text.contains(w)))
          dnaTraits['Foodie'] = dnaTraits['Foodie']! + 1;
        if (['culture', 'museum'].any((w) => text.contains(w)))
          dnaTraits['Culture Seeker'] = dnaTraits['Culture Seeker']! + 1;
        if (['relax', 'beach'].any((w) => text.contains(w)))
          dnaTraits['Relaxer'] = dnaTraits['Relaxer']! + 1;
        if (['thrill', 'extreme'].any((w) => text.contains(w)))
          dnaTraits['Thrill Seeker'] = dnaTraits['Thrill Seeker']! + 1;
        if (['nature', 'forest'].any((w) => text.contains(w)))
          dnaTraits['Nature Lover'] = dnaTraits['Nature Lover']! + 1;
        if (['city', 'urban'].any((w) => text.contains(w)))
          dnaTraits['City Dweller'] = dnaTraits['City Dweller']! + 1;
        if (['budget', 'cheap'].any((w) => text.contains(w)))
          dnaTraits['Budget Traveler'] = dnaTraits['Budget Traveler']! + 1;
        if (['luxury', 'resort'].any((w) => text.contains(w)))
          dnaTraits['Luxury Seeker'] = dnaTraits['Luxury Seeker']! + 1;
        if (['solo', 'alone'].any((w) => text.contains(w)))
          dnaTraits['Solo Adventurer'] = dnaTraits['Solo Adventurer']! + 1;
      }
    }
    int total = dnaTraits.values.reduce((a, b) => a + b);
    if (total == 0)
      return {
        'dna': [
          {'trait': 'Balanced Traveler', 'percentage': 100}
        ]
      };
    List<Map<String, dynamic>> dnaProfile = dnaTraits.entries
        .map((e) =>
            {'trait': e.key, 'percentage': (e.value / total * 100).round()})
        .where((e) => (e['percentage'] as int) > 5)
        .toList()
      ..sort(
          (a, b) => (b['percentage'] as int).compareTo(a['percentage'] as int));
    return {'dna': dnaProfile.take(5).toList()};
  }

  Future<Map<String, dynamic>> _travelFunFact(Map<String, dynamic> data) async {
    const String apiKey = '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';
    const String apiUrl = 'https://api-inference.huggingface.co/models/gpt2';
    final allText = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['textData']?.toString() ?? '')
            .where((text) => text.isNotEmpty)
            .join(' ') ??
        '';
    final locations = (data['allPages'] as List<dynamic>?)
            ?.map((p) => p['location']?.toString() ?? '')
            .where((loc) => loc.isNotEmpty)
            .toList() ??
        [];

    if (allText.isEmpty) return _basicTravelFunFact(data);

    int attempt = 0;
    while (true) {
      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'inputs':
                'Create a quirky, personalized fun fact about my travels to ${locations.join(', ')} based on my experiences: "$allText".',
            'parameters': {'max_length': 70}
          }),
        );
        print('----- TRAVEL FUN FACT RAW RESPONSE (Attempt $attempt) -----');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
        print('----------------------------------------------');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json is List && json.isNotEmpty) {
            String fact =
                json[0]['generated_text']?.toString().split('\n')[0] ?? '';
            fact = fact
                .replaceFirst(
                    'Create a quirky, personalized fun fact about my travels to ${locations.join(', ')} based on my experiences: "$allText".',
                    '')
                .trim();
            return {
              'fun_fact':
                  fact.isNotEmpty ? fact : 'Your travels are uniquely awesome!'
            };
          }
          return _basicTravelFunFact(data);
        }
      } catch (e) {
        print('Error in travel fun fact (Attempt $attempt): $e');
        attempt++;
        await Future.delayed(Duration(seconds: 1));
        continue;
      }
      break;
    }
    return _basicTravelFunFact(data);
  }

  Map<String, dynamic> _basicTravelFunFact(Map<String, dynamic> data) {
    Map<String, int> locationVisits = {};
    int totalTrips = 0;
    for (var page in (data['allPages'] as List<dynamic>? ?? [])) {
      String? loc = page['location']?.toString();
      if (loc != null) {
        locationVisits[loc] = (locationVisits[loc] ?? 0) + 1;
        totalTrips++;
      }
    }
    if (totalTrips == 0)
      return {'fun_fact': 'Your travel journey is just starting!'};
    var mostVisited =
        locationVisits.entries.reduce((a, b) => a.value > b.value ? a : b);
    return {
      'fun_fact':
          'You’ve visited ${mostVisited.key} ${mostVisited.value} times – a top pick!'
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoadingScreen();
    if (error != null) return _buildErrorScreen();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Insights',
            style: TextStyle(fontFamily: 'JosefinSans')),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAndProcessInsights)
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildTravelRecommendations(),
                _buildMoodMapping(),
                _buildActivityRecommendations(),
                _buildTravelStyle(),
                _buildTravelCultureAndCuisine(),
                _buildTravelDNA(),
                _buildTravelFunFact(),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (index) => _buildPageIndicator(index)),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        ),
        child: const Icon(Icons.navigate_next),
      ),
    );
  }

  Widget _buildTravelRecommendations() {
    final recommendationsRaw =
        insights['travel_recommendations']?['recommendations'] ?? [];
    final recommendations =
        (recommendationsRaw is List ? recommendationsRaw : [])
            .map((e) => Map<String, String>.from(e is Map ? e : {}))
            .toList();
    return InsightCard(
      icon: Icons.explore,
      title: 'Travel Recommendations',
      description: 'New destinations based on your past travels',
      child: SingleChildScrollView(
        child: recommendations.isNotEmpty
            ? ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final rec = recommendations[index];
                  return ListTile(
                    leading: const Icon(Icons.place, color: Colors.blue),
                    title: Text(rec['destination'] ?? 'Unknown',
                        style: const TextStyle(fontFamily: 'JosefinSans')),
                    subtitle: Text(rec['reason'] ?? '',
                        style: const TextStyle(fontFamily: 'JosefinSans')),
                  );
                },
              )
            : const Center(
                child: Text('No recommendations yet',
                    style: TextStyle(fontFamily: 'JosefinSans'))),
      ),
    );
  }

  Widget _buildMoodMapping() {
    final moodData = insights['mood_mapping'] ?? {};
    final happiestPlacesRaw = moodData['happiest_places'] ?? [];
    final happiestPlaces = (happiestPlacesRaw is List ? happiestPlacesRaw : [])
        .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
        .toList();
    final moodMapRaw = moodData['mood_map'] ?? {};
    final moodMap = (moodMapRaw is Map ? moodMapRaw : {})
        .map((k, v) => MapEntry(k.toString(), v.toString()));
    return InsightCard(
      icon: Icons.mood,
      title: 'Mood Map',
      description: 'Your emotional journey across locations',
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (happiestPlaces.isNotEmpty) ...[
              const Text('Happiest Places:',
                  style: TextStyle(
                      fontFamily: 'JosefinSans', fontWeight: FontWeight.bold)),
              ...happiestPlaces.map((place) => ListTile(
                    leading: Icon(Icons.emoji_emotions,
                        color: _getSentimentColor(place['score'] is num
                            ? (place['score'] as num).toDouble()
                            : 0.0)),
                    title: Text(place['location'] ?? 'Unknown',
                        style: const TextStyle(fontFamily: 'JosefinSans')),
                    subtitle: Text(
                        'Score: ${(place['score'] is num ? (place['score'] as num).toDouble() : 0.0).toStringAsFixed(2)}'),
                  )),
              const Divider(),
            ],
            ...moodMap.entries.map((e) => ListTile(
                  leading: Icon(
                    e.value == 'positive'
                        ? Icons.sentiment_satisfied
                        : Icons.sentiment_neutral,
                    color: e.value == 'positive' ? Colors.green : Colors.blue,
                  ),
                  title: Text(e.key,
                      style: const TextStyle(fontFamily: 'JosefinSans')),
                  subtitle: Text(e.value),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRecommendations() {
    final recommendationsRaw =
        insights['activity_recommendations']?['recommendations'] ?? [];
    final recommendations =
        (recommendationsRaw is List ? recommendationsRaw : [])
            .map((e) => e.toString())
            .toList();
    return InsightCard(
      icon: Icons.recommend,
      title: 'Activity Recommendations',
      description: 'Personalized suggestions for your next trip',
      child: SingleChildScrollView(
        child: recommendations.isNotEmpty
            ? ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recommendations.length,
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.arrow_forward, color: Colors.blue),
                  title: Text(recommendations[index],
                      style: const TextStyle(fontFamily: 'JosefinSans')),
                ),
              )
            : const Center(
                child: Text('No recommendations yet',
                    style: TextStyle(fontFamily: 'JosefinSans'))),
      ),
    );
  }

  Widget _buildTravelStyle() {
    final style =
        insights['travel_style']?['travel_style']?.toString() ?? 'balanced';
    return InsightCard(
      icon: Icons.person_pin,
      title: 'Travel Style',
      description: 'How you like to explore the world',
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(style.toUpperCase(),
                style: const TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            const SizedBox(height: 16),
            Icon(_getTravelStyleIcon(style), size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            Text(_getTravelStyleDescription(style),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'JosefinSans')),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelCultureAndCuisine() {
    final cultureData = insights['travel_culture_and_cuisine'] ?? {};
    final culturePrefsRaw = cultureData['cultural_preferences'] ?? [];
    final culturePrefs = (culturePrefsRaw is List ? culturePrefsRaw : [])
        .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
        .toList();
    final cuisinePrefsRaw = cultureData['cuisine_preferences'] ?? [];
    final cuisinePrefs = (cuisinePrefsRaw is List ? cuisinePrefsRaw : [])
        .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
        .toList();

    return InsightCard(
      icon: Icons.local_dining,
      title: 'Culture & Cuisine',
      description:
          'Your favorite cultural spots and cuisines with top restaurants',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cultural Preferences:',
                style: TextStyle(
                    fontFamily: 'JosefinSans', fontWeight: FontWeight.bold)),
            if (culturePrefs.isNotEmpty)
              ...culturePrefs.map((pref) => ListTile(
                    leading: const Icon(Icons.place, color: Colors.blue),
                    title: Text(
                        '${pref['type'] ?? 'Unknown'} (${pref['mentions'] ?? 0} mentions)',
                        style: const TextStyle(fontFamily: 'JosefinSans')),
                  ))
            else
              const Text('No cultural preferences yet',
                  style: TextStyle(fontFamily: 'JosefinSans')),
            const SizedBox(height: 16),
            const Text('Cuisine Preferences:',
                style: TextStyle(
                    fontFamily: 'JosefinSans', fontWeight: FontWeight.bold)),
            if (cuisinePrefs.isNotEmpty)
              ...cuisinePrefs.map((pref) => ListTile(
                    leading: const Icon(Icons.restaurant, color: Colors.green),
                    title: Text(
                        '${pref['cuisine'] ?? 'Unknown'} (${pref['preference'] ?? 0}%)',
                        style: const TextStyle(fontFamily: 'JosefinSans')),
                    subtitle: Text(pref['restaurant'] ?? 'Local Favorite',
                        style: const TextStyle(fontFamily: 'JosefinSans')),
                  ))
            else
              const Text('No cuisine preferences yet',
                  style: TextStyle(fontFamily: 'JosefinSans')),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelDNA() {
    final dnaRaw = insights['travel_dna']?['dna'] ?? [];
    final dna = (dnaRaw is List ? dnaRaw : [])
        .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
        .toList();
    return InsightCard(
      icon: Icons.biotech,
      title: 'Travel DNA',
      description: 'Your unique travel profile',
      child: SingleChildScrollView(
        child: dna.isNotEmpty
            ? Column(
                children: dna
                    .map((trait) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${trait['trait'] ?? ''} (${trait['percentage'] is num ? trait['percentage'] : 0}%)',
                                  style: const TextStyle(
                                      fontFamily: 'JosefinSans', fontSize: 16),
                                ),
                              ),
                              Container(
                                width: (trait['percentage'] is num
                                        ? (trait['percentage'] as num)
                                            .toDouble()
                                        : 0.0) *
                                    2,
                                height: 10,
                                color: Colors.blueAccent,
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              )
            : const Center(
                child: Text('No travel DNA yet',
                    style: TextStyle(fontFamily: 'JosefinSans'))),
      ),
    );
  }

  Widget _buildTravelFunFact() {
    final funFact = insights['travel_fun_fact']?['fun_fact']?.toString() ??
        'No fun facts yet';
    return InsightCard(
      icon: Icons.lightbulb,
      title: 'Travel Fun Fact',
      description: 'A quirky tidbit about your travels',
      child: SingleChildScrollView(
        child: Center(
          child: Text(
            funFact,
            style: const TextStyle(
                fontFamily: 'JosefinSans',
                fontSize: 18,
                fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSpotList(
      List<Map<String, dynamic>> spots, IconData icon, Color color) {
    return spots.isNotEmpty
        ? ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: spots.length,
            itemBuilder: (context, index) => ListTile(
              leading: Icon(icon, color: color),
              title: Text(spots[index]['location'] ?? 'Unknown',
                  style: const TextStyle(fontFamily: 'JosefinSans')),
            ),
          )
        : Center(
            child: Text('No items found',
                style: TextStyle(fontFamily: 'JosefinSans', color: color)));
  }

  Widget _buildPageIndicator(int index) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index ? Colors.blueAccent : Colors.grey[300],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.blue[300]!,
            highlightColor: Colors.blue[100]!,
            child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.blue)),
          ),
          const SizedBox(height: 20),
          Text('Analyzing your travels...',
              style: TextStyle(
                  fontFamily: 'JosefinSans', fontSize: 18, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(error ?? 'Unknown error',
                style: const TextStyle(fontFamily: 'JosefinSans', fontSize: 16),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchAndProcessInsights,
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
            child: const Text('Try Again',
                style: TextStyle(fontFamily: 'JosefinSans')),
          ),
        ],
      ),
    );
  }

  Color _getSentimentColor(double score) {
    if (score > 0.75) return Colors.green;
    if (score > 0.5) return Colors.lightGreen;
    if (score > 0.25) return Colors.blue;
    if (score > 0.0) return Colors.orange;
    return Colors.red;
  }

  IconData _getTravelStyleIcon(String style) {
    switch (style.toLowerCase()) {
      case 'adventurous':
        return Icons.landscape;
      case 'relaxed':
        return Icons.beach_access;
      case 'cultural':
        return Icons.museum;
      case 'luxury':
        return Icons.star;
      case 'budget':
        return Icons.attach_money;
      case 'solo':
        return Icons.person;
      case 'group':
        return Icons.group;
      case 'nature lover':
        return Icons.eco;
      case 'food-focused':
        return Icons.local_dining;
      case 'urban explorer':
        return Icons.location_city;
      default:
        return Icons.explore;
    }
  }

  String _getTravelStyleDescription(String style) {
    switch (style.toLowerCase()) {
      case 'adventurous':
        return 'You crave thrilling outdoor experiences';
      case 'relaxed':
        return 'You prefer peaceful, laid-back trips';
      case 'cultural':
        return 'You love history, art, and local traditions';
      case 'luxury':
        return 'You enjoy high-end travel comforts';
      case 'budget':
        return 'You travel smart with cost in mind';
      case 'solo':
        return 'You enjoy the freedom of traveling alone';
      case 'group':
        return 'You love sharing adventures with others';
      case 'nature lover':
        return 'You seek out natural beauty and serenity';
      case 'food-focused':
        return 'You travel to savor local flavors';
      case 'urban explorer':
        return 'You thrive in bustling cityscapes';
      default:
        return 'You have a versatile travel approach';
    }
  }
}

class InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  const InsightCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 40, color: Colors.blueAccent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'JosefinSans',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        Text(
                          description,
                          style: const TextStyle(
                            fontFamily: 'JosefinSans',
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
