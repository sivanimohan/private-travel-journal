import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

class _InsightPageState extends State<InsightPage> {
  Map<String, dynamic> insights = {};
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    try {
      // 1. Collect all data from Appwrite
      final allPages = await widget.databases.listDocuments(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        queries: [Query.equal('userId', widget.userId)],
      );

      // 2. Prepare data for Python processing
      final dataToSend = {
        'allPages': allPages.documents.map((doc) => doc.data).toList(),
        'bucketId': '67cd36510039f3d96c62',
        'userId': widget.userId,
      };

      // 3. Send to Python backend (replace with your actual endpoint)
      final response = await http.post(
        Uri.parse('http://192.168.230.90:5000/process-insights'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(dataToSend),
      );

      if (response.statusCode == 200) {
        setState(() {
          insights = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed with status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        error = 'Error loading insights: $e';
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSentimentInsight(),
            const SizedBox(height: 20),
            _buildLocationRepeatsInsight(),
            const SizedBox(height: 20),
            _buildSeasonalPatternsInsight(),
            const SizedBox(height: 20),
            _buildPhotoTimelineInsight(),
            const SizedBox(height: 20),
            _buildJournalHighlightsInsight(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Analyzing your travel memories...',
              style: TextStyle(fontFamily: 'JosefinSans')),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Text(error!,
          style: const TextStyle(fontFamily: 'JosefinSans', color: Colors.red)),
    );
  }

  Widget _buildSentimentInsight() {
    final timeline = insights['sentiment']?['timeline'] as List?;
    final average = insights['sentiment']?['average_score'] as double?;

    return InsightCard(
      icon: Icons.emoji_emotions,
      title: 'Sentiment Analysis',
      description: 'Your emotional journey over time',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: timeline != null && timeline.isNotEmpty
                ? LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: timeline.asMap().entries.map((e) {
                            return FlSpot(
                              e.key.toDouble(),
                              (e.value['score'] as num).toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: Colors.blue,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(value.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontFamily: 'JosefinSans', fontSize: 10));
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: true),
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
              child: Text('Average sentiment: ${average.toStringAsFixed(2)}',
                  style: const TextStyle(fontFamily: 'JosefinSans')),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRepeatsInsight() {
    final locations = insights['location_repeats']?['most_visited'] as List?;

    return InsightCard(
      icon: Icons.repeat,
      title: 'Most Visited Locations',
      description: 'Places you keep returning to',
      child: locations != null && locations.isNotEmpty
          ? Column(
              children: locations.map((loc) {
                return ListTile(
                  leading: const Icon(Icons.place, color: Colors.red),
                  title: Text(loc[0],
                      style: const TextStyle(fontFamily: 'JosefinSans')),
                  trailing: Text('${loc[1]} visits',
                      style: const TextStyle(fontFamily: 'JosefinSans')),
                );
              }).toList(),
            )
          : const Text('No location data available',
              style: TextStyle(fontFamily: 'JosefinSans')),
    );
  }

  Widget _buildSeasonalPatternsInsight() {
    final patterns = insights['seasonal_patterns']?['by_season'] as Map?;

    return InsightCard(
      icon: Icons.calendar_today,
      title: 'Seasonal Patterns',
      description: 'When you travel most often',
      child: patterns != null && patterns.isNotEmpty
          ? Column(
              children: patterns.entries.map((entry) {
                return ListTile(
                  leading: Icon(_getSeasonIcon(entry.key), color: Colors.blue),
                  title: Text(entry.key,
                      style: const TextStyle(fontFamily: 'JosefinSans')),
                  trailing: Text('${entry.value} trips',
                      style: const TextStyle(fontFamily: 'JosefinSans')),
                );
              }).toList(),
            )
          : const Text('No seasonal data available',
              style: TextStyle(fontFamily: 'JosefinSans')),
    );
  }

  Widget _buildPhotoTimelineInsight() {
    final photos = insights['photo_timeline'] as List?;

    return InsightCard(
      icon: Icons.photo_library,
      title: 'Photo Timeline',
      description: 'Your travel moments in pictures',
      child: photos != null && photos.isNotEmpty
          ? SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: CachedNetworkImage(
                      imageUrl: photos[index]['url'],
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
                  );
                },
              ),
            )
          : const Text('No photos available',
              style: TextStyle(fontFamily: 'JosefinSans')),
    );
  }

  Widget _buildJournalHighlightsInsight() {
    final highlights = insights['highlights'] as List?;

    return InsightCard(
      icon: Icons.star,
      title: 'Journal Highlights',
      description: 'Notable moments from your travels',
      child: highlights != null && highlights.isNotEmpty
          ? Column(
              children: highlights.map((highlight) {
                return ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(highlight,
                      style: const TextStyle(fontFamily: 'JosefinSans')),
                );
              }).toList(),
            )
          : const Text('No highlights available',
              style: TextStyle(fontFamily: 'JosefinSans')),
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'JosefinSans',
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(description,
                style: const TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 14,
                    color: Colors.grey)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
