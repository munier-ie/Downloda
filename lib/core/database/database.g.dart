// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DownloadItemsTable extends DownloadItems
    with TableInfo<$DownloadItemsTable, DownloadItemData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MediaPlatform, int> platform =
      GeneratedColumn<int>(
        'platform',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<MediaPlatform>($DownloadItemsTable.$converterplatform);
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DownloadStatus>($DownloadItemsTable.$converterstatus);
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _speedMbpsMeta = const VerificationMeta(
    'speedMbps',
  );
  @override
  late final GeneratedColumn<double> speedMbps = GeneratedColumn<double>(
    'speed_mbps',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _etaSecondsMeta = const VerificationMeta(
    'etaSeconds',
  );
  @override
  late final GeneratedColumn<int> etaSeconds = GeneratedColumn<int>(
    'eta_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolutionMeta = const VerificationMeta(
    'resolution',
  );
  @override
  late final GeneratedColumn<String> resolution = GeneratedColumn<String>(
    'resolution',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMbMeta = const VerificationMeta(
    'fileSizeMb',
  );
  @override
  late final GeneratedColumn<double> fileSizeMb = GeneratedColumn<double>(
    'file_size_mb',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    url,
    platform,
    status,
    progress,
    speedMbps,
    etaSeconds,
    thumbnailUrl,
    format,
    resolution,
    filePath,
    fileSizeMb,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadItemData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('speed_mbps')) {
      context.handle(
        _speedMbpsMeta,
        speedMbps.isAcceptableOrUnknown(data['speed_mbps']!, _speedMbpsMeta),
      );
    }
    if (data.containsKey('eta_seconds')) {
      context.handle(
        _etaSecondsMeta,
        etaSeconds.isAcceptableOrUnknown(data['eta_seconds']!, _etaSecondsMeta),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('resolution')) {
      context.handle(
        _resolutionMeta,
        resolution.isAcceptableOrUnknown(data['resolution']!, _resolutionMeta),
      );
    } else if (isInserting) {
      context.missing(_resolutionMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('file_size_mb')) {
      context.handle(
        _fileSizeMbMeta,
        fileSizeMb.isAcceptableOrUnknown(
          data['file_size_mb']!,
          _fileSizeMbMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadItemData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadItemData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      platform: $DownloadItemsTable.$converterplatform.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}platform'],
        )!,
      ),
      status: $DownloadItemsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      speedMbps: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed_mbps'],
      )!,
      etaSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}eta_seconds'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      resolution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      fileSizeMb: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}file_size_mb'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $DownloadItemsTable createAlias(String alias) {
    return $DownloadItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MediaPlatform, int, int> $converterplatform =
      const EnumIndexConverter<MediaPlatform>(MediaPlatform.values);
  static JsonTypeConverter2<DownloadStatus, int, int> $converterstatus =
      const EnumIndexConverter<DownloadStatus>(DownloadStatus.values);
}

class DownloadItemData extends DataClass
    implements Insertable<DownloadItemData> {
  final String id;
  final String title;
  final String url;
  final MediaPlatform platform;
  final DownloadStatus status;
  final double progress;
  final double speedMbps;
  final int etaSeconds;
  final String? thumbnailUrl;
  final String format;
  final String resolution;
  final String? filePath;
  final double fileSizeMb;
  final DateTime addedAt;
  const DownloadItemData({
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
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['url'] = Variable<String>(url);
    {
      map['platform'] = Variable<int>(
        $DownloadItemsTable.$converterplatform.toSql(platform),
      );
    }
    {
      map['status'] = Variable<int>(
        $DownloadItemsTable.$converterstatus.toSql(status),
      );
    }
    map['progress'] = Variable<double>(progress);
    map['speed_mbps'] = Variable<double>(speedMbps);
    map['eta_seconds'] = Variable<int>(etaSeconds);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    map['format'] = Variable<String>(format);
    map['resolution'] = Variable<String>(resolution);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    map['file_size_mb'] = Variable<double>(fileSizeMb);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  DownloadItemsCompanion toCompanion(bool nullToAbsent) {
    return DownloadItemsCompanion(
      id: Value(id),
      title: Value(title),
      url: Value(url),
      platform: Value(platform),
      status: Value(status),
      progress: Value(progress),
      speedMbps: Value(speedMbps),
      etaSeconds: Value(etaSeconds),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      format: Value(format),
      resolution: Value(resolution),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      fileSizeMb: Value(fileSizeMb),
      addedAt: Value(addedAt),
    );
  }

  factory DownloadItemData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadItemData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      url: serializer.fromJson<String>(json['url']),
      platform: $DownloadItemsTable.$converterplatform.fromJson(
        serializer.fromJson<int>(json['platform']),
      ),
      status: $DownloadItemsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      progress: serializer.fromJson<double>(json['progress']),
      speedMbps: serializer.fromJson<double>(json['speedMbps']),
      etaSeconds: serializer.fromJson<int>(json['etaSeconds']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      format: serializer.fromJson<String>(json['format']),
      resolution: serializer.fromJson<String>(json['resolution']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      fileSizeMb: serializer.fromJson<double>(json['fileSizeMb']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'url': serializer.toJson<String>(url),
      'platform': serializer.toJson<int>(
        $DownloadItemsTable.$converterplatform.toJson(platform),
      ),
      'status': serializer.toJson<int>(
        $DownloadItemsTable.$converterstatus.toJson(status),
      ),
      'progress': serializer.toJson<double>(progress),
      'speedMbps': serializer.toJson<double>(speedMbps),
      'etaSeconds': serializer.toJson<int>(etaSeconds),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'format': serializer.toJson<String>(format),
      'resolution': serializer.toJson<String>(resolution),
      'filePath': serializer.toJson<String?>(filePath),
      'fileSizeMb': serializer.toJson<double>(fileSizeMb),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  DownloadItemData copyWith({
    String? id,
    String? title,
    String? url,
    MediaPlatform? platform,
    DownloadStatus? status,
    double? progress,
    double? speedMbps,
    int? etaSeconds,
    Value<String?> thumbnailUrl = const Value.absent(),
    String? format,
    String? resolution,
    Value<String?> filePath = const Value.absent(),
    double? fileSizeMb,
    DateTime? addedAt,
  }) => DownloadItemData(
    id: id ?? this.id,
    title: title ?? this.title,
    url: url ?? this.url,
    platform: platform ?? this.platform,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    speedMbps: speedMbps ?? this.speedMbps,
    etaSeconds: etaSeconds ?? this.etaSeconds,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    format: format ?? this.format,
    resolution: resolution ?? this.resolution,
    filePath: filePath.present ? filePath.value : this.filePath,
    fileSizeMb: fileSizeMb ?? this.fileSizeMb,
    addedAt: addedAt ?? this.addedAt,
  );
  DownloadItemData copyWithCompanion(DownloadItemsCompanion data) {
    return DownloadItemData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      url: data.url.present ? data.url.value : this.url,
      platform: data.platform.present ? data.platform.value : this.platform,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      speedMbps: data.speedMbps.present ? data.speedMbps.value : this.speedMbps,
      etaSeconds: data.etaSeconds.present
          ? data.etaSeconds.value
          : this.etaSeconds,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      format: data.format.present ? data.format.value : this.format,
      resolution: data.resolution.present
          ? data.resolution.value
          : this.resolution,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileSizeMb: data.fileSizeMb.present
          ? data.fileSizeMb.value
          : this.fileSizeMb,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadItemData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('platform: $platform, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('speedMbps: $speedMbps, ')
          ..write('etaSeconds: $etaSeconds, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('format: $format, ')
          ..write('resolution: $resolution, ')
          ..write('filePath: $filePath, ')
          ..write('fileSizeMb: $fileSizeMb, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    url,
    platform,
    status,
    progress,
    speedMbps,
    etaSeconds,
    thumbnailUrl,
    format,
    resolution,
    filePath,
    fileSizeMb,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadItemData &&
          other.id == this.id &&
          other.title == this.title &&
          other.url == this.url &&
          other.platform == this.platform &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.speedMbps == this.speedMbps &&
          other.etaSeconds == this.etaSeconds &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.format == this.format &&
          other.resolution == this.resolution &&
          other.filePath == this.filePath &&
          other.fileSizeMb == this.fileSizeMb &&
          other.addedAt == this.addedAt);
}

class DownloadItemsCompanion extends UpdateCompanion<DownloadItemData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> url;
  final Value<MediaPlatform> platform;
  final Value<DownloadStatus> status;
  final Value<double> progress;
  final Value<double> speedMbps;
  final Value<int> etaSeconds;
  final Value<String?> thumbnailUrl;
  final Value<String> format;
  final Value<String> resolution;
  final Value<String?> filePath;
  final Value<double> fileSizeMb;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const DownloadItemsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.platform = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.speedMbps = const Value.absent(),
    this.etaSeconds = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.format = const Value.absent(),
    this.resolution = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSizeMb = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadItemsCompanion.insert({
    required String id,
    required String title,
    required String url,
    required MediaPlatform platform,
    required DownloadStatus status,
    this.progress = const Value.absent(),
    this.speedMbps = const Value.absent(),
    this.etaSeconds = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    required String format,
    required String resolution,
    this.filePath = const Value.absent(),
    this.fileSizeMb = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       url = Value(url),
       platform = Value(platform),
       status = Value(status),
       format = Value(format),
       resolution = Value(resolution),
       addedAt = Value(addedAt);
  static Insertable<DownloadItemData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? url,
    Expression<int>? platform,
    Expression<int>? status,
    Expression<double>? progress,
    Expression<double>? speedMbps,
    Expression<int>? etaSeconds,
    Expression<String>? thumbnailUrl,
    Expression<String>? format,
    Expression<String>? resolution,
    Expression<String>? filePath,
    Expression<double>? fileSizeMb,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (url != null) 'url': url,
      if (platform != null) 'platform': platform,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (speedMbps != null) 'speed_mbps': speedMbps,
      if (etaSeconds != null) 'eta_seconds': etaSeconds,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (format != null) 'format': format,
      if (resolution != null) 'resolution': resolution,
      if (filePath != null) 'file_path': filePath,
      if (fileSizeMb != null) 'file_size_mb': fileSizeMb,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? url,
    Value<MediaPlatform>? platform,
    Value<DownloadStatus>? status,
    Value<double>? progress,
    Value<double>? speedMbps,
    Value<int>? etaSeconds,
    Value<String?>? thumbnailUrl,
    Value<String>? format,
    Value<String>? resolution,
    Value<String?>? filePath,
    Value<double>? fileSizeMb,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return DownloadItemsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speedMbps: speedMbps ?? this.speedMbps,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
      filePath: filePath ?? this.filePath,
      fileSizeMb: fileSizeMb ?? this.fileSizeMb,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (platform.present) {
      map['platform'] = Variable<int>(
        $DownloadItemsTable.$converterplatform.toSql(platform.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $DownloadItemsTable.$converterstatus.toSql(status.value),
      );
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (speedMbps.present) {
      map['speed_mbps'] = Variable<double>(speedMbps.value);
    }
    if (etaSeconds.present) {
      map['eta_seconds'] = Variable<int>(etaSeconds.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (resolution.present) {
      map['resolution'] = Variable<String>(resolution.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileSizeMb.present) {
      map['file_size_mb'] = Variable<double>(fileSizeMb.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadItemsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('platform: $platform, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('speedMbps: $speedMbps, ')
          ..write('etaSeconds: $etaSeconds, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('format: $format, ')
          ..write('resolution: $resolution, ')
          ..write('filePath: $filePath, ')
          ..write('fileSizeMb: $fileSizeMb, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DownloadItemsTable downloadItems = $DownloadItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [downloadItems];
}

typedef $$DownloadItemsTableCreateCompanionBuilder =
    DownloadItemsCompanion Function({
      required String id,
      required String title,
      required String url,
      required MediaPlatform platform,
      required DownloadStatus status,
      Value<double> progress,
      Value<double> speedMbps,
      Value<int> etaSeconds,
      Value<String?> thumbnailUrl,
      required String format,
      required String resolution,
      Value<String?> filePath,
      Value<double> fileSizeMb,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$DownloadItemsTableUpdateCompanionBuilder =
    DownloadItemsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> url,
      Value<MediaPlatform> platform,
      Value<DownloadStatus> status,
      Value<double> progress,
      Value<double> speedMbps,
      Value<int> etaSeconds,
      Value<String?> thumbnailUrl,
      Value<String> format,
      Value<String> resolution,
      Value<String?> filePath,
      Value<double> fileSizeMb,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$DownloadItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadItemsTable> {
  $$DownloadItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MediaPlatform, MediaPlatform, int>
  get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadStatus, DownloadStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speedMbps => $composableBuilder(
    column: $table.speedMbps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get etaSeconds => $composableBuilder(
    column: $table.etaSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fileSizeMb => $composableBuilder(
    column: $table.fileSizeMb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadItemsTable> {
  $$DownloadItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speedMbps => $composableBuilder(
    column: $table.speedMbps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get etaSeconds => $composableBuilder(
    column: $table.etaSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fileSizeMb => $composableBuilder(
    column: $table.fileSizeMb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadItemsTable> {
  $$DownloadItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MediaPlatform, int> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<double> get speedMbps =>
      $composableBuilder(column: $table.speedMbps, builder: (column) => column);

  GeneratedColumn<int> get etaSeconds => $composableBuilder(
    column: $table.etaSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<double> get fileSizeMb => $composableBuilder(
    column: $table.fileSizeMb,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$DownloadItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadItemsTable,
          DownloadItemData,
          $$DownloadItemsTableFilterComposer,
          $$DownloadItemsTableOrderingComposer,
          $$DownloadItemsTableAnnotationComposer,
          $$DownloadItemsTableCreateCompanionBuilder,
          $$DownloadItemsTableUpdateCompanionBuilder,
          (
            DownloadItemData,
            BaseReferences<
              _$AppDatabase,
              $DownloadItemsTable,
              DownloadItemData
            >,
          ),
          DownloadItemData,
          PrefetchHooks Function()
        > {
  $$DownloadItemsTableTableManager(_$AppDatabase db, $DownloadItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<MediaPlatform> platform = const Value.absent(),
                Value<DownloadStatus> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<double> speedMbps = const Value.absent(),
                Value<int> etaSeconds = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> resolution = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<double> fileSizeMb = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadItemsCompanion(
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
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String url,
                required MediaPlatform platform,
                required DownloadStatus status,
                Value<double> progress = const Value.absent(),
                Value<double> speedMbps = const Value.absent(),
                Value<int> etaSeconds = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                required String format,
                required String resolution,
                Value<String?> filePath = const Value.absent(),
                Value<double> fileSizeMb = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadItemsCompanion.insert(
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
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadItemsTable,
      DownloadItemData,
      $$DownloadItemsTableFilterComposer,
      $$DownloadItemsTableOrderingComposer,
      $$DownloadItemsTableAnnotationComposer,
      $$DownloadItemsTableCreateCompanionBuilder,
      $$DownloadItemsTableUpdateCompanionBuilder,
      (
        DownloadItemData,
        BaseReferences<_$AppDatabase, $DownloadItemsTable, DownloadItemData>,
      ),
      DownloadItemData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DownloadItemsTableTableManager get downloadItems =>
      $$DownloadItemsTableTableManager(_db, _db.downloadItems);
}
