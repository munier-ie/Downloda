import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../models.dart';
import '../database/database.dart';
import 'notification_service.dart';
import 'social_download_service.dart';

class DownloadService {
  final AppDatabase db;
  final YoutubeExplode yt = YoutubeExplode();
  final Dio dio = Dio();

  /// Active Dio cancel tokens, keyed by download ID
  final Map<String, CancelToken> _tokens = {};

  /// Download IDs that are currently being processed (preparing, fetching info, or downloading)
  static final Set<String> _activeTasks = {};

  /// Download IDs that have been requested to pause
  final Map<String, bool> _paused = {};

  DownloadService(this.db);

  /// Sends 'refresh' to the main UI isolate so Riverpod providers re-query.
  void pingUi() {
    IsolateNameServer.lookupPortByName('dwldr_ui_port')?.send('refresh');
  }

  // ── Settings helpers ──────────────────────────────────────────────────────

  Future<int> _getMaxSimultaneous() async {
    final prefs = await SharedPreferences.getInstance();
    final batterySaver = prefs.getBool('batterySaver') ?? false;
    final userMax = prefs.getInt('maxSimultaneous') ?? 3;
    // Battery saver caps concurrent downloads at 1
    return batterySaver ? 1 : userMax;
  }

  Future<bool> _isWifiOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('wifiOnly') ?? false;
  }

  Future<bool> _isVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('vibration') ?? true;
  }

  /// Returns true if we're on a valid network for downloading.
  /// When wifiOnly=true, only WiFi connections are accepted.
  Future<bool> _canDownload() async {
    final connectivity = await Connectivity().checkConnectivity();
    final hasNetwork = connectivity.any((c) =>
        c == ConnectivityResult.wifi ||
        c == ConnectivityResult.mobile ||
        c == ConnectivityResult.ethernet);

    if (!hasNetwork) return false;

    final wifiOnly = await _isWifiOnly();
    if (wifiOnly) {
      return connectivity.contains(ConnectivityResult.wifi) ||
          connectivity.contains(ConnectivityResult.ethernet);
    }
    return true;
  }

  // ── Queue management ──────────────────────────────────────────────────────

  Future<int> getActiveCount() async {
    final all = await db.getActiveDownloads();
    return all.where((i) {
      return i.status == DownloadStatus.downloading ||
          i.status == DownloadStatus.preparing ||
          i.status == DownloadStatus.processing;
    }).length;
  }

  bool _isCheckingQueue = false;

  Future<void> checkQueue() async {
    if (_isCheckingQueue) return;
    _isCheckingQueue = true;

    try {
      // Fill ALL available download slots, not just one
      while (true) {
        final maxSim = await _getMaxSimultaneous();
        final activeCount = await getActiveCount();
        debugPrint('[QueueManager] Checking queue: active=$activeCount, max=$maxSim');

        if (activeCount >= maxSim) {
          debugPrint('[QueueManager] Max simultaneous downloads reached.');
          break;
        }

        final all = await db.getActiveDownloads();
        // Find queued items that are not awaiting resolution choice
        final queuedItems = all
            .where((i) =>
                i.status == DownloadStatus.queued &&
                i.resolution != 'ask' &&
                !_activeTasks.contains(i.id))
            .toList();
        queuedItems.sort((a, b) => a.addedAt.compareTo(b.addedAt));

        if (queuedItems.isEmpty) {
          debugPrint('[QueueManager] No queued items found.');
          break;
        }

        final next = queuedItems.first;
        debugPrint('[QueueManager] Starting queued: ${next.title} (${next.id})');

        // Update status immediately so the next iteration counts this slot as occupied
        final companion = next.toCompanion(false).copyWith(
              status: const Value(DownloadStatus.preparing),
            );
        await db.updateDownload(companion);
        _activeTasks.add(next.id); // Mark immediately to avoid double-starting

        _startDownload(
          id: next.id,
          url: next.url,
          existingItem: next.toModel(),
          thumbnailUrl: next.thumbnailUrl,
        );
      }
    } finally {
      _isCheckingQueue = false;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> downloadVideo(String url,
      {String? preferredRes,
      bool? audioOnly,
      String? directUrl,
      String? title,
      String? thumbnailUrl}) async {
    final id = const Uuid().v4();
    final maxSim = await _getMaxSimultaneous();
    final activeCount = await getActiveCount();

    final cleanUrl = _extractUrl(url);
    final platform = _detectPlatform(cleanUrl);

    // Duplicate Prevention Check
    final existing = await db.getDownloadByUrl(cleanUrl);
    if (existing != null) {
      if (existing.status == DownloadStatus.completed) {
        if (existing.filePath != null && await File(existing.filePath!).exists()) {
          debugPrint('[DownloadService] Duplicate download skipped: already completed. URL: $cleanUrl');
          await NotificationService().showCompletionNotification(
            id: cleanUrl.hashCode & 0x7fffffff,
            title: 'Already Downloaded',
            body: '${existing.title} has already been downloaded.',
            payload: existing.id,
          );
          return;
        } else {
          // User deleted the file on disk. Delete database record to allow redownload.
          debugPrint('[DownloadService] File deleted on disk. Re-enabling download for URL: $cleanUrl');
          await db.deleteDownload(existing.id);
        }
      } else if (existing.status == DownloadStatus.failed) {
        // Delete the failed record to avoid cluttering history
        debugPrint('[DownloadService] Deleting old failed download record for URL: $cleanUrl');
        await db.deleteDownload(existing.id);
      } else {
        debugPrint('[DownloadService] Duplicate download skipped: active or paused. URL: $cleanUrl');
        await NotificationService().showCompletionNotification(
          id: cleanUrl.hashCode & 0x7fffffff,
          title: 'Download Already Active',
          body: '${existing.title} is already active or in progress.',
          payload: existing.id,
        );
        return;
      }
    }

    // If it's a YouTube playlist URL (shared via share-download / external intent):
    if (platform == MediaPlatform.youtube &&
        (cleanUrl.contains('youtube.com') || cleanUrl.contains('youtu.be')) &&
        cleanUrl.contains('list=')) {
      debugPrint('[DownloadService] Shared playlist detected: $cleanUrl');
      try {
        final playlist = await yt.playlists.get(cleanUrl);
        final videosStream = yt.playlists.getVideos(playlist.id);
        final videos = await videosStream.toList();

        // Fetch user default settings from preferences
        final prefs = await SharedPreferences.getInstance();
        final defaultRes = prefs.getString('defaultRes') ?? '720p';
        final useRes = defaultRes == 'Always Ask' ? '720p' : defaultRes;
        final useAudioOnly = prefs.getBool('audioOnly') ?? false;

        // Automatically queue all videos in the playlist using user settings
        debugPrint('[DownloadService] Bulk queuing ${videos.length} videos from shared playlist');
        for (final video in videos) {
          await downloadVideo(
            video.url.toString(),
            preferredRes: useRes,
            audioOnly: useAudioOnly,
            thumbnailUrl: video.thumbnails.mediumResUrl,
            title: video.title,
          );
        }
        return;
      } catch (e) {
        debugPrint('[DownloadService] Failed to process shared playlist: $e');
      }
    }

    // Fetch user default setting
    final prefs = await SharedPreferences.getInstance();
    final settingsRes = prefs.getString('defaultRes') ?? '720p';
    final useRes = preferredRes ?? settingsRes;

    // Check if resolution is Always Ask and download was requested from share intent
    if (useRes == 'Always Ask' && preferredRes == null && directUrl == null) {
      debugPrint(
          '[DownloadService] Always Ask is active on background share. Fetching metadata and queuing...');

      String itemTitle = title ?? 'Preparing shared download...';
      String? thumbUrl = thumbnailUrl;

      final tempItem = DownloadItem(
        id: id,
        title: 'Preparing quality selection...',
        url: cleanUrl,
        platform: platform,
        status: DownloadStatus.preparing,
        progress: 0,
        speedMbps: 0,
        etaSeconds: 0,
        format: '...',
        resolution: 'ask',
        fileSizeMb: 0,
        addedAt: DateTime.now(),
      );
      await db.insertDownload(tempItem.toCompanion());
      pingUi();

      if (platform == MediaPlatform.youtube) {
        try {
          final video = await yt.videos.get(cleanUrl);
          itemTitle = video.title;
          thumbUrl = video.thumbnails.mediumResUrl;
        } catch (e) {
          debugPrint('[DownloadService] Failed to pre-fetch metadata: $e');
          itemTitle = 'Shared Video';
        }
      } else {
        itemTitle = title ?? '${platform.name.toUpperCase()} Video';
      }

      final item = DownloadItem(
        id: id,
        title: itemTitle,
        url: cleanUrl,
        platform: platform,
        status: DownloadStatus.queued,
        progress: 0,
        speedMbps: 0,
        etaSeconds: 0,
        format: '...',
        resolution: 'ask',
        fileSizeMb: 0,
        addedAt: DateTime.now(),
        thumbnailUrl: thumbUrl,
      );
      await db.updateDownload(item.toCompanion());
      pingUi();

      await NotificationService().showProgressNotification(
        id: id.hashCode & 0x7fffffff,
        title: 'Select Quality',
        body: 'Open Downloda to choose download quality for $itemTitle',
        progress: 0,
        maxProgress: 100,
        showProgress: false,
        ongoing: false,
        payload: id,
      );
      return;
    }

    // Check network constraints
    if (!await _canDownload()) {
      debugPrint('[DownloadService] No valid network. Queuing: $cleanUrl');
      final item = _makeQueuedItem(id, cleanUrl, useRes);
      await db.insertDownload(item.toCompanion());
      pingUi();
      await NotificationService().showProgressNotification(
        id: id.hashCode & 0x7fffffff,
        title: 'Waiting for Wi-Fi',
        body: 'Download will start when connected to Wi-Fi',
        progress: 0,
        maxProgress: 100,
        showProgress: false,
        ongoing: false,
        payload: id,
      );
      return;
    }

    if (activeCount >= maxSim) {
      debugPrint(
          '[QueueManager] Slots full ($activeCount/$maxSim). Queuing: $cleanUrl');
      final item = _makeQueuedItem(id, cleanUrl, useRes);
      await db.insertDownload(item.toCompanion());
      pingUi();
      return;
    }

    await _startDownload(
      id: id,
      url: cleanUrl,
      preferredRes: preferredRes,
      audioOnly: audioOnly,
      directUrl: directUrl,
      title: title,
      thumbnailUrl: thumbnailUrl,
    );
  }

  Future<void> resumeDownload(String id, String url,
      {bool broadcast = true}) async {
    if (broadcast) {
      IsolateNameServer.lookupPortByName('dwldr_cmd_port')
          ?.send({'action': 'resume', 'id': id});
      IsolateNameServer.lookupPortByName('dwldr_bg_cmd_port')
          ?.send({'action': 'resume', 'id': id});
    }

    _paused.remove(id);
    final existing = await db.getDownloadById(id);
    if (existing == null) return;

    if (!await _canDownload()) {
      final companion = existing.toCompanion(false).copyWith(
            status: const Value(DownloadStatus.queued),
          );
      await db.updateDownload(companion);
      pingUi();
      return;
    }

    final maxSim = await _getMaxSimultaneous();
    final activeCount = await getActiveCount();

    if (activeCount >= maxSim) {
      final companion = existing.toCompanion(false).copyWith(
            status: const Value(DownloadStatus.queued),
          );
      await db.updateDownload(companion);
      pingUi();
      return;
    }

    await _startDownload(
      id: id,
      url: url,
      existingItem: existing.toModel(),
      thumbnailUrl: existing.thumbnailUrl,
    );
  }

  Future<void> pauseDownload(String id, {bool broadcast = true}) async {
    if (broadcast) {
      IsolateNameServer.lookupPortByName('dwldr_cmd_port')
          ?.send({'action': 'pause', 'id': id});
      IsolateNameServer.lookupPortByName('dwldr_bg_cmd_port')
          ?.send({'action': 'pause', 'id': id});
    }

    _paused[id] = true;
    if (_tokens.containsKey(id)) {
      _tokens[id]?.cancel('paused');
    } else {
      // Not actively downloading (queued/preparing) — set paused directly
      await _updateItemStatus(id, DownloadStatus.paused);
      
      final record = await db.getDownloadById(id);
      if (record != null) {
        final model = record.toModel();
        final notifId = id.hashCode & 0x7fffffff;
        await NotificationService().showProgressNotification(
          id: notifId,
          title: model.title,
          body: 'Paused • ${model.progressLabel}',
          progress: (model.progress * 100).toInt(),
          maxProgress: 100,
          ongoing: false,
          actions: [
            const AndroidNotificationAction('resume', 'Resume',
                showsUserInterface: false),
            const AndroidNotificationAction('cancel', 'Cancel',
                showsUserInterface: false),
          ],
          payload: id,
        );
      }
      checkQueue();
    }
  }

  Future<void> cancelDownload(String id, {bool broadcast = true}) async {
    if (broadcast) {
      IsolateNameServer.lookupPortByName('dwldr_cmd_port')
          ?.send({'action': 'cancel', 'id': id});
      IsolateNameServer.lookupPortByName('dwldr_bg_cmd_port')
          ?.send({'action': 'cancel', 'id': id});
    }

    _paused.remove(id);
    final notifId = id.hashCode & 0x7fffffff;
    await NotificationService().cancel(notifId);

    if (_tokens.containsKey(id)) {
      _tokens[id]?.cancel('cancelled');
    } else {
      await db.deleteDownload(id);
      await checkQueue();
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  String _extractUrl(String raw) {
    final re = RegExp(r'https?://[^\s]+', caseSensitive: false);
    String extracted = re.firstMatch(raw)?.group(0) ?? raw;

    // Normalize YouTube Shorts URLs
    if (extracted.contains('/shorts/')) {
      final shortsRegExp = RegExp(r'/shorts/([a-zA-Z0-9_-]+)(\?.*)?');
      final match = shortsRegExp.firstMatch(extracted);
      if (match != null) {
        final videoId = match.group(1);
        final queryParams = match.group(2);
        if (queryParams != null && queryParams.startsWith('?')) {
          final normalizedQueryParams = '&${queryParams.substring(1)}';
          extracted = extracted.replaceAll(shortsRegExp, '/watch?v=$videoId$normalizedQueryParams');
        } else {
          extracted = extracted.replaceAll(shortsRegExp, '/watch?v=$videoId');
        }
      }
    }
    return extracted;
  }

  Future<int> _downloadStreamChunked({
    required String id,
    required String url,
    required String tempPath,
    required int startByte,
    required int totalStreamBytes,
    required int overallProgressStart,
    required int overallTotalBytes,
    required CancelToken cancelToken,
    required DownloadItem item,
    required int notifId,
    required bool batterySaver,
  }) async {
    final file = File(tempPath);

    final Map<String, dynamic> headers = {};
    if (startByte > 0) {
      headers['Range'] = 'bytes=$startByte-';
    }
    if (url.contains('googlevideo.com') || url.contains('youtube') || url.contains('youtu.be')) {
      headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36';
      headers['Referer'] = 'https://www.youtube.com/';
    }

    final options = Options(
      responseType: ResponseType.stream,
      headers: headers,
    );

    final response = await dio.get<ResponseBody>(
      url,
      options: options,
      cancelToken: cancelToken,
    );

    final isPartial = response.statusCode == 206;
    int actualStart = startByte;
    if (startByte > 0 && !isPartial) {
      debugPrint('[DownloadService] Server does not support resume. Starting over.');
      actualStart = 0;
    }

    final totalBytes = int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
    final streamFullSize = isPartial ? (totalBytes + actualStart) : totalBytes;

    final double sizeInMb = (overallTotalBytes > 0 ? overallTotalBytes : streamFullSize) / (1024 * 1024);
    if (sizeInMb > 0) {
      item.fileSizeMb = sizeInMb;
      await db.updateDownload(item.toCompanion());
    }

    final sink = file.openWrite(
        mode: (actualStart > 0 && isPartial) ? FileMode.append : FileMode.write);

    int downloadedInStream = actualStart;
    DateTime lastUpdate = DateTime.now();
    int lastBytes = actualStart;

    try {
      await for (final chunk in response.data!.stream) {
        if (_paused[id] == true) {
          debugPrint('[DownloadService] Stream loop: pause detected for $id');
          break;
        }
        sink.add(chunk);
        downloadedInStream += chunk.length;

        if (batterySaver) {
          await Future.delayed(const Duration(milliseconds: 80));
        }

        final now = DateTime.now();
        final diffMs = now.difference(lastUpdate).inMilliseconds;
        if (diffMs >= 800) {
          final dbItem = await db.getDownloadById(id);
          if (dbItem == null) {
            debugPrint('[DownloadService] Stream loop: cancel/delete detected in DB for $id');
            _paused[id] = true;
            break;
          } else if (dbItem.status == DownloadStatus.paused) {
            debugPrint('[DownloadService] Stream loop: pause detected in DB for $id');
            _paused[id] = true;
            break;
          }

          if (!await _canDownload()) {
            debugPrint('[DownloadService] Dynamic network check failed. Pausing.');
            _paused[id] = true;
            break;
          }

          final currentOverallDownloaded = overallProgressStart + downloadedInStream;
          final double progress = overallTotalBytes > 0
              ? currentOverallDownloaded / overallTotalBytes
              : (streamFullSize > 0 ? downloadedInStream / streamFullSize : 0.0);

          final speed = ((downloadedInStream - lastBytes) / (diffMs / 1000)) / (1024 * 1024);

          final eta = speed > 0
              ? (((overallTotalBytes > 0 ? overallTotalBytes : streamFullSize) - currentOverallDownloaded) / (speed * 1024 * 1024)).toInt()
              : 0;

          lastUpdate = now;
          lastBytes = downloadedInStream;

          item.progress = progress;
          item.speedMbps = speed;
          item.etaSeconds = eta;
          item.status = DownloadStatus.downloading;
          await db.updateDownload(item.toCompanion());
          pingUi();

          await NotificationService().showProgressNotification(
            id: notifId,
            title: item.title,
            body: '${item.progressLabel} • ${item.resolution} ${item.format.toUpperCase()} • ${item.speedLabel} • ETA ${item.etaLabel}',
            progress: (progress * 100).toInt(),
            maxProgress: 100,
            actions: [
              const AndroidNotificationAction('pause', 'Pause', showsUserInterface: false),
              const AndroidNotificationAction('cancel', 'Cancel', showsUserInterface: false),
            ],
            payload: id,
          );
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return downloadedInStream;
  }

  DownloadItem _makeQueuedItem(String id, String url, String resolution) {
    return DownloadItem(
      id: id,
      title: 'Queued in line...',
      url: url,
      platform: _detectPlatform(url),
      status: DownloadStatus.queued,
      progress: 0,
      speedMbps: 0,
      etaSeconds: 0,
      format: '...',
      resolution: resolution,
      fileSizeMb: 0,
      addedAt: DateTime.now(),
    );
  }

  Future<void> _updateItemStatus(String id, DownloadStatus status) async {
    final existing = await db.getDownloadById(id);
    if (existing != null) {
      final model = existing.toModel();
      model.status = status;
      await db.updateDownload(model.toCompanion());
      pingUi();
    }
  }

  Future<void> _startDownload({
    required String id,
    required String url,
    String? preferredRes,
    bool? audioOnly,
    DownloadItem? existingItem,
    String? directUrl,
    String? title,
    required String? thumbnailUrl,
    }) async {
    if (_activeTasks.contains(id)) {
      debugPrint('[DownloadService] Task $id is already running. Skipping.');
      return;
    }
    _activeTasks.add(id);

    final notifId = id.hashCode & 0x7fffffff;

    final cleanUrl = _extractUrl(url);
    final platform = _detectPlatform(cleanUrl);

    // Load saved settings
    final prefs = await SharedPreferences.getInstance();
    final settingsRes = prefs.getString('defaultRes') ?? '720p';
    final settingsAudio = prefs.getBool('audioOnly') ?? false;
    final batterySaver = prefs.getBool('batterySaver') ?? false;
    final useAudioOnly = audioOnly ?? settingsAudio;
    final useRes = preferredRes ?? settingsRes;

    debugPrint(
        '[DownloadService] Starting: $cleanUrl res=$useRes audio=$useAudioOnly');

    // Insert preparing placeholder
    if (existingItem == null) {
      final placeholder = DownloadItem(
        id: id,
        title: title ?? 'Preparing download...',
        url: cleanUrl,
        platform: platform,
        status: DownloadStatus.preparing,
        progress: 0,
        speedMbps: 0,
        etaSeconds: 0,
        format: useAudioOnly ? 'mp3' : 'mp4',
        resolution: useRes,
        fileSizeMb: 0,
        addedAt: DateTime.now(),
        thumbnailUrl: thumbnailUrl,
      );
      await db.insertDownload(placeholder.toCompanion());
      pingUi();
    }

    try {
      String streamUrl = '';
      String? audioStreamUrl;
      String resolvedFormat = '';
      String resolvedResolution = '';
      String videoTitle = '';
      String? thumb;
      double sizeMb = 0;
      bool isDash = false;
      int videoStreamSize = 0;
      int audioStreamSize = 0;

      if (platform == MediaPlatform.youtube && directUrl == null) {
        // ── 1. Fetch metadata ──
        final video = await yt.videos.get(cleanUrl);
        final manifest = await yt.videos.streamsClient.getManifest(video.id);
        videoTitle = video.title;
        thumb = video.thumbnails.mediumResUrl;

        // Check for duplicate title
        if (await _checkDuplicateTitle(id, videoTitle, cleanUrl, notifId)) return;

        // ── 2. Pick stream ──
        if (useAudioOnly) {
          final audioStream = manifest.audioOnly.withHighestBitrate();
          streamUrl = audioStream.url.toString();
          resolvedFormat = audioStream.container.name;
          resolvedResolution = 'Audio';
          sizeMb = audioStream.size.totalMegaBytes;
        } else {
          final resNum =
              int.tryParse(useRes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1080;
          
          final videoStreams = manifest.videoOnly.toList();
          videoStreams.sort((a, b) =>
              b.videoResolution.height.compareTo(a.videoResolution.height));
          
          VideoOnlyStreamInfo? bestVideoOnly;
          for (final s in videoStreams) {
            if (s.videoResolution.height <= resNum) {
              bestVideoOnly = s;
              break;
            }
          }
          bestVideoOnly ??= videoStreams.isNotEmpty ? videoStreams.first : null;
          
          final audioStream = manifest.audioOnly.withHighestBitrate();
          
          if (bestVideoOnly != null && bestVideoOnly.videoResolution.height > 360) {
            isDash = true;
            streamUrl = bestVideoOnly.url.toString();
            audioStreamUrl = audioStream.url.toString();
            resolvedFormat = 'mp4';
            resolvedResolution = '${bestVideoOnly.videoResolution.height}p';
            videoStreamSize = bestVideoOnly.size.totalBytes;
            audioStreamSize = audioStream.size.totalBytes;
            sizeMb = (videoStreamSize + audioStreamSize) / (1024 * 1024);
          } else {
            final muxed = manifest.muxed.toList();
            MuxedStreamInfo? bestMuxed;
            muxed.sort((a, b) =>
                b.videoResolution.height.compareTo(a.videoResolution.height));
            for (final s in muxed) {
              if (s.videoResolution.height <= resNum) {
                bestMuxed = s;
                break;
              }
            }
            bestMuxed ??= muxed.isNotEmpty
                ? muxed.first
                : manifest.muxed.withHighestBitrate();
            streamUrl = bestMuxed.url.toString();
            resolvedFormat = bestMuxed.container.name;
            resolvedResolution = '${bestMuxed.videoResolution.height}p';
            sizeMb = bestMuxed.size.totalMegaBytes;
          }
        }
      } else {
        // Social media or direct URL
        if (directUrl != null) {
          streamUrl = directUrl;
          videoTitle = title ?? '${platform.name.toUpperCase()} Video';
          thumb = thumbnailUrl;
          resolvedFormat = 'mp4';
          resolvedResolution = useRes;

          // Check for duplicate title
          if (await _checkDuplicateTitle(id, videoTitle, cleanUrl, notifId)) return;
        } else {
          final social = SocialDownloadService();
          final info = await social.fetchInfo(cleanUrl);
          videoTitle = info.title;
          thumb = info.thumbnailUrl;

          // Check for duplicate title
          if (await _checkDuplicateTitle(id, videoTitle, cleanUrl, notifId)) return;

          // Parse requested target height (0 = no numeric preference = use highest)
          final targetHeight = useRes == 'Always Ask'
              ? 0
              : (int.tryParse(useRes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0);

          // Sort variants: highest quality first
          final sortedVariants = List<VideoVariant>.from(info.variants);
          sortedVariants.sort((a, b) {
            final aH = _parseQualityHeight(a.quality);
            final bH = _parseQualityHeight(b.quality);
            return bH.compareTo(aH); // descending
          });

          VideoVariant? bestVariant;

          if (targetHeight <= 0) {
            // No preference — pick the highest quality available
            bestVariant = sortedVariants.first;
          } else {
            // Pick the closest variant that is ≤ targetHeight
            int closestDiff = 10000;
            for (final v in sortedVariants) {
              final vHeight = _parseQualityHeight(v.quality);
              final diff = (vHeight - targetHeight).abs();
              if (vHeight <= targetHeight && diff < closestDiff) {
                bestVariant = v;
                closestDiff = diff;
              }
            }
            // If no variant ≤ target, fall back to the highest available
            bestVariant ??= sortedVariants.first;
          }

          final variant = bestVariant;
          streamUrl = variant.url;
          resolvedFormat = variant.format;
          resolvedResolution = variant.quality;
        }
      }

      String savePath;
      if (existingItem != null &&
          existingItem.filePath != null &&
          existingItem.filePath!.isNotEmpty) {
        savePath = existingItem.filePath!;
        final dir = Directory(p.dirname(savePath));
        if (!await dir.exists()) await dir.create(recursive: true);
      } else {
        final safeTitle = videoTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final nowTime = DateTime.now();
        final timestamp =
            '${nowTime.year}${nowTime.month.toString().padLeft(2, '0')}${nowTime.day.toString().padLeft(2, '0')}_'
            '${nowTime.hour.toString().padLeft(2, '0')}${nowTime.minute.toString().padLeft(2, '0')}${nowTime.second.toString().padLeft(2, '0')}';

        String fileName = '${timestamp}_$safeTitle.$resolvedFormat';
        final dir = Directory('/storage/emulated/0/Download/Downloda');
        if (!await dir.exists()) await dir.create(recursive: true);

        savePath = p.join(dir.path, fileName);

        int counter = 1;
        while (await File(savePath).exists()) {
          fileName = '${timestamp}_${safeTitle}_($counter).$resolvedFormat';
          savePath = p.join(dir.path, fileName);
          counter++;
        }
      }

      final item = (existingItem ??
              DownloadItem(
                id: id,
                title: videoTitle,
                url: cleanUrl,
                platform: platform,
                status: DownloadStatus.downloading,
                progress: 0,
                speedMbps: 0,
                etaSeconds: 0,
                format: useAudioOnly ? 'mp3' : resolvedFormat,
                resolution: useAudioOnly ? 'Audio' : resolvedResolution,
                fileSizeMb: sizeMb,
                addedAt: DateTime.now(),
              ))
          .copyWith(
        title: videoTitle,
        status: DownloadStatus.downloading,
        format: useAudioOnly ? 'mp3' : resolvedFormat,
        resolution: useAudioOnly ? 'Audio' : resolvedResolution,
        fileSizeMb: sizeMb > 0 ? sizeMb : existingItem?.fileSizeMb ?? 0,
        filePath: savePath,
        thumbnailUrl: thumb,
      );

      await db.updateDownload(item.toCompanion());
      pingUi();

      final cancelToken = CancelToken();
      _tokens[id] = cancelToken;

      int downloadedBytes = 0;
      int fullSize = 0;

      if (isDash) {
        final videoTempPath = '$savePath.temp_v';
        final audioTempPath = '$savePath.temp_a';

        final videoFile = File(videoTempPath);
        final audioFile = File(audioTempPath);

        int videoDownloaded = 0;
        int audioDownloaded = 0;

        if (await videoFile.exists()) {
          videoDownloaded = await videoFile.length();
        }

        if (await audioFile.exists()) {
          audioDownloaded = await audioFile.length();
        }

        fullSize = videoStreamSize + audioStreamSize;

        // 1. Download video
        if (videoDownloaded < videoStreamSize) {
          videoDownloaded = await _downloadStreamChunked(
            id: id,
            url: streamUrl,
            tempPath: videoTempPath,
            startByte: videoDownloaded,
            totalStreamBytes: videoStreamSize,
            overallProgressStart: 0,
            overallTotalBytes: fullSize,
            cancelToken: cancelToken,
            item: item,
            notifId: notifId,
            batterySaver: batterySaver,
          );
        }

        // 2. Download audio
        if (_paused[id] != true && videoDownloaded >= videoStreamSize && audioDownloaded < audioStreamSize) {
          audioDownloaded = await _downloadStreamChunked(
            id: id,
            url: audioStreamUrl!,
            tempPath: audioTempPath,
            startByte: audioDownloaded,
            totalStreamBytes: audioStreamSize,
            overallProgressStart: videoStreamSize,
            overallTotalBytes: fullSize,
            cancelToken: cancelToken,
            item: item,
            notifId: notifId,
            batterySaver: batterySaver,
          );
        }

        downloadedBytes = videoDownloaded + audioDownloaded;
      } else {
        final tempPath = '$savePath.temp';
        final tempFile = File(tempPath);
        final file = File(savePath);
        int startByte = 0;
        if (await tempFile.exists()) {
          startByte = await tempFile.length();
          debugPrint('[DownloadService] Resuming temp file from byte $startByte');
        } else if (await file.exists()) {
          startByte = await file.length();
          debugPrint('[DownloadService] Resuming existing file from byte $startByte');
          await file.rename(tempPath);
        }

        downloadedBytes = await _downloadStreamChunked(
          id: id,
          url: streamUrl,
          tempPath: tempPath,
          startByte: startByte,
          totalStreamBytes: 0,
          overallProgressStart: 0,
          overallTotalBytes: 0,
          cancelToken: cancelToken,
          item: item,
          notifId: notifId,
          batterySaver: batterySaver,
        );

        if (await tempFile.exists()) {
          fullSize = await tempFile.length();
        } else if (await file.exists()) {
          fullSize = await file.length();
        }
      }

      // ── 5. Evaluate outcome ──
      if (_paused[id] == true) {
        _paused.remove(id);
        final itemRecord = await db.getDownloadById(id);
        if (itemRecord != null) {
          item.status = DownloadStatus.paused;
          item.progress = fullSize > 0 ? downloadedBytes / fullSize : 0;
          item.speedMbps = 0;
          item.etaSeconds = 0;
          await db.updateDownload(item.toCompanion());
          pingUi();

          await NotificationService().showProgressNotification(
            id: notifId,
            title: item.title,
            body: 'Paused • ${item.progressLabel}',
            progress: (item.progress * 100).toInt(),
            maxProgress: 100,
            ongoing: false,
            actions: [
              const AndroidNotificationAction('resume', 'Resume',
                  showsUserInterface: false),
              const AndroidNotificationAction('cancel', 'Cancel',
                  showsUserInterface: false),
            ],
            payload: id,
          );
          debugPrint('[DownloadService] Paused: $id');
        } else {
          // Deleted from DB (cancelled) — delete files
          debugPrint('[DownloadService] Cancelled and deleted from DB: $id');
          final videoTempFile = File('$savePath.temp_v');
          if (await videoTempFile.exists()) await videoTempFile.delete();
          final audioTempFile = File('$savePath.temp_a');
          if (await audioTempFile.exists()) await audioTempFile.delete();
          final file = File(savePath);
          if (await file.exists()) await file.delete();
          final tempFile = File('$savePath.temp');
          if (await tempFile.exists()) await tempFile.delete();
          await NotificationService().cancel(notifId);
        }
      } else {
        // Completed
        if (isDash) {
          debugPrint('[DownloadService] Starting DASH stream merge for $id...');
          item.status = DownloadStatus.processing;
          item.progress = 1.0;
          await db.updateDownload(item.toCompanion());
          pingUi();

          await NotificationService().showProgressNotification(
            id: notifId,
            title: 'Merging video & audio...',
            body: item.title,
            progress: 0,
            maxProgress: 100,
            showProgress: true,
            ongoing: true,
            payload: id,
          );

          final videoTempPath = '$savePath.temp_v';
          final audioTempPath = '$savePath.temp_a';

          final session = await FFmpegKit.execute(
            '-y -i "$videoTempPath" -i "$audioTempPath" -c:v copy -c:a aac "$savePath"',
          );

          final rc = await session.getReturnCode();

          if (ReturnCode.isSuccess(rc)) {
            try {
              final fv = File(videoTempPath);
              if (await fv.exists()) await fv.delete();
              final fa = File(audioTempPath);
              if (await fa.exists()) await fa.delete();
            } catch (e) {
              debugPrint('[DownloadService] Failed to delete DASH temp files: $e');
            }

            final outputFile = File(savePath);
            final double actualSizeMb = (await outputFile.length()) / (1024 * 1024);

            item.status = DownloadStatus.completed;
            item.progress = 1.0;
            item.filePath = savePath;
            item.fileSizeMb = actualSizeMb;
            await db.updateDownload(item.toCompanion());
            pingUi();

            try {
              const methodChannel =
                  MethodChannel('com.downloda.app/media_scanner');
              await methodChannel.invokeMethod('scanFile', {'path': savePath});
            } catch (e) {
              debugPrint('[DownloadService] Media scan error: $e');
            }

            await NotificationService().showCompletionNotification(
              id: notifId,
              title: 'Download Complete',
              body: '${item.title} • ${item.resolution} MP4 • ${actualSizeMb.toStringAsFixed(1)} MB',
              payload: id,
            );
          } else {
            final logs = await session.getLogsAsString();
            debugPrint('[DownloadService] FFmpeg DASH merge failure logs: $logs');
            throw Exception('Merging video and audio failed');
          }
        } else if (useAudioOnly) {
          debugPrint('[DownloadService] Starting audio extraction for $id...');
          item.status = DownloadStatus.processing;
          item.progress = 1.0;
          await db.updateDownload(item.toCompanion());
          pingUi();

          await NotificationService().showProgressNotification(
            id: notifId,
            title: 'Extracting Audio...',
            body: item.title,
            progress: 0,
            maxProgress: 100,
            showProgress: true,
            ongoing: true,
            payload: id,
          );

          final dir = Directory(p.dirname(savePath));
          final baseName = p.basenameWithoutExtension(savePath);
          final audioOutputPath = p.join(dir.path, '$baseName.mp3');
          final tempPath = '$savePath.temp';

          final session = await FFmpegKit.execute(
            '-y -i "$tempPath" -vn -acodec libmp3lame -q:a 2 "$audioOutputPath"',
          );

          final rc = await session.getReturnCode();

          if (ReturnCode.isSuccess(rc)) {
            try {
              final rawFile = File(tempPath);
              if (await rawFile.exists()) {
                await rawFile.delete();
              }
            } catch (e) {
              debugPrint('[DownloadService] Failed to delete raw temp video: $e');
            }

            final outputFile = File(audioOutputPath);
            final double sizeMb = (await outputFile.length()) / (1024 * 1024);

            item.status = DownloadStatus.completed;
            item.format = 'mp3';
            item.resolution = 'Audio';
            item.filePath = audioOutputPath;
            item.fileSizeMb = sizeMb;
            await db.updateDownload(item.toCompanion());
            pingUi();

            try {
              const methodChannel =
                  MethodChannel('com.downloda.app/media_scanner');
              await methodChannel.invokeMethod('scanFile', {'path': audioOutputPath});
            } catch (e) {
              debugPrint('[DownloadService] Media scan error: $e');
            }

            await NotificationService().showCompletionNotification(
              id: notifId,
              title: 'Download Complete',
              body:
                  '${item.title} • Audio MP3 • ${sizeMb.toStringAsFixed(1)} MB',
              payload: id,
            );
          } else {
            final logs = await session.getLogsAsString();
            debugPrint('[DownloadService] FFmpeg failure logs: $logs');
            throw Exception('Audio extraction failed');
          }
        } else {
          final tempPath = '$savePath.temp';
          final tempFile = File(tempPath);
          if (await tempFile.exists()) {
            await tempFile.rename(savePath);
          }
          final file = File(savePath);
          if (await file.exists()) {
            item.fileSizeMb = (await file.length()) / (1024 * 1024);
          }
          item.status = DownloadStatus.completed;
          item.progress = 1.0;
          await db.updateDownload(item.toCompanion());
          pingUi();

          try {
            const methodChannel =
                MethodChannel('com.downloda.app/media_scanner');
            await methodChannel.invokeMethod('scanFile', {'path': savePath});
          } catch (e) {
            debugPrint('[DownloadService] Media scan error: $e');
          }

          await NotificationService().showCompletionNotification(
            id: notifId,
            title: 'Download Complete',
            body: '${item.title} • ${item.resolution} ${item.format.toUpperCase()} • ${item.fileSizeLabel}',
            payload: id,
          );
        }

        if (await _isVibrationEnabled()) {
          try {
            await HapticFeedback.heavyImpact();
          } catch (e) {
            debugPrint('[DownloadService] Direct background haptic error: $e');
          }
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (_paused[id] == true) {
          _paused.remove(id);
          // Update status and notification for pause
          final record = await db.getDownloadById(id);
          if (record != null) {
            final model = record.toModel();
            model.status = DownloadStatus.paused;
            model.speedMbps = 0;
            model.etaSeconds = 0;
            await db.updateDownload(model.toCompanion());
            pingUi();

            await NotificationService().showProgressNotification(
              id: notifId,
              title: model.title,
              body: 'Paused • ${model.progressLabel}',
              progress: (model.progress * 100).toInt(),
              maxProgress: 100,
              ongoing: false,
              actions: [
                const AndroidNotificationAction('resume', 'Resume',
                    showsUserInterface: false),
                const AndroidNotificationAction('cancel', 'Cancel',
                    showsUserInterface: false),
              ],
              payload: id,
            );
          }
        } else {
          final record = await db.getDownloadById(id);
          if (record != null) {
            final file = File(record.filePath ?? '');
            if (await file.exists()) {
              try {
                await file.delete();
              } catch (e) {
                debugPrint('[DownloadService] Failed to delete cancelled file: $e');
              }
            }
            final tempFile = File('${record.filePath}.temp');
            if (await tempFile.exists()) {
              try {
                await tempFile.delete();
              } catch (e) {
                debugPrint('[DownloadService] Failed to delete cancelled temp file: $e');
              }
            }
            final videoTempFile = File('${record.filePath}.temp_v');
            if (await videoTempFile.exists()) {
              try {
                await videoTempFile.delete();
              } catch (e) {
                debugPrint('[DownloadService] Failed to delete cancelled video temp: $e');
              }
            }
            final audioTempFile = File('${record.filePath}.temp_a');
            if (await audioTempFile.exists()) {
              try {
                await audioTempFile.delete();
              } catch (e) {
                debugPrint('[DownloadService] Failed to delete cancelled audio temp: $e');
              }
            }
          }
          await db.deleteDownload(id);
          await NotificationService().cancel(notifId);
        }
      } else {
        await _markFailed(id, notifId, e);
      }
    } catch (e) {
      await _markFailed(id, notifId, e);
    } finally {
      _activeTasks.remove(id);
      _tokens.remove(id);
      checkQueue();
    }
  }

  Future<void> _markFailed(String id, int notifId, dynamic error) async {
    final record = await db.getDownloadById(id);
    String userMessage = 'Unexpected error occurred.';

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 500) {
        userMessage = 'Server error (500). Try again later.';
      } else if (statusCode == 403) {
        userMessage = 'Access denied (403). The link might be expired.';
      } else if (statusCode == 404) {
        userMessage = 'Video not found (404).';
      } else if (statusCode == 416) {
        // Range Not Satisfiable - usually means file is already complete or corrupt
        debugPrint('[DownloadService] 416 Error: File might be complete or size mismatch.');
        if (record != null) {
          final model = record.toModel();
          if (model.progress < 0.9) {
            // If it wasn't near finished, it's probably corrupt/mismatched size
            userMessage = 'Resume failed. Retrying from start...';
            // We could auto-retry here by deleting file and calling resume, 
            // but let's just let user retry for now to be safe.
          } else {
            // Probably finished but Range header was off
            model.status = DownloadStatus.completed;
            model.progress = 1.0;
            await db.updateDownload(model.toCompanion());
            pingUi();
            await NotificationService().showCompletionNotification(
              id: notifId,
              title: 'Download Complete',
              body: model.title,
            );
            return;
          }
        }
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        userMessage = 'Connection timed out. Check your network.';
      } else if (error.error is SocketException) {
        userMessage = 'Network error. Please check your connection.';
      } else {
        // Fallback for other Dio errors: keep it short
        userMessage = 'Download failed. (${statusCode ?? 'Error'})';
      }
    } else {
      final errStr = error.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('host lookup')) {
        userMessage = 'Network error. Please check your connection.';
      } else if (errStr.contains('403')) {
        userMessage = 'Access denied. Link expired.';
      } else if (errStr.contains('no space')) {
        userMessage = 'Storage full. Free up space.';
      } else {
        // For generic exceptions, just show the first few words
        final msg = error.toString().split('\n').first;
        userMessage = msg.length > 60 ? '${msg.substring(0, 57)}...' : msg;
      }
    }

    debugPrint('[DownloadService] Failed ($id): $userMessage');

    if (record != null) {
      final model = record.toModel();
      model.status = DownloadStatus.failed;
      await db.updateDownload(model.toCompanion());
      pingUi();
    }

    await NotificationService().showProgressNotification(
      id: notifId,
      title: 'Download Failed',
      body: userMessage,
      progress: 0,
      maxProgress: 100,
      showProgress: false,
      ongoing: false,
      actions: [
        const AndroidNotificationAction('resume', 'Retry',
            showsUserInterface: false),
        const AndroidNotificationAction('cancel', 'Dismiss',
            showsUserInterface: false),
      ],
      payload: id,
    );
  }

  MediaPlatform _detectPlatform(String url) {
    if (url.contains('youtube') || url.contains('youtu.be')) {
      return MediaPlatform.youtube;
    }
    if (url.contains('instagram')) return MediaPlatform.instagram;
    if (url.contains('tiktok')) return MediaPlatform.tiktok;
    if (url.contains('facebook') || url.contains('fb.watch')) {
      return MediaPlatform.facebook;
    }
    if (url.contains('x.com') || url.contains('twitter.com')) {
      return MediaPlatform.x;
    }
    return MediaPlatform.youtube;
  }

  int _parseQualityHeight(String quality) {
    final clean = quality.toLowerCase();
    if (clean.contains('hd') || clean.contains('high quality')) return 1080;
    final num = int.tryParse(clean.replaceAll(RegExp(r'[^0-9]'), ''));
    if (num != null && num > 0) return num;
    if (clean.contains('without watermark') || clean.contains('no watermark') || clean.contains('watermark')) {
      if (clean.contains('2') || clean.contains('backup')) return 480;
      return 720;
    }
    return 360;
  }

  Future<void> resetActiveDownloadsToPaused() async {
    try {
      final active = await db.getActiveDownloads();
      for (final item in active) {
        if (item.status == DownloadStatus.preparing ||
            item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.processing) {
          final companion = item.toCompanion(false).copyWith(
            status: const Value(DownloadStatus.paused),
            speedMbps: const Value(0.0),
            etaSeconds: const Value(0),
          );
          await db.updateDownload(companion);
        }
      }
      pingUi();
    } catch (e, st) {
      debugPrint('[DownloadService] Error resetting active downloads: $e\n$st');
    }
  }

  Future<String?> _generateLocalThumbnail(String id, String videoPath) async {
    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory(p.join(appDocsDir.path, '.thumbnails'));
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }
      final thumbPath = p.join(thumbDir.path, '$id.jpg');

      // Try native MediaMetadataRetriever first (extremely fast and reliable on Android)
      try {
        const methodChannel = MethodChannel('com.downloda.app/media_scanner');
        final bytes = await methodChannel.invokeMethod<Uint8List>(
          'getVideoThumbnail',
          {'path': videoPath},
        );
        if (bytes != null && bytes.isNotEmpty) {
          final file = File(thumbPath);
          await file.writeAsBytes(bytes);
          return thumbPath;
        }
      } catch (e) {
        debugPrint('[DownloadService] Failed to generate offline thumbnail via native channel: $e');
      }

      // Fallback to FFmpeg Kit execution
      final session = await FFmpegKit.execute(
        '-y -ss 00:00:01 -i "$videoPath" -vframes 1 "$thumbPath"',
      );
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        return thumbPath;
      }
    } catch (e) {
      debugPrint('[DownloadService] Failed to generate offline thumbnail via FFmpeg: $e');
    }
    return null;
  }

  Future<void> syncLocalDownloads() async {
    try {
      final dir = Directory('/storage/emulated/0/Download/Downloda');
      if (!await dir.exists()) return;

      final files = await dir.list().toList();
      final allItems = await db.getHistory();
      final existingPaths = allItems.map((e) => e.filePath).whereType<String>().toSet();

      for (final entity in files) {
        if (entity is File) {
          final filePath = entity.path;
          final ext = p.extension(filePath).toLowerCase();
          if (ext != '.mp4' && ext != '.mp3') continue;

          // If already in the DB, skip it
          if (existingPaths.contains(filePath)) continue;

          // Extract title
          String fileName = p.basenameWithoutExtension(filePath);
          final regExp = RegExp(r'^\d{8}_\d{6}_(.*)$');
          final match = regExp.firstMatch(fileName);
          String title = fileName;
          if (match != null && match.groupCount >= 1) {
            title = match.group(1)!.replaceAll('_', ' ');
          } else {
            title = title.replaceAll('_', ' ');
          }

          // Guess platform
          MediaPlatform platform = _detectPlatform(filePath);

          // Determine format and resolution
          final format = ext.substring(1);
          final resolution = format == 'mp3' ? 'Audio' : 'Best Quality';
          final fileSizeMb = await entity.length() / (1024.0 * 1024.0);

          final itemId = const Uuid().v4();
          String? thumbUrl;
          if (format == 'mp4') {
            thumbUrl = await _generateLocalThumbnail(itemId, filePath);
          }

          final item = DownloadItem(
            id: itemId,
            title: title,
            url: '',
            platform: platform,
            status: DownloadStatus.completed,
            progress: 1.0,
            speedMbps: 0.0,
            etaSeconds: 0,
            thumbnailUrl: thumbUrl,
            format: format,
            resolution: resolution,
            filePath: filePath,
            fileSizeMb: fileSizeMb,
            addedAt: (await entity.stat()).changed,
          );

          await db.insertDownload(item.toCompanion());
        }
      }
      pingUi();
    } catch (e, st) {
      debugPrint('[DownloadService] Error syncing local downloads: $e\n$st');
    }
  }

  Future<String?> _findExistingFileOnDisk(String videoTitle) async {
    try {
      final dir = Directory('/storage/emulated/0/Download/Downloda');
      if (!await dir.exists()) return null;
      
      final safeTitle = videoTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final targetPattern = '_$safeTitle.';
      final targetPatternLower = targetPattern.toLowerCase();
      
      final files = await dir.list().toList();
      for (final entity in files) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.toLowerCase().contains(targetPatternLower)) {
            return entity.path;
          }
        }
      }
    } catch (e) {
      debugPrint('[DownloadService] Error checking disk files: $e');
    }
    return null;
  }

  Future<bool> _checkDuplicateTitle(String id, String videoTitle, String cleanUrl, int notifId) async {
    if (videoTitle.isEmpty) return false;
    
    // 1. Check database first
    final duplicate = await db.getDownloadByTitle(videoTitle);
    if (duplicate != null && duplicate.id != id) {
      if (duplicate.status == DownloadStatus.completed) {
        if (duplicate.filePath != null && await File(duplicate.filePath!).exists()) {
          debugPrint('[DownloadService] Duplicate download skipped: matching title "$videoTitle". URL: $cleanUrl');
          // Clean up the current download
          await db.deleteDownload(id);
          await NotificationService().showCompletionNotification(
            id: videoTitle.hashCode & 0x7fffffff,
            title: 'Already Downloaded',
            body: 'Video "$videoTitle" has already been downloaded.',
            payload: duplicate.id,
          );
          return true;
        } else {
          // File was deleted from disk. Remove duplicate db entry to allow redownload.
          debugPrint('[DownloadService] Duplicate completed file deleted from disk. Deleting record for title "$videoTitle".');
          await db.deleteDownload(duplicate.id);
        }
      } else if (duplicate.status == DownloadStatus.failed) {
        // Old failed record. Delete it.
        debugPrint('[DownloadService] Deleting old failed duplicate record for title "$videoTitle".');
        await db.deleteDownload(duplicate.id);
      } else {
        // Active/paused/queued/preparing
        debugPrint('[DownloadService] Duplicate download skipped: active download matching title "$videoTitle". URL: $cleanUrl');
        await db.deleteDownload(id);
        await NotificationService().showCompletionNotification(
          id: videoTitle.hashCode & 0x7fffffff,
          title: 'Download Already Active',
          body: 'A download for "$videoTitle" is already active.',
          payload: duplicate.id,
        );
        return true;
      }
    }

    // 2. Check disk directory directly (Mitigation for reinstall/database wipe)
    final existingFilePath = await _findExistingFileOnDisk(videoTitle);
    if (existingFilePath != null) {
      debugPrint('[DownloadService] Duplicate download skipped (Disk file exists): "$existingFilePath". URL: $cleanUrl');
      // Clean up the current download
      await db.deleteDownload(id);
      await NotificationService().showCompletionNotification(
        id: videoTitle.hashCode & 0x7fffffff,
        title: 'Already Downloaded',
        body: 'Video "$videoTitle" is already present on disk.',
      );
      return true;
    }

    return false;
  }
}

extension _DownloadItemCopyWith on DownloadItem {
  DownloadItem copyWith({
    String? title,
    DownloadStatus? status,
    double? progress,
    String? format,
    String? resolution,
    double? fileSizeMb,
    String? filePath,
    String? thumbnailUrl,
  }) {
    return DownloadItem(
      id: id,
      title: title ?? this.title,
      url: url,
      platform: platform,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedMbps: speedMbps,
      etaSeconds: etaSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
      filePath: filePath ?? this.filePath,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      addedAt: addedAt,
    );
  }
}
