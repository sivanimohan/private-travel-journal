import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search and Play Songs"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search for a song...",
                border: OutlineInputBorder(),
              ),
              onChanged: (query) async {
                if (query.isNotEmpty) {
                  _searchResults = await YouTubeAPI.searchVideos(query);
                  setState(() {});
                }
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final video = _searchResults[index];
                return ListTile(
                  title: Text(video['snippet']['title']),
                  subtitle: Text(video['snippet']['channelTitle']),
                  onTap: () {
                    Navigator.pop(
                        context, video['id']['videoId']); // Return video ID
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class YouTubeAPI {
  static const String _apiKey = "AIzaSyBgWM2m_UatmmrEfO8y41fos3E12qjkv4E";

  // Search for videos
  static Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    final response = await http.get(
      Uri.parse(
          "https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&maxResults=10&key=$_apiKey"),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['items']);
    } else {
      throw Exception("Failed to load videos");
    }
  }
}
