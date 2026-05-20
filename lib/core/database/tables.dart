import 'package:drift/drift.dart';
import '../models.dart';

@DataClassName('DownloadItemData')
class DownloadItems extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get url => text()();
  IntColumn get platform => intEnum<MediaPlatform>()();
  IntColumn get status => intEnum<DownloadStatus>()();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  RealColumn get speedMbps => real().withDefault(const Constant(0.0))();
  IntColumn get etaSeconds => integer().withDefault(const Constant(0))();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get format => text()();
  TextColumn get resolution => text()();
  TextColumn get filePath => text().nullable()();
  RealColumn get fileSizeMb => real().withDefault(const Constant(0.0))();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
