import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart';
class YouTubeAudioExtractor {
  static Future<String> getAudioStreamUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      // First get the video metadata
      final video = await yt.videos.get(videoId);
      
      // Then get the stream manifest
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      
      // Get the best audio-only stream
      final audioStream = manifest.audioOnly.withHighestBitrate();
      
      if (audioStream == null) {
        throw Exception('No audio streams found');
      }
      
      final audioUrl = audioStream.url.toString();
      print('Obtained audio URL: $audioUrl');
      return audioUrl;
    } finally {
      yt.close();
    }
  }
}