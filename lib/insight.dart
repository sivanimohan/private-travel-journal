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
        collectionId: '67eab72f0030b02f1623',
        queries: [Query.equal('userId', widget.userId)],
      ).timeout(const Duration(seconds: 30));

      final dataToSend = {
        'allPages': allPages.documents.map((doc) => doc.data).toList(),
        'bucketId': '67cd36510039f3d96c62',
        'userId': widget.userId,
        'currentDate': DateTime.now().toIso8601String(),
      };

      const baseUrl = 'http://192.168.46.90:5000';
      final response = await http
          .post(
            Uri.parse('$baseUrl/process-insights'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(dataToSend),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        _safeSetState(() {
          insights = responseData;
          isLoading = false;
          _confettiController?.play();
        });
      } else {
        throw Exception(
            'Server returned status code ${response.statusCode}: ${response.body}');
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
                _buildSafeInsight(_buildSentimentInsight,
                    title: 'Emotional Journey'),
                _buildSafeInsight(_buildLocationSentimentInsight,
                    title: 'Location Sentiment'),
                _buildSafeInsight(_buildJournalHighlightsInsight,
                    title: 'Journal Highlights'),
                _buildSafeInsight(_buildTravelPersonalityInsight,
                    title: 'Travel Personality'),
                _buildSafeInsight(_buildSeasonalPatternsInsight,
                    title: 'Seasonal Patterns'),
                _buildSafeInsight(_buildPhotoMemoriesInsight,
                    title: 'Photo Memories'),
                _buildSafeInsight(_buildActivityPatternsInsight,
                    title: 'Activity Patterns'),
                _buildSafeInsight(_buildBucketListInsight,
                    title: 'Bucket List'),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(8, (index) => _buildPageIndicator(index)),
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

  Widget _buildLocationSentimentInsight() {
    final locationSentiment = insights['location_sentiment'] ?? {};
    final topLocations =
        (locationSentiment['top_locations'] as List?)?.cast<List<dynamic>>() ??
            [];
    final bottomLocations = (locationSentiment['bottom_locations'] as List?)
            ?.cast<List<dynamic>>() ??
        [];
    final overallAverage =
        locationSentiment['overall_average'] as double? ?? 0.0;

    return InsightCard(
      icon: Icons.location_on,
      title: 'Location Sentiment',
      description: 'Your happiest and most reflective places',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Overall Average: ${overallAverage.toStringAsFixed(2)}',
                style: TextStyle(
                    fontFamily: 'JosefinSans',
                    color: overallAverage > 0 ? Colors.green : Colors.red)),
          ),
          const Text('Top Locations:',
              style: TextStyle(
                  fontFamily: 'JosefinSans', fontWeight: FontWeight.bold)),
          ...topLocations
              .map((loc) => ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: Text(loc[0].toString(),
                        style: const TextStyle(fontFamily: 'JosefinSans')),
                    trailing: Text(loc[1].toStringAsFixed(2)),
                  ))
              .toList(),
          const Divider(),
          const Text('Bottom Locations:',
              style: TextStyle(
                  fontFamily: 'JosefinSans', fontWeight: FontWeight.bold)),
          ...bottomLocations
              .map((loc) => ListTile(
                    leading: const Icon(Icons.mood_bad, color: Colors.blue),
                    title: Text(loc[0].toString(),
                        style: const TextStyle(fontFamily: 'JosefinSans')),
                    trailing: Text(loc[1].toStringAsFixed(2)),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildTravelPersonalityInsight() {
    final personalityData = insights['travel_personality'] ?? {};
    final personality =
        personalityData['travel_personality'] as String? ?? 'The Explorer';
    final traits =
        (personalityData['personality_traits'] as List?)?.cast<String>() ?? [];
    final avgDuration = personalityData['avg_trip_duration'] as double? ?? 0.0;
    final locationDiversity =
        personalityData['location_diversity'] as int? ?? 0;

    return InsightCard(
      icon: Icons.person,
      title: 'Travel Personality',
      description: 'Your unique travel style',
      child: Column(
        children: [
          Text(personality,
              style: const TextStyle(
                  fontFamily: 'JosefinSans',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: traits
                .map((trait) => Chip(
                      label: Text(trait,
                          style: const TextStyle(fontFamily: 'JosefinSans')),
                      backgroundColor: Colors.blue[100],
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Average Trip Duration',
                style: TextStyle(fontFamily: 'JosefinSans')),
            trailing: Text('${avgDuration.toStringAsFixed(1)} days',
                style: const TextStyle(fontFamily: 'JosefinSans')),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Location Diversity',
                style: TextStyle(fontFamily: 'JosefinSans')),
            trailing: Text('$locationDiversity unique locations',
                style: const TextStyle(fontFamily: 'JosefinSans')),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonalPatternsInsight() {
    final seasonalData = insights['seasonal_patterns'] ?? {};
    final bySeason = seasonalData['by_season'] as Map? ?? {};
    final mostCommonSeason =
        seasonalData['most_common_season'] as String? ?? 'None';

    return InsightCard(
      icon: Icons.ac_unit,
      title: 'Seasonal Patterns',
      description: 'When you travel most',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: (bySeason['Winter'] as num?)?.toDouble() ?? 0,
                    color: Colors.blue,
                    title: 'Winter',
                  ),
                  PieChartSectionData(
                    value: (bySeason['Spring'] as num?)?.toDouble() ?? 0,
                    color: Colors.green,
                    title: 'Spring',
                  ),
                  PieChartSectionData(
                    value: (bySeason['Summer'] as num?)?.toDouble() ?? 0,
                    color: Colors.yellow,
                    title: 'Summer',
                  ),
                  PieChartSectionData(
                    value: (bySeason['Fall'] as num?)?.toDouble() ?? 0,
                    color: Colors.orange,
                    title: 'Fall',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Most Common Season: $mostCommonSeason',
              style: const TextStyle(fontFamily: 'JosefinSans')),
        ],
      ),
    );
  }

  Widget _buildActivityPatternsInsight() {
    final activityData = insights['activity_patterns'] ?? {};
    final patterns =
        (activityData['activity_patterns'] as Map?)?.cast<String, dynamic>() ??
            {};
    final clusters =
        (activityData['activity_clusters'] as Map?)?.cast<String, dynamic>() ??
            {};

    return InsightCard(
      icon: Icons.directions_run,
      title: 'Activity Patterns',
      description: 'Your most common activities',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Activities:',
              style: TextStyle(
                  fontFamily: 'JosefinSans', fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: patterns.entries
                .map((entry) => Chip(
                      label: Text('${entry.key} (${entry.value})',
                          style: const TextStyle(fontFamily: 'JosefinSans')),
                      backgroundColor: Colors.green[100],
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Activity Clusters:',
              style: TextStyle(
                  fontFamily: 'JosefinSans', fontWeight: FontWeight.bold)),
          ...clusters.entries
              .map((entry) => ExpansionTile(
                    title: Text(entry.key,
                        style: const TextStyle(fontFamily: 'JosefinSans')),
                    children: (entry.value as List)
                        .map((activity) => ListTile(
                              title: Text(activity.toString(),
                                  style: const TextStyle(
                                      fontFamily: 'JosefinSans')),
                            ))
                        .toList(),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildBucketListInsight() {
    final bucketList =
        (insights['bucket_list']?['bucket_list'] as List?)?.cast<String>() ??
            [];

    return InsightCard(
      icon: Icons.list,
      title: 'Bucket List',
      description: 'Personalized travel suggestions',
      child: bucketList.isNotEmpty
          ? Column(
              children: bucketList
                  .map((item) => ListTile(
                        leading: const Icon(Icons.flag, color: Colors.blue),
                        title: Text(item,
                            style: const TextStyle(fontFamily: 'JosefinSans')),
                      ))
                  .toList(),
            )
          : const Text('No bucket list suggestions available',
              style: TextStyle(fontFamily: 'JosefinSans')),
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

  Widget _buildSentimentInsight() {
    final timeline = insights['sentiment']?['timeline'] as List?;
    final average = insights['sentiment']?['average_score'] as double?;

    return InsightCard(
      icon: Icons.emoji_emotions,
      title: 'Emotional Journey',
      description: 'Your emotional patterns over time',
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

  Widget _buildJournalHighlightsInsight() {
    final highlights = (insights['highlights'] as List?)?.cast<String>() ?? [];

    return InsightCard(
      icon: Icons.star,
      title: 'Journal Highlights',
      description: 'Your most meaningful entries',
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

  Widget _buildPhotoMemoriesInsight() {
    final photos =
        (insights['photo_timeline'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

    final validPhotos = photos.where((photo) {
      final url = photo['url'] as String?;
      return url != null && url.isNotEmpty;
    }).toList();

    return InsightCard(
      icon: Icons.photo_library,
      title: 'Photo Memories',
      description: 'Visual moments from your journey',
      child: validPhotos.isNotEmpty
          ? Column(
              children: [
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: validPhotos.length,
                    itemBuilder: (context, index) {
                      final photo = validPhotos[index];
                      final url = photo['url'] as String;
                      final date = photo['date'] as String? ?? 'Unknown date';
                      final location =
                          photo['location'] as String? ?? 'Unknown location';

                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: GestureDetector(
                          onTap: () => _showPhotoDetails(context, photo),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: url,
                                width: 100,
                                height: 120,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                      child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  color: Colors.black54,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        location,
                                        style: const TextStyle(
                                          fontFamily: 'JosefinSans',
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${validPhotos.length} memories',
                  style: TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            )
          : const Text('No photos available',
              style: TextStyle(fontFamily: 'JosefinSans')),
    );
  }

  Widget _buildSafeInsight(Widget Function() builder,
      {String title = 'Insight'}) {
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

  void _showPhotoDetails(BuildContext context, Map<String, dynamic> photo) {
    final url = photo['url'] as String;
    final date = photo['date'] as String? ?? 'Unknown date';
    final location = photo['location'] as String? ?? 'Unknown location';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              width: MediaQuery.of(context).size.width * 0.8,
              fit: BoxFit.contain,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location,
                      style: const TextStyle(
                          fontFamily: 'JosefinSans',
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(date,
                      style: const TextStyle(
                          fontFamily: 'JosefinSans', color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
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
