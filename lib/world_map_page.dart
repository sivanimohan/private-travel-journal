import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:appwrite/appwrite.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:confetti/confetti.dart';

class WorldMapPage extends StatefulWidget {
  final Databases databases;
  final String userId;

  const WorldMapPage({
    super.key,
    required this.databases,
    required this.userId,
  });

  @override
  _WorldMapPageState createState() => _WorldMapPageState();
}

class _WorldMapPageState extends State<WorldMapPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> locations = [];
  bool isLoading = true;
  String errorMessage = '';
  LatLng? _currentMapCenter;
  double _currentZoom = 3.0;
  bool _showFullPath = false;
  bool _showTravelStats = false;
  bool _showConnectionLines = true;
  bool _showLocationMarkers = true;

  late AnimationController _pathAnimationController;
  double _pathAnimationProgress = 0.0;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _pathAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        setState(() {
          _pathAnimationProgress = _pathAnimationController.value;
        });
      });

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _fetchData();
  }

  @override
  void dispose() {
    _pathAnimationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _togglePathAnimation() {
    if (_pathAnimationController.isAnimating) {
      _pathAnimationController.stop();
    } else {
      _pathAnimationController.repeat(reverse: true);
      _confettiController.play();
    }
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      await _fetchLocations();
      if (locations.isNotEmpty) {
        _currentMapCenter = locations.first['coordinates'];
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _geocodeLocation(String address) async {
    if (address.isEmpty) return null;
    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$encodedAddress');
    try {
      final response =
          await http.get(url, headers: {'User-Agent': 'TravelJournal/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          return {
            'name': address,
            'coordinates': LatLng(lat, lon),
            'display_name': data[0]['display_name'].toString(),
            'date': 'Unknown date',
            'duration': 'Unknown duration',
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
              'date': doc.data['date']?.toString() ?? 'Unknown date',
              'duration':
                  doc.data['duration']?.toString() ?? 'Unknown duration',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          locations = fetchedLocations;
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

  double _calculateTotalDistance() {
    if (locations.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < locations.length - 1; i++) {
      total += Distance().distance(
              locations[i]['coordinates'], locations[i + 1]['coordinates']) /
          1000;
    }
    return total;
  }

  int _calculateDaysTraveled() {
    return locations.length * 2; // Simplified assumption
  }

  String _getMostVisitedRegion() {
    if (locations.isEmpty) return 'None';
    final regionCounts = <String, int>{};
    for (final loc in locations) {
      final name = loc['name'].toString();
      final region = name.contains(',') ? name.split(',').last.trim() : name;
      regionCounts[region] = (regionCounts[region] ?? 0) + 1;
    }
    return regionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.blueAccent),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 12,
                    color: Colors.grey)),
            Text(value,
                style: const TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Travel Map',
            style: TextStyle(fontFamily: 'JosefinSans', fontSize: 24)),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(_showFullPath ? Icons.pause : Icons.timeline),
            onPressed: () {
              setState(() {
                _showFullPath = !_showFullPath;
                if (_showFullPath) {
                  _pathAnimationController.forward(from: 0.0);
                }
              });
            },
            tooltip: 'Toggle travel path',
          ),
          IconButton(
            icon: Icon(_showConnectionLines
                ? Icons.line_style
                : Icons.line_style_outlined),
            onPressed: () =>
                setState(() => _showConnectionLines = !_showConnectionLines),
            tooltip: 'Toggle connection lines',
          ),
          IconButton(
            icon: Icon(
                _showLocationMarkers ? Icons.location_on : Icons.location_off),
            onPressed: () =>
                setState(() => _showLocationMarkers = !_showLocationMarkers),
            tooltip: 'Toggle location markers',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'Refresh data',
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
            child: isLoading ? _buildLoadingScreen() : _buildMapView(),
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
        onPressed: _togglePathAnimation,
        child: Icon(_pathAnimationController.isAnimating
            ? Icons.pause
            : Icons.play_arrow),
        backgroundColor: Colors.blueAccent,
        tooltip: 'Animate path',
      ),
    );
  }

  Widget _buildMapView() {
    if (locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              errorMessage.isNotEmpty ? errorMessage : 'No locations available',
              style: const TextStyle(
                  fontFamily: 'JosefinSans', fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchData,
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

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _currentMapCenter ?? locations.first['coordinates'],
            initialZoom: _currentZoom,
            onTap: (_, LatLng coords) =>
                setState(() => _currentMapCenter = coords),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.travel_journal',
            ),
            if (_showFullPath && _showConnectionLines && locations.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: locations
                        .map((loc) => loc['coordinates'] as LatLng)
                        .toList(),
                    color: Colors.blueAccent.withOpacity(0.5),
                    strokeWidth: 4,
                    borderColor: Colors.pinkAccent.withOpacity(0.7),
                    borderStrokeWidth: 2,
                  ),
                  if (_pathAnimationController.isAnimating)
                    Polyline(
                      points: locations
                          .sublist(
                              0,
                              max(
                                  1,
                                  (locations.length * _pathAnimationProgress)
                                      .round()))
                          .map((loc) => loc['coordinates'] as LatLng)
                          .toList(),
                      color: Colors.purple.withOpacity(0.8),
                      strokeWidth: 5,
                      gradientColors: [
                        Colors.purple,
                        Colors.pink,
                        Colors.orange
                      ],
                    ),
                ],
              ),
            if (_showLocationMarkers)
              MarkerLayer(
                markers: locations.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final location = entry.value;
                  return Marker(
                    point: location['coordinates'],
                    width: 50,
                    height: 50,
                    child: GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: Text(location['name']?.toString() ?? 'Unknown',
                              style: const TextStyle(
                                  fontFamily: 'JosefinSans',
                                  color: Colors.blueAccent)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(location['display_name']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontFamily: 'JosefinSans')),
                              const SizedBox(height: 8),
                              Text('Visited on: ${location['date']}',
                                  style: const TextStyle(
                                      fontFamily: 'JosefinSans')),
                              Text('Duration: ${location['duration']}',
                                  style: const TextStyle(
                                      fontFamily: 'JosefinSans')),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close',
                                  style: TextStyle(fontFamily: 'JosefinSans')),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _openInMaps(location['coordinates']);
                              },
                              child: const Text('Open in Maps',
                                  style: TextStyle(fontFamily: 'JosefinSans')),
                            ),
                          ],
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blueAccent.withOpacity(0.8),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.favorite,
                            color: Colors.pinkAccent,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: () => setState(() => _showTravelStats = !_showTravelStats),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showTravelStats
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    color: Colors.blueAccent,
                  ),
                  const Text('Travel Stats',
                      style: TextStyle(
                          fontFamily: 'JosefinSans',
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent)),
                ],
              ),
            ),
          ),
        ),
        if (_showTravelStats)
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatCard(
                      'Locations Visited',
                      locations.length.toString(),
                      Icons.location_on,
                    ),
                    _buildStatCard(
                      'Total Distance',
                      '${_calculateTotalDistance().toStringAsFixed(0)} km',
                      Icons.airplanemode_active,
                    ),
                    _buildStatCard(
                      'Days Traveled',
                      _calculateDaysTraveled().toString(),
                      Icons.calendar_today,
                    ),
                    _buildStatCard(
                      'Favorite Region',
                      _getMostVisitedRegion(),
                      Icons.favorite,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                onPressed: () => setState(() {
                  _currentMapCenter = locations.first['coordinates'];
                  _currentZoom = 3.0;
                }),
                backgroundColor: Colors.blueAccent,
                child: const Icon(Icons.explore),
                tooltip: 'Reset view',
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: () =>
                    setState(() => _currentZoom = _currentZoom + 1),
                mini: true,
                backgroundColor: Colors.blueAccent,
                child: const Icon(Icons.add),
                tooltip: 'Zoom in',
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                onPressed: () =>
                    setState(() => _currentZoom = _currentZoom - 1),
                mini: true,
                backgroundColor: Colors.blueAccent,
                child: const Icon(Icons.remove),
                tooltip: 'Zoom out',
              ),
            ],
          ),
        ),
      ],
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
          Text('Loading your travel map...',
              style: TextStyle(
                  fontFamily: 'JosefinSans', fontSize: 18, color: Colors.blue)),
        ],
      ),
    );
  }

  Future<void> _openInMaps(LatLng coords) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${coords.latitude},${coords.longitude}');
    if (await launcher.canLaunchUrl(url)) {
      await launcher.launchUrl(url);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not launch maps')));
    }
  }
}
