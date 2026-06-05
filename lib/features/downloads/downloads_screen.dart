import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/services/social_download_service.dart';
import '../../widgets/widgets.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> with WidgetsBindingObserver {
  int _filterIndex = 0; // 0: Active, 1: Queued, 2: All
  final TextEditingController _urlController = TextEditingController();
  bool _isLoadingMetadata = false;
  SocialMediaInfo? _socialMetadata;
  yt_exp.Video? _ytMetadata;
  yt_exp.Playlist? _playlistMetadata;
  List<yt_exp.Video>? _playlistVideos;
  MediaPlatform? _platform;
  VideoVariant? _selectedVariant;
  bool _isDrawerOpen = false;
  ProviderSubscription<bool>? _inputVisibilitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _urlController.addListener(_onUrlChanged);
    
    // Listen for visibility changes to trigger auto-paste
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboard();
      _inputVisibilitySubscription = ref.listenManual(inputVisibleProvider, (prev, next) {
        if (next == true) {
          _checkClipboard();
        }
      });
    });
  }

  @override
  void dispose() {
    _inputVisibilitySubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _socialMetadata = null;
        _ytMetadata = null;
        _platform = null;
        _selectedVariant = null;
      });
      return;
    }

    final platform = SocialDownloadService.detectPlatform(url);
    if (platform != _platform) {
      setState(() {
        _platform = platform;
        _socialMetadata = null;
        _ytMetadata = null;
        _selectedVariant = null;
      });
      if (platform != null) {
        _fetchMetadata(url, platform);
      }
    }
  }

  Future<void> _checkClipboard() async {
    // Only auto-paste if the input is visible
    if (!ref.read(inputVisibleProvider)) return;
    
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      final url = data!.text!.trim();
      final platform = SocialDownloadService.detectPlatform(url);
      if (platform != null && _urlController.text != url) {
        _urlController.text = url;
      }
    }
  }

  bool _isYoutubePlaylist(String url) {
    return (url.contains('youtube.com') || url.contains('youtu.be')) && url.contains('list=');
  }

  Future<void> _fetchMetadata(String url, MediaPlatform platform) async {
    setState(() {
      _isLoadingMetadata = true;
    });

    try {
      if (platform == MediaPlatform.youtube) {
        String targetUrl = url;
        if (targetUrl.contains('/shorts/')) {
          final shortsRegExp = RegExp(r'/shorts/([a-zA-Z0-9_-]+)(\?.*)?');
          final match = shortsRegExp.firstMatch(targetUrl);
          if (match != null) {
            final videoId = match.group(1);
            final queryParams = match.group(2);
            if (queryParams != null && queryParams.startsWith('?')) {
              final normalizedQueryParams = '&${queryParams.substring(1)}';
              targetUrl = targetUrl.replaceAll(shortsRegExp, '/watch?v=$videoId$normalizedQueryParams');
            } else {
              targetUrl = targetUrl.replaceAll(shortsRegExp, '/watch?v=$videoId');
            }
          }
        }
        final yt = yt_exp.YoutubeExplode();
        if (_isYoutubePlaylist(targetUrl)) {
          final playlist = await yt.playlists.get(targetUrl);
          final videosStream = yt.playlists.getVideos(playlist.id);
          final videos = await videosStream.toList();
          if (mounted) {
            setState(() {
              _playlistMetadata = playlist;
              _playlistVideos = videos;
            });
            _showPlaylistDrawer();
          }
        } else {
          final video = await yt.videos.get(targetUrl);
          if (mounted) {
            setState(() {
              _ytMetadata = video;
            });
            _showDownloadDrawer();
          }
        }
      } else {
        final social = ref.read(socialDownloadServiceProvider);
        final info = await social.fetchInfo(url);
        if (mounted) {
          setState(() {
            _socialMetadata = info;
            if (info.variants.isNotEmpty) {
              _selectedVariant = info.variants.first;
            }
          });
          _showDownloadDrawer();
        }
      }
    } catch (e) {
      debugPrint('Error fetching metadata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch video info: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMetadata = false;
        });
      }
    }
  }

  void _showDownloadDrawer() {
    if (_isDrawerOpen || !mounted) return;
    _isDrawerOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => _DownloadDrawer(
        ytMetadata: _ytMetadata,
        socialMetadata: _socialMetadata,
        platform: _platform!,
        onDownload: (variant, isAudio) {
          _startDownload(variant, isAudio);
        },
      ),
    ).then((_) => _isDrawerOpen = false);
  }

  void _showPlaylistDrawer() {
    if (_isDrawerOpen || !mounted || _playlistMetadata == null || _playlistVideos == null) return;
    _isDrawerOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => _PlaylistDrawer(
        playlistMetadata: _playlistMetadata!,
        videos: _playlistVideos!,
        onDownload: (selectedVideos, isAudio, resolution) {
          final service = ref.read(downloadServiceProvider);
          for (final video in selectedVideos) {
            service.downloadVideo(
              video.url,
              preferredRes: resolution,
              audioOnly: isAudio,
              title: video.title,
              thumbnailUrl: video.thumbnails.mediumResUrl,
            );
          }
          _urlController.clear();
          setState(() {
            _ytMetadata = null;
            _socialMetadata = null;
            _playlistMetadata = null;
            _playlistVideos = null;
            _platform = null;
            _selectedVariant = null;
          });
          ref.read(inputVisibleProvider.notifier).toggle();
          FocusScope.of(context).unfocus();
        },
      ),
    ).then((_) => _isDrawerOpen = false);
  }

  void _startDownload([VideoVariant? variant, bool isAudio = false]) {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final service = ref.read(downloadServiceProvider);
    
    if (_platform == MediaPlatform.youtube) {
      if (isAudio) {
        service.downloadVideo(url, audioOnly: true);
      } else if (variant != null) {
        service.downloadVideo(url, preferredRes: variant.quality);
      } else {
        // Fallback for default settings if somehow variant is null
        service.downloadVideo(url);
      }
    } else if (_socialMetadata != null) {
      final useVariant = variant ?? _selectedVariant;
      if (useVariant != null) {
        service.downloadVideo(
          url,
          preferredRes: useVariant.quality,
          directUrl: useVariant.url,
          title: _socialMetadata!.title,
          thumbnailUrl: _socialMetadata!.thumbnailUrl,
          audioOnly: isAudio,
        );
      }
    }

    _urlController.clear();
    setState(() {
      _ytMetadata = null;
      _socialMetadata = null;
      _playlistMetadata = null;
      _playlistVideos = null;
      _platform = null;
      _selectedVariant = null;
    });
    
    // Close input bar after download starts
    ref.read(inputVisibleProvider.notifier).toggle();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final downloadsAsync = ref.watch(activeDownloadsProvider);
    final isInputVisible = ref.watch(inputVisibleProvider);

    return Scaffold(
      backgroundColor: context.colorBackground,
      body: SafeArea(
        child: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isInputVisible 
                  ? _buildTopInputSection(context) 
                  : const SizedBox(width: double.infinity),
            ),
            if (_isLoadingMetadata)
              _buildLoadingState(context),
            Expanded(
              child: downloadsAsync.when(
                data: (data) {
                  final items = data.map((d) => d.toModel()).toList();
                  final active = items
                      .where((i) =>
                          i.status == DownloadStatus.downloading ||
                          i.status == DownloadStatus.processing ||
                          i.status == DownloadStatus.preparing ||
                          i.status == DownloadStatus.paused)
                      .toList();
                  final queued = items
                      .where((i) => i.status == DownloadStatus.queued)
                      .toList();

                  final filteredItems = _filterIndex == 0
                      ? active
                      : _filterIndex == 1
                          ? queued
                          : items;

                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(activeDownloadsProvider),
                    color: context.colorAccent,
                    backgroundColor: context.colorElevated,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkillHeader(
                                greeting:
                                    '${active.length} Active, ${queued.length} Queued',
                                title: 'Downloads',
                                trailingIcon: Icons.auto_awesome_rounded,
                                onTrailingTap: () {},
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _filterIndex == 0
                                          ? const SkillPill(label: 'Active')
                                          : SkillTag(
                                              label: 'Active',
                                              onTap: () =>
                                                  setState(() => _filterIndex = 0)),
                                      const SizedBox(width: 8),
                                      _filterIndex == 1
                                          ? const SkillPill(label: 'Queued')
                                          : SkillTag(
                                              label: 'Queued',
                                              onTap: () =>
                                                  setState(() => _filterIndex = 1)),
                                      const SizedBox(width: 8),
                                      _filterIndex == 2
                                          ? const SkillPill(label: 'All')
                                          : SkillTag(
                                              label: 'All',
                                              onTap: () =>
                                                  setState(() => _filterIndex = 2)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (filteredItems.isEmpty)
                                SizedBox(
                                  height: 400,
                                  child: _buildEmptyState(context),
                                ),
                            ],
                          ),
                        ),
                        if (filteredItems.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DownloadTile(
                                    item: filteredItems[i],
                                    onMoreTap: () =>
                                        _showActionMenu(context, filteredItems[i]),
                                  ),
                                ),
                                childCount: filteredItems.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInputSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: context.colorBackground,
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: context.colorSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colorDivider, width: 0.5),
        ),
        child: TextField(
          controller: _urlController,
          style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Paste video link here...',
            hintStyle: TextStyle(color: context.colorTextTertiary, fontSize: 14),
            prefixIcon: Icon(Icons.link_rounded, color: context.colorTextTertiary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(Icons.content_paste_rounded, color: context.colorAccent, size: 20),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  _urlController.text = data!.text!.trim();
                }
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorDivider.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Text(
            'Fetching video info...',
            style: TextStyle(color: context.colorTextPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Three-dots action menu for active/queued downloads ──────────────────

  void _showActionMenu(BuildContext context, DownloadItem item) {
    final service = ref.read(downloadServiceProvider);
    final isPaused = item.status == DownloadStatus.paused;
    final isActive = item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.processing;
    final isQueued = item.status == DownloadStatus.queued;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colorElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.colorDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.colorTextPrimary,
                ),
              ),
            ),
            const Divider(height: 1),

            if (isActive)
              _ActionTile(
                icon: Icons.pause_rounded,
                label: 'Pause',
                onTap: () {
                  Navigator.pop(ctx);
                  service.pauseDownload(item.id);
                },
              ),
            if (isPaused || isQueued)
              _ActionTile(
                icon: Icons.play_arrow_rounded,
                label: 'Resume',
                onTap: () {
                  Navigator.pop(ctx);
                  service.resumeDownload(item.id, item.url);
                },
              ),
            _ActionTile(
              icon: Icons.close_rounded,
              label: 'Cancel',
              color: context.colorFailure,
              onTap: () {
                Navigator.pop(ctx);
                _confirmCancel(context, item, service);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(
      BuildContext context, DownloadItem item, dynamic service) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colorElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Download?',
            style: TextStyle(
                fontSize: 14, color: context.colorTextPrimary)),
        content: Text(item.title,
            style: TextStyle(
                fontSize: 12, color: context.colorTextSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Keep',
                  style: TextStyle(color: context.colorTextSecondary))),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                service.cancelDownload(item.id);
              },
              child: Text('Cancel Download',
                  style: TextStyle(color: context.colorFailure))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_done_rounded,
              size: 48, color: context.colorTextTertiary),
          const SizedBox(height: 16),
          Text('No downloads found',
              style: context.typographyBody
                  .copyWith(color: context.colorTextSecondary)),
        ],
      ),
    );
  }
}

// ── Download tile ──────────────────────────────────────────────────────────

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback onMoreTap;

  const _DownloadTile({required this.item, required this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    final isActive = item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.processing;
    final isPaused = item.status == DownloadStatus.paused;
    final isQueued = item.status == DownloadStatus.queued;
    final isPreparing = item.status == DownloadStatus.preparing;

    // Resolution + format badge text (skip placeholders)
    final showMeta = item.resolution != '...' && item.resolution.isNotEmpty;

    return SkillListRow(
      avatar: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.thumbnailUrl != null
                ? (item.thumbnailUrl!.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                            width: 44,
                            height: 44,
                            color: context.colorSurface))
                    : Image.file(
                        File(item.thumbnailUrl!),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                            width: 44,
                            height: 44,
                            color: context.colorSurface),
                      ))
                : Container(
                    width: 44, height: 44, color: context.colorSurface),
          ),
          if (isActive || isPaused || isQueued || isPreparing)
            ProgressRing(progress: item.progress, status: item.status, size: 32),
        ],
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (isActive || isPaused)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: item.progress,
                backgroundColor: context.colorRingTrack,
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.colorAccent),
                minHeight: 2,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Resolution + format (shown when available)
              if (showMeta) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: context.colorAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.resolution} ${item.format.toUpperCase()}',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: context.colorAccent),
                  ),
                ),
                Text(' • ',
                    style: TextStyle(color: context.colorTextTertiary)),
              ],
              Text(
                item.fileSizeMb > 0
                    ? '${item.progressLabel} (${item.fileSizeLabel})'
                    : item.progressLabel,
                style: TextStyle(
                    fontSize: 11, color: context.colorTextSecondary),
              ),
              if (isActive && item.speedMbps > 0) ...[
                Text(' • ',
                    style: TextStyle(color: context.colorTextTertiary)),
                Text(item.speedLabel,
                    style: TextStyle(
                        fontSize: 11, color: context.colorTextSecondary)),
                Text(' • ',
                    style: TextStyle(color: context.colorTextTertiary)),
                Text(item.etaLabel,
                    style: TextStyle(
                        fontSize: 11, color: context.colorTextSecondary)),
              ],
              if (isPaused) ...[
                Text(' • ',
                    style: TextStyle(color: context.colorTextTertiary)),
                Text('Paused',
                    style: TextStyle(
                        fontSize: 11, color: context.colorWarning)),
              ],
              if (isQueued) ...[
                Text(' • ',
                    style: TextStyle(color: context.colorTextTertiary)),
                Text('Queued',
                    style: TextStyle(
                        fontSize: 11, color: context.colorTextTertiary)),
              ],
            ],
          ),
        ],
      ),
      trailing: GestureDetector(
        onTap: onMoreTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.more_vert_rounded,
              size: 20, color: context.colorTextSecondary),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colorTextPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label, style: TextStyle(fontSize: 14, color: c)),
      onTap: onTap,
      dense: true,
    );
  }
}

// ── Download Drawer (The "App Drawer" for Selection) ────────────────────────

class _DownloadDrawer extends StatefulWidget {
  final yt_exp.Video? ytMetadata;
  final SocialMediaInfo? socialMetadata;
  final MediaPlatform platform;
  final Function(VideoVariant?, bool) onDownload;

  const _DownloadDrawer({
    this.ytMetadata,
    this.socialMetadata,
    required this.platform,
    required this.onDownload,
  });

  @override
  State<_DownloadDrawer> createState() => _DownloadDrawerState();
}

class _DownloadDrawerState extends State<_DownloadDrawer> {
  bool _isAudioOnly = false;
  VideoVariant? _selectedVariant;
  String _selectedYtRes = '1080p';
  bool _isProcessing = false;

  yt_exp.StreamManifest? _ytManifest;
  bool _isLoadingManifest = false;

  void _fetchManifest() async {
    if (widget.platform != MediaPlatform.youtube || widget.ytMetadata == null) return;
    setState(() => _isLoadingManifest = true);
    try {
      final yt = yt_exp.YoutubeExplode();
      final manifest = await yt.videos.streamsClient.getManifest(widget.ytMetadata!.id);
      if (mounted) {
        setState(() {
          _ytManifest = manifest;
          _isLoadingManifest = false;
        });
      }
      yt.close();
    } catch (e) {
      debugPrint('[_DownloadDrawer] Error fetching manifest: $e');
      if (mounted) {
        setState(() => _isLoadingManifest = false);
      }
    }
  }

  String get _estimatedSizeStr {
    if (widget.platform == MediaPlatform.youtube && _ytManifest != null) {
      double totalMb = 0;
      if (_isAudioOnly) {
        final audioStream = _ytManifest!.audioOnly.withHighestBitrate();
        totalMb = audioStream.size.totalMegaBytes;
      } else {
        final resNum = int.tryParse(_selectedYtRes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1080;
        if (resNum > 360) {
          final videoStreams = _ytManifest!.videoOnly.toList();
          videoStreams.sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
          yt_exp.VideoOnlyStreamInfo? bestVideoOnly;
          for (final s in videoStreams) {
            if (s.videoResolution.height <= resNum) {
              bestVideoOnly = s;
              break;
            }
          }
          bestVideoOnly ??= videoStreams.isNotEmpty ? videoStreams.first : null;
          final audioStream = _ytManifest!.audioOnly.withHighestBitrate();
          if (bestVideoOnly != null) {
            totalMb = bestVideoOnly.size.totalMegaBytes + audioStream.size.totalMegaBytes;
          } else {
            final muxed = _ytManifest!.muxed.toList();
            yt_exp.MuxedStreamInfo? bestStream;
            muxed.sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
            for (final s in muxed) {
              if (s.videoResolution.height <= resNum) {
                bestStream = s;
                break;
              }
            }
            bestStream ??= muxed.isNotEmpty
                ? muxed.first
                : (_ytManifest!.muxed.isEmpty ? null : _ytManifest!.muxed.withHighestBitrate());
            totalMb = bestStream?.size.totalMegaBytes ?? 0;
          }
        } else {
          final muxed = _ytManifest!.muxed.toList();
          yt_exp.MuxedStreamInfo? bestStream;
          muxed.sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
          for (final s in muxed) {
            if (s.videoResolution.height <= resNum) {
              bestStream = s;
              break;
            }
          }
          bestStream ??= muxed.isNotEmpty
              ? muxed.first
              : (_ytManifest!.muxed.isEmpty ? null : _ytManifest!.muxed.withHighestBitrate());
          totalMb = bestStream?.size.totalMegaBytes ?? 0;
        }
      }
      if (totalMb >= 1024) {
        return '${(totalMb / 1024).toStringAsFixed(1)} GB';
      }
      return '${totalMb.toStringAsFixed(1)} MB';
    }

    double totalMb = 0;
    
    if (widget.platform == MediaPlatform.youtube && widget.ytMetadata != null) {
      final durationSec = widget.ytMetadata!.duration?.inSeconds ?? 0;
      if (_isAudioOnly) {
        totalMb = (durationSec * 0.015); // ~0.9 MB per minute
      } else {
        switch (_selectedYtRes) {
          case '360p':
            totalMb = (durationSec * 0.075); // ~4.5 MB per minute
            break;
          case '480p':
            totalMb = (durationSec * 0.133); // ~8.0 MB per minute
            break;
          case '720p':
            totalMb = (durationSec * 0.3);   // ~18.0 MB per minute
            break;
          case '1080p':
            totalMb = (durationSec * 0.583); // ~35.0 MB per minute
            break;
          case '4K':
            totalMb = (durationSec * 2.25);  // ~135.0 MB per minute
            break;
          default:
            totalMb = (durationSec * 0.583);
        }
      }
    } else {
      // Social platforms video (duration usually short, estimate ~5-15MB depending on quality/watermark)
      final quality = _selectedVariant?.quality.toLowerCase() ?? '';
      if (_isAudioOnly) {
        totalMb = 2.5; // typical audio size
      } else if (quality.contains('watermark')) {
        totalMb = 6.0;
      } else {
        totalMb = 12.0; // standard 1080p TikTok/Instagram video is around 8-15 MB
      }
    }
    
    if (totalMb == 0) return 'Unknown Size';
    if (totalMb >= 1024) {
      return '${(totalMb / 1024).toStringAsFixed(1)} GB';
    }
    return '${totalMb.toStringAsFixed(0)} MB';
  }

  @override
  void initState() {
    super.initState();
    if (widget.socialMetadata != null && widget.socialMetadata!.variants.isNotEmpty) {
      _selectedVariant = widget.socialMetadata!.variants.first;
    }
    _fetchManifest();
  }

  void _handleDownload() async {
    setState(() => _isProcessing = true);
    
    // Simulate "processing" briefly as requested
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      VideoVariant? variant;
      if (widget.platform == MediaPlatform.youtube) {
        variant = VideoVariant(quality: _selectedYtRes, url: '', format: 'mp4');
      } else {
        variant = _selectedVariant;
      }
      
      widget.onDownload(variant, _isAudioOnly);
      Navigator.pop(context); // Close drawer after processing
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.ytMetadata?.title ?? widget.socialMetadata?.title ?? 'Unknown Video';
    final thumb = widget.ytMetadata?.thumbnails.mediumResUrl ?? widget.socialMetadata?.thumbnailUrl;

    return Container(
      decoration: BoxDecoration(
        color: context.colorElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 12,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Header: Thumb + Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: thumb != null
                    ? CachedNetworkImage(
                        imageUrl: thumb,
                        width: 100,
                        height: 75,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                            width: 100, height: 75, color: context.colorSurface))
                    : Container(width: 100, height: 75, color: context.colorSurface),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typographyH3.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    _buildPlatformBadge(context),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Selection Sections
          Text('Select Format', style: context.typographyMeta),
          const SizedBox(height: 12),
          Row(
            children: [
              _TypeChip(
                label: 'Video',
                icon: Icons.videocam_rounded,
                isSelected: !_isAudioOnly,
                onTap: () => setState(() => _isAudioOnly = false),
              ),
              const SizedBox(width: 12),
              _TypeChip(
                label: 'Audio',
                icon: Icons.audiotrack_rounded,
                isSelected: _isAudioOnly,
                onTap: () => setState(() => _isAudioOnly = true),
              ),
            ],
          ),
          
          if (!_isAudioOnly) ...[
            const SizedBox(height: 24),
            Text('Select Quality', style: context.typographyMeta),
            const SizedBox(height: 12),
            if (widget.platform == MediaPlatform.youtube)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['360p', '480p', '720p', '1080p', '4K'].map((res) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(res),
                      selected: _selectedYtRes == res,
                      onSelected: (val) => setState(() => _selectedYtRes = res),
                      backgroundColor: context.colorSurface,
                      selectedColor: context.colorAccent.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _selectedYtRes == res ? context.colorAccent : context.colorTextPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )).toList(),
                ),
              )
            else if (widget.socialMetadata != null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.socialMetadata!.variants.map((v) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(v.quality),
                      selected: _selectedVariant == v,
                      onSelected: (val) => setState(() => _selectedVariant = v),
                      backgroundColor: context.colorSurface,
                      selectedColor: context.colorAccent.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _selectedVariant == v ? context.colorAccent : context.colorTextPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )).toList(),
                ),
              ),
          ],

          const SizedBox(height: 32),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handleDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorAccent,
                foregroundColor: context.colorBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isProcessing
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: context.colorBackground, strokeWidth: 3))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Start Download ($_estimatedSizeStr)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (_isLoadingManifest) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBadge(BuildContext context) {
    String label = 'Unknown';
    Color color = Colors.grey;
    IconData icon = Icons.video_library_rounded;

    switch (widget.platform) {
      case MediaPlatform.youtube:
        label = 'YouTube';
        color = Colors.red;
        icon = Icons.play_circle_filled_rounded;
        break;
      case MediaPlatform.instagram:
        label = 'Instagram';
        color = Colors.pink;
        icon = Icons.camera_alt_rounded;
        break;
      case MediaPlatform.tiktok:
        label = 'TikTok';
        color = Colors.black;
        icon = Icons.music_note_rounded;
        break;
      case MediaPlatform.facebook:
        label = 'Facebook';
        color = Colors.blue;
        icon = Icons.facebook_rounded;
        break;
      case MediaPlatform.x:
        label = 'X';
        color = Colors.black;
        icon = Icons.close_rounded;
        break;
      case MediaPlatform.reddit:
        label = 'Reddit';
        color = Colors.orange;
        icon = Icons.reddit;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? context.colorAccent.withValues(alpha: 0.1) : context.colorSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? context.colorAccent : context.colorDivider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? context.colorAccent : context.colorTextSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? context.colorAccent : context.colorTextPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDrawer extends StatefulWidget {
  final yt_exp.Playlist playlistMetadata;
  final List<yt_exp.Video> videos;
  final Function(List<yt_exp.Video> selectedVideos, bool isAudio, String resolution) onDownload;

  const _PlaylistDrawer({
    required this.playlistMetadata,
    required this.videos,
    required this.onDownload,
  });

  @override
  State<_PlaylistDrawer> createState() => _PlaylistDrawerState();
}

class _PlaylistDrawerState extends State<_PlaylistDrawer> {
  bool _isAudioOnly = false;
  String _selectedYtRes = '1080p';
  late Set<String> _selectedVideoIds;
  bool _isProcessing = false;

  String get _estimatedSizeStr {
    double totalMb = 0;
    for (final video in widget.videos) {
      if (_selectedVideoIds.contains(video.id.value)) {
        final durationSec = video.duration?.inSeconds ?? 0;
        if (_isAudioOnly) {
          totalMb += (durationSec * 0.015); // ~0.9 MB per minute
        } else {
          switch (_selectedYtRes) {
            case '360p':
              totalMb += (durationSec * 0.075); // ~4.5 MB per minute
              break;
            case '480p':
              totalMb += (durationSec * 0.133); // ~8.0 MB per minute
              break;
            case '720p':
              totalMb += (durationSec * 0.3);   // ~18.0 MB per minute
              break;
            case '1080p':
              totalMb += (durationSec * 0.583); // ~35.0 MB per minute
              break;
            case '4K':
              totalMb += (durationSec * 2.25);  // ~135.0 MB per minute
              break;
            default:
              totalMb += (durationSec * 0.583);
          }
        }
      }
    }
    if (totalMb == 0) return '0 MB';
    if (totalMb >= 1024) {
      return '${(totalMb / 1024).toStringAsFixed(1)} GB';
    }
    return '${totalMb.toStringAsFixed(0)} MB';
  }

  @override
  void initState() {
    super.initState();
    // Default: Auto select all
    _selectedVideoIds = widget.videos.map((v) => v.id.value).toSet();
  }

  void _handleDownload() async {
    final selected = widget.videos.where((v) => _selectedVideoIds.contains(v.id.value)).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one video to download.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    
    // Simulate "processing" briefly as requested
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      widget.onDownload(selected, _isAudioOnly, _selectedYtRes);
      Navigator.pop(context); // Close drawer after processing
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedVideoIds.length == widget.videos.length) {
        _selectedVideoIds.clear();
      } else {
        _selectedVideoIds = widget.videos.map((v) => v.id.value).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlistTitle = widget.playlistMetadata.title;
    final playlistAuthor = widget.playlistMetadata.author;
    final thumb = widget.playlistMetadata.thumbnails.mediumResUrl.isNotEmpty
        ? widget.playlistMetadata.thumbnails.mediumResUrl
        : (widget.videos.isNotEmpty ? widget.videos.first.thumbnails.mediumResUrl : null);

    return Container(
      decoration: BoxDecoration(
        color: context.colorElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 12,
        left: 24,
        right: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header: Thumb + Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: thumb != null
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          width: 100,
                          height: 75,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                              width: 100, height: 75, color: context.colorSurface))
                      : Container(width: 100, height: 75, color: context.colorSurface),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlistTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.typographyH3.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        playlistAuthor.isNotEmpty ? 'by $playlistAuthor' : 'YouTube Playlist',
                        style: TextStyle(color: context.colorTextSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.playlist_play_rounded, size: 10, color: Colors.red),
                            const SizedBox(width: 4),
                            Text('Playlist • ${widget.videos.length} videos', 
                                style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            
            // Format Selection
            const SizedBox(height: 8),
            Text('Select Format', style: context.typographyMeta),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeChip(
                  label: 'Video',
                  icon: Icons.videocam_rounded,
                  isSelected: !_isAudioOnly,
                  onTap: () => setState(() => _isAudioOnly = false),
                ),
                const SizedBox(width: 12),
                _TypeChip(
                  label: 'Audio',
                  icon: Icons.audiotrack_rounded,
                  isSelected: _isAudioOnly,
                  onTap: () => setState(() => _isAudioOnly = true),
                ),
              ],
            ),
            
            if (!_isAudioOnly) ...[
              const SizedBox(height: 16),
              Text('Select Quality', style: context.typographyMeta),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['360p', '480p', '720p', '1080p', '4K'].map((res) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(res),
                      selected: _selectedYtRes == res,
                      onSelected: (val) => setState(() => _selectedYtRes = res),
                      backgroundColor: context.colorSurface,
                      selectedColor: context.colorAccent.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _selectedYtRes == res ? context.colorAccent : context.colorTextPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            const Divider(),
            
            // Bulk action bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected: ${_selectedVideoIds.length} of ${widget.videos.length}',
                  style: TextStyle(
                    color: context.colorTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: _toggleSelectAll,
                  style: TextButton.styleFrom(
                    foregroundColor: context.colorAccent,
                  ),
                  child: Text(
                    _selectedVideoIds.length == widget.videos.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            
            // Video list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: widget.videos.length,
                itemBuilder: (ctx, index) {
                  final video = widget.videos[index];
                  final isSelected = _selectedVideoIds.contains(video.id.value);
                  final durationString = video.duration != null
                      ? '${video.duration!.inMinutes}:${(video.duration!.inSeconds % 60).toString().padLeft(2, '0')}'
                      : '';
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedVideoIds.remove(video.id.value);
                        } else {
                          _selectedVideoIds.add(video.id.value);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          // Checkbox
                          Checkbox(
                            value: isSelected,
                            activeColor: context.colorAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedVideoIds.add(video.id.value);
                                } else {
                                  _selectedVideoIds.remove(video.id.value);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          
                          // Video Thumbnail
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: video.thumbnails.mediumResUrl,
                                  width: 80,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      Container(width: 80, height: 50, color: context.colorSurface),
                                ),
                              ),
                              if (durationString.isNotEmpty)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      durationString,
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          
                          // Video Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  video.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? context.colorTextPrimary : context.colorTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  video.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: context.colorTextTertiary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Download button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing || _selectedVideoIds.isEmpty ? null : _handleDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colorAccent,
                  foregroundColor: context.colorBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: context.colorBackground, strokeWidth: 3))
                    : Text(
                        _selectedVideoIds.isEmpty
                            ? 'Select Videos to Download'
                            : 'Download ${_selectedVideoIds.length} Videos ($_estimatedSizeStr)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
