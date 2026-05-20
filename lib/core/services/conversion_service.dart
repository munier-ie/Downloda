import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../database/database.dart';
import 'notification_service.dart';

class ConversionService {
  final AppDatabase db;
  ConversionService(this.db);

  /// Extracts audio from a downloaded video file to MP3.
  /// Returns the path of the output file, or null on failure.
  Future<String?> convertToAudio(DownloadItem source) async {
    if (source.filePath == null) return null;

    final sourceFile = File(source.filePath!);
    if (!await sourceFile.exists()) return null;

    final dir = sourceFile.parent.path;
    final baseName = p.basenameWithoutExtension(source.filePath!);
    final outputPath = p.join(dir, '$baseName.mp3');
    final notifId = '${source.id}_conv'.hashCode & 0x7fffffff;

    // Show "converting" notification
    await NotificationService().showProgressNotification(
      id: notifId,
      title: 'Converting to Audio',
      body: source.title,
      progress: 0,
      maxProgress: 100,
      showProgress: true,
      ongoing: true,
      payload: source.id,
    );

    debugPrint('[ConversionService] Starting: ${source.filePath} → $outputPath');

    // -vn = no video, -acodec libmp3lame, -q:a 2 = high quality VBR
    final session = await FFmpegKit.execute(
      '-y -i "${source.filePath!}" -vn -acodec libmp3lame -q:a 2 "$outputPath"',
    );

    final rc = await session.getReturnCode();

    if (ReturnCode.isSuccess(rc)) {
      final outputFile = File(outputPath);
      final sizeMb = (await outputFile.length()) / (1024 * 1024);

      // Insert as a new completed record in the DB
      final newId = const Uuid().v4();
      final audioItem = DownloadItem(
        id: newId,
        title: source.title,
        url: source.url,
        platform: source.platform,
        status: DownloadStatus.completed,
        progress: 1.0,
        speedMbps: 0,
        etaSeconds: 0,
        thumbnailUrl: source.thumbnailUrl,
        format: 'mp3',
        resolution: 'Audio',
        filePath: outputPath,
        fileSizeMb: sizeMb,
        addedAt: DateTime.now(),
      );
      await db.insertDownload(audioItem.toCompanion());

      // Update notification to success
      await NotificationService().showCompletionNotification(
        id: notifId,
        title: 'Audio Extracted',
        body: '${source.title} • ${sizeMb.toStringAsFixed(1)} MB',
        payload: newId,
      );

      debugPrint('[ConversionService] Done: $outputPath');
      return outputPath;
    } else {
      final logs = await session.getLogsAsString();
      debugPrint('[ConversionService] Failed: $logs');

      await NotificationService().showProgressNotification(
        id: notifId,
        title: 'Conversion Failed',
        body: source.title,
        progress: 0,
        maxProgress: 100,
        showProgress: false,
        ongoing: false,
        payload: source.id,
      );
      return null;
    }
  }
}
