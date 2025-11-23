// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ConcertsTable extends Concerts with TableInfo<$ConcertsTable, Concert> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConcertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _choirIdMeta =
      const VerificationMeta('choirId');
  @override
  late final GeneratedColumn<String> choirId = GeneratedColumn<String>(
      'choir_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _choirNameMeta =
      const VerificationMeta('choirName');
  @override
  late final GeneratedColumn<String> choirName = GeneratedColumn<String>(
      'choir_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _concertDateMeta =
      const VerificationMeta('concertDate');
  @override
  late final GeneratedColumn<DateTime> concertDate = GeneratedColumn<DateTime>(
      'concert_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        choirId,
        choirName,
        name,
        concertDate,
        createdAt,
        updatedAt,
        deleted,
        synced
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'concerts';
  @override
  VerificationContext validateIntegrity(Insertable<Concert> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('choir_id')) {
      context.handle(_choirIdMeta,
          choirId.isAcceptableOrUnknown(data['choir_id']!, _choirIdMeta));
    } else if (isInserting) {
      context.missing(_choirIdMeta);
    }
    if (data.containsKey('choir_name')) {
      context.handle(_choirNameMeta,
          choirName.isAcceptableOrUnknown(data['choir_name']!, _choirNameMeta));
    } else if (isInserting) {
      context.missing(_choirNameMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('concert_date')) {
      context.handle(
          _concertDateMeta,
          concertDate.isAcceptableOrUnknown(
              data['concert_date']!, _concertDateMeta));
    } else if (isInserting) {
      context.missing(_concertDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Concert map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Concert(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      choirId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}choir_id'])!,
      choirName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}choir_name'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      concertDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}concert_date'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $ConcertsTable createAlias(String alias) {
    return $ConcertsTable(attachedDatabase, alias);
  }
}

class Concert extends DataClass implements Insertable<Concert> {
  /// Unique identifier (UUID)
  final String id;

  /// ID of the choir this concert belongs to
  final String choirId;

  /// Name of the choir (denormalized for performance)
  final String choirName;

  /// Concert name/title
  final String name;

  /// Date of the concert
  final DateTime concertDate;

  /// When this record was created
  final DateTime createdAt;

  /// When this record was last updated (for sync)
  final DateTime updatedAt;

  /// Soft delete flag (true = deleted, false = active)
  final bool deleted;

  /// Sync tracking flag (true = synced to cloud, false = needs sync)
  final bool synced;
  const Concert(
      {required this.id,
      required this.choirId,
      required this.choirName,
      required this.name,
      required this.concertDate,
      required this.createdAt,
      required this.updatedAt,
      required this.deleted,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['choir_id'] = Variable<String>(choirId);
    map['choir_name'] = Variable<String>(choirName);
    map['name'] = Variable<String>(name);
    map['concert_date'] = Variable<DateTime>(concertDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  ConcertsCompanion toCompanion(bool nullToAbsent) {
    return ConcertsCompanion(
      id: Value(id),
      choirId: Value(choirId),
      choirName: Value(choirName),
      name: Value(name),
      concertDate: Value(concertDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      synced: Value(synced),
    );
  }

  factory Concert.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Concert(
      id: serializer.fromJson<String>(json['id']),
      choirId: serializer.fromJson<String>(json['choirId']),
      choirName: serializer.fromJson<String>(json['choirName']),
      name: serializer.fromJson<String>(json['name']),
      concertDate: serializer.fromJson<DateTime>(json['concertDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'choirId': serializer.toJson<String>(choirId),
      'choirName': serializer.toJson<String>(choirName),
      'name': serializer.toJson<String>(name),
      'concertDate': serializer.toJson<DateTime>(concertDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  Concert copyWith(
          {String? id,
          String? choirId,
          String? choirName,
          String? name,
          DateTime? concertDate,
          DateTime? createdAt,
          DateTime? updatedAt,
          bool? deleted,
          bool? synced}) =>
      Concert(
        id: id ?? this.id,
        choirId: choirId ?? this.choirId,
        choirName: choirName ?? this.choirName,
        name: name ?? this.name,
        concertDate: concertDate ?? this.concertDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        synced: synced ?? this.synced,
      );
  Concert copyWithCompanion(ConcertsCompanion data) {
    return Concert(
      id: data.id.present ? data.id.value : this.id,
      choirId: data.choirId.present ? data.choirId.value : this.choirId,
      choirName: data.choirName.present ? data.choirName.value : this.choirName,
      name: data.name.present ? data.name.value : this.name,
      concertDate:
          data.concertDate.present ? data.concertDate.value : this.concertDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Concert(')
          ..write('id: $id, ')
          ..write('choirId: $choirId, ')
          ..write('choirName: $choirName, ')
          ..write('name: $name, ')
          ..write('concertDate: $concertDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, choirId, choirName, name, concertDate,
      createdAt, updatedAt, deleted, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Concert &&
          other.id == this.id &&
          other.choirId == this.choirId &&
          other.choirName == this.choirName &&
          other.name == this.name &&
          other.concertDate == this.concertDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.synced == this.synced);
}

class ConcertsCompanion extends UpdateCompanion<Concert> {
  final Value<String> id;
  final Value<String> choirId;
  final Value<String> choirName;
  final Value<String> name;
  final Value<DateTime> concertDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> synced;
  final Value<int> rowid;
  const ConcertsCompanion({
    this.id = const Value.absent(),
    this.choirId = const Value.absent(),
    this.choirName = const Value.absent(),
    this.name = const Value.absent(),
    this.concertDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConcertsCompanion.insert({
    required String id,
    required String choirId,
    required String choirName,
    required String name,
    required DateTime concertDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        choirId = Value(choirId),
        choirName = Value(choirName),
        name = Value(name),
        concertDate = Value(concertDate),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Concert> custom({
    Expression<String>? id,
    Expression<String>? choirId,
    Expression<String>? choirName,
    Expression<String>? name,
    Expression<DateTime>? concertDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (choirId != null) 'choir_id': choirId,
      if (choirName != null) 'choir_name': choirName,
      if (name != null) 'name': name,
      if (concertDate != null) 'concert_date': concertDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConcertsCompanion copyWith(
      {Value<String>? id,
      Value<String>? choirId,
      Value<String>? choirName,
      Value<String>? name,
      Value<DateTime>? concertDate,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool>? deleted,
      Value<bool>? synced,
      Value<int>? rowid}) {
    return ConcertsCompanion(
      id: id ?? this.id,
      choirId: choirId ?? this.choirId,
      choirName: choirName ?? this.choirName,
      name: name ?? this.name,
      concertDate: concertDate ?? this.concertDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (choirId.present) {
      map['choir_id'] = Variable<String>(choirId.value);
    }
    if (choirName.present) {
      map['choir_name'] = Variable<String>(choirName.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (concertDate.present) {
      map['concert_date'] = Variable<DateTime>(concertDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConcertsCompanion(')
          ..write('id: $id, ')
          ..write('choirId: $choirId, ')
          ..write('choirName: $choirName, ')
          ..write('name: $name, ')
          ..write('concertDate: $concertDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConcertsTable concerts = $ConcertsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [concerts];
}

typedef $$ConcertsTableCreateCompanionBuilder = ConcertsCompanion Function({
  required String id,
  required String choirId,
  required String choirName,
  required String name,
  required DateTime concertDate,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<bool> synced,
  Value<int> rowid,
});
typedef $$ConcertsTableUpdateCompanionBuilder = ConcertsCompanion Function({
  Value<String> id,
  Value<String> choirId,
  Value<String> choirName,
  Value<String> name,
  Value<DateTime> concertDate,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> synced,
  Value<int> rowid,
});

class $$ConcertsTableFilterComposer
    extends Composer<_$AppDatabase, $ConcertsTable> {
  $$ConcertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get choirId => $composableBuilder(
      column: $table.choirId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get choirName => $composableBuilder(
      column: $table.choirName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get concertDate => $composableBuilder(
      column: $table.concertDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$ConcertsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConcertsTable> {
  $$ConcertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get choirId => $composableBuilder(
      column: $table.choirId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get choirName => $composableBuilder(
      column: $table.choirName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get concertDate => $composableBuilder(
      column: $table.concertDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$ConcertsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConcertsTable> {
  $$ConcertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get choirId =>
      $composableBuilder(column: $table.choirId, builder: (column) => column);

  GeneratedColumn<String> get choirName =>
      $composableBuilder(column: $table.choirName, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get concertDate => $composableBuilder(
      column: $table.concertDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$ConcertsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ConcertsTable,
    Concert,
    $$ConcertsTableFilterComposer,
    $$ConcertsTableOrderingComposer,
    $$ConcertsTableAnnotationComposer,
    $$ConcertsTableCreateCompanionBuilder,
    $$ConcertsTableUpdateCompanionBuilder,
    (Concert, BaseReferences<_$AppDatabase, $ConcertsTable, Concert>),
    Concert,
    PrefetchHooks Function()> {
  $$ConcertsTableTableManager(_$AppDatabase db, $ConcertsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConcertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConcertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConcertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> choirId = const Value.absent(),
            Value<String> choirName = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> concertDate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConcertsCompanion(
            id: id,
            choirId: choirId,
            choirName: choirName,
            name: name,
            concertDate: concertDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            synced: synced,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String choirId,
            required String choirName,
            required String name,
            required DateTime concertDate,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<bool> synced = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConcertsCompanion.insert(
            id: id,
            choirId: choirId,
            choirName: choirName,
            name: name,
            concertDate: concertDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            synced: synced,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConcertsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ConcertsTable,
    Concert,
    $$ConcertsTableFilterComposer,
    $$ConcertsTableOrderingComposer,
    $$ConcertsTableAnnotationComposer,
    $$ConcertsTableCreateCompanionBuilder,
    $$ConcertsTableUpdateCompanionBuilder,
    (Concert, BaseReferences<_$AppDatabase, $ConcertsTable, Concert>),
    Concert,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConcertsTableTableManager get concerts =>
      $$ConcertsTableTableManager(_db, _db.concerts);
}
