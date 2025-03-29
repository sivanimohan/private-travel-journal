import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:appwrite/appwrite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WorldMapPage extends StatefulWidget {
  final Databases databases;
  final String userId;

  const WorldMapPage(
      {super.key, required this.databases, required this.userId});

  @override
  _WorldMapPageState createState() => _WorldMapPageState();
}

class _WorldMapPageState extends State<WorldMapPage> {
  List<LatLng> locations = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<LatLng?> _geocodeLocation(String address) async {
    if (address.isEmpty) return null;

    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$encodedAddress');

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'YourAppName/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
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
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      // Fetch all documents for the user that have a location
      final response = await widget.databases.listDocuments(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        queries: [
          Query.equal('userId', widget.userId),
          Query.isNotNull('location'),
          Query.notEqual('location', ''),
        ],
      );

      final List<LatLng> fetchedLocations = [];

      // Geocode each location
      for (final doc in response.documents) {
        final location = doc.data['location'] as String;
        if (location.isNotEmpty) {
          final coords = await _geocodeLocation(location);
          if (coords != null) {
            fetchedLocations.add(coords);
          }
        }
      }

      setState(() {
        locations = fetchedLocations;
        isLoading = false;
        if (locations.isEmpty) {
          errorMessage = 'No locations found or could not be geocoded';
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching locations: ${e.toString()}';
        isLoading = false;
      });
      debugPrint('Error fetching locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('World Map'),
        backgroundColor: const Color(0xFF2C7DA0),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : locations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage.isNotEmpty
                            ? errorMessage
                            : 'No locations available',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _fetchLocations,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: locations.first,
                    initialZoom: 3.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    MarkerLayer(
                      markers: locations
                          .map((location) => Marker(
                                point: location,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
    );
  }
}
