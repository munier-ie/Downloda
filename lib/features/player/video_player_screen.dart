import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/models.dart';
import '../../core/theme.dart';


/// Full-screen landscape video player for locally downloaded files.
///
/// Usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => VideoPlayerScreen(
///     items: completedItems,
///     initialIndex: tappedIndex,
///     seekSeconds: 5,
///   ),
/// ));
/// ```
class VideoPlayerScreen extends StatefulWidget {
  /// All playable items (completed downloads with a valid filePath)
  final List<DownloadItem> items;

  /// Which item to start on
  final int initialIndex;

  /// Seek step in seconds (from Settings)
  final int seekSeconds;

  const VideoPlayerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    this.seekSeconds = 5,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late int _currentIndex;
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _controlsVisible = true;
  bool _isPortrait = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initPlayer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    // Restore to portrait when leaving
    _restoreOrientation();
    super.dispose();
  }

  void _setLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _isPortrait = false;
  }

  void _setPortrait() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _isPortrait = true;
  }

  void _restoreOrientation() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _initPlayer() async {
    final item = widget.items[_currentIndex];
    if (item.filePath == null) return;

    final file = File(item.filePath!);
    if (!await file.exists()) return;

    setState(() {
      _isInitialized = false;
    });

    _controller?.dispose();
    _controller = VideoPlayerController.file(file);

    await _controller!.initialize();
    
    final double aspect = _controller!.value.aspectRatio;
    if (aspect < 1.0) {
      _setPortrait();
    } else {
      _setLandscape();
    }

    _controller!.addListener(_onVideoUpdate);
    _controller!.play();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
    _startHideTimer();
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    setState(() {});
    // Auto-advance when video ends
    if (_controller!.value.position >= _controller!.value.duration &&
        _controller!.value.duration > Duration.zero &&
        !_controller!.value.isPlaying) {
      _nextVideo();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _startHideTimer();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    _showControls();
  }

  void _seekForward() {
    if (_controller == null || !_isInitialized) return;
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    final target = pos + Duration(seconds: widget.seekSeconds);
    _controller!.seekTo(target > dur ? dur : target);
    _showControls();
  }

  void _seekBackward() {
    if (_controller == null || !_isInitialized) return;
    final pos = _controller!.value.position;
    final target = pos - Duration(seconds: widget.seekSeconds);
    _controller!.seekTo(target < Duration.zero ? Duration.zero : target);
    _showControls();
  }

  void _nextVideo() {
    if (_currentIndex < widget.items.length - 1) {
      setState(() {
        _currentIndex++;
        _isInitialized = false;
      });
      _initPlayer();
    }
  }

  void _prevVideo() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isInitialized = false;
      });
      _initPlayer();
    }
  }

  void _toggleOrientation() {
    if (_isPortrait) {
      _setLandscape();
    } else {
      _setPortrait();
    }
    setState(() {});
  }

  void _close() {
    Navigator.of(context).pop();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    final ctrl = _controller;
    final isPlaying = ctrl?.value.isPlaying ?? false;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _showControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video ────────────────────────────────────────────────────────
            Center(
              child: _isInitialized && ctrl != null
                  ? AspectRatio(
                      aspectRatio: ctrl.value.aspectRatio,
                      child: VideoPlayer(ctrl),
                    )
                  : CircularProgressIndicator(
                      color: context.colorAccent,
                      strokeWidth: 2,
                    ),
            ),

            // ── Controls overlay ─────────────────────────────────────────────
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC000000),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xCC000000),
                    ],
                    stops: [0.0, 0.25, 0.75, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // ── Top bar ────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            _IconBtn(
                              icon: Icons.close_rounded,
                              onTap: _close,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_currentIndex + 1} of ${widget.items.length} • ${item.resolution} ${item.format.toUpperCase()}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _IconBtn(
                              icon: _isPortrait
                                  ? Icons.screen_lock_landscape_rounded
                                  : Icons.screen_lock_portrait_rounded,
                              onTap: _toggleOrientation,
                              tooltip: _isPortrait
                                  ? 'Switch to Landscape'
                                  : 'Switch to Portrait',
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // ── Centre controls ────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _IconBtn(
                            icon: Icons.skip_previous_rounded,
                            size: 36,
                            onTap: _currentIndex > 0 ? _prevVideo : null,
                          ),
                          const SizedBox(width: 24),
                          _IconBtn(
                            icon: Icons.replay_5_rounded,
                            size: 32,
                            onTap: _seekBackward,
                          ),
                          const SizedBox(width: 24),
                          // Play/pause main button
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          _IconBtn(
                            icon: Icons.forward_5_rounded,
                            size: 32,
                            onTap: _seekForward,
                          ),
                          const SizedBox(width: 24),
                          _IconBtn(
                            icon: Icons.skip_next_rounded,
                            size: 36,
                            onTap: _currentIndex < widget.items.length - 1
                                ? _nextVideo
                                : null,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Seek bar + time ────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                                activeTrackColor: context.colorAccent,
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.2),
                                thumbColor: Colors.white,
                                overlayColor:
                                    Colors.white.withValues(alpha: 0.1),
                              ),
                              child: Slider(
                                value: progress.clamp(0.0, 1.0),
                                onChanged: _isInitialized && ctrl != null
                                    ? (v) {
                                        final target = Duration(
                                          milliseconds: (v *
                                                  duration.inMilliseconds)
                                              .toInt(),
                                        );
                                        ctrl.seekTo(target);
                                        _showControls();
                                      }
                                    : null,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  const _IconBtn({
    required this.icon,
    this.onTap,
    this.size = 24,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap != null ? 1.0 : 0.3,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
