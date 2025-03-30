import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:confetti/confetti.dart';
import 'package:shimmer/shimmer.dart';
import 'package:latlong2/latlong.dart';

class InsightPage extends StatefulWidget {
  final Databases databases;
  final String userId;
  final Client client;

  const InsightPage({
    super.key,
    required this.databases,
    required this.userId,
    required this.client,
  });

  @override
  State<InsightPage> createState() => _InsightPageState();
}

class _InsightPageState extends State<InsightPage>
    with TickerProviderStateMixin {
  Map<String, dynamic> insights = {};
  bool isLoading = true;
  String? error;
  bool _isDisposed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  ConfettiController? _confettiController;
  int _currentInsightIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fetchInsights();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _confettiController?.dispose();
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  Future<void> _fetchInsights() async {
  _safeSetState(() {
    isLoading = true;
    error = null;
  });

  try {
    final allPages = await widget.databases.listDocuments(
      databaseId: '67c32fc700070ceeadac',
      collectionId: '67cbeccb00382aae9f27',
      queries: [Query.equal('userId', widget.userId)],
    ).timeout(const Duration(seconds: 30));

    final dataToSend = {
      'allPages': allPages.documents.map((doc) => doc.data).toList(),
      'bucketId': '67cd36510039f3d96c62',
      'userId': widget.userId,
    };

    const baseUrl = 'http://192.168.46.90:5000';
    final response = await http.post(
      Uri.parse('$baseUrl/process-insights'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8', // Explicit content type
        'Accept': 'application/json',
      },
      body: jsonEncode(dataToSend), // Ensure proper JSON encoding
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      _safeSetState(() {
        insights = responseData;
        isLoading = false;
        _confettiController?.play();
      });
    } else {
      throw Exception('Server returned status code ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    _safeSetState(() {
      error = 'Error: ${e.toString()}';
      isLoading = false;
    });
  }
}
  @override
  Widget build(BuildContext context) {
    print('Insights data: ${jsonEncode(insights)}');
    if (isLoading) {
      return _buildLoadingScreen();
    }

    if (error != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Insights',
            style: TextStyle(fontFamily: 'JosefinSans')),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchInsights,
          ),
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
              onPageChanged: (index) =>
                  setState(() => _currentInsightIndex = index),
              children: [
  _buildSafeInsight(_buildLocationSentimentInsight, title: 'Mood by Destination'),
  _buildSafeInsight(_buildSentimentInsight, title: 'Sentiment Journey'),
  _buildSafeInsight(_buildLocationRepeatsInsight, title: 'Favorite Destinations'),
  _buildSafeInsight(_buildSeasonalPatternsInsight, title: 'Travel Seasons'),
  _buildSafeInsight(_buildPhotoTimelineInsight, title: 'Photo Memories'),
  _buildSafeInsight(_buildJournalHighlightsInsight, title: 'Travel Highlights'),
  _buildSafeInsight(_buildTravelPersonalityInsight, title: 'Travel Personality'),
  _buildSafeInsight(_buildGeographicFactsInsight, title: 'Geographic Facts'),
  _buildSafeInsight(_buildActivityPatternsInsight, title: 'Activity Patterns'),
  _buildSafeInsight(_buildMoodTimelineInsight, title: 'Mood Timeline'),
  _buildSafeInsight(_buildTravelDistanceInsight, title: 'Travel Distance'),
  _buildSafeInsight(_buildBucketListInsight, title: 'Bucket List'),
],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:
                  List.generate(12, (index) => _buildPageIndicator(index)),
            ),
          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        child: const Icon(Icons.navigate_next),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentInsightIndex == index
            ? Colors.blueAccent
            : Colors.grey[300],
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
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Unpacking your travel story...',
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
          Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 10),
          Text(error!,
              style: TextStyle(
                  fontFamily: 'JosefinSans', color: Colors.red, fontSize: 16)),
          ElevatedButton(
            onPressed: _fetchInsights,
            child: Text('Retry', style: TextStyle(fontFamily: 'JosefinSans')),
          ),
        ],
      ),
    );
  }

Widget _buildLocationSentimentInsight() {
  final sentimentData = insights['location_sentiment'] as Map<String, dynamic>? ?? {};
  
  // Helper function to safely parse location entries
  List<Map<String, dynamic>> _parseLocations(List<dynamic>? rawLocations) {
    return (rawLocations ?? []).map((item) {
      if (item is List && item.length >= 2) {
        return {
          'name': item[0]?.toString() ?? 'Unknown',
          'value': (item[1] is num ? item[1].toDouble() : 0.0),
        };
      }
      return {'name': 'Unknown', 'value': 0.0};
    }).toList();
  }

  final topLocations = _parseLocations(sentimentData['top_locations'] as List?);
  final bottomLocations = _parseLocations(sentimentData['bottom_locations'] as List?);
  final overallAvg = (sentimentData['overall_average'] as num?)?.toDouble() ?? 0.0;

  return InsightCard(
    icon: Icons.emoji_emotions,
    title: 'Mood by Destination',
    description: 'Where you felt happiest and most reflective',
    child: Column(
      children: [
        Text('Overall Mood Score: ${overallAvg.toStringAsFixed(2)}',
            style: TextStyle(
                fontFamily: 'JosefinSans',
                fontSize: 16,
                color: overallAvg > 0 ? Colors.green : Colors.red)),
        const SizedBox(height: 16),
        if (topLocations.isNotEmpty) ...[
          const Text('Happiest Places:',
              style: TextStyle(
                  fontFamily: 'JosefinSans',
                  fontWeight: FontWeight.bold)),
          ...topLocations.map((loc) => ListTile(
                leading: const Icon(Icons.sentiment_very_satisfied, color: Colors.green),
                title: Text(loc['name'] as String, style: TextStyle(fontFamily: 'JosefinSans')),
                trailing: Text((loc['value'] as double).toStringAsFixed(2),
                    style: TextStyle(
                        fontFamily: 'JosefinSans',
                        color: (loc['value'] as double) > 0.1 ? Colors.green : 
                              (loc['value'] as double) < -0.1 ? Colors.red : Colors.orange)),
              )),
          const Divider(),
        ],
        if (bottomLocations.isNotEmpty) ...[
          const Text('Most Reflective Places:',
              style: TextStyle(
                  fontFamily: 'JosefinSans',
                  fontWeight: FontWeight.bold)),
          ...bottomLocations.map((loc) => ListTile(
                leading: const Icon(Icons.sentiment_dissatisfied, color: Colors.blue),
                title: Text(loc['name'] as String, style: TextStyle(fontFamily: 'JosefinSans')),
                trailing: Text((loc['value'] as double).toStringAsFixed(2),
                    style: TextStyle(
                        fontFamily: 'JosefinSans',
                        color: (loc['value'] as double) > 0.1 ? Colors.green : 
                              (loc['value'] as double) < -0.1 ? Colors.red : Colors.orange)),
              )),
        ],
        const SizedBox(height: 8),
        Text(
          'Positive score > 0.1\nNeutral -0.1 to 0.1\nNegative < -0.1',
          style: TextStyle(
              fontFamily: 'JosefinSans',
              fontSize: 12,
              fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

  Widget _buildSentimentInsight() {
    final timeline = insights['sentiment']?['timeline'] as List?;
    final average = insights['sentiment']?['average_score'] as double?;

    return InsightCard(
      icon: Icons.emoji_emotions,
      title: 'Sentiment Journey',
      description: 'Your emotional adventure over time',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: timeline != null && timeline.isNotEmpty
                ? LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: timeline
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(),
                                  (e.value['score'] as num).toDouble()))
                              .toList(),
                          isCurved: true,
                          color: Colors.blueAccent,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                              show: true, color: Colors.blue.withOpacity(0.2)),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) => Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(
                                  fontFamily: 'JosefinSans', fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: true),
                    ),
                  )
                : const Center(
                    child: Text('No sentiment data available',
                        style: TextStyle(fontFamily: 'JosefinSans'))),
          ),
          if (average != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Average Mood: ${average.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontFamily: 'JosefinSans',
                      color: average > 0 ? Colors.green : Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRepeatsInsight() {
    final locations = insights['location_repeats']?['most_visited'] as List?;

    return InsightCard(
      icon: Icons.repeat,
      title: 'Favorite Destinations',
      description: 'Places you can\'t get enough of',
      child: locations != null && locations.isNotEmpty
          ? Column(
              children: locations
                  .map((loc) => ListTile(
                        leading: Icon(Icons.place, color: Colors.redAccent),
                        title: Text(loc[0],
                            style: TextStyle(fontFamily: 'JosefinSans')),
                        trailing: Text('${loc[1]} visits',
                            style: TextStyle(fontFamily: 'JosefinSans')),
                        onTap: () =>
                            _showLocationDialog(context, loc[0], loc[1]),
                      ))
                  .toList(),
            )
          : const Text('No location data available',
              style: TextStyle(fontFamily: 'JosefinSans')),
    );
  }

  Widget _buildSeasonalPatternsInsight() {
    final patterns = insights['seasonal_patterns']?['by_season'] as Map?;

    return InsightCard(
      icon: Icons.calendar_today,
      title: 'Travel Seasons',
      description: 'Your seasonal travel rhythm',
      child: patterns != null && patterns.isNotEmpty
          ? Column(
              children: patterns.entries
                  .map((entry) => ListTile(
                        leading: Icon(_getSeasonIcon(entry.key),
                            color: Colors.blueAccent),
                        title: Text(entry.key,
                            style: TextStyle(fontFamily: 'JosefinSans')),
                        trailing: Text('${entry.value} trips',
                            style: TextStyle(fontFamily: 'JosefinSans')),
                      ))
                  .toList(),
            )
          : const Text('No seasonal data available',
              style: TextStyle(fontFamily: 'JosefinSans')),
    );
  }

 Widget _buildPhotoTimelineInsight() {
  final photos = (insights['photo_timeline'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  return InsightCard(
    icon: Icons.photo_library,
    title: 'Photo Memories',
    description: 'Relive your travel moments',
    child: photos.isNotEmpty
        ? SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                final url = photo['url'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Hero(
                    tag: 'photo_$index', // Unique tag for each photo
                    child: GestureDetector(
                      onTap: () => _showFullImage(context, url),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        : const Text('No photos available',
            style: TextStyle(fontFamily: 'JosefinSans')),
  );
}

 Widget _buildJournalHighlightsInsight() {
  final highlights = (insights['highlights'] as List?)?.cast<String>() ?? [];

  return InsightCard(
    icon: Icons.star,
    title: 'Travel Highlights',
    description: 'Your standout moments',
    child: highlights.isNotEmpty
        ? Column(
            children: highlights
                .map((highlight) => ListTile(
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: Text(highlight,
                          style: const TextStyle(fontFamily: 'JosefinSans')),
                    ))
                .toList(),
          )
        : const Text('No highlights available',
            style: TextStyle(fontFamily: 'JosefinSans')),
  );
}

  Widget _buildTravelPersonalityInsight() {
    final personality = insights['travel_personality'] ?? 'The Explorer';
    final traits = insights['personality_traits'] ?? ['Adventurous', 'Curious'];

    return InsightCard(
      icon: Icons.psychology,
      title: 'Your Travel Personality',
      description: 'Discover what kind of traveler you are',
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Text(personality,
                style: TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: traits
                .map((trait) => Chip(
                      label: Text(trait,
                          style: TextStyle(fontFamily: 'JosefinSans')),
                      backgroundColor: Colors.blue[100],
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Based on your travel patterns and journal entries',
              style: TextStyle(
                  fontFamily: 'JosefinSans', fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

Widget _buildBucketListInsight() {
  final bucketListData = insights['bucket_list'] as Map<String, dynamic>? ?? {};
  final rawSuggestions = bucketListData['bucket_list'];
  
  List<String> suggestions;
  
  if (rawSuggestions is List) {
    suggestions = rawSuggestions.map((item) {
      if (item is String) return item;
      if (item is Map) return item.toString();
      return 'Unknown suggestion';
    }).whereType<String>().toList();
  } else {
    suggestions = [
      'Visit the Northern Lights',
      'Go on a safari in Africa',
      'Explore the Amazon rainforest'
    ];
  }

  return InsightCard(
    icon: Icons.format_list_bulleted,
    title: 'Your Travel Bucket List',
    description: 'Suggested destinations based on your patterns',
    child: Column(
      children: [
        ...suggestions.map((item) => ListTile(
          leading: const Icon(Icons.place, color: Colors.blue),
          title: Text(item, style: const TextStyle(fontFamily: 'JosefinSans')),
        )).toList(),
        ElevatedButton(
          onPressed: () {
            setState(() {
              suggestions.shuffle();
            });
          },
          child: const Text('Shuffle Suggestions',
              style: TextStyle(fontFamily: 'JosefinSans')),
        ),
      ],
    ),
  );
}

Widget _buildGeographicFactsInsight() {
  final geoData = insights['geographic_facts'] as Map<String, dynamic>? ?? {};
  final rawFacts = geoData['geographic_facts'];
  
  List<String> facts;
  
  if (rawFacts is List) {
    facts = rawFacts.map((item) {
      if (item is String) return item;
      if (item is Map) return item.toString();
      return 'Unknown fact';
    }).whereType<String>().toList();
  } else {
    facts = [
      'You\'ve traveled across 3 climate zones',
      'Your average trip distance is 1200 km',
      'You prefer coastal destinations'
    ];
  }

  return InsightCard(
    icon: Icons.public,
    title: 'Geographic Facts',
    description: 'Fun facts about your travels',
    child: Column(
      children: [
        ...facts.map((fact) => ListTile(
          leading: const Icon(Icons.place, color: Colors.blue),
          title: Text(fact, style: const TextStyle(fontFamily: 'JosefinSans')),
        )).toList(),
        ElevatedButton(
          onPressed: () {
            final randomFact = facts[DateTime.now().millisecondsSinceEpoch % facts.length];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(randomFact,
                  style: const TextStyle(fontFamily: 'JosefinSans')
                ),
              ),
            );
          },
          child: const Text('Show Random Fact',
              style: TextStyle(fontFamily: 'JosefinSans')),
        ),
      ],
    ),
  );
}
Widget _buildSafeInsight(Widget Function() builder, {String title = 'Insight'}) {
  try {
    return builder();
  } catch (e, stack) {
    debugPrint('Error building $title: $e\n$stack');
    return InsightCard(
      icon: Icons.error,
      title: title,
      description: 'Could not load this insight',
      child: Text('Please try again later',
          style: TextStyle(fontFamily: 'JosefinSans')),
    );
  }
}
  Widget _buildActivityPatternsInsight() {
    final activities = insights['activity_patterns'] ??
        {'Hiking': 12, 'Beach': 8, 'City Exploration': 15};

    return InsightCard(
      icon: Icons.directions_walk,
      title: 'Activity Patterns',
      description: 'Your most frequent travel activities',
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            barGroups: activities.entries
                .map((e) => BarChartGroupData(
                      x: activities.keys.toList().indexOf(e.key),
                      barRods: [
                        BarChartRodData(
                          toY: e.value.toDouble(),
                          color: Colors.blue,
                          width: 16,
                        )
                      ],
                    ))
                .toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      activities.keys.elementAt(value.toInt()),
                      style: const TextStyle(
                          fontSize: 10, fontFamily: 'JosefinSans'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodTimelineInsight() {
    final moods = insights['mood_timeline'] ??
        List.generate(12, (i) => {'month': i + 1, 'mood': 0.5 + (i % 3 * 0.1)});

    return InsightCard(
      icon: Icons.emoji_emotions,
      title: 'Mood Timeline',
      description: 'How your travel mood changed over time',
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: moods
                    .map((m) =>
                        FlSpot(m['month'].toDouble(), m['mood'].toDouble()))
                    .toList(),
                isCurved: true,
                color: Colors.blue,
                belowBarData: BarAreaData(
                    show: true, color: Colors.blue.withOpacity(0.1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTravelDistanceInsight() {
    final distance = insights['total_distance'] ?? 4500;
    final earthCircumference = 40075;
    final laps = distance / earthCircumference;

    return InsightCard(
      icon: Icons.airplanemode_active,
      title: 'Travel Distance',
      description: 'How far you\'ve traveled',
      child: Column(
        children: [
          Text('${distance}km',
              style: TextStyle(fontFamily: 'JosefinSans', fontSize: 24)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: laps % 1,
            minHeight: 20,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 8),
          Text('That\'s ${laps.toStringAsFixed(2)} times around the Earth!',
              style: TextStyle(fontFamily: 'JosefinSans')),
        ],
      ),
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

  void _showFullImage(BuildContext context, String imageData) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: imageData.startsWith('http')
              ? CachedNetworkImage(imageUrl: imageData)
              : Image.memory(base64Decode(imageData)),
        ),
      ),
    );
  }

  void _showLocationDialog(BuildContext context, String location, int visits) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(location, style: TextStyle(fontFamily: 'JosefinSans')),
        content: Text("You've visited this place $visits times!",
            style: TextStyle(fontFamily: 'JosefinSans')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(fontFamily: 'JosefinSans')),
          ),
        ],
      ),
    );
  }
}

class InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  const InsightCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blueAccent, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontFamily: 'JosefinSans',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800])),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description,
                style: TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 14,
                    color: Colors.grey[600])),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
