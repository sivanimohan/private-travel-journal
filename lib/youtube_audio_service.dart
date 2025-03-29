import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeAudioService {
  static final YoutubeExplode _yt = YoutubeExplode();

  /// Extracts the best audio stream URL from a YouTube video
  ///
  /// [youtubeUrl] can be either:
  /// - Full URL (https://www.youtube.com/watch?v=VIDEO_ID)
  /// - Short URL (https://youtu.be/VIDEO_ID)
  /// - Just the video ID (VIDEO_ID)
  ///
  /// Throws [Exception] if no audio streams are available or if extraction fails
  static Future<String> getAudioStreamUrl(String youtubeUrl) async {
    try {
      // Extract video ID from URL if needed
      final videoId = _extractVideoId(youtubeUrl);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL or video ID');
      }

      // Get stream manifest
      final streamManifest =
          await _yt.videos.streamsClient.getManifest(videoId);

      // Get the best audio-only stream
      final audioStream = streamManifest.audioOnly.withHighestBitrate();

      if (audioStream == null) {
        throw Exception('No audio streams available for this video');
      }

      return audioStream.url.toString();
    } catch (e) {
      throw Exception('Failed to get audio stream: $e');
    }
  }

  /// Helper method to extract video ID from various YouTube URL formats
  static String? _extractVideoId(String url) {
    try {
      // Handle direct video IDs
      if (!url.contains(RegExp(r'[^a-zA-Z0-9_-]'))) {
        return url;
      }

      // Handle various URL formats
      final regex = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|youtu\.be\/)([^"&?\/\s]{11})',
        caseSensitive: false,
      );

      final match = regex.firstMatch(url);
      return match?.group(1);
    } catch (e) {
      return null;
    }
  }

  /// Close the YouTube client when done (call this when your app closes)
  static void close() {
    _yt.close();
  }
}
