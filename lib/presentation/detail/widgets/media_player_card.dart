import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'package:beacon_client/presentation/theme/museum_palette.dart';

/// Glassmorphic audio/video controller card.
///
/// Phase 6: Upgraded to use [VideoPlayerController]. It takes a [videoUrl],
/// initializes the player stream, and handles buffering/playing states. 
/// For now, it plays the audio of the video file in the background.
class MediaPlayerCard extends StatefulWidget {
  final String? videoUrl;
  
  const MediaPlayerCard({super.key, this.videoUrl});

  @override
  State<MediaPlayerCard> createState() => _MediaPlayerCardState();
}

class _MediaPlayerCardState extends State<MediaPlayerCard> {
  VideoPlayerController? _controller;
  
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _progress = 0.0;
  String _elapsed = '00:00';
  String _total = '00:00';

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller!.addListener(_onPlayerUpdate);
    
    // Bắt đầu tải video/audio
    await _controller!.initialize();
    
    // Cập nhật giao diện sau khi tải xong thông số thời gian
    if (mounted) setState(() {}); 
  }

  void _onPlayerUpdate() {
    if (!mounted || _controller == null) return;
    
    final value = _controller!.value;
    setState(() {
      _isPlaying = value.isPlaying;
      _isBuffering = value.isBuffering || !value.isInitialized;
      
      if (value.duration.inMilliseconds > 0) {
        _progress = value.position.inMilliseconds / value.duration.inMilliseconds;
        _elapsed = _formatDuration(value.position);
        _total = _formatDuration(value.duration);
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.videoUrl != null && widget.videoUrl!.isNotEmpty;
    final isInitialized = _controller != null && _controller!.value.isInitialized;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Giới thiệu hiện vật',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const Icon(Icons.info_outline, color: AppColors.muted, size: 16),
                ],
              ),

              // >>> CHÈN TOÀN BỘ ĐOẠN KHUNG HÌNH VIDEO NÀY VÀO ĐÂY <<<
              if (hasVideo) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: isInitialized ? _controller!.value.aspectRatio : 16 / 9,
                    child: Container(
                      color: Colors.black26,
                      child: isInitialized
                          ? VideoPlayer(_controller!)
                          : const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
              // >>> KẾT THÚC ĐOẠN CHÈN <<<

              const SizedBox(height: 18),
              
              // Progress + Play Button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProgressBar(progress: hasVideo ? _progress : 0.0),
                        const SizedBox(height: 9),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(hasVideo ? _elapsed : '--:--', style: _timeStyle),
                            Text(hasVideo ? _total : '--:--', style: _timeStyle),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  _PlayButton(
                    isPlaying: _isPlaying,
                    isBuffering: _isBuffering,
                    enabled: hasVideo,
                    onTap: _togglePlay,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _timeStyle => GoogleFonts.beVietnamPro(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      );
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 5,
        child: Row(
          children: [
            Expanded(
              flex: (p * 1000).round().clamp(0, 1000),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.gold, AppColors.goldLight],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: ((1 - p) * 1000).round().clamp(0, 1000),
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final bool enabled;
  final VoidCallback onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !isBuffering ? onTap : null,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: enabled
                ? [AppColors.goldLight, AppColors.gold]
                : [AppColors.muted, AppColors.border],
          ),
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.40),
                    blurRadius: 22,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: _buildIcon(),
      ),
    );
  }

  Widget _buildIcon() {
    if (isBuffering && enabled) {
      return const Padding(
        padding: EdgeInsets.all(22.0),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.background),
        ),
      );
    }
    return Icon(
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      color: AppColors.background,
      size: 34,
    );
  }
}