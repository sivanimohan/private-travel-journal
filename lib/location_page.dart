import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:appwrite/appwrite.dart';

class LocationPage extends StatefulWidget {
  final String userId;
  final Databases databases;
  final List<String> existingLocations;

  const LocationPage({
    super.key,
    required this.userId,
    required this.databases,
    this.existingLocations = const [],
  });

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  static const String nominatimUrl =
      'https://nominatim.openstreetmap.org/search';
  final TextEditingController _searchController = TextEditingController();
  List<String> locations = [];
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    locations = List.from(
        widget.existingLocations); // Initialize with existing locations
  }

  Future<List<Map<String, dynamic>>> fetchSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$nominatimUrl?format=json&q=$query'),
        headers: {'User-Agent': 'YourAppName/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          return {
            'displayName': item['display_name'],
            'latitude': double.tryParse(item['lat'] ?? '0.0') ?? 0.0,
            'longitude': double.tryParse(item['lon'] ?? '0.0') ?? 0.0,
          };
        }).toList();
      }
    } catch (e) {
      print("Error fetching locations: $e");
    }
    return [];
  }

  void _addLocation(Map<String, dynamic> location) {
    if (!locations.contains(location['displayName'])) {
      setState(() {
        locations.add(location['displayName']);
      });
    }
    _searchController.clear();
  }

  Future<void> _saveLocationToDatabase() async {
    if (locations.isEmpty) return;

    setState(() => isSaving = true);

    try {
      await widget.databases.updateDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        documentId: widget.userId, // Ensure this is a valid document ID
        data: {'locations': locations},
      );

      if (mounted) {
        Navigator.pop(context, locations);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Locations'),
        backgroundColor: const Color(0xFF2C7DA0),
        actions: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveLocationToDatabase,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TypeAheadField<Map<String, dynamic>>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Location',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  ),
                ),
              ),
              suggestionsCallback: fetchSuggestions,
              itemBuilder: (context, suggestion) {
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(suggestion['displayName'],
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
              onSuggestionSelected: _addLocation,
              noItemsFoundBuilder: (context) => const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No locations found."),
              ),
            ),
            const SizedBox(height: 16),
            if (locations.isNotEmpty)
              Expanded(
                child: Card(
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.place),
                        title: Text('Selected Locations',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: locations.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(locations[index]),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() => locations.removeAt(index));
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text('Search and select locations above',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
