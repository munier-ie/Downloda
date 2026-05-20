import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    return prefs.getBool('vibration') ?? false;
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
      final maxSim = await _getMaxSimultaneous();
      final activeCount = await getActiveCount();
      debugPrint('[QueueManager] Checking queue: active=$activeCount, max=$maxSim');

      if (activeCount >= maxSim) {
        debugPrint('[QueueManager] Max simultaneous downloads reached.');
        return;
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
        return;
      }

      final next = queuedItems.first;
      debugPrint('[QueueManager] Starting queued: ${next.title} (${next.id})');

      // Update status immediately so concurrent check loops recognize this occupied slot
      final companion = next.toCompanion(false).copyWith(
            status: const Value(DownloadStatus.preparing),
          );
      await db.updateDownload(companion);

      _startDownload(
        id: next.id,
        url: next.url,
        existingItem: next.toModel(),
        thumbnailUrl: next.thumbnailUrl,
      );
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
        final defaultRes = prefs.getString('defaultRes') ?? '1080p';
        final useRes = defaultRes == 'Always Ask' ? '1080p' : defaultRes;
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
    final settingsRes = prefs.getString('defaultRes') ?? '1080p';
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
    return re.firstMatch(raw)?.group(0) ?? raw;
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
    final settingsRes = prefs.getString('defaultRes') ?? '1080p';
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
      String streamUrl;
      String resolvedFormat;
      String resolvedResolution;
      String videoTitle;
      String? thumb;
      double sizeMb = 0;

      if (platform == MediaPlatform.youtube && directUrl == null) {
        // ── 1. Fetch metadata ──
        final video = await yt.videos.get(cleanUrl);
        final manifest = await yt.videos.streamsClient.getManifest(video.id);
        videoTitle = video.title;
        thumb = video.thumbnails.mediumResUrl;

        // ── 2. Pick stream ──
        StreamInfo streamInfo;
        if (useAudioOnly) {
          final audioStream = manifest.audioOnly.withHighestBitrate();
          streamInfo = audioStream;
          resolvedFormat = audioStream.container.name;
          resolvedResolution = 'Audio';
        } else {
          final muxed = manifest.muxed.toList();
          MuxedStreamInfo? bestStream;
          final resNum =
              int.tryParse(useRes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1080;
          muxed.sort((a, b) =>
              b.videoResolution.height.compareTo(a.videoResolution.height));
          for (final s in muxed) {
            if (s.videoResolution.height <= resNum) {
              bestStream = s;
              break;
            }
          }
          bestStream ??= muxed.isNotEmpty
              ? muxed.first
              : manifest.muxed.withHighestBitrate();
          streamInfo = bestStream;
          resolvedFormat = bestStream.container.name;
          resolvedResolution = '${bestStream.videoResolution.height}p';
        }
        streamUrl = streamInfo.url.toString();
        sizeMb = streamInfo.size.totalMegaBytes;
      } else {
        // Social media or direct URL
        if (directUrl != null) {
          streamUrl = directUrl;
          videoTitle = title ?? '${platform.name.toUpperCase()} Video';
          thumb = thumbnailUrl;
          resolvedFormat = 'mp4';
          resolvedResolution = useRes;
        } else {
          // We need to fetch from SocialDownloadService
          final social = SocialDownloadService();
          final info = await social.fetchInfo(cleanUrl);
          videoTitle = info.title;
          thumb = info.thumbnailUrl;
          
          // Robust fuzzy matching for resolution
          final targetHeight = int.tryParse(useRes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1080;
          
          VideoVariant? bestVariant;
          int closestDiff = 10000;
          
          for (final v in info.variants) {
            final vHeight = int.tryParse(v.quality.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (vHeight == 0) continue; // Skip variants with non-numeric quality labels if any
            
            final diff = (vHeight - targetHeight).abs();
            // Prioritize variants that don't exceed targetHeight, or are the closest
            if (vHeight <= targetHeight && diff < closestDiff) {
              bestVariant = v;
              closestDiff = diff;
            }
          }
          
          final variant = bestVariant ?? info.variants.first;
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
        // Ensure the directory exists (might have been deleted)
        final dir = Directory(p.dirname(savePath));
        if (!await dir.exists()) await dir.create(recursive: true);
      } else {
        final safeTitle = videoTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        // Prefix with timestamp for ordering (YYMMDD_HHMMSS)
        final nowTime = DateTime.now();
        final timestamp =
            '${nowTime.year}${nowTime.month.toString().padLeft(2, '0')}${nowTime.day.toString().padLeft(2, '0')}_'
            '${nowTime.hour.toString().padLeft(2, '0')}${nowTime.minute.toString().padLeft(2, '0')}${nowTime.second.toString().padLeft(2, '0')}';

        String fileName = '${timestamp}_$safeTitle.$resolvedFormat';
        final dir = Directory('/storage/emulated/0/Download/Downloda');
        if (!await dir.exists()) await dir.create(recursive: true);

        savePath = p.join(dir.path, fileName);

        // Handle potential collisions
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

      // ── 3. Check for partial file (resume) ──
      final file = File(savePath);
      int startByte = 0;
      if (await file.exists()) {
        startByte = await file.length();
        debugPrint('[DownloadService] Resuming from byte $startByte');
      }

      // ── 4. Download with Dio ──
      final cancelToken = CancelToken();
      _tokens[id] = cancelToken;

      final options = Options(
        responseType: ResponseType.stream,
        headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
      );

      final response = await dio.get<ResponseBody>(
        streamUrl,
        options: options,
        cancelToken: cancelToken,
      );

      // If we asked for a range but didn't get 206 (Partial Content),
      // it means the server doesn't support ranges or the file changed.
      // We should probably start over in that case.
      final isPartial = response.statusCode == 206;
      if (startByte > 0 && !isPartial) {
        debugPrint('[DownloadService] Server does not support resume. Starting over.');
        startByte = 0;
        // Re-open sink in write mode to truncate
      }

      final totalBytes =
          int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
      final fullSize = isPartial ? (totalBytes + startByte) : totalBytes;

      if (sizeMb == 0 && fullSize > 0) {
        item.fileSizeMb = fullSize / (1024 * 1024);
        await db.updateDownload(item.toCompanion());
      }

      final sink = file.openWrite(
          mode: (startByte > 0 && isPartial) ? FileMode.append : FileMode.write);
      int downloadedBytes = startByte;
      DateTime lastUpdate = DateTime.now();
      int lastBytes = startByte;

      try {
        await for (final chunk in response.data!.stream) {
          if (_paused[id] == true) {
            debugPrint('[DownloadService] Stream loop: pause detected for $id');
            break;
          }
          sink.add(chunk);
          downloadedBytes += chunk.length;

          // Battery saver: throttle chunk processing
          if (batterySaver) {
            await Future.delayed(const Duration(milliseconds: 80));
          }

          final now = DateTime.now();
          final diffMs = now.difference(lastUpdate).inMilliseconds;
          if (diffMs >= 800) {
            // Check network constraints dynamically during active download
            if (!await _canDownload()) {
              debugPrint(
                  '[DownloadService] Dynamic network check failed. Pausing.');
              _paused[id] = true;
              break;
            }

            final progress = fullSize > 0 ? downloadedBytes / fullSize : 0.0;
            final speed = ((downloadedBytes - lastBytes) / (diffMs / 1000)) /
                (1024 * 1024);
            final eta = speed > 0
                ? ((fullSize - downloadedBytes) / (speed * 1024 * 1024)).toInt()
                : 0;

            lastUpdate = now;
            lastBytes = downloadedBytes;

            item.progress = progress;
            item.speedMbps = speed;
            item.etaSeconds = eta;
            item.status = DownloadStatus.downloading;
            await db.updateDownload(item.toCompanion());
            pingUi();

            await NotificationService().showProgressNotification(
              id: notifId,
              title: item.title,
              body:
                  '${item.progressLabel} • ${item.resolution} ${item.format.toUpperCase()} • ${item.speedLabel} • ETA ${item.etaLabel}',
              progress: (progress * 100).toInt(),
              maxProgress: 100,
              actions: [
                const AndroidNotificationAction('pause', 'Pause',
                    showsUserInterface: false),
                const AndroidNotificationAction('cancel', 'Cancel',
                    showsUserInterface: false),
              ],
              payload: id,
            );
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      // ── 5. Evaluate outcome ──
      if (_paused[id] == true) {
        _paused.remove(id); // Clear flag after handling
        item.status = DownloadStatus.paused;
        item.progress = fullSize > 0 ? downloadedBytes / fullSize : 0;
        item.speedMbps = 0;
        item.etaSeconds = 0;
        await db.updateDownload(item.toCompanion());
        pingUi();

        // Show a "Paused" notification with a Resume button
        await NotificationService().showProgressNotification(
          id: notifId,
          title: item.title,
          body: 'Paused • ${item.progressLabel}',
          progress: (item.progress * 100).toInt(),
          maxProgress: 100,
          ongoing: false, // Not ongoing when paused
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
        // Completed
        if (useAudioOnly) {
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

          final session = await FFmpegKit.execute(
            '-y -i "$savePath" -vn -acodec libmp3lame -q:a 2 "$audioOutputPath"',
          );

          final rc = await session.getReturnCode();

          if (ReturnCode.isSuccess(rc)) {
            // Delete raw video file
            try {
              final rawFile = File(savePath);
              if (await rawFile.exists()) {
                await rawFile.delete();
              }
            } catch (e) {
              debugPrint('[DownloadService] Failed to delete raw video: $e');
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

            // Scan MP3 file
            try {
              const methodChannel =
                  MethodChannel('com.downloda.app/media_scanner');
              await methodChannel.invokeMethod('scanFile', {'path': audioOutputPath});
            } catch (e) {
              debugPrint('[DownloadService] Media scan error: $e');
            }

            // Show completion notification
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
          item.status = DownloadStatus.completed;
          item.progress = 1.0;
          await db.updateDownload(item.toCompanion());
          pingUi();

          // Scan media so it shows in gallery
          try {
            const methodChannel =
                MethodChannel('com.downloda.app/media_scanner');
            await methodChannel.invokeMethod('scanFile', {'path': savePath});
          } catch (e) {
            debugPrint('[DownloadService] Media scan error: $e');
          }

          // Show completion notification
          await NotificationService().showCompletionNotification(
            id: notifId,
            title: 'Download Complete',
            body:
                '${item.title} • $resolvedResolution ${resolvedFormat.toUpperCase()} • ${item.fileSizeMb.toStringAsFixed(1)} MB',
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
