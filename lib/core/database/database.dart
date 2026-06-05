import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [DownloadItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Use raw SQL so it never fails if column already exists
        try {
          await m.database.customStatement(
            'ALTER TABLE download_items ADD COLUMN file_path TEXT;',
          );
        } catch (_) {}
        try {
          await m.database.customStatement(
            'ALTER TABLE download_items ADD COLUMN file_size_mb REAL NOT NULL DEFAULT 0.0;',
          );
        } catch (_) {}
      }
    },
  );

  Future<List<DownloadItemData>> getActiveDownloads() {
    return (select(downloadItems)
          ..where((t) =>
              t.status.equals(DownloadStatus.preparing.index) |
              t.status.equals(DownloadStatus.downloading.index) |
              t.status.equals(DownloadStatus.processing.index) |
              t.status.equals(DownloadStatus.paused.index) |
              t.status.equals(DownloadStatus.queued.index))
          ..orderBy([(t) => OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<List<DownloadItemData>> getHistory() {
    return (select(downloadItems)
          ..where((t) =>
              t.status.equals(DownloadStatus.completed.index) |
              t.status.equals(DownloadStatus.failed.index))
          ..orderBy([(t) => OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Stream<List<DownloadItemData>> watchActiveDownloads() {
    return (select(downloadItems)
          ..where((t) =>
              t.status.equals(DownloadStatus.preparing.index) |
              t.status.equals(DownloadStatus.downloading.index) |
              t.status.equals(DownloadStatus.processing.index) |
              t.status.equals(DownloadStatus.paused.index) |
              t.status.equals(DownloadStatus.queued.index))
          ..orderBy([(t) => OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<DownloadItemData>> watchHistory() {
    return (select(downloadItems)
          ..where((t) =>
              t.status.equals(DownloadStatus.completed.index) |
              t.status.equals(DownloadStatus.failed.index))
          ..orderBy([(t) => OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> insertDownload(DownloadItemsCompanion item) => into(downloadItems).insert(item, mode: InsertMode.insertOrReplace);
  Future<bool> updateDownload(DownloadItemsCompanion item) => update(downloadItems).replace(item);
  Future<int> deleteDownload(String id) => (delete(downloadItems)..where((t) => t.id.equals(id))).go();
  Future<DownloadItemData?> getDownloadById(String id) => (select(downloadItems)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<DownloadItemData?> getDownloadByUrl(String url) => (select(downloadItems)..where((t) => t.url.equals(url))).getSingleOrNull();
  Future<DownloadItemData?> getDownloadByTitle(String title) => (select(downloadItems)..where((t) => t.title.equals(title))).getSingleOrNull();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL;');
      },
    );
  });
}
