import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart' as video_player;
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

class WhatsappScreen extends StatefulWidget {
  const WhatsappScreen({super.key});

  @override
  State<WhatsappScreen> createState() => _WhatsappScreenState();
}

class _WhatsappScreenState extends State<WhatsappScreen> {
  int _filterIndex = 0; // 0: All, 1: Images, 2: Videos
  bool _hasPermission = false;
  bool _permanentlyDenied = false;
  List<File> _statuses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final storage = await Permission.storage.status;
    final manage = await Permission.manageExternalStorage.status;

    if (storage.isGranted || manage.isGranted) {
      setState(() => _hasPermission = true);
      _scanStatuses();
    } else if (storage.isPermanentlyDenied || manage.isPermanentlyDenied) {
      setState(() => _permanentlyDenied = true);
    }
  }

  Future<void> _requestPermission() async {
    if (_permanentlyDenied) {
      openAppSettings();
      return;
    }

    // For Android 11+ use MANAGE_EXTERNAL_STORAGE; for older use READ_EXTERNAL_STORAGE
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _permanentlyDenied = false;
      });
      _scanStatuses();
    } else {
      final legacy = await Permission.storage.request();
      if (legacy.isGranted) {
        setState(() {
          _hasPermission = true;
          _permanentlyDenied = false;
        });
        _scanStatuses();
      } else if (legacy.isPermanentlyDenied || status.isPermanentlyDenied) {
        setState(() => _permanentlyDenied = true);
      }
    }
  }

  Future<void> _scanStatuses() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final List<String> paths = [
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
      '/storage/emulated/0/WhatsApp/Media/.Statuses',
      '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
      '/storage/emulated/0/WhatsApp Business/Media/.Statuses',
    ];

    List<File> found = [];
    for (var path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          final files = dir.listSync().whereType<File>().toList();
          // Filter out nomedia and hidden files
          found.addAll(files.where((f) => !PathUtils.basename(f.path).startsWith('.')));
        } catch (e) {
          debugPrint('Error scanning $path: $e');
        }
      }
    }

    // Sort newest first
    found.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    // Apply filter
    List<File> filtered = found;
    if (_filterIndex == 1) {
      filtered = found.where((f) {
        final ext = f.path.toLowerCase();
        return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png');
      }).toList();
    } else if (_filterIndex == 2) {
      filtered = found.where((f) {
        final ext = f.path.toLowerCase();
        return ext.endsWith('.mp4') || ext.endsWith('.gif');
      }).toList();
    }

    if (mounted) {
      setState(() {
        _statuses = filtered;
        _isLoading = false;
      });
    }
  }

  bool _isVideo(File f) {
    final ext = f.path.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.gif');
  }

  Future<void> _saveFile(File file) async {
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download/Downloda/statuses');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final name = file.path.split('/').last;
      final dest = File('${downloadsDir.path}/$name');
      
      if (await dest.exists()) {
        if (mounted) {
          TopToast.show(context, message: 'Already saved to Download/Downloda/statuses');
        }
        return; // Skip copying
      }

      await file.copy(dest.path);

      // Notify android system gallery to scan the newly created file
      try {
        const channel = MethodChannel('com.downloda.app/media_scanner');
        await channel.invokeMethod('scanFile', {'path': dest.path});
      } catch (e) {
        debugPrint('Media scanner channel error: $e');
      }

      if (mounted) {
        TopToast.show(context, message: 'Saved to Download/Downloda/statuses');
      }
    } catch (e) {
      if (mounted) {
        TopToast.show(context, message: 'Save failed: $e', isError: true);
      }
    }
  }

  void _openPreview(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StatusPreviewScreen(
          files: _statuses,
          initialIndex: initialIndex,
          onSave: _saveFile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkillHeader(
              greeting: 'Local Media',
              title: 'WhatsApp',
              trailingIcon: Icons.refresh_rounded,
              onTrailingTap: _scanStatuses,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterIndex == 0
                        ? const SkillPill(label: 'All')
                        : SkillTag(label: 'All', onTap: () {
                            setState(() => _filterIndex = 0);
                            _scanStatuses();
                          }),
                    const SizedBox(width: 8),
                    _filterIndex == 1
                        ? const SkillPill(label: 'Images')
                        : SkillTag(label: 'Images', onTap: () {
                            setState(() => _filterIndex = 1);
                            _scanStatuses();
                          }),
                    const SizedBox(width: 8),
                    _filterIndex == 2
                        ? const SkillPill(label: 'Videos')
                        : SkillTag(label: 'Videos', onTap: () {
                            setState(() => _filterIndex = 2);
                            _scanStatuses();
                          }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _hasPermission
                  ? RefreshIndicator(
                      onRefresh: _scanStatuses,
                      color: const Color(0xFF25D366),
                      backgroundColor: context.colorElevated,
                      child: _buildContent(),
                    )
                  : _buildPermissionRequest(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)));
    }
    if (_statuses.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined, size: 48, color: context.colorTextTertiary),
                const SizedBox(height: 16),
                Text('No statuses found', style: TextStyle(color: context.colorTextSecondary)),
                const SizedBox(height: 8),
                Text('Pull down to refresh', style: TextStyle(fontSize: 12, color: context.colorTextTertiary)),
              ],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _statuses.length,
      itemBuilder: (ctx, i) => _StatusTile(
        file: _statuses[i],
        isVideo: _isVideo(_statuses[i]),
        onTap: () => _openPreview(i),
        onSave: () => _saveFile(_statuses[i]),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/whatsapplogo.png',
                width: 72,
                height: 72,
                errorBuilder: (_, e, st) => const Icon(Icons.message_rounded, size: 72, color: Color(0xFF25D366)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Storage Permission Required', style: context.typographyH2, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              _permanentlyDenied
                  ? 'Storage permission was permanently denied. Open App Settings to enable it manually.'
                  : 'Downloda needs storage access to view and save your WhatsApp statuses.',
              textAlign: TextAlign.center,
              style: context.typographyBody.copyWith(color: context.colorTextSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
              child: Text(
                _permanentlyDenied ? 'Open App Settings' : 'Grant Access',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple path utility inline
class PathUtils {
  static String basename(String path) => path.split('/').last;
}

// ─── Status Tile ────────────────────────────────────────────────────────────

class _StatusTile extends StatelessWidget {
  final File file;
  final bool isVideo;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const _StatusTile({
    required this.file,
    required this.isVideo,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail — images render directly; videos show a dark placeholder with icon
            isVideo
                ? _VideoThumbnail(file: file)
                : Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, st) => Container(
                      color: Colors.grey.shade900,
                      child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
                    ),
                  ),
            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 32,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),
            // Save button
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: onSave,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.download_rounded, color: Colors.white, size: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-screen Preview Gallery ─────────────────────────────────────────────

class _StatusPreviewScreen extends StatefulWidget {
  final List<File> files;
  final int initialIndex;
  final Future<void> Function(File) onSave;

  const _StatusPreviewScreen({
    required this.files,
    required this.initialIndex,
    required this.onSave,
  });

  @override
  State<_StatusPreviewScreen> createState() => _StatusPreviewScreenState();
}

class _StatusPreviewScreenState extends State<_StatusPreviewScreen> {
  late PageController _controller;
  late int _current;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isVideo(File f) {
    final ext = f.path.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.gif');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(widget.files[_current]);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.files[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_current + 1} / ${widget.files.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.files.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) {
              final f = widget.files[i];
              if (_isVideo(f)) {
                return _VideoPreviewItem(file: f);
              }
              return InteractiveViewer(
                child: Center(
                  child: Image.file(
                    f,
                    fit: BoxFit.contain,
                  errorBuilder: (_, e, st) => const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
                  ),
                ),
              );
            },
          ),
          // Indicator dots
          if (widget.files.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: () {
                  final total = widget.files.length;
                  const maxDots = 8;
                  if (total <= maxDots) {
                    return List.generate(
                      total,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _current ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _current ? context.colorAccent : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }
                  
                  int start = _current - (maxDots ~/ 2);
                  if (start < 0) start = 0;
                  int end = start + maxDots;
                  if (end > total) {
                    end = total;
                    start = end - maxDots;
                  }
                  
                  return List.generate(
                    end - start,
                    (index) {
                      final i = start + index;
                      final isActive = i == _current;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? context.colorAccent : Colors.white38,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  );
                }(),
              ),
            ),
          // Type badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isVideo(file) ? '🎬 Video' : '🖼 Image',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreviewItem extends StatefulWidget {
  final File file;
  const _VideoPreviewItem({required this.file});

  @override
  State<_VideoPreviewItem> createState() => _VideoPreviewItemState();
}

class _VideoPreviewItemState extends State<_VideoPreviewItem> {
  late video_player.VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = video_player.VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.play();
          _controller.setLooping(true);
        }
      }).catchError((err) {
        debugPrint('Video Player Error: $err');
        if (mounted) {
          setState(() {
            _error = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text('Failed to play status video', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF25D366)),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_controller.value.isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: video_player.VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final File file;
  const _VideoThumbnail({required this.file});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      const channel = MethodChannel('com.downloda.app/media_scanner');
      final bytes = await channel.invokeMethod<Uint8List>(
        'getVideoThumbnail',
        {'path': widget.file.path},
      );
      if (mounted && bytes != null) {
        setState(() {
          _bytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error || _bytes == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.play_circle_fill_rounded, color: Colors.white54, size: 36),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          _bytes!,
          fit: BoxFit.cover,
        ),
        Container(
          color: Colors.black.withValues(alpha: 0.15),
          child: const Center(
            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 36),
          ),
        ),
      ],
    );
  }
}
