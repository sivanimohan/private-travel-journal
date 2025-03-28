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
    _fetchAndGeocodeLocation();
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

  /// Fetch and geocode location
  Future<void> _fetchAndGeocodeLocation() async {
    try {
      print("🔄 Fetching document for user ID: ${widget.userId}");

      final documents = await widget.databases.listDocuments(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        queries: [
          Query.equal("userId", widget.userId),
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

      final document = documents.documents.first;
      print("📄 Found Document: ${document.data}");

      if (!document.data.containsKey('location')) {
        print("⚠️ Error: 'location' field is missing in the document.");
        setState(() {
          errorMessage = "'location' field is missing";
          isLoading = false;
        });
        return;
      }

      final locationString = document.data['location'] as String;
      print("📍 Raw location string: '$locationString'");

      if (locationString.isEmpty) {
        print("⚠️ Location string is empty");
        setState(() {
          errorMessage = "No location entered";
          isLoading = false;
        });
        return;
      }

      final coordinates = await geocodeWithNominatim(locationString);
      if (coordinates != null) {
        setState(() {
          locations = [coordinates];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "No location could be found";
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching and geocoding location: $e');
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
                            : "No location found.",
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            errorMessage = '';
                          });
                          _fetchAndGeocodeLocation();
                        },
                        child: const Text("Retry"),
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
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
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
