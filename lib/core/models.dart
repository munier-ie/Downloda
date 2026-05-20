import 'package:drift/drift.dart' as drift;
import 'database/database.dart';

enum DownloadStatus {
  preparing,
  downloading,
  queued,
  paused,
  processing,
  completed,
  failed,
}

enum MediaPlatform { youtube, instagram, tiktok, facebook, x }

class DownloadItem {
  final String id;
  final String title;
  final String url;
  final MediaPlatform platform;
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  double speedMbps; // MB/s
  int etaSeconds;
  String? thumbnailUrl;
  String format;
  String resolution;
  String? filePath;
  double fileSizeMb;
  DateTime addedAt;

  DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.platform,
    required this.status,
    required this.progress,
    required this.speedMbps,
    required this.etaSeconds,
    this.thumbnailUrl,
    required this.format,
    required this.resolution,
    this.filePath,
    required this.fileSizeMb,
    required this.addedAt,
  });

  String get platformLabel {
    switch (platform) {
      case MediaPlatform.youtube:
        return 'YouTube';
      case MediaPlatform.instagram:
        return 'Instagram';
      case MediaPlatform.tiktok:
        return 'TikTok';
      case MediaPlatform.facebook:
        return 'Facebook';
      case MediaPlatform.x:
        return 'X (Twitter)';
    }
  }

  String get statusLabel {
    switch (status) {
      case DownloadStatus.preparing:
        return 'Preparing';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.processing:
        return 'Processing';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed';
    }
  }

  String get etaLabel {
    if (etaSeconds <= 0) return '--';
    if (etaSeconds < 60) return '${etaSeconds}s';
    final m = etaSeconds ~/ 60;
    final s = etaSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get speedLabel {
    if (speedMbps < 1.0) {
      return '${(speedMbps * 1024).toStringAsFixed(0)} KB/s';
    }
    return '${speedMbps.toStringAsFixed(1)} MB/s';
  }

  String get progressLabel => '${(progress * 100).toStringAsFixed(0)}%';

  String get fileSizeLabel =>
      '${(fileSizeMb * progress).toStringAsFixed(1)} / ${fileSizeMb.toStringAsFixed(1)} MB';
}

extension DownloadItemDataX on DownloadItemData {
  DownloadItem toModel() {
    return DownloadItem(
      id: id,
      title: title,
      url: url,
      platform: platform,
      status: status,
      progress: progress,
      speedMbps: speedMbps,
      etaSeconds: etaSeconds,
      thumbnailUrl: thumbnailUrl,
      format: format,
      resolution: resolution,
      filePath: filePath,
      fileSizeMb: fileSizeMb,
      addedAt: addedAt,
    );
  }
}

extension DownloadItemX on DownloadItem {
  DownloadItemsCompanion toCompanion() {
    return DownloadItemsCompanion(
      id: drift.Value(id),
      title: drift.Value(title),
      url: drift.Value(url),
      platform: drift.Value(platform),
      status: drift.Value(status),
      progress: drift.Value(progress),
      speedMbps: drift.Value(speedMbps),
      etaSeconds: drift.Value(etaSeconds),
      thumbnailUrl: drift.Value(thumbnailUrl),
      format: drift.Value(format),
      resolution: drift.Value(resolution),
      filePath: drift.Value(filePath),
      fileSizeMb: drift.Value(fileSizeMb),
      addedAt: drift.Value(addedAt),
    );
  }
}

// Mock data factory
class MockData {
  static final List<DownloadItem> _active = [
    DownloadItem(
      id: '1',
      title: 'How to Build Flutter Apps in 2025',
      url: 'https://youtu.be/abc123',
      platform: MediaPlatform.youtube,
      status: DownloadStatus.downloading,
      progress: 0.45,
      speedMbps: 3.2,
      etaSeconds: 18,
      format: 'mp4',
      resolution: '1080p',
      fileSizeMb: 142.4,
      addedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    DownloadItem(
      id: '2',
      title: 'Morning Routine Reel',
      url: 'https://instagram.com/reel/xyz',
      platform: MediaPlatform.instagram,
      status: DownloadStatus.downloading,
      progress: 0.72,
      speedMbps: 5.8,
      etaSeconds: 7,
      format: 'mp4',
      resolution: '720p',
      fileSizeMb: 28.6,
      addedAt: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
    DownloadItem(
      id: '3',
      title: 'Viral Dance Challenge #fyp',
      url: 'https://tiktok.com/@user/video/123',
      platform: MediaPlatform.tiktok,
      status: DownloadStatus.paused,
      progress: 0.31,
      speedMbps: 0,
      etaSeconds: 0,
      format: 'mp4',
      resolution: '1080p',
      fileSizeMb: 18.2,
      addedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    DownloadItem(
      id: '4',
      title: 'Architecture Deep Dive — Clean Code',
      url: 'https://youtu.be/def456',
      platform: MediaPlatform.youtube,
      status: DownloadStatus.queued,
      progress: 0.0,
      speedMbps: 0,
      etaSeconds: 0,
      format: 'mp4',
      resolution: '720p',
      fileSizeMb: 284.1,
      addedAt: DateTime.now().subtract(const Duration(seconds: 30)),
    ),
    DownloadItem(
      id: '5',
      title: 'Sunset Timelapse - Maldives',
      url: 'https://instagram.com/p/abc',
      platform: MediaPlatform.instagram,
      status: DownloadStatus.processing,
      progress: 1.0,
      speedMbps: 0,
      etaSeconds: 0,
      format: 'mp4',
      resolution: '4K',
      fileSizeMb: 312.8,
      addedAt: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
  ];

  static final List<DownloadItem> _history = [
    DownloadItem(
        id: '10',
        title: 'Lo-fi Chill Mix 2025 — 2 Hours',
        url: 'https://youtu.be/lofi',
        platform: MediaPlatform.youtube,
        status: DownloadStatus.completed,
        progress: 1.0,
        speedMbps: 0,
        etaSeconds: 0,
        format: 'mp3',
        resolution: 'Audio',
        fileSizeMb: 48.2,
        addedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      DownloadItem(
        id: '11',
        title: 'Tokyo Night Walk 4K',
        url: 'https://youtu.be/tokyo',
        platform: MediaPlatform.youtube,
        status: DownloadStatus.completed,
        progress: 1.0,
        speedMbps: 0,
        etaSeconds: 0,
        format: 'mp4',
        resolution: '4K',
        fileSizeMb: 1240.5,
        addedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      DownloadItem(
        id: '12',
        title: 'Gym Motivation Short',
        url: 'https://tiktok.com/@gym/video/999',
        platform: MediaPlatform.tiktok,
        status: DownloadStatus.failed,
        progress: 0.12,
        speedMbps: 0,
        etaSeconds: 0,
        format: 'mp4',
        resolution: '1080p',
        fileSizeMb: 14.4,
        addedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      DownloadItem(
        id: '13',
        title: 'Street Photography Tips',
        url: 'https://instagram.com/p/photo',
        platform: MediaPlatform.instagram,
        status: DownloadStatus.completed,
        progress: 1.0,
        speedMbps: 0,
        etaSeconds: 0,
        format: 'mp4',
        resolution: '1080p',
        fileSizeMb: 62.1,
        addedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      DownloadItem(
        id: '14',
        title: 'Dart Async Programming Masterclass',
        url: 'https://youtu.be/async',
        platform: MediaPlatform.youtube,
        status: DownloadStatus.completed,
        progress: 1.0,
        speedMbps: 0,
        etaSeconds: 0,
        format: 'mp4',
        resolution: '1080p',
        fileSizeMb: 388.2,
        addedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      DownloadItem(
        id: '15',
        title: 'Minimalist Apartment Tour',
        url: 'https://instagram.com/reel/apt',
        platform: MediaPlatform.instagram,
        status: DownloadStatus.completed,
        progress: 1.0,
        speedMbps: 0,
        etaSeconds: 0,
        format: 'mp4',
        resolution: '720p',
        fileSizeMb: 88.4,
        addedAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    ),
  ];

  static List<DownloadItem> getActiveDownloads() => _active;
  static List<DownloadItem> getHistory() => _history;
}
