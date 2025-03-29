import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'youtube_audio_service.dart';

class AudioPlayerPage extends StatefulWidget {
  final String youtubeUrl;
  
  const AudioPlayerPage({Key? key, required this.youtubeUrl}) : super(key: key);

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  final AudioPlayer _player = AudioPlayer();
  String? _audioUrl;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPlaying = false;
  Duration? _duration;
  Duration? _position;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      // Extract audio stream URL
      _audioUrl = await YouTubeAudioService.getAudioStreamUrl(widget.youtubeUrl);
      
      // Setup audio player
      await _player.setAudioSource(AudioSource.uri(Uri.parse(_audioUrl!)));
      
      // Get duration (may need to wait for buffering)
      _duration = _player.duration;
      
      // Setup listeners
      _player.playerStateStream.listen((state) {
        if (mounted) setState(() => _isPlaying = state.playing);
      });
      
      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? const Center(child: Text('Failed to load audio', style: TextStyle(color: Colors.red)))
              : _buildPlayerUI(),
    );
  }

  Widget _buildPlayerUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Progress bar
        Slider(
          value: (_position ?? Duration.zero).inSeconds.toDouble(),
          min: 0,
          max: (_duration ?? Duration(seconds: 1)).inSeconds.toDouble(),
          onChanged: (value) => _player.seek(Duration(seconds: value.toInt())),
        ),
        
        // Time indicators
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatTime(_position ?? Duration.zero)),
              Text(_formatTime(_duration ?? Duration.zero)),
            ],
          ),
        ),
        
        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () {}, // Add playlist functionality
            ),
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 48,
              onPressed: _togglePlayback,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () {}, // Add playlist functionality
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  Future<void> _togglePlayback() async {
    _isPlaying ? await _player.pause() : await _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}