import 'dart:math';

import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:appwrite/appwrite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:confetti/confetti.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shimmer/shimmer.dart';

class WorldMapPage extends StatefulWidget {
  final Databases databases;
  final String userId;

  const WorldMapPage(
      {super.key, required this.databases, required this.userId});

  @override
  _WorldMapPageState createState() => _WorldMapPageState();
}

class _WorldMapPageState extends State<WorldMapPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> locations = [];
  Map<String, dynamic> travelInsights = {};
  bool isLoading = true;
  String errorMessage = '';
  int _currentTabIndex = 0;
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  LatLng? _currentMapCenter;
  double _currentZoom = 3.0;
  List<LatLng> _animatedPath = [];
  int _pathAnimationIndex = 0;
  bool _showFullPath = false;
  bool _showHeatmap = false;
  bool _showEmojiReaction = false;
  String _selectedEmoji = "❤️";
  ConfettiController? _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _travelPersonality = "";
  String _travelMood = "";
  Map<String, double> _sentimentAnalysis = {};
  List<String> _recommendedDestinations = [];
  final List<String> _emojiOptions = [
    "❤️",
    "😊",
    "😍",
    "🤩",
    "🌍",
    "✈️",
    "🗺️"
  ];

  // New animation controllers
  late AnimationController _mapPulseController;
  late Animation<double> _mapPulseAnimation;
  late AnimationController _markerBounceController;
  late Animation<double> _markerBounceAnimation;
  late AnimationController _compassController;
  double? _compassHeading;
  bool _showCompass = false;
  bool _showTravelStats = false;
  bool _show3DView = false;
  double _tiltAngle = 0.0;
  List<Map<String, dynamic>> _clusterMarkers = [];
  bool _showClusters = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // New animation controllers
    _mapPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _mapPulseAnimation = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _mapPulseController, curve: Curves.easeInOut),
    );

    _markerBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _markerBounceAnimation = Tween(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
          parent: _markerBounceController, curve: Curves.elasticOut),
    );

    _compassController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Setup compass listener
    FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _compassHeading = event.heading;
        });
      }
    });

    _fetchData();
    Future.delayed(const Duration(milliseconds: 500), _animatePath);
  }

  @override
  void dispose() {
    _confettiController?.dispose();
    _pulseController.dispose();
    _mapPulseController.dispose();
    _markerBounceController.dispose();
    _compassController.dispose();
    super.dispose();
  }

  void _animatePath() {
    if (_pathAnimationIndex < _animatedPath.length - 1) {
      setState(() {
        _pathAnimationIndex++;
      });
      Future.delayed(
        Duration(milliseconds: 100 + (_pathAnimationIndex % 3) * 50),
        _animatePath,
      );
    } else if (_pathAnimationIndex == _animatedPath.length - 1) {
      _confettiController?.play();
      setState(() {
        _showTravelStats = true;
      });
    }
  }

  void _toggle3DView() {
    setState(() {
      _show3DView = !_show3DView;
      if (_show3DView) {
        _tiltAngle = 45.0;
      } else {
        _tiltAngle = 0.0;
      }
    });
  }

  void _toggleCompass() {
    setState(() {
      _showCompass = !_showCompass;
    });
  }

  void _toggleClusters() {
    setState(() {
      _showClusters = !_showClusters;
      if (_showClusters) {
        _generateClusters();
      }
    });
  }

  void _generateClusters() {
    final clusters = <Map<String, dynamic>>[];
    final double clusterDistance = 100000 / _currentZoom;

    for (final location in locations) {
      bool addedToCluster = false;
      final currentPoint = location['coordinates'] as LatLng;

      for (final cluster in clusters) {
        final clusterCenter = cluster['center'] as LatLng;
        final distance = _calculateDistance(currentPoint, clusterCenter);

        if (distance < clusterDistance) {
          (cluster['locations'] as List).add(location);
          cluster['count'] = (cluster['count'] as int) + 1;
          cluster['center'] = LatLng(
            (clusterCenter.latitude + currentPoint.latitude) / 2,
            (clusterCenter.longitude + currentPoint.longitude) / 2,
          );
          addedToCluster = true;
          break;
        }
      }

      if (!addedToCluster) {
        clusters.add({
          'center': currentPoint,
          'locations': [location],
          'count': 1,
        });
      }
    }

    setState(() {
      _clusterMarkers = clusters;
    });
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _fetchLocations(),
        _fetchTravelInsights(),
      ]);
      if (locations.isNotEmpty) {
        _animatedPath =
            locations.map((loc) => loc['coordinates'] as LatLng).toList();
        _generateNLPInsights();
        _generateRecommendations();
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _generateNLPInsights() {
    final allActivities =
        travelInsights['activity_preferences']?.keys.toList() ?? [];
    final allLocations = locations.map((l) => l['name'].toString()).toList();

    int positiveWords = 0;
    int neutralWords = 0;
    int negativeWords = 0;

    for (final loc in locations) {
      final name = loc['name'].toString().toLowerCase();
      if (name.contains("beach") ||
          name.contains("paradise") ||
          name.contains("resort")) {
        positiveWords++;
      } else if (name.contains("mountain") || name.contains("adventure")) {
        positiveWords++;
      } else if (name.contains("airport") || name.contains("station")) {
        neutralWords++;
      } else {
        neutralWords++;
      }
    }

    final total = positiveWords + neutralWords + negativeWords;
    if (total > 0) {
      _sentimentAnalysis = {
        'positive': positiveWords / total,
        'neutral': neutralWords / total,
        'negative': negativeWords / total,
      };
    }

    final avgStay = travelInsights['avg_trip_duration'] ?? 0;
    final totalTrips = travelInsights['total_trips'] ?? 0;
    final mostCommonActivities = travelInsights['most_common_activities'] ?? [];

    if (avgStay > 14) {
      _travelPersonality = "The Deep Explorer";
    } else if (avgStay > 7) {
      _travelPersonality = "The Cultural Immerser";
    } else if (avgStay > 3) {
      _travelPersonality = "The Weekend Wanderer";
    } else {
      _travelPersonality = "The Quick Adventurer";
    }

    bool hasAdventure = mostCommonActivities.any((a) =>
        a.key.toString().toLowerCase().contains('hiking') ||
        a.key.toString().toLowerCase().contains('adventure'));
    bool hasRelaxation = mostCommonActivities.any((a) =>
        a.key.toString().toLowerCase().contains('beach') ||
        a.key.toString().toLowerCase().contains('spa'));
    bool hasUrban = mostCommonActivities.any((a) =>
        a.key.toString().toLowerCase().contains('city') ||
        a.key.toString().toLowerCase().contains('museum'));

    if (hasAdventure && !hasRelaxation && !hasUrban) {
      _travelPersonality += " - Thrill Seeker";
    } else if (!hasAdventure && hasRelaxation && !hasUrban) {
      _travelPersonality += " - Relaxation Enthusiast";
    } else if (!hasAdventure && !hasRelaxation && hasUrban) {
      _travelPersonality += " - Urban Explorer";
    } else if (totalTrips > 20) {
      _travelPersonality += " - Seasoned Globetrotter";
    }

    if (_sentimentAnalysis['positive'] != null) {
      if (_sentimentAnalysis['positive']! > 0.8) {
        _travelMood = "Joyful Wanderer";
      } else if (_sentimentAnalysis['positive']! > 0.6) {
        _travelMood = "Happy Explorer";
      } else if (_sentimentAnalysis['negative']! > 0.3) {
        _travelMood = "Moody Traveler";
      } else {
        _travelMood = "Curious Explorer";
      }
    }
  }

  void _generateRecommendations() {
    final mostCommonActivities = travelInsights['most_common_activities'] ?? [];
    final mostActiveSeason =
        travelInsights['most_active_season']?.toString() ?? 'Summer';

    final recommendations = <String>[];

    for (final activity in mostCommonActivities.take(3)) {
      final activityStr = activity.key.toString().toLowerCase();
      if (activityStr.contains("beach")) {
        recommendations.add("Maldives");
        recommendations.add("Bora Bora");
      }
      if (activityStr.contains("hiking")) {
        recommendations.add("Swiss Alps");
        recommendations.add("Patagonia");
      }
      if (activityStr.contains("city")) {
        recommendations.add("Tokyo");
        recommendations.add("New York");
      }
    }

    if (mostActiveSeason == 'Winter') {
      recommendations.add("Northern Lights in Iceland");
      recommendations.add("Skiing in Whistler");
    } else if (mostActiveSeason == 'Summer') {
      recommendations.add("Greek Islands");
      recommendations.add("California Coast");
    }

    _recommendedDestinations = recommendations.toSet().toList();

    if (_recommendedDestinations.isEmpty) {
      _recommendedDestinations.addAll(
          ["Kyoto, Japan", "Santorini, Greece", "Banff National Park, Canada"]);
    }
  }

  List<String> _generateMapFunFacts() {
    final totalTrips = travelInsights['total_trips'] ?? 0;
    final farthestLocation =
        travelInsights['farthest_location'] ?? {'distance': 0};
    final mostVisited = travelInsights['most_visited_location'] ?? {'count': 0};
    final avgStay = travelInsights['avg_trip_duration'] ?? 0;
    final seasonalDist = travelInsights['seasonal_distribution'] ?? {};
    final mostActiveSeason = travelInsights['most_active_season'] ?? 'Summer';
    final longestStay = travelInsights['longest_stay'] ?? {'value': 0};

    double worldCoverage = (locations.length / 195 * 100).clamp(0, 100);

    String compassDirection = "north";
    if (locations.isNotEmpty && farthestLocation['name'] != null) {
      final home = locations.firstWhere((l) => l['name'] == mostVisited['name'],
          orElse: () => locations.first)['coordinates'];
      final farthest = locations.firstWhere(
          (l) => l['name'] == farthestLocation['name'],
          orElse: () => locations.last)['coordinates'];

      final angle = vm.degrees(atan2(farthest.longitude - home.longitude,
          farthest.latitude - home.latitude));

      if (angle >= -45 && angle < 45)
        compassDirection = "north";
      else if (angle >= 45 && angle < 135)
        compassDirection = "east";
      else if (angle >= 135 || angle < -135)
        compassDirection = "south";
      else
        compassDirection = "west";
    }

    return [
      "You've traveled ${farthestLocation['distance']} km ${compassDirection} to your farthest destination!",
      "Your most visited location (${mostVisited['name']}) accounts for ${(mostVisited['count'] / totalTrips * 100).toStringAsFixed(1)}% of your trips!",
      "Based on your travel patterns, you've explored approximately ${worldCoverage.toStringAsFixed(2)}% of the world's countries!",
      "Your longest stay was ${longestStay['value']} days - that's ${(longestStay['value'] / 30).toStringAsFixed(1)} months of adventure!",
      "You average ${avgStay.toStringAsFixed(1)} days per trip - ${avgStay > 7 ? 'a true immersion seeker!' : 'always on the move!'}",
      "${mostActiveSeason} is your favorite season with ${seasonalDist[mostActiveSeason]} trips!",
      "Your travel path forms a ${_calculatePathShape()} shape across the map!",
      "You've traveled enough to circle the Earth ${(farthestLocation['distance'] / 40075).toStringAsFixed(2)} times!",
      "Your travel density is highest in ${_calculateDenseRegion()} region!",
      "Based on your locations, you prefer ${_calculateClimatePreference()} climates!",
    ];
  }

  String _calculatePathShape() {
    if (locations.length < 3) return "simple";

    final first = locations.first['coordinates'] as LatLng;
    final last = locations.last['coordinates'] as LatLng;
    final distance = _calculateDistance(first, last);

    if (distance < 1000) return "circular";

    double latRange = 0;
    double lonRange = 0;

    for (final loc in locations) {
      final coords = loc['coordinates'] as LatLng;
      latRange += coords.latitude.abs();
      lonRange += coords.longitude.abs();
    }

    latRange = latRange / locations.length;
    lonRange = lonRange / locations.length;

    if (latRange > lonRange * 1.5) return "vertical";
    if (lonRange > latRange * 1.5) return "horizontal";
    return "zig-zag";
  }

  String _calculateDenseRegion() {
    if (locations.isEmpty) return "unknown";

    int europe = 0, asia = 0, africa = 0, americas = 0, oceania = 0;

    for (final loc in locations) {
      final coords = loc['coordinates'] as LatLng;
      if (coords.latitude > 35 &&
          coords.longitude > -20 &&
          coords.longitude < 40) {
        europe++;
      } else if (coords.latitude > -10 &&
          coords.longitude > 60 &&
          coords.longitude < 150) {
        asia++;
      } else if (coords.latitude > -35 && coords.latitude < 35) {
        africa++;
      } else if (coords.longitude > -160 && coords.longitude < -30) {
        americas++;
      } else {
        oceania++;
      }
    }

    final counts = {
      'Europe': europe,
      'Asia': asia,
      'Africa': africa,
      'Americas': americas,
      'Oceania': oceania,
    };

    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _calculateClimatePreference() {
    if (locations.isEmpty) return "temperate";

    int tropical = 0, arid = 0, temperate = 0, continental = 0, polar = 0;

    for (final loc in locations) {
      final coords = loc['coordinates'] as LatLng;
      final lat = coords.latitude.abs();

      if (lat < 23.5)
        tropical++;
      else if (lat < 35)
        arid++;
      else if (lat < 50)
        temperate++;
      else if (lat < 66.5)
        continental++;
      else
        polar++;
    }

    final counts = {
      'tropical': tropical,
      'arid': arid,
      'temperate': temperate,
      'continental': continental,
      'polar': polar,
    };

    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Future<Map<String, dynamic>?> _geocodeLocation(String address) async {
    if (address.isEmpty) return null;

    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$encodedAddress');

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'TravelJournal/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          return {
            'name': address,
            'coordinates': LatLng(lat, lon),
            'display_name': data[0]['display_name'].toString(),
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return null;
    }
  }

  Future<void> _fetchLocations() async {
    try {
      final response = await widget.databases.listDocuments(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67eab72f0030b02f1623',
        queries: [
          Query.equal('userId', widget.userId),
          Query.isNotNull('location'),
          Query.notEqual('location', ''),
        ],
      );

      final List<Map<String, dynamic>> fetchedLocations = [];

      for (final doc in response.documents) {
        final location = doc.data['location'].toString();
        if (location.isNotEmpty) {
          final geoData = await _geocodeLocation(location);
          if (geoData != null) {
            fetchedLocations.add({
              ...geoData,
              'createdAt': doc.data['createdAt'].toString(),
              'tags': (doc.data['tags'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              'photos': (doc.data['photos'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
            });
          }
        }
      }

      fetchedLocations.sort((a, b) => DateTime.parse(b['createdAt'])
          .compareTo(DateTime.parse(a['createdAt'])));

      if (mounted) {
        setState(() {
          locations = fetchedLocations;
          if (locations.isNotEmpty) {
            _currentMapCenter = locations.first['coordinates'];
          }
          if (locations.isEmpty) {
            errorMessage = 'No locations found or could not be geocoded';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error fetching locations: ${e.toString()}';
        });
      }
      debugPrint('Error fetching locations: $e');
    }
  }

  Future<void> _fetchTravelInsights() async {
    try {
      final response = await widget.databases.listDocuments(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67eab72f0030b02f1623',
        queries: [Query.equal('userId', widget.userId)],
      );

      final insights = _analyzeTravelPatterns(response.documents);
      if (mounted) {
        setState(() => travelInsights = insights);
      }
    } catch (e) {
      debugPrint('Error fetching insights: $e');
    }
  }

  Map<String, dynamic> _analyzeTravelPatterns(List<Document> documents) {
    final List<int> durations = [];
    final Map<String, int> locationCounts = {};
    final Map<String, int> locationDurations = {};
    final Map<String, int> activityCounts = {};
    final Map<String, List<String>> locationActivities = {};
    final Map<int, int> hourDistribution = {};
    final Map<String, int> weekdayDistribution = {};
    final Map<String, int> seasonalDistribution = {
      'Winter': 0,
      'Spring': 0,
      'Summer': 0,
      'Fall': 0
    };

    LatLng? homeLocation;
    final Map<String, double> locationDistances = {};

    for (final doc in documents) {
      try {
        if (doc.data['location'] != null) {
          final loc = doc.data['location'].toString();
          locationCounts[loc] = (locationCounts[loc] ?? 0) + 1;

          if (homeLocation == null && locations.isNotEmpty) {
            homeLocation = locations.firstWhere(
                (l) => l['name'].toString() == loc,
                orElse: () => locations.first)['coordinates'];
          }
        }

        final createdAt = DateTime.parse(doc.data['createdAt'].toString());
        DateTime? endDate;

        if (doc.data['endDate'] != null) {
          endDate = DateTime.parse(doc.data['endDate'].toString());
        } else if (doc.data['updatedAt'] != null) {
          endDate = DateTime.parse(doc.data['updatedAt'].toString());
        }

        if (endDate != null) {
          final duration = endDate.difference(createdAt).inDays;
          durations.add(duration);

          if (doc.data['location'] != null) {
            final loc = doc.data['location'].toString();
            locationDurations[loc] = (locationDurations[loc] ?? 0) + duration;
          }
        }

        if (doc.data['tags'] is List) {
          for (final tag in (doc.data['tags'] as List)) {
            final tagStr = tag.toString();
            activityCounts[tagStr] = (activityCounts[tagStr] ?? 0) + 1;

            if (doc.data['location'] != null) {
              final loc = doc.data['location'].toString();
              locationActivities[loc] ??= [];
              locationActivities[loc]!.add(tagStr);
            }
          }
        }

        final hour = createdAt.hour;
        final weekday = createdAt.weekday;
        final month = createdAt.month;

        hourDistribution[hour] = (hourDistribution[hour] ?? 0) + 1;
        weekdayDistribution[weekday.toString()] =
            (weekdayDistribution[weekday.toString()] ?? 0) + 1;

        if (month >= 3 && month <= 5) {
          seasonalDistribution['Spring'] = seasonalDistribution['Spring']! + 1;
        } else if (month >= 6 && month <= 8) {
          seasonalDistribution['Summer'] = seasonalDistribution['Summer']! + 1;
        } else if (month >= 9 && month <= 11) {
          seasonalDistribution['Fall'] = seasonalDistribution['Fall']! + 1;
        } else {
          seasonalDistribution['Winter'] = seasonalDistribution['Winter']! + 1;
        }
      } catch (e) {
        debugPrint('Error parsing document: $e');
      }
    }

    if (homeLocation != null) {
      for (final loc in locations) {
        if (loc['name'] != null && loc['coordinates'] != null) {
          final distance = _calculateDistance(
            homeLocation,
            loc['coordinates'],
          );
          locationDistances[loc['name'].toString()] = distance;
        }
      }
    }

    final mostCommonLocation = locationCounts.entries.isNotEmpty
        ? locationCounts.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    final mostCommonHour = hourDistribution.entries.isNotEmpty
        ? hourDistribution.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    final mostCommonWeekday = weekdayDistribution.entries.isNotEmpty
        ? weekdayDistribution.entries
            .reduce((a, b) => a.value > b.value ? a : b)
        : null;

    final mostActiveSeason = seasonalDistribution.entries.isNotEmpty
        ? seasonalDistribution.entries
            .reduce((a, b) => a.value > b.value ? a : b)
        : null;

    final farthestLocation = locationDistances.entries.isNotEmpty
        ? locationDistances.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    return {
      'avg_trip_duration': durations.isNotEmpty
          ? (durations.reduce((a, b) => a + b) ~/ durations.length)
          : 0,
      'total_trips': documents.length,
      'activity_preferences': activityCounts,
      'most_common_activities': _getTopItems(activityCounts, 3),
      'hour_distribution': hourDistribution,
      'most_common_hour': mostCommonHour?.key,
      'weekday_distribution': weekdayDistribution,
      'most_common_weekday': mostCommonWeekday?.key,
      'seasonal_distribution': seasonalDistribution,
      'most_active_season': mostActiveSeason?.key,
      'location_counts': locationCounts,
      'most_visited_location': mostCommonLocation != null
          ? {
              'name': mostCommonLocation.key,
              'count': mostCommonLocation.value,
            }
          : null,
      'location_durations': locationDurations,
      'longest_stay': _getTopItems(locationDurations, 1).isNotEmpty
          ? _getTopItems(locationDurations, 1)[0]
          : null,
      'farthest_location': farthestLocation != null
          ? {
              'name': farthestLocation.key,
              'distance': farthestLocation.value,
            }
          : null,
    };
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance(start, end) / 1000;
  }

  double _calculateTotalDistance() {
    if (locations.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 0; i < locations.length - 1; i++) {
      total += _calculateDistance(
        locations[i]['coordinates'],
        locations[i + 1]['coordinates'],
      );
    }
    return total;
  }

  List<MapEntry<String, dynamic>> _getTopItems(
      Map<String, dynamic> map, int count) {
    final entries = map.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(count).toList();
  }

  String _generateFunFact() {
    final totalTrips = travelInsights['total_trips'] ?? 0;
    final mostCommonHour =
        travelInsights['most_common_hour']?.toString() ?? '12';
    final mostActiveSeason =
        travelInsights['most_active_season']?.toString() ?? 'Summer';
    final farthestLocation =
        travelInsights['farthest_location'] ?? {'distance': 0};

    final facts = [
      "You've traveled ${farthestLocation['distance']} km to your farthest destination! That's like traveling to the moon ${(farthestLocation['distance'] / 384400).toStringAsFixed(5)} times!",
      "Your most active travel season is $mostActiveSeason. Perfect time for ${mostActiveSeason == 'Summer' ? 'beaches' : mostActiveSeason == 'Winter' ? 'skiing' : mostActiveSeason == 'Spring' ? 'flower viewing' : 'fall foliage'}!",
      "You usually start your adventures around ${_formatHour(int.parse(mostCommonHour))}. ${int.parse(mostCommonHour) < 12 ? 'Early bird catches the worm!' : 'Perfect time to start the day!'}",
      "With $totalTrips trips logged, you're a ${totalTrips > 20 ? 'seasoned globetrotter' : totalTrips > 10 ? 'frequent traveler' : 'budding explorer'}!",
      "Your travel pattern suggests you're a $_travelPersonality. Keep exploring!",
    ];

    return facts[DateTime.now().millisecondsSinceEpoch % facts.length];
  }

  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: _buildInsightCard(
              icon: Icons.psychology,
              title: 'Your Travel Personality',
              child: Column(
                children: [
                  Text(
                    _travelPersonality,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mood: $_travelMood',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blue[800],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_sentimentAnalysis.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: _sentimentAnalysis['positive']! * 100,
                              color: Colors.green,
                              title:
                                  '${(_sentimentAnalysis['positive']! * 100).toStringAsFixed(1)}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            PieChartSectionData(
                              value: _sentimentAnalysis['neutral']! * 100,
                              color: Colors.blue,
                              title:
                                  '${(_sentimentAnalysis['neutral']! * 100).toStringAsFixed(1)}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            PieChartSectionData(
                              value: _sentimentAnalysis['negative']! * 100,
                              color: Colors.red,
                              title:
                                  '${(_sentimentAnalysis['negative']! * 100).toStringAsFixed(1)}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your travel sentiment analysis based on visited locations',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          _buildInsightCard(
            icon: Icons.travel_explore,
            title: 'Your Next Adventure Awaits!',
            child: Column(
              children: [
                const Text(
                  'Based on your travel patterns, we recommend:',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recommendedDestinations
                      .map((dest) => Chip(
                            label: Text(dest),
                            avatar: const Icon(Icons.place, size: 18),
                            backgroundColor: Colors.orange[100],
                            elevation: 2,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _recommendedDestinations.shuffle();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Show More Suggestions'),
                ),
              ],
            ),
          ),
          _buildInsightCard(
            icon: Icons.timeline,
            title: 'Your Travel DNA',
            child: Column(
              children: [
                _buildStatRow('Total Locations Visited',
                    travelInsights['total_trips']?.toString() ?? '0'),
                _buildStatRow('Average Stay Duration',
                    '${travelInsights['avg_trip_duration']?.toString() ?? '0'} days'),
                if (travelInsights['longest_stay'] != null)
                  _buildStatRow(
                      'Longest Stay',
                      '${travelInsights['longest_stay']!.key} '
                          '(${travelInsights['longest_stay']!.value} days)'),
                if (travelInsights['most_common_hour'] != null)
                  _buildStatRow(
                      'Favorite Time to Explore',
                      _formatHour(int.parse(
                          travelInsights['most_common_hour'].toString()))),
                if (travelInsights['most_common_weekday'] != null)
                  _buildStatRow(
                      'Favorite Day to Travel',
                      _formatWeekday(int.parse(
                          travelInsights['most_common_weekday'].toString()))),
              ],
            ),
          ),
          _buildInsightCard(
            icon: Icons.emoji_events,
            title: 'Activity Profile',
            child: Column(
              children: [
                if (travelInsights['most_common_activities'] != null)
                  ...travelInsights['most_common_activities']!
                      .map((entry) =>
                          _buildActivityItem(entry.key.toString(), entry.value))
                      .toList(),
                if (travelInsights['activity_preferences'] != null)
                  SizedBox(
                    height: 200,
                    child: _buildActivityChart(
                        travelInsights['activity_preferences']),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'This shows what types of activities you most frequently engage in while traveling',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          _buildInsightCard(
            icon: Icons.flag,
            title: 'Recent Adventures',
            child: Column(
              children: [
                if (locations.isNotEmpty)
                  ...locations
                      .take(5)
                      .map((location) => _buildLocationCard(location)),
                if (locations.isEmpty)
                  const Text(
                    'No recent locations found',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
          _buildInsightCard(
            icon: Icons.star,
            title: 'Travel Superlatives',
            child: Column(
              children: [
                if (travelInsights['most_visited_location'] != null)
                  _buildSuperlativeItem(
                    Icons.location_city,
                    'Most Visited Place',
                    travelInsights['most_visited_location']['name'].toString(),
                    '${travelInsights['most_visited_location']['count']} visits',
                  ),
                if (travelInsights['farthest_location'] != null)
                  _buildSuperlativeItem(
                    Icons.airplanemode_active,
                    'Farthest Journey',
                    travelInsights['farthest_location']['name'].toString(),
                    '${travelInsights['farthest_location']['distance'].toStringAsFixed(0)} km from home',
                  ),
                if (travelInsights['most_active_season'] != null)
                  _buildSuperlativeItem(
                    _getSeasonIcon(
                        travelInsights['most_active_season'].toString()),
                    'Favorite Season',
                    travelInsights['most_active_season'].toString(),
                    '${travelInsights['seasonal_distribution'][travelInsights['most_active_season']]} trips',
                  ),
              ],
            ),
          ),
          _buildInsightCard(
            icon: Icons.emoji_emotions,
            title: 'Fun Travel Fact',
            child: Column(
              children: [
                const Icon(Icons.auto_awesome, size: 40, color: Colors.amber),
                const SizedBox(height: 12),
                Text(
                  _generateFunFact(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (_showEmojiReaction)
                  Text(
                    _selectedEmoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                IconButton(
                  icon: const Icon(Icons.mood),
                  onPressed: () {
                    setState(() {
                      _showEmojiReaction = !_showEmojiReaction;
                      if (_showEmojiReaction) {
                        _selectedEmoji = _emojiOptions[
                            DateTime.now().millisecondsSinceEpoch %
                                _emojiOptions.length];
                      }
                    });
                  },
                  tooltip: 'React to this fact',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String activity, int count) {
    return ListTile(
      leading: const Icon(Icons.label, color: Colors.blue),
      title: Text(
        activity,
        style: const TextStyle(fontFamily: 'JosefinSans'),
      ),
      trailing: Text(
        '$count times',
        style: const TextStyle(
          fontFamily: 'JosefinSans',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActivityChart(Map<String, dynamic> activities) {
    final entries = activities.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < entries.length && index < 5) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      entries[index].key,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(),
                    style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barGroups: entries
            .take(5)
            .map((entry) => BarChartGroupData(
                  x: entries.indexOf(entry),
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.toDouble(),
                      color: Colors.blue,
                      width: 16,
                    )
                  ],
                ))
            .toList(),
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.red),
        title: Text(location['name']?.toString() ?? 'Unknown location'),
        subtitle: Text(location['display_name']?.toString() ?? ''),
        trailing: IconButton(
          icon: const Icon(Icons.map),
          onPressed: () => _openInMaps(location['coordinates']),
        ),
        onTap: () {
          setState(() {
            _currentTabIndex = 0;
            _currentMapCenter = location['coordinates'];
            _currentZoom = 10.0;
          });
        },
      ),
    );
  }

  Future<void> _openInMaps(LatLng coords) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${coords.latitude},${coords.longitude}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not launch maps')));
    }
  }

  Widget _buildSuperlativeItem(
      IconData icon, String title, String value, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing:
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  IconData _getSeasonIcon(String season) {
    switch (season.toLowerCase()) {
      case 'winter':
        return Icons.ac_unit;
      case 'spring':
        return Icons.local_florist;
      case 'summer':
        return Icons.wb_sunny;
      case 'fall':
        return Icons.forest;
      default:
        return Icons.calendar_today;
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
      {required IconData icon, required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  String _formatHour(int hour) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, hour, 0);
    return DateFormat.jm().format(dateTime);
  }

  String _formatWeekday(int weekday) {
    return DateFormat.EEEE().format(DateTime(2023, 1, weekday));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTabIndex == 0 ? 'Your Travel Map' : 'Travel Personality',
          style: const TextStyle(
            fontFamily: 'JosefinSans',
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF2C7DA0),
        actions: [
          if (_currentTabIndex == 0)
            IconButton(
              icon: const Icon(Icons.timeline),
              onPressed: () {
                setState(() {
                  _showFullPath = !_showFullPath;
                  if (_showFullPath) {
                    _pathAnimationIndex = 0;
                    _animatePath();
                  }
                });
              },
              tooltip: 'Toggle travel path',
            ),
          if (_currentTabIndex == 0)
            IconButton(
              icon: const Icon(Icons.whatshot),
              onPressed: () {
                setState(() {
                  _showHeatmap = !_showHeatmap;
                });
              },
              tooltip: 'Toggle heatmap',
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentTabIndex == 0
                  ? _buildMapView()
                  : _buildInsightsTab(),
          ConfettiWidget(
            confettiController: _confettiController!,
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
    );
  }

  Widget _buildMapView() {
    if (locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              errorMessage.isNotEmpty ? errorMessage : 'No locations available',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Animated map container
        ScaleTransition(
          scale: _mapPulseAnimation,
          child: FlutterMap(
            options: MapOptions(
              initialCenter:
                  _currentMapCenter ?? locations.first['coordinates'],
              initialZoom: _currentZoom,
              onTap: (_, LatLng coords) {
                setState(() {
                  _currentMapCenter = coords;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.travel_journal',
              ),
              if (_showFullPath && _animatedPath.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _animatedPath.sublist(0, _pathAnimationIndex + 1),
                      color: Colors.blue.withOpacity(0.7),
                      strokeWidth: 3,
                    ),
                  ],
                ),
              if (_showHeatmap && locations.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final loc in locations)
                      Marker(
                        point: loc['coordinates'],
                        width: 80,
                        height: 80,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.red.withOpacity(0.2),
                                Colors.transparent,
                              ],
                              stops: const [0.1, 0.8],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (_showClusters && _clusterMarkers.isNotEmpty)
                MarkerLayer(
                  markers: _clusterMarkers.map((cluster) {
                    return Marker(
                      point: cluster['center'],
                      width: 40 + (cluster['count'] as int) * 5,
                      height: 40 + (cluster['count'] as int) * 5,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentZoom = _currentZoom + 2;
                            _currentMapCenter = cluster['center'];
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.6),
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cluster['count'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              if (!_showClusters)
                MarkerLayer(
                  markers: locations.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final location = entry.value;
                    return Marker(
                      point: location['coordinates'],
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(location['name']?.toString() ??
                                  'Unknown location'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(location['display_name']?.toString() ??
                                      ''),
                                  const SizedBox(height: 8),
                                  if (location['tags'] != null &&
                                      location['tags'].isNotEmpty)
                                    Wrap(
                                      spacing: 4,
                                      children: (location['tags'] as List)
                                          .map((tag) => Chip(
                                                label: Text(tag.toString()),
                                                backgroundColor:
                                                    Colors.blue[100],
                                              ))
                                          .toList(),
                                    ),
                                  if (location['photos'] != null &&
                                      location['photos'].isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: SizedBox(
                                        height: 100,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount:
                                              (location['photos'] as List)
                                                  .length,
                                          itemBuilder: (context, index) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8),
                                              child: Image.network(
                                                location['photos'][index]
                                                    .toString(),
                                                width: 100,
                                                fit: BoxFit.cover,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _openInMaps(location['coordinates']);
                                  },
                                  child: const Text('Open in Maps'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: AnimatedBuilder(
                          animation: _markerBounceAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                  0,
                                  -_markerBounceAnimation.value *
                                      (_currentMapCenter ==
                                              location['coordinates']
                                          ? 1.5
                                          : 1.0)),
                              child: AnimatedScale(
                                scale:
                                    _currentMapCenter == location['coordinates']
                                        ? 1.5
                                        : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  Icons.location_pin,
                                  color: idx == 0
                                      ? Colors.red
                                      : Colors.blue.withOpacity(
                                          0.7 + (idx / locations.length) * 0.3),
                                  size: 40,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),

        // Compass overlay
        if (_showCompass && _compassHeading != null)
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentZoom = _currentZoom + 1;
                });
              },
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 500),
                turns: -(_compassHeading! / 360),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.explore,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ),

        // Travel stats overlay
        if (_showTravelStats)
          Positioned(
            top: 16,
            left: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Travel Stats',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                        'Locations Visited', locations.length.toString()),
                    _buildStatRow('Total Distance',
                        '${_calculateTotalDistance().toStringAsFixed(0)} km'),
                    _buildStatRow('Average Stay',
                        '${travelInsights['avg_trip_duration']?.toString() ?? '0'} days'),
                    _buildStatRow(
                        'Favorite Season',
                        travelInsights['most_active_season']?.toString() ??
                            'Unknown'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showTravelStats = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Fun facts floating button
        Positioned(
          bottom: 120,
          right: 16,
          child: FloatingActionButton(
            onPressed: () {
              final facts = _generateMapFunFacts();
              final randomFact =
                  facts[DateTime.now().millisecondsSinceEpoch % facts.length];
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(randomFact),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            heroTag: 'funFacts',
            mini: true,
            child: const Icon(Icons.emoji_objects),
            tooltip: 'Show travel fun fact',
          ),
        ),

        // Map controls
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _currentMapCenter = locations.first['coordinates'];
                    _currentZoom = 3.0;
                    _tiltAngle = 0.0;
                  });
                },
                child: const Icon(Icons.explore),
                tooltip: 'Reset view',
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _currentZoom = _currentZoom + 1;
                  });
                },
                mini: true,
                child: const Icon(Icons.add),
                tooltip: 'Zoom in',
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _currentZoom = _currentZoom - 1;
                  });
                },
                mini: true,
                child: const Icon(Icons.remove),
                tooltip: 'Zoom out',
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: _toggleCompass,
                mini: true,
                child: const Icon(Icons.explore),
                tooltip: 'Toggle compass',
                backgroundColor: _showCompass ? Colors.blue : null,
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: _toggle3DView,
                mini: true,
                child: const Icon(Icons.threed_rotation),
                tooltip: 'Toggle 3D view',
                backgroundColor: _show3DView ? Colors.blue : null,
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: _toggleClusters,
                mini: true,
                child: const Icon(Icons.group_work),
                tooltip: 'Toggle clusters',
                backgroundColor: _showClusters ? Colors.blue : null,
              ),
            ],
          ),
        ),

        // Path animation progress indicator
        if (_showFullPath && _pathAnimationIndex < _animatedPath.length - 1)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: LinearProgressIndicator(
              value: _pathAnimationIndex / (_animatedPath.length - 1),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
      ],
    );
  }
}
