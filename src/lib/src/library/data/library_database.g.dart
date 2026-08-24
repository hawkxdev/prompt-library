// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    normalizedName,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final String normalizedName;
  final int sortOrder;
  final DateTime createdAt;
  const Category({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? normalizedName,
    int? sortOrder,
    DateTime? createdAt,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, normalizedName, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    required int sortOrder,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalizedName = Value(normalizedName),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keywordMeta = const VerificationMeta(
    'keyword',
  );
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
    'keyword',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastCopiedAtMeta = const VerificationMeta(
    'lastCopiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCopiedAt = GeneratedColumn<DateTime>(
    'last_copied_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    body,
    keyword,
    categoryId,
    isFavorite,
    isArchived,
    createdAt,
    updatedAt,
    lastCopiedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
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
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('keyword')) {
      context.handle(
        _keywordMeta,
        keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_copied_at')) {
      context.handle(
        _lastCopiedAtMeta,
        lastCopiedAt.isAcceptableOrUnknown(
          data['last_copied_at']!,
          _lastCopiedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      keyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keyword'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastCopiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_copied_at'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
  final String id;
  final String title;
  final String body;
  final String? keyword;
  final String? categoryId;
  final bool isFavorite;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastCopiedAt;
  const Entry({
    required this.id,
    required this.title,
    required this.body,
    this.keyword,
    this.categoryId,
    required this.isFavorite,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.lastCopiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || keyword != null) {
      map['keyword'] = Variable<String>(keyword);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastCopiedAt != null) {
      map['last_copied_at'] = Variable<DateTime>(lastCopiedAt);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
      keyword: keyword == null && nullToAbsent
          ? const Value.absent()
          : Value(keyword),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      isFavorite: Value(isFavorite),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastCopiedAt: lastCopiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCopiedAt),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      keyword: serializer.fromJson<String?>(json['keyword']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastCopiedAt: serializer.fromJson<DateTime?>(json['lastCopiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'keyword': serializer.toJson<String?>(keyword),
      'categoryId': serializer.toJson<String?>(categoryId),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastCopiedAt': serializer.toJson<DateTime?>(lastCopiedAt),
    };
  }

  Entry copyWith({
    String? id,
    String? title,
    String? body,
    Value<String?> keyword = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    bool? isFavorite,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastCopiedAt = const Value.absent(),
  }) => Entry(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    keyword: keyword.present ? keyword.value : this.keyword,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    isFavorite: isFavorite ?? this.isFavorite,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastCopiedAt: lastCopiedAt.present ? lastCopiedAt.value : this.lastCopiedAt,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastCopiedAt: data.lastCopiedAt.present
          ? data.lastCopiedAt.value
          : this.lastCopiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('keyword: $keyword, ')
          ..write('categoryId: $categoryId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastCopiedAt: $lastCopiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    body,
    keyword,
    categoryId,
    isFavorite,
    isArchived,
    createdAt,
    updatedAt,
    lastCopiedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body &&
          other.keyword == this.keyword &&
          other.categoryId == this.categoryId &&
          other.isFavorite == this.isFavorite &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastCopiedAt == this.lastCopiedAt);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> keyword;
  final Value<String?> categoryId;
  final Value<bool> isFavorite;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastCopiedAt;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.keyword = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastCopiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required String title,
    required String body,
    this.keyword = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isArchived = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastCopiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       body = Value(body),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Entry> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? keyword,
    Expression<String>? categoryId,
    Expression<bool>? isFavorite,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastCopiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (keyword != null) 'keyword': keyword,
      if (categoryId != null) 'category_id': categoryId,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastCopiedAt != null) 'last_copied_at': lastCopiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? body,
    Value<String?>? keyword,
    Value<String?>? categoryId,
    Value<bool>? isFavorite,
    Value<bool>? isArchived,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastCopiedAt,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      keyword: keyword ?? this.keyword,
      categoryId: categoryId ?? this.categoryId,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCopiedAt: lastCopiedAt ?? this.lastCopiedAt,
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
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastCopiedAt.present) {
      map['last_copied_at'] = Variable<DateTime>(lastCopiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('keyword: $keyword, ')
          ..write('categoryId: $categoryId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastCopiedAt: $lastCopiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, normalizedName, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  final String normalizedName;
  final DateTime createdAt;
  const Tag({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      createdAt: Value(createdAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    String? normalizedName,
    DateTime? createdAt,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    createdAt: createdAt ?? this.createdAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, normalizedName, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.createdAt == this.createdAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalizedName = Value(normalizedName),
       createdAt = Value(createdAt);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntryTagsTable extends EntryTags
    with TableInfo<$EntryTagsTable, EntryTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, tagId};
  @override
  EntryTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryTag(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $EntryTagsTable createAlias(String alias) {
    return $EntryTagsTable(attachedDatabase, alias);
  }
}

class EntryTag extends DataClass implements Insertable<EntryTag> {
  final String entryId;
  final String tagId;
  const EntryTag({required this.entryId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  EntryTagsCompanion toCompanion(bool nullToAbsent) {
    return EntryTagsCompanion(entryId: Value(entryId), tagId: Value(tagId));
  }

  factory EntryTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryTag(
      entryId: serializer.fromJson<String>(json['entryId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  EntryTag copyWith({String? entryId, String? tagId}) =>
      EntryTag(entryId: entryId ?? this.entryId, tagId: tagId ?? this.tagId);
  EntryTag copyWithCompanion(EntryTagsCompanion data) {
    return EntryTag(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryTag(')
          ..write('entryId: $entryId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryTag &&
          other.entryId == this.entryId &&
          other.tagId == this.tagId);
}

class EntryTagsCompanion extends UpdateCompanion<EntryTag> {
  final Value<String> entryId;
  final Value<String> tagId;
  final Value<int> rowid;
  const EntryTagsCompanion({
    this.entryId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryTagsCompanion.insert({
    required String entryId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       tagId = Value(tagId);
  static Insertable<EntryTag> custom({
    Expression<String>? entryId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryTagsCompanion copyWith({
    Value<String>? entryId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return EntryTagsCompanion(
      entryId: entryId ?? this.entryId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryTagsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LibraryDatabase extends GeneratedDatabase {
  _$LibraryDatabase(QueryExecutor e) : super(e);
  $LibraryDatabaseManager get managers => $LibraryDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $EntryTagsTable entryTags = $EntryTagsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    entries,
    tags,
    entryTags,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entries', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entry_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entry_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String name,
  required String normalizedName,
  required int sortOrder,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> normalizedName,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$LibraryDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EntriesTable, List<Entry>> _entriesRefsTable(
    _$LibraryDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'categories__id__entries__category_id',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$LibraryDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$LibraryDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool entriesRefs})
        > {
  $$CategoriesTableTableManager(_$LibraryDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String normalizedName,
                required int sortOrder,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entriesRefs) db.entries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entriesRefs)
                    await $_getPrefetchedData<
                      Category,
                      $CategoriesTable,
                      Entry
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._entriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).entriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool entriesRefs})
    >;
typedef $$EntriesTableCreateCompanionBuilder = EntriesCompanion Function({
  required String id,
  required String title,
  required String body,
  Value<String?> keyword,
  Value<String?> categoryId,
  Value<bool> isFavorite,
  Value<bool> isArchived,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> lastCopiedAt,
  Value<int> rowid,
});
typedef $$EntriesTableUpdateCompanionBuilder = EntriesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> body,
  Value<String?> keyword,
  Value<String?> categoryId,
  Value<bool> isFavorite,
  Value<bool> isArchived,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> lastCopiedAt,
  Value<int> rowid,
});

final class $$EntriesTableReferences
    extends BaseReferences<_$LibraryDatabase, $EntriesTable, Entry> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$LibraryDatabase db) =>
      db.categories.createAlias('entries__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EntryTagsTable, List<EntryTag>>
  _entryTagsRefsTable(_$LibraryDatabase db) => MultiTypedResultKey.fromTable(
    db.entryTags,
    aliasName: 'entries__id__entry_tags__entry_id',
  );

  $$EntryTagsTableProcessedTableManager get entryTagsRefs {
    final manager = $$EntryTagsTableTableManager(
      $_db,
      $_db.entryTags,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_entryTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EntriesTableFilterComposer
    extends Composer<_$LibraryDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
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

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCopiedAt => $composableBuilder(
    column: $table.lastCopiedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> entryTagsRefs(
    Expression<bool> Function($$EntryTagsTableFilterComposer f) f,
  ) {
    final $$EntryTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entryTags,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagsTableFilterComposer(
            $db: $db,
            $table: $db.entryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntriesTableOrderingComposer
    extends Composer<_$LibraryDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
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

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCopiedAt => $composableBuilder(
    column: $table.lastCopiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
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

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCopiedAt => $composableBuilder(
    column: $table.lastCopiedAt,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> entryTagsRefs<T extends Object>(
    Expression<T> Function($$EntryTagsTableAnnotationComposer a) f,
  ) {
    final $$EntryTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entryTags,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.entryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, $$EntriesTableReferences),
          Entry,
          PrefetchHooks Function({bool categoryId, bool entryTagsRefs})
        > {
  $$EntriesTableTableManager(_$LibraryDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> keyword = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastCopiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                title: title,
                body: body,
                keyword: keyword,
                categoryId: categoryId,
                isFavorite: isFavorite,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastCopiedAt: lastCopiedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String body,
                Value<String?> keyword = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> lastCopiedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                title: title,
                body: body,
                keyword: keyword,
                categoryId: categoryId,
                isFavorite: isFavorite,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastCopiedAt: lastCopiedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, entryTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entryTagsRefs) db.entryTags],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$EntriesTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$EntriesTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entryTagsRefs)
                    await $_getPrefetchedData<Entry, $EntriesTable, EntryTag>(
                      currentTable: table,
                      referencedTable: $$EntriesTableReferences
                          ._entryTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EntriesTableReferences(db, table, p0).entryTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.entryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, $$EntriesTableReferences),
      Entry,
      PrefetchHooks Function({bool categoryId, bool entryTagsRefs})
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  required String id,
  required String name,
  required String normalizedName,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> normalizedName,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$TagsTableReferences
    extends BaseReferences<_$LibraryDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EntryTagsTable, List<EntryTag>>
  _entryTagsRefsTable(_$LibraryDatabase db) => MultiTypedResultKey.fromTable(
    db.entryTags,
    aliasName: 'tags__id__entry_tags__tag_id',
  );

  $$EntryTagsTableProcessedTableManager get entryTagsRefs {
    final manager = $$EntryTagsTableTableManager(
      $_db,
      $_db.entryTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_entryTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer
    extends Composer<_$LibraryDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entryTagsRefs(
    Expression<bool> Function($$EntryTagsTableFilterComposer f) f,
  ) {
    final $$EntryTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entryTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagsTableFilterComposer(
            $db: $db,
            $table: $db.entryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> entryTagsRefs<T extends Object>(
    Expression<T> Function($$EntryTagsTableAnnotationComposer a) f,
  ) {
    final $$EntryTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entryTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.entryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool entryTagsRefs})
        > {
  $$TagsTableTableManager(_$LibraryDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String normalizedName,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({entryTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entryTagsRefs) db.entryTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entryTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, EntryTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._entryTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).entryTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool entryTagsRefs})
    >;
typedef $$EntryTagsTableCreateCompanionBuilder = EntryTagsCompanion Function({
  required String entryId,
  required String tagId,
  Value<int> rowid,
});
typedef $$EntryTagsTableUpdateCompanionBuilder = EntryTagsCompanion Function({
  Value<String> entryId,
  Value<String> tagId,
  Value<int> rowid,
});

final class $$EntryTagsTableReferences
    extends BaseReferences<_$LibraryDatabase, $EntryTagsTable, EntryTag> {
  $$EntryTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EntriesTable _entryIdTable(_$LibraryDatabase db) =>
      db.entries.createAlias('entry_tags__entry_id__entries__id');

  $$EntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$LibraryDatabase db) =>
      db.tags.createAlias('entry_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntryTagsTableFilterComposer
    extends Composer<_$LibraryDatabase, $EntryTagsTable> {
  $$EntryTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$EntriesTableFilterComposer get entryId {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryTagsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $EntryTagsTable> {
  $$EntryTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$EntriesTableOrderingComposer get entryId {
    final $$EntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableOrderingComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryTagsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $EntryTagsTable> {
  $$EntryTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$EntriesTableAnnotationComposer get entryId {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryTagsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $EntryTagsTable,
          EntryTag,
          $$EntryTagsTableFilterComposer,
          $$EntryTagsTableOrderingComposer,
          $$EntryTagsTableAnnotationComposer,
          $$EntryTagsTableCreateCompanionBuilder,
          $$EntryTagsTableUpdateCompanionBuilder,
          (EntryTag, $$EntryTagsTableReferences),
          EntryTag,
          PrefetchHooks Function({bool entryId, bool tagId})
        > {
  $$EntryTagsTableTableManager(_$LibraryDatabase db, $EntryTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryTagsCompanion(
                entryId: entryId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => EntryTagsCompanion.insert(
                entryId: entryId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntryTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (entryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.entryId,
                        referencedTable: $$EntryTagsTableReferences
                            ._entryIdTable(db),
                        referencedColumn: $$EntryTagsTableReferences
                            ._entryIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$EntryTagsTableReferences._tagIdTable(
                          db,
                        ),
                        referencedColumn: $$EntryTagsTableReferences
                            ._tagIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EntryTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $EntryTagsTable,
      EntryTag,
      $$EntryTagsTableFilterComposer,
      $$EntryTagsTableOrderingComposer,
      $$EntryTagsTableAnnotationComposer,
      $$EntryTagsTableCreateCompanionBuilder,
      $$EntryTagsTableUpdateCompanionBuilder,
      (EntryTag, $$EntryTagsTableReferences),
      EntryTag,
      PrefetchHooks Function({bool entryId, bool tagId})
    >;

class $LibraryDatabaseManager {
  final _$LibraryDatabase _db;
  $LibraryDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$EntryTagsTableTableManager get entryTags =>
      $$EntryTagsTableTableManager(_db, _db.entryTags);
}
