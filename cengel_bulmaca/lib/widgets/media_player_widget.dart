import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class MediaPlayerWidget extends StatefulWidget {
  final String mediaPath;
  final String mediaType; // 'video' or 'audio'

  const MediaPlayerWidget({
    Key? key,
    required this.mediaPath,
    required this.mediaType,
  }) : super(key: key);

  @override
  State<MediaPlayerWidget> createState() => _MediaPlayerWidgetState();
}

class _MediaPlayerWidgetState extends State<MediaPlayerWidget> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      if (widget.mediaType.toLowerCase() == 'video') {
        await _initializeVideo();
      } else {
        await _initializeAudio();
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Medya dosyası yüklenemedi: $e';
      });
    }
  }

  Future<void> _initializeVideo() async {
    final file = File(widget.mediaPath);
    if (!await file.exists()) {
      throw Exception('Video dosyası bulunamadı');
    }

    _videoController = VideoPlayerController.file(file);
    await _videoController!.initialize();
    
    setState(() {
      _isInitialized = true;
    });

    _videoController!.addListener(() {
      final isPlaying = _videoController!.value.isPlaying;
      if (isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });
  }

  Future<void> _initializeAudio() async {
    final file = File(widget.mediaPath);
    if (!await file.exists()) {
      throw Exception('Ses dosyası bulunamadı');
    }

    _audioPlayer = AudioPlayer();
    
    _audioPlayer!.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade100,
        ),
        child: _hasError 
            ? _buildErrorWidget()
            : !_isInitialized 
                ? _buildLoadingWidget()
                : widget.mediaType.toLowerCase() == 'video'
                    ? _buildVideoPlayer()
                    : _buildAudioPlayer(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Medya Hatası',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _errorMessage ?? 'Bilinmeyen hata',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Medya yükleniyor...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
          
          // Play/Pause overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: _toggleVideoPlayback,
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          
          // Progress indicator
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Theme.of(context).primaryColor,
                bufferedColor: Colors.grey.shade400,
                backgroundColor: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audiotrack,
            size: 64,
            color: Colors.blue.shade600,
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Ses Dosyası',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _stopAudio,
                icon: const Icon(Icons.stop),
                iconSize: 32,
                color: Colors.grey.shade600,
              ),
              
              const SizedBox(width: 16),
              
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _toggleAudioPlayback,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  iconSize: 48,
                ),
              ),
              
              const SizedBox(width: 16),
              
              IconButton(
                onPressed: _restartAudio,
                icon: const Icon(Icons.replay),
                iconSize: 32,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleVideoPlayback() {
    if (_videoController == null) return;
    
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  void _toggleAudioPlayback() async {
    if (_audioPlayer == null) return;
    
    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.play(DeviceFileSource(widget.mediaPath));
    }
  }

  void _stopAudio() async {
    if (_audioPlayer == null) return;
    await _audioPlayer!.stop();
  }

  void _restartAudio() async {
    if (_audioPlayer == null) return;
    await _audioPlayer!.stop();
    await _audioPlayer!.play(DeviceFileSource(widget.mediaPath));
  }
}
