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
    _fetchAndGeocodeLocations();
  }

  /// Geocoding function using Nominatim
  Future<LatLng?> geocodeWithNominatim(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$encodedAddress');

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'YourAppName/1.0'}, // Required by Nominatim
      );
      print("🔹 Geocode API Response for '$address': ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          print("✅ Found coordinates for '$address': $lat, $lon");
          return LatLng(lat, lon);
        } else {
          print("⚠️ No coordinates found for address: $address");
        }
      }
      return null;
    } catch (e) {
      print('❌ Error geocoding with Nominatim: $e');
      return null;
    }
  }

  /// Fetch and geocode locations
  Future<void> _fetchAndGeocodeLocations() async {
    try {
      print("🔄 Fetching document for user ID: ${widget.userId}");

      // Correctly fetch the document using userId
      final documents = await widget.databases.listDocuments(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        queries: [
          Query.equal("userId", widget.userId), // ✅ Fetch using userId field
        ],
      );

      if (documents.documents.isEmpty) {
        print("❌ No document found for user ID: ${widget.userId}");
        setState(() {
          errorMessage = "No document found for this user.";
          isLoading = false;
        });
        return;
      }

      final document =
          documents.documents.first; // ✅ Get the first matching document
      print("📄 Found Document: ${document.data}");

      // Check if locations field exists
      if (!document.data.containsKey('locations')) {
        print("⚠️ Error: 'locations' field is missing in the document.");
        setState(() {
          errorMessage = "'locations' field is missing";
          isLoading = false;
        });
        return;
      }

      // Extract the locations string
      final locationsString = document.data['locations'] as String;
      print("📍 Raw locations string: '$locationsString'");

      if (locationsString.isEmpty) {
        print("⚠️ Locations string is empty");
        setState(() {
          errorMessage = "No locations entered";
          isLoading = false;
        });
        return;
      }

      // Split the string into individual addresses
      final addresses = locationsString
          .split(',')
          .map((address) => address.trim())
          .where((address) => address.isNotEmpty)
          .toList();

      print("🔹 Addresses to geocode: $addresses");

      final geocodedLocations = <LatLng>[];

      // Geocode each address with a delay to avoid rate limiting
      for (final address in addresses) {
        if (geocodedLocations.isNotEmpty) {
          // Add a small delay between requests to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 1000));
        }

        final coordinates = await geocodeWithNominatim(address);
        if (coordinates != null) {
          geocodedLocations.add(coordinates);
          print("✅ Added coordinates for '$address'");
        }
      }

      setState(() {
        locations = geocodedLocations;
        isLoading = false;
        if (geocodedLocations.isEmpty) {
          errorMessage = "No locations could be found";
        }
      });
    } catch (e) {
      print('❌ Error fetching and geocoding locations: $e');
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'World Map',
          style: TextStyle(fontFamily: 'JosefinSans'),
        ),
        backgroundColor: const Color(0xFF2C7DA0),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : locations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage.isNotEmpty
                            ? errorMessage
                            : "No locations found.",
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = '';
                          });
                          _fetchAndGeocodeLocations();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: locations.isNotEmpty
                        ? locations.first
                        : const LatLng(51.5074, -0.1278), // Default: London
                    initialZoom: 3.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    if (locations.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: locations,
                            color: Colors.blue,
                            strokeWidth: 2.0,
                            strokeCap: StrokeCap.round,
                          ),
                        ],
                      ),
                    if (locations.isNotEmpty)
                      MarkerLayer(
                        markers: locations.map((location) {
                          return Marker(
                            point: location,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
    );
  }
}
