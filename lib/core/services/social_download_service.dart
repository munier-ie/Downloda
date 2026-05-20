import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models.dart';

// ── Swap this constant when moving from local → hosted server ───────────────
// On a physical device connected via USB with ADB port forwarding
// (`adb reverse tcp:3000 tcp:3000`) use http://localhost:3000.
// On an Android emulator talking to the host machine use http://10.0.2.2:3000.
const String kSocialApiBase = 'https://dwldr-backend.onrender.com';

// ── Data models ──────────────────────────────────────────────────────────────

class VideoVariant {
  final String quality; // e.g. "Without watermark", "1080p", "720p", "Audio"
  final String url;     // direct CDN link
  final String format;  // "mp4" | "mp3"

  const VideoVariant({
    required this.quality,
    required this.url,
    required this.format,
  });
}

class SocialMediaInfo {
  final String title;
  final String? thumbnailUrl;
  final MediaPlatform platform;
  final List<VideoVariant> variants; // at least one entry

  const SocialMediaInfo({
    required this.title,
    required this.thumbnailUrl,
    required this.platform,
    required this.variants,
  });
}

// ── Service ──────────────────────────────────────────────────────────────────

class SocialDownloadService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Detect which platform a URL belongs to.
  static MediaPlatform? detectPlatform(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube.com') || u.contains('youtu.be')) {
      return MediaPlatform.youtube;
    }
    if (u.contains('instagram.com')) return MediaPlatform.instagram;
    if (u.contains('tiktok.com') || u.contains('vm.tiktok.com') || u.contains('vt.tiktok.com')) {
      return MediaPlatform.tiktok;
    }
    if (u.contains('facebook.com') || u.contains('fb.watch') ||
        u.contains('fb.com')) {
      return MediaPlatform.facebook;
    }
    if (u.contains('x.com') || u.contains('twitter.com')) {
      return MediaPlatform.x;
    }
    return null; // unsupported
  }

  /// Returns true if this URL is a social-media (non-YouTube) platform we
  /// handle via the universalDownloader API.
  static bool isSocialUrl(String url) {
    final p = detectPlatform(url);
    return p != null && p != MediaPlatform.youtube;
  }

  /// Fetch video info (title, thumbnail, variants) from the local API.
  Future<SocialMediaInfo> fetchInfo(String url) async {
    final platform = detectPlatform(url);
    if (platform == null || platform == MediaPlatform.youtube) {
      throw Exception('URL is not a supported social platform: $url');
    }

    try {
      switch (platform) {
        case MediaPlatform.instagram:
        case MediaPlatform.facebook:
          return await _fetchMeta(url, platform);
        case MediaPlatform.tiktok:
          return await _fetchTikTok(url);
        case MediaPlatform.x:
          return await _fetchTwitter(url);
        default:
          throw Exception('Unsupported platform');
      }
    } catch (e) {
      debugPrint('[SocialDownloadService] fetchInfo error: $e');
      rethrow;
    }
  }

  // ── Instagram / Facebook via /api/meta/download ──────────────────────────

  Future<SocialMediaInfo> _fetchMeta(
      String url, MediaPlatform platform) async {
    final resp = await _dio.get(
      '$kSocialApiBase/api/meta/download',
      queryParameters: {'url': url},
    );

    final body = resp.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception('API error: ${body['error'] ?? 'unknown'}');
    }

    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List?) ?? [];

    // Build variants from the items list
    final variants = <VideoVariant>[];
    for (final item in items) {
      final dlUrl = item['url'] as String?;
      if (dlUrl == null || dlUrl.isEmpty) continue;
      final resolution = (item['resolution'] as String?) ?? 'Best Quality';
      variants.add(VideoVariant(
        quality: resolution,
        url: dlUrl,
        format: 'mp4',
      ));
    }

    if (variants.isEmpty) throw Exception('No downloadable variants found');

    // Thumbnail comes from the first item
    final thumbnail =
        (items.isNotEmpty ? items.first['thumbnail'] as String? : null);

    // The API doesn't return a title for Meta platforms — use a fallback
    final title = platform == MediaPlatform.instagram
        ? 'Instagram Reel'
        : 'Facebook Video';

    return SocialMediaInfo(
      title: title,
      thumbnailUrl: thumbnail,
      platform: platform,
      variants: variants,
    );
  }

  // ── TikTok via /api/tiktok/download ─────────────────────────────────────

  Future<SocialMediaInfo> _fetchTikTok(String url) async {
    final resp = await _dio.get(
      '$kSocialApiBase/api/tiktok/download',
      queryParameters: {'url': url},
    );

    final body = resp.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception('API error: ${body['error'] ?? 'unknown'}');
    }

    final data = body['data'] as Map<String, dynamic>;
    final title = (data['title'] as String?) ?? 'TikTok Video';
    final thumbnail = data['thumbnail'] as String?;
    final downloads = (data['downloads'] as List?) ?? [];

    final variants = <VideoVariant>[];
    for (final dl in downloads) {
      final dlUrl = dl['url'] as String?;
      final text = dl['text'] as String? ?? 'Video';
      if (dlUrl == null || dlUrl.isEmpty) continue;

      // Only grab the video without watermark (skip MP3 here; we handle
      // audio conversion ourselves via FFmpeg for consistency)
      if (text.toLowerCase().contains('mp3') ||
          text.toLowerCase().contains('audio')) {
        continue;
      }
      variants.add(VideoVariant(
        quality: text,
        url: dlUrl,
        format: 'mp4',
      ));
    }

    if (variants.isEmpty) throw Exception('No downloadable TikTok variants');

    return SocialMediaInfo(
      title: title,
      thumbnailUrl: thumbnail,
      platform: MediaPlatform.tiktok,
      variants: variants,
    );
  }

  // ── X (Twitter) via /api/twitter/download ────────────────────────────────

  Future<SocialMediaInfo> _fetchTwitter(String url) async {
    final resp = await _dio.get(
      '$kSocialApiBase/api/twitter/download',
      queryParameters: {'url': url},
    );

    final body = resp.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception('API error: ${body['error'] ?? 'unknown'}');
    }

    final data = body['data'] as Map<String, dynamic>;
    final title = (data['title'] as String?) ?? 'X Post';
    final thumbnail = data['thumbnail'] as String?;
    final videos = (data['videos'] as List?) ?? [];

    final variants = <VideoVariant>[];
    for (final v in videos) {
      final dlUrl = v['url'] as String?;
      final quality = v['quality'] as String? ?? 'Unknown';
      if (dlUrl == null || dlUrl.isEmpty) continue;
      variants.add(VideoVariant(
        quality: quality,
        url: dlUrl,
        format: 'mp4',
      ));
    }

    if (variants.isEmpty) throw Exception('No downloadable X variants');

    return SocialMediaInfo(
      title: title,
      thumbnailUrl: thumbnail,
      platform: MediaPlatform.x,
      variants: variants,
    );
  }
}
