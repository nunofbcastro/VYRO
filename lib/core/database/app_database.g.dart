// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FoodEntriesTable extends FoodEntries
    with TableInfo<$FoodEntriesTable, FoodEntryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealTypeMeta = const VerificationMeta(
    'mealType',
  );
  @override
  late final GeneratedColumn<String> mealType = GeneratedColumn<String>(
    'meal_type',
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
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityGramsMeta = const VerificationMeta(
    'quantityGrams',
  );
  @override
  late final GeneratedColumn<double> quantityGrams = GeneratedColumn<double>(
    'quantity_grams',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalPer100gMeta = const VerificationMeta(
    'kcalPer100g',
  );
  @override
  late final GeneratedColumn<double> kcalPer100g = GeneratedColumn<double>(
    'kcal_per100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteinPer100gMeta = const VerificationMeta(
    'proteinPer100g',
  );
  @override
  late final GeneratedColumn<double> proteinPer100g = GeneratedColumn<double>(
    'protein_per100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbsPer100gMeta = const VerificationMeta(
    'carbsPer100g',
  );
  @override
  late final GeneratedColumn<double> carbsPer100g = GeneratedColumn<double>(
    'carbs_per100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatPer100gMeta = const VerificationMeta(
    'fatPer100g',
  );
  @override
  late final GeneratedColumn<double> fatPer100g = GeneratedColumn<double>(
    'fat_per100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _portionUnitMeta = const VerificationMeta(
    'portionUnit',
  );
  @override
  late final GeneratedColumn<String> portionUnit = GeneratedColumn<String>(
    'portion_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portionCountMeta = const VerificationMeta(
    'portionCount',
  );
  @override
  late final GeneratedColumn<double> portionCount = GeneratedColumn<double>(
    'portion_count',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    day,
    mealType,
    name,
    brand,
    quantityGrams,
    kcalPer100g,
    proteinPer100g,
    carbsPer100g,
    fatPer100g,
    source,
    portionUnit,
    portionCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodEntryRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('meal_type')) {
      context.handle(
        _mealTypeMeta,
        mealType.isAcceptableOrUnknown(data['meal_type']!, _mealTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mealTypeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('quantity_grams')) {
      context.handle(
        _quantityGramsMeta,
        quantityGrams.isAcceptableOrUnknown(
          data['quantity_grams']!,
          _quantityGramsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quantityGramsMeta);
    }
    if (data.containsKey('kcal_per100g')) {
      context.handle(
        _kcalPer100gMeta,
        kcalPer100g.isAcceptableOrUnknown(
          data['kcal_per100g']!,
          _kcalPer100gMeta,
        ),
      );
    }
    if (data.containsKey('protein_per100g')) {
      context.handle(
        _proteinPer100gMeta,
        proteinPer100g.isAcceptableOrUnknown(
          data['protein_per100g']!,
          _proteinPer100gMeta,
        ),
      );
    }
    if (data.containsKey('carbs_per100g')) {
      context.handle(
        _carbsPer100gMeta,
        carbsPer100g.isAcceptableOrUnknown(
          data['carbs_per100g']!,
          _carbsPer100gMeta,
        ),
      );
    }
    if (data.containsKey('fat_per100g')) {
      context.handle(
        _fatPer100gMeta,
        fatPer100g.isAcceptableOrUnknown(data['fat_per100g']!, _fatPer100gMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('portion_unit')) {
      context.handle(
        _portionUnitMeta,
        portionUnit.isAcceptableOrUnknown(
          data['portion_unit']!,
          _portionUnitMeta,
        ),
      );
    }
    if (data.containsKey('portion_count')) {
      context.handle(
        _portionCountMeta,
        portionCount.isAcceptableOrUnknown(
          data['portion_count']!,
          _portionCountMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodEntryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodEntryRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      mealType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      quantityGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity_grams'],
      )!,
      kcalPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal_per100g'],
      ),
      proteinPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_per100g'],
      ),
      carbsPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_per100g'],
      ),
      fatPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_per100g'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      portionUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portion_unit'],
      ),
      portionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}portion_count'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FoodEntriesTable createAlias(String alias) {
    return $FoodEntriesTable(attachedDatabase, alias);
  }
}

class FoodEntryRecord extends DataClass implements Insertable<FoodEntryRecord> {
  final int id;
  final String day;
  final String mealType;
  final String name;
  final String? brand;
  final double quantityGrams;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final String source;

  /// How the amount was entered: grams, serving, unit or package.
  final String? portionUnit;

  /// Number of portions; `quantityGrams` stays the source of truth.
  final double? portionCount;
  final DateTime createdAt;
  const FoodEntryRecord({
    required this.id,
    required this.day,
    required this.mealType,
    required this.name,
    this.brand,
    required this.quantityGrams,
    this.kcalPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    required this.source,
    this.portionUnit,
    this.portionCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day'] = Variable<String>(day);
    map['meal_type'] = Variable<String>(mealType);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    map['quantity_grams'] = Variable<double>(quantityGrams);
    if (!nullToAbsent || kcalPer100g != null) {
      map['kcal_per100g'] = Variable<double>(kcalPer100g);
    }
    if (!nullToAbsent || proteinPer100g != null) {
      map['protein_per100g'] = Variable<double>(proteinPer100g);
    }
    if (!nullToAbsent || carbsPer100g != null) {
      map['carbs_per100g'] = Variable<double>(carbsPer100g);
    }
    if (!nullToAbsent || fatPer100g != null) {
      map['fat_per100g'] = Variable<double>(fatPer100g);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || portionUnit != null) {
      map['portion_unit'] = Variable<String>(portionUnit);
    }
    if (!nullToAbsent || portionCount != null) {
      map['portion_count'] = Variable<double>(portionCount);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FoodEntriesCompanion toCompanion(bool nullToAbsent) {
    return FoodEntriesCompanion(
      id: Value(id),
      day: Value(day),
      mealType: Value(mealType),
      name: Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      quantityGrams: Value(quantityGrams),
      kcalPer100g: kcalPer100g == null && nullToAbsent
          ? const Value.absent()
          : Value(kcalPer100g),
      proteinPer100g: proteinPer100g == null && nullToAbsent
          ? const Value.absent()
          : Value(proteinPer100g),
      carbsPer100g: carbsPer100g == null && nullToAbsent
          ? const Value.absent()
          : Value(carbsPer100g),
      fatPer100g: fatPer100g == null && nullToAbsent
          ? const Value.absent()
          : Value(fatPer100g),
      source: Value(source),
      portionUnit: portionUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(portionUnit),
      portionCount: portionCount == null && nullToAbsent
          ? const Value.absent()
          : Value(portionCount),
      createdAt: Value(createdAt),
    );
  }

  factory FoodEntryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodEntryRecord(
      id: serializer.fromJson<int>(json['id']),
      day: serializer.fromJson<String>(json['day']),
      mealType: serializer.fromJson<String>(json['mealType']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      quantityGrams: serializer.fromJson<double>(json['quantityGrams']),
      kcalPer100g: serializer.fromJson<double?>(json['kcalPer100g']),
      proteinPer100g: serializer.fromJson<double?>(json['proteinPer100g']),
      carbsPer100g: serializer.fromJson<double?>(json['carbsPer100g']),
      fatPer100g: serializer.fromJson<double?>(json['fatPer100g']),
      source: serializer.fromJson<String>(json['source']),
      portionUnit: serializer.fromJson<String?>(json['portionUnit']),
      portionCount: serializer.fromJson<double?>(json['portionCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'day': serializer.toJson<String>(day),
      'mealType': serializer.toJson<String>(mealType),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'quantityGrams': serializer.toJson<double>(quantityGrams),
      'kcalPer100g': serializer.toJson<double?>(kcalPer100g),
      'proteinPer100g': serializer.toJson<double?>(proteinPer100g),
      'carbsPer100g': serializer.toJson<double?>(carbsPer100g),
      'fatPer100g': serializer.toJson<double?>(fatPer100g),
      'source': serializer.toJson<String>(source),
      'portionUnit': serializer.toJson<String?>(portionUnit),
      'portionCount': serializer.toJson<double?>(portionCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FoodEntryRecord copyWith({
    int? id,
    String? day,
    String? mealType,
    String? name,
    Value<String?> brand = const Value.absent(),
    double? quantityGrams,
    Value<double?> kcalPer100g = const Value.absent(),
    Value<double?> proteinPer100g = const Value.absent(),
    Value<double?> carbsPer100g = const Value.absent(),
    Value<double?> fatPer100g = const Value.absent(),
    String? source,
    Value<String?> portionUnit = const Value.absent(),
    Value<double?> portionCount = const Value.absent(),
    DateTime? createdAt,
  }) => FoodEntryRecord(
    id: id ?? this.id,
    day: day ?? this.day,
    mealType: mealType ?? this.mealType,
    name: name ?? this.name,
    brand: brand.present ? brand.value : this.brand,
    quantityGrams: quantityGrams ?? this.quantityGrams,
    kcalPer100g: kcalPer100g.present ? kcalPer100g.value : this.kcalPer100g,
    proteinPer100g: proteinPer100g.present
        ? proteinPer100g.value
        : this.proteinPer100g,
    carbsPer100g: carbsPer100g.present ? carbsPer100g.value : this.carbsPer100g,
    fatPer100g: fatPer100g.present ? fatPer100g.value : this.fatPer100g,
    source: source ?? this.source,
    portionUnit: portionUnit.present ? portionUnit.value : this.portionUnit,
    portionCount: portionCount.present ? portionCount.value : this.portionCount,
    createdAt: createdAt ?? this.createdAt,
  );
  FoodEntryRecord copyWithCompanion(FoodEntriesCompanion data) {
    return FoodEntryRecord(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      quantityGrams: data.quantityGrams.present
          ? data.quantityGrams.value
          : this.quantityGrams,
      kcalPer100g: data.kcalPer100g.present
          ? data.kcalPer100g.value
          : this.kcalPer100g,
      proteinPer100g: data.proteinPer100g.present
          ? data.proteinPer100g.value
          : this.proteinPer100g,
      carbsPer100g: data.carbsPer100g.present
          ? data.carbsPer100g.value
          : this.carbsPer100g,
      fatPer100g: data.fatPer100g.present
          ? data.fatPer100g.value
          : this.fatPer100g,
      source: data.source.present ? data.source.value : this.source,
      portionUnit: data.portionUnit.present
          ? data.portionUnit.value
          : this.portionUnit,
      portionCount: data.portionCount.present
          ? data.portionCount.value
          : this.portionCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodEntryRecord(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('mealType: $mealType, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('quantityGrams: $quantityGrams, ')
          ..write('kcalPer100g: $kcalPer100g, ')
          ..write('proteinPer100g: $proteinPer100g, ')
          ..write('carbsPer100g: $carbsPer100g, ')
          ..write('fatPer100g: $fatPer100g, ')
          ..write('source: $source, ')
          ..write('portionUnit: $portionUnit, ')
          ..write('portionCount: $portionCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    day,
    mealType,
    name,
    brand,
    quantityGrams,
    kcalPer100g,
    proteinPer100g,
    carbsPer100g,
    fatPer100g,
    source,
    portionUnit,
    portionCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodEntryRecord &&
          other.id == this.id &&
          other.day == this.day &&
          other.mealType == this.mealType &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.quantityGrams == this.quantityGrams &&
          other.kcalPer100g == this.kcalPer100g &&
          other.proteinPer100g == this.proteinPer100g &&
          other.carbsPer100g == this.carbsPer100g &&
          other.fatPer100g == this.fatPer100g &&
          other.source == this.source &&
          other.portionUnit == this.portionUnit &&
          other.portionCount == this.portionCount &&
          other.createdAt == this.createdAt);
}

class FoodEntriesCompanion extends UpdateCompanion<FoodEntryRecord> {
  final Value<int> id;
  final Value<String> day;
  final Value<String> mealType;
  final Value<String> name;
  final Value<String?> brand;
  final Value<double> quantityGrams;
  final Value<double?> kcalPer100g;
  final Value<double?> proteinPer100g;
  final Value<double?> carbsPer100g;
  final Value<double?> fatPer100g;
  final Value<String> source;
  final Value<String?> portionUnit;
  final Value<double?> portionCount;
  final Value<DateTime> createdAt;
  const FoodEntriesCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.mealType = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.quantityGrams = const Value.absent(),
    this.kcalPer100g = const Value.absent(),
    this.proteinPer100g = const Value.absent(),
    this.carbsPer100g = const Value.absent(),
    this.fatPer100g = const Value.absent(),
    this.source = const Value.absent(),
    this.portionUnit = const Value.absent(),
    this.portionCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FoodEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String day,
    required String mealType,
    required String name,
    this.brand = const Value.absent(),
    required double quantityGrams,
    this.kcalPer100g = const Value.absent(),
    this.proteinPer100g = const Value.absent(),
    this.carbsPer100g = const Value.absent(),
    this.fatPer100g = const Value.absent(),
    this.source = const Value.absent(),
    this.portionUnit = const Value.absent(),
    this.portionCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : day = Value(day),
       mealType = Value(mealType),
       name = Value(name),
       quantityGrams = Value(quantityGrams);
  static Insertable<FoodEntryRecord> custom({
    Expression<int>? id,
    Expression<String>? day,
    Expression<String>? mealType,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<double>? quantityGrams,
    Expression<double>? kcalPer100g,
    Expression<double>? proteinPer100g,
    Expression<double>? carbsPer100g,
    Expression<double>? fatPer100g,
    Expression<String>? source,
    Expression<String>? portionUnit,
    Expression<double>? portionCount,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (mealType != null) 'meal_type': mealType,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (quantityGrams != null) 'quantity_grams': quantityGrams,
      if (kcalPer100g != null) 'kcal_per100g': kcalPer100g,
      if (proteinPer100g != null) 'protein_per100g': proteinPer100g,
      if (carbsPer100g != null) 'carbs_per100g': carbsPer100g,
      if (fatPer100g != null) 'fat_per100g': fatPer100g,
      if (source != null) 'source': source,
      if (portionUnit != null) 'portion_unit': portionUnit,
      if (portionCount != null) 'portion_count': portionCount,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FoodEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? day,
    Value<String>? mealType,
    Value<String>? name,
    Value<String?>? brand,
    Value<double>? quantityGrams,
    Value<double?>? kcalPer100g,
    Value<double?>? proteinPer100g,
    Value<double?>? carbsPer100g,
    Value<double?>? fatPer100g,
    Value<String>? source,
    Value<String?>? portionUnit,
    Value<double?>? portionCount,
    Value<DateTime>? createdAt,
  }) {
    return FoodEntriesCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      mealType: mealType ?? this.mealType,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      quantityGrams: quantityGrams ?? this.quantityGrams,
      kcalPer100g: kcalPer100g ?? this.kcalPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      source: source ?? this.source,
      portionUnit: portionUnit ?? this.portionUnit,
      portionCount: portionCount ?? this.portionCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(mealType.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (quantityGrams.present) {
      map['quantity_grams'] = Variable<double>(quantityGrams.value);
    }
    if (kcalPer100g.present) {
      map['kcal_per100g'] = Variable<double>(kcalPer100g.value);
    }
    if (proteinPer100g.present) {
      map['protein_per100g'] = Variable<double>(proteinPer100g.value);
    }
    if (carbsPer100g.present) {
      map['carbs_per100g'] = Variable<double>(carbsPer100g.value);
    }
    if (fatPer100g.present) {
      map['fat_per100g'] = Variable<double>(fatPer100g.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (portionUnit.present) {
      map['portion_unit'] = Variable<String>(portionUnit.value);
    }
    if (portionCount.present) {
      map['portion_count'] = Variable<double>(portionCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodEntriesCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('mealType: $mealType, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('quantityGrams: $quantityGrams, ')
          ..write('kcalPer100g: $kcalPer100g, ')
          ..write('proteinPer100g: $proteinPer100g, ')
          ..write('carbsPer100g: $carbsPer100g, ')
          ..write('fatPer100g: $fatPer100g, ')
          ..write('source: $source, ')
          ..write('portionUnit: $portionUnit, ')
          ..write('portionCount: $portionCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CachedProductsTable extends CachedProducts
    with TableInfo<$CachedProductsTable, CachedProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
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
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalPer100gMeta = const VerificationMeta(
    'kcalPer100g',
  );
  @override
  late final GeneratedColumn<double> kcalPer100g = GeneratedColumn<double>(
    'kcal_per100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteinPer100gMeta = const VerificationMeta(
    'proteinPer100g',
  );
  @override
  late final GeneratedColumn<double> proteinPer100g = GeneratedColumn<double>(
    'protein_per100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbsPer100gMeta = const VerificationMeta(
    'carbsPer100g',
  );
  @override
  late final GeneratedColumn<double> carbsPer100g = GeneratedColumn<double>(
    'carbs_per100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatPer100gMeta = const VerificationMeta(
    'fatPer100g',
  );
  @override
  late final GeneratedColumn<double> fatPer100g = GeneratedColumn<double>(
    'fat_per100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nutriScoreMeta = const VerificationMeta(
    'nutriScore',
  );
  @override
  late final GeneratedColumn<String> nutriScore = GeneratedColumn<String>(
    'nutri_score',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingSizeMeta = const VerificationMeta(
    'servingSize',
  );
  @override
  late final GeneratedColumn<String> servingSize = GeneratedColumn<String>(
    'serving_size',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingGramsMeta = const VerificationMeta(
    'servingGrams',
  );
  @override
  late final GeneratedColumn<double> servingGrams = GeneratedColumn<double>(
    'serving_grams',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packageGramsMeta = const VerificationMeta(
    'packageGrams',
  );
  @override
  late final GeneratedColumn<double> packageGrams = GeneratedColumn<double>(
    'package_grams',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _liquidMeta = const VerificationMeta('liquid');
  @override
  late final GeneratedColumn<bool> liquid = GeneratedColumn<bool>(
    'liquid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("liquid" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastFetchedAtMeta = const VerificationMeta(
    'lastFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastFetchedAt =
      GeneratedColumn<DateTime>(
        'last_fetched_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    barcode,
    name,
    brand,
    quantity,
    kcalPer100g,
    proteinPer100g,
    carbsPer100g,
    fatPer100g,
    nutriScore,
    servingSize,
    servingGrams,
    packageGrams,
    liquid,
    lastFetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedProduct> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    } else if (isInserting) {
      context.missing(_barcodeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('kcal_per100g')) {
      context.handle(
        _kcalPer100gMeta,
        kcalPer100g.isAcceptableOrUnknown(
          data['kcal_per100g']!,
          _kcalPer100gMeta,
        ),
      );
    }
    if (data.containsKey('protein_per100g')) {
      context.handle(
        _proteinPer100gMeta,
        proteinPer100g.isAcceptableOrUnknown(
          data['protein_per100g']!,
          _proteinPer100gMeta,
        ),
      );
    }
    if (data.containsKey('carbs_per100g')) {
      context.handle(
        _carbsPer100gMeta,
        carbsPer100g.isAcceptableOrUnknown(
          data['carbs_per100g']!,
          _carbsPer100gMeta,
        ),
      );
    }
    if (data.containsKey('fat_per100g')) {
      context.handle(
        _fatPer100gMeta,
        fatPer100g.isAcceptableOrUnknown(data['fat_per100g']!, _fatPer100gMeta),
      );
    }
    if (data.containsKey('nutri_score')) {
      context.handle(
        _nutriScoreMeta,
        nutriScore.isAcceptableOrUnknown(data['nutri_score']!, _nutriScoreMeta),
      );
    }
    if (data.containsKey('serving_size')) {
      context.handle(
        _servingSizeMeta,
        servingSize.isAcceptableOrUnknown(
          data['serving_size']!,
          _servingSizeMeta,
        ),
      );
    }
    if (data.containsKey('serving_grams')) {
      context.handle(
        _servingGramsMeta,
        servingGrams.isAcceptableOrUnknown(
          data['serving_grams']!,
          _servingGramsMeta,
        ),
      );
    }
    if (data.containsKey('package_grams')) {
      context.handle(
        _packageGramsMeta,
        packageGrams.isAcceptableOrUnknown(
          data['package_grams']!,
          _packageGramsMeta,
        ),
      );
    }
    if (data.containsKey('liquid')) {
      context.handle(
        _liquidMeta,
        liquid.isAcceptableOrUnknown(data['liquid']!, _liquidMeta),
      );
    }
    if (data.containsKey('last_fetched_at')) {
      context.handle(
        _lastFetchedAtMeta,
        lastFetchedAt.isAcceptableOrUnknown(
          data['last_fetched_at']!,
          _lastFetchedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastFetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {barcode};
  @override
  CachedProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProduct(
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity'],
      ),
      kcalPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal_per100g'],
      ),
      proteinPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_per100g'],
      ),
      carbsPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs_per100g'],
      ),
      fatPer100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_per100g'],
      ),
      nutriScore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nutri_score'],
      ),
      servingSize: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serving_size'],
      ),
      servingGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serving_grams'],
      ),
      packageGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}package_grams'],
      ),
      liquid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}liquid'],
      )!,
      lastFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_fetched_at'],
      )!,
    );
  }

  @override
  $CachedProductsTable createAlias(String alias) {
    return $CachedProductsTable(attachedDatabase, alias);
  }
}

class CachedProduct extends DataClass implements Insertable<CachedProduct> {
  final String barcode;
  final String name;
  final String? brand;
  final String? quantity;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final String? nutriScore;
  final String? servingSize;
  final double? servingGrams;
  final double? packageGrams;
  final bool liquid;
  final DateTime lastFetchedAt;
  const CachedProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.quantity,
    this.kcalPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.nutriScore,
    this.servingSize,
    this.servingGrams,
    this.packageGrams,
    required this.liquid,
    required this.lastFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['barcode'] = Variable<String>(barcode);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<String>(quantity);
    }
    if (!nullToAbsent || kcalPer100g != null) {
      map['kcal_per100g'] = Variable<double>(kcalPer100g);
    }
    if (!nullToAbsent || proteinPer100g != null) {
      map['protein_per100g'] = Variable<double>(proteinPer100g);
    }
    if (!nullToAbsent || carbsPer100g != null) {
      map['carbs_per100g'] = Variable<double>(carbsPer100g);
    }
    if (!nullToAbsent || fatPer100g != null) {
      map['fat_per100g'] = Variable<double>(fatPer100g);
    }
    if (!nullToAbsent || nutriScore != null) {
      map['nutri_score'] = Variable<String>(nutriScore);
    }
    if (!nullToAbsent || servingSize != null) {
      map['serving_size'] = Variable<String>(servingSize);
    }
    if (!nullToAbsent || servingGrams != null) {
      map['serving_grams'] = Variable<double>(servingGrams);
    }
    if (!nullToAbsent || packageGrams != null) {
      map['package_grams'] = Variable<double>(packageGrams);
    }
    map['liquid'] = Variable<bool>(liquid);
    map['last_fetched_at'] = Variable<DateTime>(lastFetchedAt);
    return map;
  }

  CachedProductsCompanion toCompanion(bool nullToAbsent) {
    return CachedProductsCompanion(
      barcode: Value(barcode),
      name: Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      kcalPer100g: kcalPer100g == null && nullToAbsent
          ? const Value.absent()
          : Value(kcalPer100g),
      proteinPer100g: proteinPer100g == null && nullToAbsent
          ? const Value.absent()
          : Value(proteinPer100g),
      carbsPer100g: carbsPer100g == null && nullToAbsent
          ? const Value.absent()
          : Value(carbsPer100g),
      fatPer100g: fatPer100g == null && nullToAbsent
          ? const Value.absent()
          : Value(fatPer100g),
      nutriScore: nutriScore == null && nullToAbsent
          ? const Value.absent()
          : Value(nutriScore),
      servingSize: servingSize == null && nullToAbsent
          ? const Value.absent()
          : Value(servingSize),
      servingGrams: servingGrams == null && nullToAbsent
          ? const Value.absent()
          : Value(servingGrams),
      packageGrams: packageGrams == null && nullToAbsent
          ? const Value.absent()
          : Value(packageGrams),
      liquid: Value(liquid),
      lastFetchedAt: Value(lastFetchedAt),
    );
  }

  factory CachedProduct.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProduct(
      barcode: serializer.fromJson<String>(json['barcode']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      quantity: serializer.fromJson<String?>(json['quantity']),
      kcalPer100g: serializer.fromJson<double?>(json['kcalPer100g']),
      proteinPer100g: serializer.fromJson<double?>(json['proteinPer100g']),
      carbsPer100g: serializer.fromJson<double?>(json['carbsPer100g']),
      fatPer100g: serializer.fromJson<double?>(json['fatPer100g']),
      nutriScore: serializer.fromJson<String?>(json['nutriScore']),
      servingSize: serializer.fromJson<String?>(json['servingSize']),
      servingGrams: serializer.fromJson<double?>(json['servingGrams']),
      packageGrams: serializer.fromJson<double?>(json['packageGrams']),
      liquid: serializer.fromJson<bool>(json['liquid']),
      lastFetchedAt: serializer.fromJson<DateTime>(json['lastFetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'barcode': serializer.toJson<String>(barcode),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'quantity': serializer.toJson<String?>(quantity),
      'kcalPer100g': serializer.toJson<double?>(kcalPer100g),
      'proteinPer100g': serializer.toJson<double?>(proteinPer100g),
      'carbsPer100g': serializer.toJson<double?>(carbsPer100g),
      'fatPer100g': serializer.toJson<double?>(fatPer100g),
      'nutriScore': serializer.toJson<String?>(nutriScore),
      'servingSize': serializer.toJson<String?>(servingSize),
      'servingGrams': serializer.toJson<double?>(servingGrams),
      'packageGrams': serializer.toJson<double?>(packageGrams),
      'liquid': serializer.toJson<bool>(liquid),
      'lastFetchedAt': serializer.toJson<DateTime>(lastFetchedAt),
    };
  }

  CachedProduct copyWith({
    String? barcode,
    String? name,
    Value<String?> brand = const Value.absent(),
    Value<String?> quantity = const Value.absent(),
    Value<double?> kcalPer100g = const Value.absent(),
    Value<double?> proteinPer100g = const Value.absent(),
    Value<double?> carbsPer100g = const Value.absent(),
    Value<double?> fatPer100g = const Value.absent(),
    Value<String?> nutriScore = const Value.absent(),
    Value<String?> servingSize = const Value.absent(),
    Value<double?> servingGrams = const Value.absent(),
    Value<double?> packageGrams = const Value.absent(),
    bool? liquid,
    DateTime? lastFetchedAt,
  }) => CachedProduct(
    barcode: barcode ?? this.barcode,
    name: name ?? this.name,
    brand: brand.present ? brand.value : this.brand,
    quantity: quantity.present ? quantity.value : this.quantity,
    kcalPer100g: kcalPer100g.present ? kcalPer100g.value : this.kcalPer100g,
    proteinPer100g: proteinPer100g.present
        ? proteinPer100g.value
        : this.proteinPer100g,
    carbsPer100g: carbsPer100g.present ? carbsPer100g.value : this.carbsPer100g,
    fatPer100g: fatPer100g.present ? fatPer100g.value : this.fatPer100g,
    nutriScore: nutriScore.present ? nutriScore.value : this.nutriScore,
    servingSize: servingSize.present ? servingSize.value : this.servingSize,
    servingGrams: servingGrams.present ? servingGrams.value : this.servingGrams,
    packageGrams: packageGrams.present ? packageGrams.value : this.packageGrams,
    liquid: liquid ?? this.liquid,
    lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
  );
  CachedProduct copyWithCompanion(CachedProductsCompanion data) {
    return CachedProduct(
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      kcalPer100g: data.kcalPer100g.present
          ? data.kcalPer100g.value
          : this.kcalPer100g,
      proteinPer100g: data.proteinPer100g.present
          ? data.proteinPer100g.value
          : this.proteinPer100g,
      carbsPer100g: data.carbsPer100g.present
          ? data.carbsPer100g.value
          : this.carbsPer100g,
      fatPer100g: data.fatPer100g.present
          ? data.fatPer100g.value
          : this.fatPer100g,
      nutriScore: data.nutriScore.present
          ? data.nutriScore.value
          : this.nutriScore,
      servingSize: data.servingSize.present
          ? data.servingSize.value
          : this.servingSize,
      servingGrams: data.servingGrams.present
          ? data.servingGrams.value
          : this.servingGrams,
      packageGrams: data.packageGrams.present
          ? data.packageGrams.value
          : this.packageGrams,
      liquid: data.liquid.present ? data.liquid.value : this.liquid,
      lastFetchedAt: data.lastFetchedAt.present
          ? data.lastFetchedAt.value
          : this.lastFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProduct(')
          ..write('barcode: $barcode, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('quantity: $quantity, ')
          ..write('kcalPer100g: $kcalPer100g, ')
          ..write('proteinPer100g: $proteinPer100g, ')
          ..write('carbsPer100g: $carbsPer100g, ')
          ..write('fatPer100g: $fatPer100g, ')
          ..write('nutriScore: $nutriScore, ')
          ..write('servingSize: $servingSize, ')
          ..write('servingGrams: $servingGrams, ')
          ..write('packageGrams: $packageGrams, ')
          ..write('liquid: $liquid, ')
          ..write('lastFetchedAt: $lastFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    barcode,
    name,
    brand,
    quantity,
    kcalPer100g,
    proteinPer100g,
    carbsPer100g,
    fatPer100g,
    nutriScore,
    servingSize,
    servingGrams,
    packageGrams,
    liquid,
    lastFetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProduct &&
          other.barcode == this.barcode &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.quantity == this.quantity &&
          other.kcalPer100g == this.kcalPer100g &&
          other.proteinPer100g == this.proteinPer100g &&
          other.carbsPer100g == this.carbsPer100g &&
          other.fatPer100g == this.fatPer100g &&
          other.nutriScore == this.nutriScore &&
          other.servingSize == this.servingSize &&
          other.servingGrams == this.servingGrams &&
          other.packageGrams == this.packageGrams &&
          other.liquid == this.liquid &&
          other.lastFetchedAt == this.lastFetchedAt);
}

class CachedProductsCompanion extends UpdateCompanion<CachedProduct> {
  final Value<String> barcode;
  final Value<String> name;
  final Value<String?> brand;
  final Value<String?> quantity;
  final Value<double?> kcalPer100g;
  final Value<double?> proteinPer100g;
  final Value<double?> carbsPer100g;
  final Value<double?> fatPer100g;
  final Value<String?> nutriScore;
  final Value<String?> servingSize;
  final Value<double?> servingGrams;
  final Value<double?> packageGrams;
  final Value<bool> liquid;
  final Value<DateTime> lastFetchedAt;
  final Value<int> rowid;
  const CachedProductsCompanion({
    this.barcode = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.quantity = const Value.absent(),
    this.kcalPer100g = const Value.absent(),
    this.proteinPer100g = const Value.absent(),
    this.carbsPer100g = const Value.absent(),
    this.fatPer100g = const Value.absent(),
    this.nutriScore = const Value.absent(),
    this.servingSize = const Value.absent(),
    this.servingGrams = const Value.absent(),
    this.packageGrams = const Value.absent(),
    this.liquid = const Value.absent(),
    this.lastFetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProductsCompanion.insert({
    required String barcode,
    required String name,
    this.brand = const Value.absent(),
    this.quantity = const Value.absent(),
    this.kcalPer100g = const Value.absent(),
    this.proteinPer100g = const Value.absent(),
    this.carbsPer100g = const Value.absent(),
    this.fatPer100g = const Value.absent(),
    this.nutriScore = const Value.absent(),
    this.servingSize = const Value.absent(),
    this.servingGrams = const Value.absent(),
    this.packageGrams = const Value.absent(),
    this.liquid = const Value.absent(),
    required DateTime lastFetchedAt,
    this.rowid = const Value.absent(),
  }) : barcode = Value(barcode),
       name = Value(name),
       lastFetchedAt = Value(lastFetchedAt);
  static Insertable<CachedProduct> custom({
    Expression<String>? barcode,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? quantity,
    Expression<double>? kcalPer100g,
    Expression<double>? proteinPer100g,
    Expression<double>? carbsPer100g,
    Expression<double>? fatPer100g,
    Expression<String>? nutriScore,
    Expression<String>? servingSize,
    Expression<double>? servingGrams,
    Expression<double>? packageGrams,
    Expression<bool>? liquid,
    Expression<DateTime>? lastFetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (barcode != null) 'barcode': barcode,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (quantity != null) 'quantity': quantity,
      if (kcalPer100g != null) 'kcal_per100g': kcalPer100g,
      if (proteinPer100g != null) 'protein_per100g': proteinPer100g,
      if (carbsPer100g != null) 'carbs_per100g': carbsPer100g,
      if (fatPer100g != null) 'fat_per100g': fatPer100g,
      if (nutriScore != null) 'nutri_score': nutriScore,
      if (servingSize != null) 'serving_size': servingSize,
      if (servingGrams != null) 'serving_grams': servingGrams,
      if (packageGrams != null) 'package_grams': packageGrams,
      if (liquid != null) 'liquid': liquid,
      if (lastFetchedAt != null) 'last_fetched_at': lastFetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProductsCompanion copyWith({
    Value<String>? barcode,
    Value<String>? name,
    Value<String?>? brand,
    Value<String?>? quantity,
    Value<double?>? kcalPer100g,
    Value<double?>? proteinPer100g,
    Value<double?>? carbsPer100g,
    Value<double?>? fatPer100g,
    Value<String?>? nutriScore,
    Value<String?>? servingSize,
    Value<double?>? servingGrams,
    Value<double?>? packageGrams,
    Value<bool>? liquid,
    Value<DateTime>? lastFetchedAt,
    Value<int>? rowid,
  }) {
    return CachedProductsCompanion(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      quantity: quantity ?? this.quantity,
      kcalPer100g: kcalPer100g ?? this.kcalPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      nutriScore: nutriScore ?? this.nutriScore,
      servingSize: servingSize ?? this.servingSize,
      servingGrams: servingGrams ?? this.servingGrams,
      packageGrams: packageGrams ?? this.packageGrams,
      liquid: liquid ?? this.liquid,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (kcalPer100g.present) {
      map['kcal_per100g'] = Variable<double>(kcalPer100g.value);
    }
    if (proteinPer100g.present) {
      map['protein_per100g'] = Variable<double>(proteinPer100g.value);
    }
    if (carbsPer100g.present) {
      map['carbs_per100g'] = Variable<double>(carbsPer100g.value);
    }
    if (fatPer100g.present) {
      map['fat_per100g'] = Variable<double>(fatPer100g.value);
    }
    if (nutriScore.present) {
      map['nutri_score'] = Variable<String>(nutriScore.value);
    }
    if (servingSize.present) {
      map['serving_size'] = Variable<String>(servingSize.value);
    }
    if (servingGrams.present) {
      map['serving_grams'] = Variable<double>(servingGrams.value);
    }
    if (packageGrams.present) {
      map['package_grams'] = Variable<double>(packageGrams.value);
    }
    if (liquid.present) {
      map['liquid'] = Variable<bool>(liquid.value);
    }
    if (lastFetchedAt.present) {
      map['last_fetched_at'] = Variable<DateTime>(lastFetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProductsCompanion(')
          ..write('barcode: $barcode, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('quantity: $quantity, ')
          ..write('kcalPer100g: $kcalPer100g, ')
          ..write('proteinPer100g: $proteinPer100g, ')
          ..write('carbsPer100g: $carbsPer100g, ')
          ..write('fatPer100g: $fatPer100g, ')
          ..write('nutriScore: $nutriScore, ')
          ..write('servingSize: $servingSize, ')
          ..write('servingGrams: $servingGrams, ')
          ..write('packageGrams: $packageGrams, ')
          ..write('liquid: $liquid, ')
          ..write('lastFetchedAt: $lastFetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutPlansTable extends WorkoutPlans
    with TableInfo<$WorkoutPlansTable, WorkoutPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<String> goal = GeneratedColumn<String>(
    'goal',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, goal, active, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('goal')) {
      context.handle(
        _goalMeta,
        goal.isAcceptableOrUnknown(data['goal']!, _goalMeta),
      );
    } else if (isInserting) {
      context.missing(_goalMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutPlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      goal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WorkoutPlansTable createAlias(String alias) {
    return $WorkoutPlansTable(attachedDatabase, alias);
  }
}

class WorkoutPlan extends DataClass implements Insertable<WorkoutPlan> {
  final int id;
  final String title;
  final String goal;
  final bool active;
  final DateTime createdAt;
  const WorkoutPlan({
    required this.id,
    required this.title,
    required this.goal,
    required this.active,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['goal'] = Variable<String>(goal);
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WorkoutPlansCompanion toCompanion(bool nullToAbsent) {
    return WorkoutPlansCompanion(
      id: Value(id),
      title: Value(title),
      goal: Value(goal),
      active: Value(active),
      createdAt: Value(createdAt),
    );
  }

  factory WorkoutPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutPlan(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      goal: serializer.fromJson<String>(json['goal']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'goal': serializer.toJson<String>(goal),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WorkoutPlan copyWith({
    int? id,
    String? title,
    String? goal,
    bool? active,
    DateTime? createdAt,
  }) => WorkoutPlan(
    id: id ?? this.id,
    title: title ?? this.title,
    goal: goal ?? this.goal,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
  );
  WorkoutPlan copyWithCompanion(WorkoutPlansCompanion data) {
    return WorkoutPlan(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      goal: data.goal.present ? data.goal.value : this.goal,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutPlan(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('goal: $goal, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, goal, active, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutPlan &&
          other.id == this.id &&
          other.title == this.title &&
          other.goal == this.goal &&
          other.active == this.active &&
          other.createdAt == this.createdAt);
}

class WorkoutPlansCompanion extends UpdateCompanion<WorkoutPlan> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> goal;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  const WorkoutPlansCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.goal = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WorkoutPlansCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String goal,
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : title = Value(title),
       goal = Value(goal);
  static Insertable<WorkoutPlan> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? goal,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (goal != null) 'goal': goal,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WorkoutPlansCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? goal,
    Value<bool>? active,
    Value<DateTime>? createdAt,
  }) {
    return WorkoutPlansCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      goal: goal ?? this.goal,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (goal.present) {
      map['goal'] = Variable<String>(goal.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutPlansCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('goal: $goal, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $WorkoutDaysTable extends WorkoutDays
    with TableInfo<$WorkoutDaysTable, WorkoutDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayNumberMeta = const VerificationMeta(
    'dayNumber',
  );
  @override
  late final GeneratedColumn<int> dayNumber = GeneratedColumn<int>(
    'day_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namePtMeta = const VerificationMeta('namePt');
  @override
  late final GeneratedColumn<String> namePt = GeneratedColumn<String>(
    'name_pt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameEnMeta = const VerificationMeta('nameEn');
  @override
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
    'name_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekdayMeta = const VerificationMeta(
    'weekday',
  );
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
    'weekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    dayNumber,
    namePt,
    nameEn,
    weekday,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('day_number')) {
      context.handle(
        _dayNumberMeta,
        dayNumber.isAcceptableOrUnknown(data['day_number']!, _dayNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_dayNumberMeta);
    }
    if (data.containsKey('name_pt')) {
      context.handle(
        _namePtMeta,
        namePt.isAcceptableOrUnknown(data['name_pt']!, _namePtMeta),
      );
    } else if (isInserting) {
      context.missing(_namePtMeta);
    }
    if (data.containsKey('name_en')) {
      context.handle(
        _nameEnMeta,
        nameEn.isAcceptableOrUnknown(data['name_en']!, _nameEnMeta),
      );
    } else if (isInserting) {
      context.missing(_nameEnMeta);
    }
    if (data.containsKey('weekday')) {
      context.handle(
        _weekdayMeta,
        weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutDay(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plan_id'],
      )!,
      dayNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_number'],
      )!,
      namePt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_pt'],
      )!,
      nameEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_en'],
      )!,
      weekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday'],
      ),
    );
  }

  @override
  $WorkoutDaysTable createAlias(String alias) {
    return $WorkoutDaysTable(attachedDatabase, alias);
  }
}

class WorkoutDay extends DataClass implements Insertable<WorkoutDay> {
  final int id;
  final int planId;
  final int dayNumber;
  final String namePt;
  final String nameEn;

  /// ISO weekday this workout is scheduled on (1 = Monday … 7 = Sunday).
  final int? weekday;
  const WorkoutDay({
    required this.id,
    required this.planId,
    required this.dayNumber,
    required this.namePt,
    required this.nameEn,
    this.weekday,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['plan_id'] = Variable<int>(planId);
    map['day_number'] = Variable<int>(dayNumber);
    map['name_pt'] = Variable<String>(namePt);
    map['name_en'] = Variable<String>(nameEn);
    if (!nullToAbsent || weekday != null) {
      map['weekday'] = Variable<int>(weekday);
    }
    return map;
  }

  WorkoutDaysCompanion toCompanion(bool nullToAbsent) {
    return WorkoutDaysCompanion(
      id: Value(id),
      planId: Value(planId),
      dayNumber: Value(dayNumber),
      namePt: Value(namePt),
      nameEn: Value(nameEn),
      weekday: weekday == null && nullToAbsent
          ? const Value.absent()
          : Value(weekday),
    );
  }

  factory WorkoutDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutDay(
      id: serializer.fromJson<int>(json['id']),
      planId: serializer.fromJson<int>(json['planId']),
      dayNumber: serializer.fromJson<int>(json['dayNumber']),
      namePt: serializer.fromJson<String>(json['namePt']),
      nameEn: serializer.fromJson<String>(json['nameEn']),
      weekday: serializer.fromJson<int?>(json['weekday']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'planId': serializer.toJson<int>(planId),
      'dayNumber': serializer.toJson<int>(dayNumber),
      'namePt': serializer.toJson<String>(namePt),
      'nameEn': serializer.toJson<String>(nameEn),
      'weekday': serializer.toJson<int?>(weekday),
    };
  }

  WorkoutDay copyWith({
    int? id,
    int? planId,
    int? dayNumber,
    String? namePt,
    String? nameEn,
    Value<int?> weekday = const Value.absent(),
  }) => WorkoutDay(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    dayNumber: dayNumber ?? this.dayNumber,
    namePt: namePt ?? this.namePt,
    nameEn: nameEn ?? this.nameEn,
    weekday: weekday.present ? weekday.value : this.weekday,
  );
  WorkoutDay copyWithCompanion(WorkoutDaysCompanion data) {
    return WorkoutDay(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      dayNumber: data.dayNumber.present ? data.dayNumber.value : this.dayNumber,
      namePt: data.namePt.present ? data.namePt.value : this.namePt,
      nameEn: data.nameEn.present ? data.nameEn.value : this.nameEn,
      weekday: data.weekday.present ? data.weekday.value : this.weekday,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutDay(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('dayNumber: $dayNumber, ')
          ..write('namePt: $namePt, ')
          ..write('nameEn: $nameEn, ')
          ..write('weekday: $weekday')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, planId, dayNumber, namePt, nameEn, weekday);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutDay &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.dayNumber == this.dayNumber &&
          other.namePt == this.namePt &&
          other.nameEn == this.nameEn &&
          other.weekday == this.weekday);
}

class WorkoutDaysCompanion extends UpdateCompanion<WorkoutDay> {
  final Value<int> id;
  final Value<int> planId;
  final Value<int> dayNumber;
  final Value<String> namePt;
  final Value<String> nameEn;
  final Value<int?> weekday;
  const WorkoutDaysCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.dayNumber = const Value.absent(),
    this.namePt = const Value.absent(),
    this.nameEn = const Value.absent(),
    this.weekday = const Value.absent(),
  });
  WorkoutDaysCompanion.insert({
    this.id = const Value.absent(),
    required int planId,
    required int dayNumber,
    required String namePt,
    required String nameEn,
    this.weekday = const Value.absent(),
  }) : planId = Value(planId),
       dayNumber = Value(dayNumber),
       namePt = Value(namePt),
       nameEn = Value(nameEn);
  static Insertable<WorkoutDay> custom({
    Expression<int>? id,
    Expression<int>? planId,
    Expression<int>? dayNumber,
    Expression<String>? namePt,
    Expression<String>? nameEn,
    Expression<int>? weekday,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (dayNumber != null) 'day_number': dayNumber,
      if (namePt != null) 'name_pt': namePt,
      if (nameEn != null) 'name_en': nameEn,
      if (weekday != null) 'weekday': weekday,
    });
  }

  WorkoutDaysCompanion copyWith({
    Value<int>? id,
    Value<int>? planId,
    Value<int>? dayNumber,
    Value<String>? namePt,
    Value<String>? nameEn,
    Value<int?>? weekday,
  }) {
    return WorkoutDaysCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      dayNumber: dayNumber ?? this.dayNumber,
      namePt: namePt ?? this.namePt,
      nameEn: nameEn ?? this.nameEn,
      weekday: weekday ?? this.weekday,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (dayNumber.present) {
      map['day_number'] = Variable<int>(dayNumber.value);
    }
    if (namePt.present) {
      map['name_pt'] = Variable<String>(namePt.value);
    }
    if (nameEn.present) {
      map['name_en'] = Variable<String>(nameEn.value);
    }
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutDaysCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('dayNumber: $dayNumber, ')
          ..write('namePt: $namePt, ')
          ..write('nameEn: $nameEn, ')
          ..write('weekday: $weekday')
          ..write(')'))
        .toString();
  }
}

class $ExerciseCatalogTable extends ExerciseCatalog
    with TableInfo<$ExerciseCatalogTable, ExerciseCatalogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseCatalogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _exerciseKeyMeta = const VerificationMeta(
    'exerciseKey',
  );
  @override
  late final GeneratedColumn<String> exerciseKey = GeneratedColumn<String>(
    'exercise_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namePtMeta = const VerificationMeta('namePt');
  @override
  late final GeneratedColumn<String> namePt = GeneratedColumn<String>(
    'name_pt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameEnMeta = const VerificationMeta('nameEn');
  @override
  late final GeneratedColumn<String> nameEn = GeneratedColumn<String>(
    'name_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _muscleGroupMeta = const VerificationMeta(
    'muscleGroup',
  );
  @override
  late final GeneratedColumn<String> muscleGroup = GeneratedColumn<String>(
    'muscle_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instructionsPtMeta = const VerificationMeta(
    'instructionsPt',
  );
  @override
  late final GeneratedColumn<String> instructionsPt = GeneratedColumn<String>(
    'instructions_pt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instructionsEnMeta = const VerificationMeta(
    'instructionsEn',
  );
  @override
  late final GeneratedColumn<String> instructionsEn = GeneratedColumn<String>(
    'instructions_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentMeta = const VerificationMeta(
    'equipment',
  );
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    exerciseKey,
    namePt,
    nameEn,
    muscleGroup,
    instructionsPt,
    instructionsEn,
    equipment,
    difficulty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_catalog';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseCatalogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('exercise_key')) {
      context.handle(
        _exerciseKeyMeta,
        exerciseKey.isAcceptableOrUnknown(
          data['exercise_key']!,
          _exerciseKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseKeyMeta);
    }
    if (data.containsKey('name_pt')) {
      context.handle(
        _namePtMeta,
        namePt.isAcceptableOrUnknown(data['name_pt']!, _namePtMeta),
      );
    } else if (isInserting) {
      context.missing(_namePtMeta);
    }
    if (data.containsKey('name_en')) {
      context.handle(
        _nameEnMeta,
        nameEn.isAcceptableOrUnknown(data['name_en']!, _nameEnMeta),
      );
    } else if (isInserting) {
      context.missing(_nameEnMeta);
    }
    if (data.containsKey('muscle_group')) {
      context.handle(
        _muscleGroupMeta,
        muscleGroup.isAcceptableOrUnknown(
          data['muscle_group']!,
          _muscleGroupMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_muscleGroupMeta);
    }
    if (data.containsKey('instructions_pt')) {
      context.handle(
        _instructionsPtMeta,
        instructionsPt.isAcceptableOrUnknown(
          data['instructions_pt']!,
          _instructionsPtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instructionsPtMeta);
    }
    if (data.containsKey('instructions_en')) {
      context.handle(
        _instructionsEnMeta,
        instructionsEn.isAcceptableOrUnknown(
          data['instructions_en']!,
          _instructionsEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instructionsEnMeta);
    }
    if (data.containsKey('equipment')) {
      context.handle(
        _equipmentMeta,
        equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta),
      );
    } else if (isInserting) {
      context.missing(_equipmentMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {exerciseKey};
  @override
  ExerciseCatalogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseCatalogData(
      exerciseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_key'],
      )!,
      namePt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_pt'],
      )!,
      nameEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_en'],
      )!,
      muscleGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscle_group'],
      )!,
      instructionsPt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instructions_pt'],
      )!,
      instructionsEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instructions_en'],
      )!,
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      )!,
    );
  }

  @override
  $ExerciseCatalogTable createAlias(String alias) {
    return $ExerciseCatalogTable(attachedDatabase, alias);
  }
}

class ExerciseCatalogData extends DataClass
    implements Insertable<ExerciseCatalogData> {
  final String exerciseKey;
  final String namePt;
  final String nameEn;
  final String muscleGroup;
  final String instructionsPt;
  final String instructionsEn;
  final String equipment;
  final String difficulty;
  const ExerciseCatalogData({
    required this.exerciseKey,
    required this.namePt,
    required this.nameEn,
    required this.muscleGroup,
    required this.instructionsPt,
    required this.instructionsEn,
    required this.equipment,
    required this.difficulty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['exercise_key'] = Variable<String>(exerciseKey);
    map['name_pt'] = Variable<String>(namePt);
    map['name_en'] = Variable<String>(nameEn);
    map['muscle_group'] = Variable<String>(muscleGroup);
    map['instructions_pt'] = Variable<String>(instructionsPt);
    map['instructions_en'] = Variable<String>(instructionsEn);
    map['equipment'] = Variable<String>(equipment);
    map['difficulty'] = Variable<String>(difficulty);
    return map;
  }

  ExerciseCatalogCompanion toCompanion(bool nullToAbsent) {
    return ExerciseCatalogCompanion(
      exerciseKey: Value(exerciseKey),
      namePt: Value(namePt),
      nameEn: Value(nameEn),
      muscleGroup: Value(muscleGroup),
      instructionsPt: Value(instructionsPt),
      instructionsEn: Value(instructionsEn),
      equipment: Value(equipment),
      difficulty: Value(difficulty),
    );
  }

  factory ExerciseCatalogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseCatalogData(
      exerciseKey: serializer.fromJson<String>(json['exerciseKey']),
      namePt: serializer.fromJson<String>(json['namePt']),
      nameEn: serializer.fromJson<String>(json['nameEn']),
      muscleGroup: serializer.fromJson<String>(json['muscleGroup']),
      instructionsPt: serializer.fromJson<String>(json['instructionsPt']),
      instructionsEn: serializer.fromJson<String>(json['instructionsEn']),
      equipment: serializer.fromJson<String>(json['equipment']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'exerciseKey': serializer.toJson<String>(exerciseKey),
      'namePt': serializer.toJson<String>(namePt),
      'nameEn': serializer.toJson<String>(nameEn),
      'muscleGroup': serializer.toJson<String>(muscleGroup),
      'instructionsPt': serializer.toJson<String>(instructionsPt),
      'instructionsEn': serializer.toJson<String>(instructionsEn),
      'equipment': serializer.toJson<String>(equipment),
      'difficulty': serializer.toJson<String>(difficulty),
    };
  }

  ExerciseCatalogData copyWith({
    String? exerciseKey,
    String? namePt,
    String? nameEn,
    String? muscleGroup,
    String? instructionsPt,
    String? instructionsEn,
    String? equipment,
    String? difficulty,
  }) => ExerciseCatalogData(
    exerciseKey: exerciseKey ?? this.exerciseKey,
    namePt: namePt ?? this.namePt,
    nameEn: nameEn ?? this.nameEn,
    muscleGroup: muscleGroup ?? this.muscleGroup,
    instructionsPt: instructionsPt ?? this.instructionsPt,
    instructionsEn: instructionsEn ?? this.instructionsEn,
    equipment: equipment ?? this.equipment,
    difficulty: difficulty ?? this.difficulty,
  );
  ExerciseCatalogData copyWithCompanion(ExerciseCatalogCompanion data) {
    return ExerciseCatalogData(
      exerciseKey: data.exerciseKey.present
          ? data.exerciseKey.value
          : this.exerciseKey,
      namePt: data.namePt.present ? data.namePt.value : this.namePt,
      nameEn: data.nameEn.present ? data.nameEn.value : this.nameEn,
      muscleGroup: data.muscleGroup.present
          ? data.muscleGroup.value
          : this.muscleGroup,
      instructionsPt: data.instructionsPt.present
          ? data.instructionsPt.value
          : this.instructionsPt,
      instructionsEn: data.instructionsEn.present
          ? data.instructionsEn.value
          : this.instructionsEn,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseCatalogData(')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('namePt: $namePt, ')
          ..write('nameEn: $nameEn, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('instructionsPt: $instructionsPt, ')
          ..write('instructionsEn: $instructionsEn, ')
          ..write('equipment: $equipment, ')
          ..write('difficulty: $difficulty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    exerciseKey,
    namePt,
    nameEn,
    muscleGroup,
    instructionsPt,
    instructionsEn,
    equipment,
    difficulty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseCatalogData &&
          other.exerciseKey == this.exerciseKey &&
          other.namePt == this.namePt &&
          other.nameEn == this.nameEn &&
          other.muscleGroup == this.muscleGroup &&
          other.instructionsPt == this.instructionsPt &&
          other.instructionsEn == this.instructionsEn &&
          other.equipment == this.equipment &&
          other.difficulty == this.difficulty);
}

class ExerciseCatalogCompanion extends UpdateCompanion<ExerciseCatalogData> {
  final Value<String> exerciseKey;
  final Value<String> namePt;
  final Value<String> nameEn;
  final Value<String> muscleGroup;
  final Value<String> instructionsPt;
  final Value<String> instructionsEn;
  final Value<String> equipment;
  final Value<String> difficulty;
  final Value<int> rowid;
  const ExerciseCatalogCompanion({
    this.exerciseKey = const Value.absent(),
    this.namePt = const Value.absent(),
    this.nameEn = const Value.absent(),
    this.muscleGroup = const Value.absent(),
    this.instructionsPt = const Value.absent(),
    this.instructionsEn = const Value.absent(),
    this.equipment = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseCatalogCompanion.insert({
    required String exerciseKey,
    required String namePt,
    required String nameEn,
    required String muscleGroup,
    required String instructionsPt,
    required String instructionsEn,
    required String equipment,
    required String difficulty,
    this.rowid = const Value.absent(),
  }) : exerciseKey = Value(exerciseKey),
       namePt = Value(namePt),
       nameEn = Value(nameEn),
       muscleGroup = Value(muscleGroup),
       instructionsPt = Value(instructionsPt),
       instructionsEn = Value(instructionsEn),
       equipment = Value(equipment),
       difficulty = Value(difficulty);
  static Insertable<ExerciseCatalogData> custom({
    Expression<String>? exerciseKey,
    Expression<String>? namePt,
    Expression<String>? nameEn,
    Expression<String>? muscleGroup,
    Expression<String>? instructionsPt,
    Expression<String>? instructionsEn,
    Expression<String>? equipment,
    Expression<String>? difficulty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (exerciseKey != null) 'exercise_key': exerciseKey,
      if (namePt != null) 'name_pt': namePt,
      if (nameEn != null) 'name_en': nameEn,
      if (muscleGroup != null) 'muscle_group': muscleGroup,
      if (instructionsPt != null) 'instructions_pt': instructionsPt,
      if (instructionsEn != null) 'instructions_en': instructionsEn,
      if (equipment != null) 'equipment': equipment,
      if (difficulty != null) 'difficulty': difficulty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseCatalogCompanion copyWith({
    Value<String>? exerciseKey,
    Value<String>? namePt,
    Value<String>? nameEn,
    Value<String>? muscleGroup,
    Value<String>? instructionsPt,
    Value<String>? instructionsEn,
    Value<String>? equipment,
    Value<String>? difficulty,
    Value<int>? rowid,
  }) {
    return ExerciseCatalogCompanion(
      exerciseKey: exerciseKey ?? this.exerciseKey,
      namePt: namePt ?? this.namePt,
      nameEn: nameEn ?? this.nameEn,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      instructionsPt: instructionsPt ?? this.instructionsPt,
      instructionsEn: instructionsEn ?? this.instructionsEn,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (exerciseKey.present) {
      map['exercise_key'] = Variable<String>(exerciseKey.value);
    }
    if (namePt.present) {
      map['name_pt'] = Variable<String>(namePt.value);
    }
    if (nameEn.present) {
      map['name_en'] = Variable<String>(nameEn.value);
    }
    if (muscleGroup.present) {
      map['muscle_group'] = Variable<String>(muscleGroup.value);
    }
    if (instructionsPt.present) {
      map['instructions_pt'] = Variable<String>(instructionsPt.value);
    }
    if (instructionsEn.present) {
      map['instructions_en'] = Variable<String>(instructionsEn.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseCatalogCompanion(')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('namePt: $namePt, ')
          ..write('nameEn: $nameEn, ')
          ..write('muscleGroup: $muscleGroup, ')
          ..write('instructionsPt: $instructionsPt, ')
          ..write('instructionsEn: $instructionsEn, ')
          ..write('equipment: $equipment, ')
          ..write('difficulty: $difficulty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanExercisesTable extends PlanExercises
    with TableInfo<$PlanExercisesTable, PlanExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  @override
  late final GeneratedColumn<int> dayId = GeneratedColumn<int>(
    'day_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseKeyMeta = const VerificationMeta(
    'exerciseKey',
  );
  @override
  late final GeneratedColumn<String> exerciseKey = GeneratedColumn<String>(
    'exercise_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _setsMeta = const VerificationMeta('sets');
  @override
  late final GeneratedColumn<int> sets = GeneratedColumn<int>(
    'sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _repTargetMeta = const VerificationMeta(
    'repTarget',
  );
  @override
  late final GeneratedColumn<int> repTarget = GeneratedColumn<int>(
    'rep_target',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(90),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dayId,
    exerciseKey,
    sortOrder,
    sets,
    repTarget,
    restSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanExercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day_id')) {
      context.handle(
        _dayIdMeta,
        dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('exercise_key')) {
      context.handle(
        _exerciseKeyMeta,
        exerciseKey.isAcceptableOrUnknown(
          data['exercise_key']!,
          _exerciseKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseKeyMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('sets')) {
      context.handle(
        _setsMeta,
        sets.isAcceptableOrUnknown(data['sets']!, _setsMeta),
      );
    }
    if (data.containsKey('rep_target')) {
      context.handle(
        _repTargetMeta,
        repTarget.isAcceptableOrUnknown(data['rep_target']!, _repTargetMeta),
      );
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanExercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dayId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_id'],
      )!,
      exerciseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_key'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      sets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sets'],
      )!,
      repTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rep_target'],
      )!,
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      )!,
    );
  }

  @override
  $PlanExercisesTable createAlias(String alias) {
    return $PlanExercisesTable(attachedDatabase, alias);
  }
}

class PlanExercise extends DataClass implements Insertable<PlanExercise> {
  final int id;
  final int dayId;
  final String exerciseKey;
  final int sortOrder;
  final int sets;
  final int repTarget;
  final int restSeconds;
  const PlanExercise({
    required this.id,
    required this.dayId,
    required this.exerciseKey,
    required this.sortOrder,
    required this.sets,
    required this.repTarget,
    required this.restSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day_id'] = Variable<int>(dayId);
    map['exercise_key'] = Variable<String>(exerciseKey);
    map['sort_order'] = Variable<int>(sortOrder);
    map['sets'] = Variable<int>(sets);
    map['rep_target'] = Variable<int>(repTarget);
    map['rest_seconds'] = Variable<int>(restSeconds);
    return map;
  }

  PlanExercisesCompanion toCompanion(bool nullToAbsent) {
    return PlanExercisesCompanion(
      id: Value(id),
      dayId: Value(dayId),
      exerciseKey: Value(exerciseKey),
      sortOrder: Value(sortOrder),
      sets: Value(sets),
      repTarget: Value(repTarget),
      restSeconds: Value(restSeconds),
    );
  }

  factory PlanExercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanExercise(
      id: serializer.fromJson<int>(json['id']),
      dayId: serializer.fromJson<int>(json['dayId']),
      exerciseKey: serializer.fromJson<String>(json['exerciseKey']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      sets: serializer.fromJson<int>(json['sets']),
      repTarget: serializer.fromJson<int>(json['repTarget']),
      restSeconds: serializer.fromJson<int>(json['restSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dayId': serializer.toJson<int>(dayId),
      'exerciseKey': serializer.toJson<String>(exerciseKey),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'sets': serializer.toJson<int>(sets),
      'repTarget': serializer.toJson<int>(repTarget),
      'restSeconds': serializer.toJson<int>(restSeconds),
    };
  }

  PlanExercise copyWith({
    int? id,
    int? dayId,
    String? exerciseKey,
    int? sortOrder,
    int? sets,
    int? repTarget,
    int? restSeconds,
  }) => PlanExercise(
    id: id ?? this.id,
    dayId: dayId ?? this.dayId,
    exerciseKey: exerciseKey ?? this.exerciseKey,
    sortOrder: sortOrder ?? this.sortOrder,
    sets: sets ?? this.sets,
    repTarget: repTarget ?? this.repTarget,
    restSeconds: restSeconds ?? this.restSeconds,
  );
  PlanExercise copyWithCompanion(PlanExercisesCompanion data) {
    return PlanExercise(
      id: data.id.present ? data.id.value : this.id,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      exerciseKey: data.exerciseKey.present
          ? data.exerciseKey.value
          : this.exerciseKey,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      sets: data.sets.present ? data.sets.value : this.sets,
      repTarget: data.repTarget.present ? data.repTarget.value : this.repTarget,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanExercise(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sets: $sets, ')
          ..write('repTarget: $repTarget, ')
          ..write('restSeconds: $restSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dayId,
    exerciseKey,
    sortOrder,
    sets,
    repTarget,
    restSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanExercise &&
          other.id == this.id &&
          other.dayId == this.dayId &&
          other.exerciseKey == this.exerciseKey &&
          other.sortOrder == this.sortOrder &&
          other.sets == this.sets &&
          other.repTarget == this.repTarget &&
          other.restSeconds == this.restSeconds);
}

class PlanExercisesCompanion extends UpdateCompanion<PlanExercise> {
  final Value<int> id;
  final Value<int> dayId;
  final Value<String> exerciseKey;
  final Value<int> sortOrder;
  final Value<int> sets;
  final Value<int> repTarget;
  final Value<int> restSeconds;
  const PlanExercisesCompanion({
    this.id = const Value.absent(),
    this.dayId = const Value.absent(),
    this.exerciseKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.sets = const Value.absent(),
    this.repTarget = const Value.absent(),
    this.restSeconds = const Value.absent(),
  });
  PlanExercisesCompanion.insert({
    this.id = const Value.absent(),
    required int dayId,
    required String exerciseKey,
    required int sortOrder,
    this.sets = const Value.absent(),
    this.repTarget = const Value.absent(),
    this.restSeconds = const Value.absent(),
  }) : dayId = Value(dayId),
       exerciseKey = Value(exerciseKey),
       sortOrder = Value(sortOrder);
  static Insertable<PlanExercise> custom({
    Expression<int>? id,
    Expression<int>? dayId,
    Expression<String>? exerciseKey,
    Expression<int>? sortOrder,
    Expression<int>? sets,
    Expression<int>? repTarget,
    Expression<int>? restSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayId != null) 'day_id': dayId,
      if (exerciseKey != null) 'exercise_key': exerciseKey,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (sets != null) 'sets': sets,
      if (repTarget != null) 'rep_target': repTarget,
      if (restSeconds != null) 'rest_seconds': restSeconds,
    });
  }

  PlanExercisesCompanion copyWith({
    Value<int>? id,
    Value<int>? dayId,
    Value<String>? exerciseKey,
    Value<int>? sortOrder,
    Value<int>? sets,
    Value<int>? repTarget,
    Value<int>? restSeconds,
  }) {
    return PlanExercisesCompanion(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      exerciseKey: exerciseKey ?? this.exerciseKey,
      sortOrder: sortOrder ?? this.sortOrder,
      sets: sets ?? this.sets,
      repTarget: repTarget ?? this.repTarget,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<int>(dayId.value);
    }
    if (exerciseKey.present) {
      map['exercise_key'] = Variable<String>(exerciseKey.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (sets.present) {
      map['sets'] = Variable<int>(sets.value);
    }
    if (repTarget.present) {
      map['rep_target'] = Variable<int>(repTarget.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanExercisesCompanion(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sets: $sets, ')
          ..write('repTarget: $repTarget, ')
          ..write('restSeconds: $restSeconds')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSessionsTable extends WorkoutSessions
    with TableInfo<$WorkoutSessionsTable, WorkoutSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planNameMeta = const VerificationMeta(
    'planName',
  );
  @override
  late final GeneratedColumn<String> planName = GeneratedColumn<String>(
    'plan_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workoutNameMeta = const VerificationMeta(
    'workoutName',
  );
  @override
  late final GeneratedColumn<String> workoutName = GeneratedColumn<String>(
    'workout_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    day,
    planName,
    workoutName,
    startedAt,
    finishedAt,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('plan_name')) {
      context.handle(
        _planNameMeta,
        planName.isAcceptableOrUnknown(data['plan_name']!, _planNameMeta),
      );
    } else if (isInserting) {
      context.missing(_planNameMeta);
    }
    if (data.containsKey('workout_name')) {
      context.handle(
        _workoutNameMeta,
        workoutName.isAcceptableOrUnknown(
          data['workout_name']!,
          _workoutNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workoutNameMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      planName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_name'],
      )!,
      workoutName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_name'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $WorkoutSessionsTable createAlias(String alias) {
    return $WorkoutSessionsTable(attachedDatabase, alias);
  }
}

class WorkoutSession extends DataClass implements Insertable<WorkoutSession> {
  final int id;
  final String day;
  final String planName;
  final String workoutName;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String status;
  const WorkoutSession({
    required this.id,
    required this.day,
    required this.planName,
    required this.workoutName,
    required this.startedAt,
    this.finishedAt,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day'] = Variable<String>(day);
    map['plan_name'] = Variable<String>(planName);
    map['workout_name'] = Variable<String>(workoutName);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  WorkoutSessionsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionsCompanion(
      id: Value(id),
      day: Value(day),
      planName: Value(planName),
      workoutName: Value(workoutName),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      status: Value(status),
    );
  }

  factory WorkoutSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSession(
      id: serializer.fromJson<int>(json['id']),
      day: serializer.fromJson<String>(json['day']),
      planName: serializer.fromJson<String>(json['planName']),
      workoutName: serializer.fromJson<String>(json['workoutName']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'day': serializer.toJson<String>(day),
      'planName': serializer.toJson<String>(planName),
      'workoutName': serializer.toJson<String>(workoutName),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'status': serializer.toJson<String>(status),
    };
  }

  WorkoutSession copyWith({
    int? id,
    String? day,
    String? planName,
    String? workoutName,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    String? status,
  }) => WorkoutSession(
    id: id ?? this.id,
    day: day ?? this.day,
    planName: planName ?? this.planName,
    workoutName: workoutName ?? this.workoutName,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    status: status ?? this.status,
  );
  WorkoutSession copyWithCompanion(WorkoutSessionsCompanion data) {
    return WorkoutSession(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      planName: data.planName.present ? data.planName.value : this.planName,
      workoutName: data.workoutName.present
          ? data.workoutName.value
          : this.workoutName,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSession(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('planName: $planName, ')
          ..write('workoutName: $workoutName, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    day,
    planName,
    workoutName,
    startedAt,
    finishedAt,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSession &&
          other.id == this.id &&
          other.day == this.day &&
          other.planName == this.planName &&
          other.workoutName == this.workoutName &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.status == this.status);
}

class WorkoutSessionsCompanion extends UpdateCompanion<WorkoutSession> {
  final Value<int> id;
  final Value<String> day;
  final Value<String> planName;
  final Value<String> workoutName;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<String> status;
  const WorkoutSessionsCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.planName = const Value.absent(),
    this.workoutName = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.status = const Value.absent(),
  });
  WorkoutSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String day,
    required String planName,
    required String workoutName,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.status = const Value.absent(),
  }) : day = Value(day),
       planName = Value(planName),
       workoutName = Value(workoutName);
  static Insertable<WorkoutSession> custom({
    Expression<int>? id,
    Expression<String>? day,
    Expression<String>? planName,
    Expression<String>? workoutName,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (planName != null) 'plan_name': planName,
      if (workoutName != null) 'workout_name': workoutName,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (status != null) 'status': status,
    });
  }

  WorkoutSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? day,
    Value<String>? planName,
    Value<String>? workoutName,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<String>? status,
  }) {
    return WorkoutSessionsCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      planName: planName ?? this.planName,
      workoutName: workoutName ?? this.workoutName,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (planName.present) {
      map['plan_name'] = Variable<String>(planName.value);
    }
    if (workoutName.present) {
      map['workout_name'] = Variable<String>(workoutName.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionsCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('planName: $planName, ')
          ..write('workoutName: $workoutName, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $ExerciseSetsTable extends ExerciseSets
    with TableInfo<$ExerciseSetsTable, ExerciseSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseKeyMeta = const VerificationMeta(
    'exerciseKey',
  );
  @override
  late final GeneratedColumn<String> exerciseKey = GeneratedColumn<String>(
    'exercise_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setNumberMeta = const VerificationMeta(
    'setNumber',
  );
  @override
  late final GeneratedColumn<int> setNumber = GeneratedColumn<int>(
    'set_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetRepsMeta = const VerificationMeta(
    'targetReps',
  );
  @override
  late final GeneratedColumn<int> targetReps = GeneratedColumn<int>(
    'target_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    exerciseKey,
    setNumber,
    targetReps,
    reps,
    weightKg,
    completed,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('exercise_key')) {
      context.handle(
        _exerciseKeyMeta,
        exerciseKey.isAcceptableOrUnknown(
          data['exercise_key']!,
          _exerciseKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseKeyMeta);
    }
    if (data.containsKey('set_number')) {
      context.handle(
        _setNumberMeta,
        setNumber.isAcceptableOrUnknown(data['set_number']!, _setNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_setNumberMeta);
    }
    if (data.containsKey('target_reps')) {
      context.handle(
        _targetRepsMeta,
        targetReps.isAcceptableOrUnknown(data['target_reps']!, _targetRepsMeta),
      );
    } else if (isInserting) {
      context.missing(_targetRepsMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      exerciseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_key'],
      )!,
      setNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_number'],
      )!,
      targetReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_reps'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $ExerciseSetsTable createAlias(String alias) {
    return $ExerciseSetsTable(attachedDatabase, alias);
  }
}

class ExerciseSet extends DataClass implements Insertable<ExerciseSet> {
  final int id;
  final int sessionId;
  final String exerciseKey;
  final int setNumber;
  final int targetReps;
  final int? reps;
  final double? weightKg;
  final bool completed;
  final DateTime? completedAt;
  const ExerciseSet({
    required this.id,
    required this.sessionId,
    required this.exerciseKey,
    required this.setNumber,
    required this.targetReps,
    this.reps,
    this.weightKg,
    required this.completed,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['exercise_key'] = Variable<String>(exerciseKey);
    map['set_number'] = Variable<int>(setNumber);
    map['target_reps'] = Variable<int>(targetReps);
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  ExerciseSetsCompanion toCompanion(bool nullToAbsent) {
    return ExerciseSetsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      exerciseKey: Value(exerciseKey),
      setNumber: Value(setNumber),
      targetReps: Value(targetReps),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      completed: Value(completed),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory ExerciseSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseSet(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      exerciseKey: serializer.fromJson<String>(json['exerciseKey']),
      setNumber: serializer.fromJson<int>(json['setNumber']),
      targetReps: serializer.fromJson<int>(json['targetReps']),
      reps: serializer.fromJson<int?>(json['reps']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      completed: serializer.fromJson<bool>(json['completed']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'exerciseKey': serializer.toJson<String>(exerciseKey),
      'setNumber': serializer.toJson<int>(setNumber),
      'targetReps': serializer.toJson<int>(targetReps),
      'reps': serializer.toJson<int?>(reps),
      'weightKg': serializer.toJson<double?>(weightKg),
      'completed': serializer.toJson<bool>(completed),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  ExerciseSet copyWith({
    int? id,
    int? sessionId,
    String? exerciseKey,
    int? setNumber,
    int? targetReps,
    Value<int?> reps = const Value.absent(),
    Value<double?> weightKg = const Value.absent(),
    bool? completed,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => ExerciseSet(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    exerciseKey: exerciseKey ?? this.exerciseKey,
    setNumber: setNumber ?? this.setNumber,
    targetReps: targetReps ?? this.targetReps,
    reps: reps.present ? reps.value : this.reps,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    completed: completed ?? this.completed,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  ExerciseSet copyWithCompanion(ExerciseSetsCompanion data) {
    return ExerciseSet(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      exerciseKey: data.exerciseKey.present
          ? data.exerciseKey.value
          : this.exerciseKey,
      setNumber: data.setNumber.present ? data.setNumber.value : this.setNumber,
      targetReps: data.targetReps.present
          ? data.targetReps.value
          : this.targetReps,
      reps: data.reps.present ? data.reps.value : this.reps,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      completed: data.completed.present ? data.completed.value : this.completed,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSet(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('setNumber: $setNumber, ')
          ..write('targetReps: $targetReps, ')
          ..write('reps: $reps, ')
          ..write('weightKg: $weightKg, ')
          ..write('completed: $completed, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    exerciseKey,
    setNumber,
    targetReps,
    reps,
    weightKg,
    completed,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseSet &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.exerciseKey == this.exerciseKey &&
          other.setNumber == this.setNumber &&
          other.targetReps == this.targetReps &&
          other.reps == this.reps &&
          other.weightKg == this.weightKg &&
          other.completed == this.completed &&
          other.completedAt == this.completedAt);
}

class ExerciseSetsCompanion extends UpdateCompanion<ExerciseSet> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> exerciseKey;
  final Value<int> setNumber;
  final Value<int> targetReps;
  final Value<int?> reps;
  final Value<double?> weightKg;
  final Value<bool> completed;
  final Value<DateTime?> completedAt;
  const ExerciseSetsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exerciseKey = const Value.absent(),
    this.setNumber = const Value.absent(),
    this.targetReps = const Value.absent(),
    this.reps = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.completed = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  ExerciseSetsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String exerciseKey,
    required int setNumber,
    required int targetReps,
    this.reps = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.completed = const Value.absent(),
    this.completedAt = const Value.absent(),
  }) : sessionId = Value(sessionId),
       exerciseKey = Value(exerciseKey),
       setNumber = Value(setNumber),
       targetReps = Value(targetReps);
  static Insertable<ExerciseSet> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? exerciseKey,
    Expression<int>? setNumber,
    Expression<int>? targetReps,
    Expression<int>? reps,
    Expression<double>? weightKg,
    Expression<bool>? completed,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exerciseKey != null) 'exercise_key': exerciseKey,
      if (setNumber != null) 'set_number': setNumber,
      if (targetReps != null) 'target_reps': targetReps,
      if (reps != null) 'reps': reps,
      if (weightKg != null) 'weight_kg': weightKg,
      if (completed != null) 'completed': completed,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  ExerciseSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<String>? exerciseKey,
    Value<int>? setNumber,
    Value<int>? targetReps,
    Value<int?>? reps,
    Value<double?>? weightKg,
    Value<bool>? completed,
    Value<DateTime?>? completedAt,
  }) {
    return ExerciseSetsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseKey: exerciseKey ?? this.exerciseKey,
      setNumber: setNumber ?? this.setNumber,
      targetReps: targetReps ?? this.targetReps,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (exerciseKey.present) {
      map['exercise_key'] = Variable<String>(exerciseKey.value);
    }
    if (setNumber.present) {
      map['set_number'] = Variable<int>(setNumber.value);
    }
    if (targetReps.present) {
      map['target_reps'] = Variable<int>(targetReps.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSetsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('setNumber: $setNumber, ')
          ..write('targetReps: $targetReps, ')
          ..write('reps: $reps, ')
          ..write('weightKg: $weightKg, ')
          ..write('completed: $completed, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $BodyMeasurementsTable extends BodyMeasurements
    with TableInfo<$BodyMeasurementsTable, BodyMeasurement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyMeasurementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _measuredAtMeta = const VerificationMeta(
    'measuredAt',
  );
  @override
  late final GeneratedColumn<DateTime> measuredAt = GeneratedColumn<DateTime>(
    'measured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, measuredAt, weightKg, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'body_measurements';
  @override
  VerificationContext validateIntegrity(
    Insertable<BodyMeasurement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('measured_at')) {
      context.handle(
        _measuredAtMeta,
        measuredAt.isAcceptableOrUnknown(data['measured_at']!, _measuredAtMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BodyMeasurement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyMeasurement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      measuredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}measured_at'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $BodyMeasurementsTable createAlias(String alias) {
    return $BodyMeasurementsTable(attachedDatabase, alias);
  }
}

class BodyMeasurement extends DataClass implements Insertable<BodyMeasurement> {
  final int id;
  final DateTime measuredAt;
  final double weightKg;
  final String? note;
  const BodyMeasurement({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['measured_at'] = Variable<DateTime>(measuredAt);
    map['weight_kg'] = Variable<double>(weightKg);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  BodyMeasurementsCompanion toCompanion(bool nullToAbsent) {
    return BodyMeasurementsCompanion(
      id: Value(id),
      measuredAt: Value(measuredAt),
      weightKg: Value(weightKg),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory BodyMeasurement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyMeasurement(
      id: serializer.fromJson<int>(json['id']),
      measuredAt: serializer.fromJson<DateTime>(json['measuredAt']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'measuredAt': serializer.toJson<DateTime>(measuredAt),
      'weightKg': serializer.toJson<double>(weightKg),
      'note': serializer.toJson<String?>(note),
    };
  }

  BodyMeasurement copyWith({
    int? id,
    DateTime? measuredAt,
    double? weightKg,
    Value<String?> note = const Value.absent(),
  }) => BodyMeasurement(
    id: id ?? this.id,
    measuredAt: measuredAt ?? this.measuredAt,
    weightKg: weightKg ?? this.weightKg,
    note: note.present ? note.value : this.note,
  );
  BodyMeasurement copyWithCompanion(BodyMeasurementsCompanion data) {
    return BodyMeasurement(
      id: data.id.present ? data.id.value : this.id,
      measuredAt: data.measuredAt.present
          ? data.measuredAt.value
          : this.measuredAt,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyMeasurement(')
          ..write('id: $id, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('weightKg: $weightKg, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, measuredAt, weightKg, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyMeasurement &&
          other.id == this.id &&
          other.measuredAt == this.measuredAt &&
          other.weightKg == this.weightKg &&
          other.note == this.note);
}

class BodyMeasurementsCompanion extends UpdateCompanion<BodyMeasurement> {
  final Value<int> id;
  final Value<DateTime> measuredAt;
  final Value<double> weightKg;
  final Value<String?> note;
  const BodyMeasurementsCompanion({
    this.id = const Value.absent(),
    this.measuredAt = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.note = const Value.absent(),
  });
  BodyMeasurementsCompanion.insert({
    this.id = const Value.absent(),
    this.measuredAt = const Value.absent(),
    required double weightKg,
    this.note = const Value.absent(),
  }) : weightKg = Value(weightKg);
  static Insertable<BodyMeasurement> custom({
    Expression<int>? id,
    Expression<DateTime>? measuredAt,
    Expression<double>? weightKg,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (measuredAt != null) 'measured_at': measuredAt,
      if (weightKg != null) 'weight_kg': weightKg,
      if (note != null) 'note': note,
    });
  }

  BodyMeasurementsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? measuredAt,
    Value<double>? weightKg,
    Value<String?>? note,
  }) {
    return BodyMeasurementsCompanion(
      id: id ?? this.id,
      measuredAt: measuredAt ?? this.measuredAt,
      weightKg: weightKg ?? this.weightKg,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (measuredAt.present) {
      map['measured_at'] = Variable<DateTime>(measuredAt.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyMeasurementsCompanion(')
          ..write('id: $id, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('weightKg: $weightKg, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $ScheduleSkipsTable extends ScheduleSkips
    with TableInfo<$ScheduleSkipsTable, ScheduleSkip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleSkipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [date, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_skips';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleSkip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  ScheduleSkip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleSkip(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ScheduleSkipsTable createAlias(String alias) {
    return $ScheduleSkipsTable(attachedDatabase, alias);
  }
}

class ScheduleSkip extends DataClass implements Insertable<ScheduleSkip> {
  final String date;
  final DateTime createdAt;
  const ScheduleSkip({required this.date, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ScheduleSkipsCompanion toCompanion(bool nullToAbsent) {
    return ScheduleSkipsCompanion(
      date: Value(date),
      createdAt: Value(createdAt),
    );
  }

  factory ScheduleSkip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleSkip(
      date: serializer.fromJson<String>(json['date']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ScheduleSkip copyWith({String? date, DateTime? createdAt}) => ScheduleSkip(
    date: date ?? this.date,
    createdAt: createdAt ?? this.createdAt,
  );
  ScheduleSkip copyWithCompanion(ScheduleSkipsCompanion data) {
    return ScheduleSkip(
      date: data.date.present ? data.date.value : this.date,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleSkip(')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleSkip &&
          other.date == this.date &&
          other.createdAt == this.createdAt);
}

class ScheduleSkipsCompanion extends UpdateCompanion<ScheduleSkip> {
  final Value<String> date;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ScheduleSkipsCompanion({
    this.date = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduleSkipsCompanion.insert({
    required String date,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<ScheduleSkip> custom({
    Expression<String>? date,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduleSkipsCompanion copyWith({
    Value<String>? date,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ScheduleSkipsCompanion(
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
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
    return (StringBuffer('ScheduleSkipsCompanion(')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MotionAnalysesTable extends MotionAnalyses
    with TableInfo<$MotionAnalysesTable, MotionAnalysisRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MotionAnalysesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _exerciseKeyMeta = const VerificationMeta(
    'exerciseKey',
  );
  @override
  late final GeneratedColumn<String> exerciseKey = GeneratedColumn<String>(
    'exercise_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patternIdMeta = const VerificationMeta(
    'patternId',
  );
  @override
  late final GeneratedColumn<String> patternId = GeneratedColumn<String>(
    'pattern_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullRepsMeta = const VerificationMeta(
    'fullReps',
  );
  @override
  late final GeneratedColumn<int> fullReps = GeneratedColumn<int>(
    'full_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partialRepsMeta = const VerificationMeta(
    'partialReps',
  );
  @override
  late final GeneratedColumn<int> partialReps = GeneratedColumn<int>(
    'partial_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _holdMsMeta = const VerificationMeta('holdMs');
  @override
  late final GeneratedColumn<int> holdMs = GeneratedColumn<int>(
    'hold_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _meanConfidenceMeta = const VerificationMeta(
    'meanConfidence',
  );
  @override
  late final GeneratedColumn<double> meanConfidence = GeneratedColumn<double>(
    'mean_confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _observedRatioMeta = const VerificationMeta(
    'observedRatio',
  );
  @override
  late final GeneratedColumn<double> observedRatio = GeneratedColumn<double>(
    'observed_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventsJsonMeta = const VerificationMeta(
    'eventsJson',
  );
  @override
  late final GeneratedColumn<String> eventsJson = GeneratedColumn<String>(
    'events_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _techniqueScoreMeta = const VerificationMeta(
    'techniqueScore',
  );
  @override
  late final GeneratedColumn<double> techniqueScore = GeneratedColumn<double>(
    'technique_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    exerciseKey,
    patternId,
    startedAt,
    durationMs,
    fullReps,
    partialReps,
    holdMs,
    meanConfidence,
    observedRatio,
    status,
    eventsJson,
    techniqueScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'motion_analyses';
  @override
  VerificationContext validateIntegrity(
    Insertable<MotionAnalysisRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('exercise_key')) {
      context.handle(
        _exerciseKeyMeta,
        exerciseKey.isAcceptableOrUnknown(
          data['exercise_key']!,
          _exerciseKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseKeyMeta);
    }
    if (data.containsKey('pattern_id')) {
      context.handle(
        _patternIdMeta,
        patternId.isAcceptableOrUnknown(data['pattern_id']!, _patternIdMeta),
      );
    } else if (isInserting) {
      context.missing(_patternIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('full_reps')) {
      context.handle(
        _fullRepsMeta,
        fullReps.isAcceptableOrUnknown(data['full_reps']!, _fullRepsMeta),
      );
    } else if (isInserting) {
      context.missing(_fullRepsMeta);
    }
    if (data.containsKey('partial_reps')) {
      context.handle(
        _partialRepsMeta,
        partialReps.isAcceptableOrUnknown(
          data['partial_reps']!,
          _partialRepsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_partialRepsMeta);
    }
    if (data.containsKey('hold_ms')) {
      context.handle(
        _holdMsMeta,
        holdMs.isAcceptableOrUnknown(data['hold_ms']!, _holdMsMeta),
      );
    }
    if (data.containsKey('mean_confidence')) {
      context.handle(
        _meanConfidenceMeta,
        meanConfidence.isAcceptableOrUnknown(
          data['mean_confidence']!,
          _meanConfidenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_meanConfidenceMeta);
    }
    if (data.containsKey('observed_ratio')) {
      context.handle(
        _observedRatioMeta,
        observedRatio.isAcceptableOrUnknown(
          data['observed_ratio']!,
          _observedRatioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_observedRatioMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('events_json')) {
      context.handle(
        _eventsJsonMeta,
        eventsJson.isAcceptableOrUnknown(data['events_json']!, _eventsJsonMeta),
      );
    }
    if (data.containsKey('technique_score')) {
      context.handle(
        _techniqueScoreMeta,
        techniqueScore.isAcceptableOrUnknown(
          data['technique_score']!,
          _techniqueScoreMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MotionAnalysisRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MotionAnalysisRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      exerciseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_key'],
      )!,
      patternId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      fullReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}full_reps'],
      )!,
      partialReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}partial_reps'],
      )!,
      holdMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hold_ms'],
      )!,
      meanConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mean_confidence'],
      )!,
      observedRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}observed_ratio'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      eventsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}events_json'],
      )!,
      techniqueScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}technique_score'],
      ),
    );
  }

  @override
  $MotionAnalysesTable createAlias(String alias) {
    return $MotionAnalysesTable(attachedDatabase, alias);
  }
}

class MotionAnalysisRecord extends DataClass
    implements Insertable<MotionAnalysisRecord> {
  final int id;
  final String exerciseKey;
  final String patternId;
  final DateTime startedAt;
  final int durationMs;
  final int fullReps;
  final int partialReps;
  final int holdMs;
  final double meanConfidence;
  final double observedRatio;

  /// withinCriteria | possibleIssue | notObservable | inconclusive
  final String status;

  /// JSON list of technique events (check id, time, confidence, rep).
  final String eventsJson;

  /// Only set when every check used was professionally validated.
  final double? techniqueScore;
  const MotionAnalysisRecord({
    required this.id,
    required this.exerciseKey,
    required this.patternId,
    required this.startedAt,
    required this.durationMs,
    required this.fullReps,
    required this.partialReps,
    required this.holdMs,
    required this.meanConfidence,
    required this.observedRatio,
    required this.status,
    required this.eventsJson,
    this.techniqueScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['exercise_key'] = Variable<String>(exerciseKey);
    map['pattern_id'] = Variable<String>(patternId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['full_reps'] = Variable<int>(fullReps);
    map['partial_reps'] = Variable<int>(partialReps);
    map['hold_ms'] = Variable<int>(holdMs);
    map['mean_confidence'] = Variable<double>(meanConfidence);
    map['observed_ratio'] = Variable<double>(observedRatio);
    map['status'] = Variable<String>(status);
    map['events_json'] = Variable<String>(eventsJson);
    if (!nullToAbsent || techniqueScore != null) {
      map['technique_score'] = Variable<double>(techniqueScore);
    }
    return map;
  }

  MotionAnalysesCompanion toCompanion(bool nullToAbsent) {
    return MotionAnalysesCompanion(
      id: Value(id),
      exerciseKey: Value(exerciseKey),
      patternId: Value(patternId),
      startedAt: Value(startedAt),
      durationMs: Value(durationMs),
      fullReps: Value(fullReps),
      partialReps: Value(partialReps),
      holdMs: Value(holdMs),
      meanConfidence: Value(meanConfidence),
      observedRatio: Value(observedRatio),
      status: Value(status),
      eventsJson: Value(eventsJson),
      techniqueScore: techniqueScore == null && nullToAbsent
          ? const Value.absent()
          : Value(techniqueScore),
    );
  }

  factory MotionAnalysisRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MotionAnalysisRecord(
      id: serializer.fromJson<int>(json['id']),
      exerciseKey: serializer.fromJson<String>(json['exerciseKey']),
      patternId: serializer.fromJson<String>(json['patternId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      fullReps: serializer.fromJson<int>(json['fullReps']),
      partialReps: serializer.fromJson<int>(json['partialReps']),
      holdMs: serializer.fromJson<int>(json['holdMs']),
      meanConfidence: serializer.fromJson<double>(json['meanConfidence']),
      observedRatio: serializer.fromJson<double>(json['observedRatio']),
      status: serializer.fromJson<String>(json['status']),
      eventsJson: serializer.fromJson<String>(json['eventsJson']),
      techniqueScore: serializer.fromJson<double?>(json['techniqueScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'exerciseKey': serializer.toJson<String>(exerciseKey),
      'patternId': serializer.toJson<String>(patternId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'fullReps': serializer.toJson<int>(fullReps),
      'partialReps': serializer.toJson<int>(partialReps),
      'holdMs': serializer.toJson<int>(holdMs),
      'meanConfidence': serializer.toJson<double>(meanConfidence),
      'observedRatio': serializer.toJson<double>(observedRatio),
      'status': serializer.toJson<String>(status),
      'eventsJson': serializer.toJson<String>(eventsJson),
      'techniqueScore': serializer.toJson<double?>(techniqueScore),
    };
  }

  MotionAnalysisRecord copyWith({
    int? id,
    String? exerciseKey,
    String? patternId,
    DateTime? startedAt,
    int? durationMs,
    int? fullReps,
    int? partialReps,
    int? holdMs,
    double? meanConfidence,
    double? observedRatio,
    String? status,
    String? eventsJson,
    Value<double?> techniqueScore = const Value.absent(),
  }) => MotionAnalysisRecord(
    id: id ?? this.id,
    exerciseKey: exerciseKey ?? this.exerciseKey,
    patternId: patternId ?? this.patternId,
    startedAt: startedAt ?? this.startedAt,
    durationMs: durationMs ?? this.durationMs,
    fullReps: fullReps ?? this.fullReps,
    partialReps: partialReps ?? this.partialReps,
    holdMs: holdMs ?? this.holdMs,
    meanConfidence: meanConfidence ?? this.meanConfidence,
    observedRatio: observedRatio ?? this.observedRatio,
    status: status ?? this.status,
    eventsJson: eventsJson ?? this.eventsJson,
    techniqueScore: techniqueScore.present
        ? techniqueScore.value
        : this.techniqueScore,
  );
  MotionAnalysisRecord copyWithCompanion(MotionAnalysesCompanion data) {
    return MotionAnalysisRecord(
      id: data.id.present ? data.id.value : this.id,
      exerciseKey: data.exerciseKey.present
          ? data.exerciseKey.value
          : this.exerciseKey,
      patternId: data.patternId.present ? data.patternId.value : this.patternId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      fullReps: data.fullReps.present ? data.fullReps.value : this.fullReps,
      partialReps: data.partialReps.present
          ? data.partialReps.value
          : this.partialReps,
      holdMs: data.holdMs.present ? data.holdMs.value : this.holdMs,
      meanConfidence: data.meanConfidence.present
          ? data.meanConfidence.value
          : this.meanConfidence,
      observedRatio: data.observedRatio.present
          ? data.observedRatio.value
          : this.observedRatio,
      status: data.status.present ? data.status.value : this.status,
      eventsJson: data.eventsJson.present
          ? data.eventsJson.value
          : this.eventsJson,
      techniqueScore: data.techniqueScore.present
          ? data.techniqueScore.value
          : this.techniqueScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MotionAnalysisRecord(')
          ..write('id: $id, ')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('patternId: $patternId, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('fullReps: $fullReps, ')
          ..write('partialReps: $partialReps, ')
          ..write('holdMs: $holdMs, ')
          ..write('meanConfidence: $meanConfidence, ')
          ..write('observedRatio: $observedRatio, ')
          ..write('status: $status, ')
          ..write('eventsJson: $eventsJson, ')
          ..write('techniqueScore: $techniqueScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    exerciseKey,
    patternId,
    startedAt,
    durationMs,
    fullReps,
    partialReps,
    holdMs,
    meanConfidence,
    observedRatio,
    status,
    eventsJson,
    techniqueScore,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MotionAnalysisRecord &&
          other.id == this.id &&
          other.exerciseKey == this.exerciseKey &&
          other.patternId == this.patternId &&
          other.startedAt == this.startedAt &&
          other.durationMs == this.durationMs &&
          other.fullReps == this.fullReps &&
          other.partialReps == this.partialReps &&
          other.holdMs == this.holdMs &&
          other.meanConfidence == this.meanConfidence &&
          other.observedRatio == this.observedRatio &&
          other.status == this.status &&
          other.eventsJson == this.eventsJson &&
          other.techniqueScore == this.techniqueScore);
}

class MotionAnalysesCompanion extends UpdateCompanion<MotionAnalysisRecord> {
  final Value<int> id;
  final Value<String> exerciseKey;
  final Value<String> patternId;
  final Value<DateTime> startedAt;
  final Value<int> durationMs;
  final Value<int> fullReps;
  final Value<int> partialReps;
  final Value<int> holdMs;
  final Value<double> meanConfidence;
  final Value<double> observedRatio;
  final Value<String> status;
  final Value<String> eventsJson;
  final Value<double?> techniqueScore;
  const MotionAnalysesCompanion({
    this.id = const Value.absent(),
    this.exerciseKey = const Value.absent(),
    this.patternId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.fullReps = const Value.absent(),
    this.partialReps = const Value.absent(),
    this.holdMs = const Value.absent(),
    this.meanConfidence = const Value.absent(),
    this.observedRatio = const Value.absent(),
    this.status = const Value.absent(),
    this.eventsJson = const Value.absent(),
    this.techniqueScore = const Value.absent(),
  });
  MotionAnalysesCompanion.insert({
    this.id = const Value.absent(),
    required String exerciseKey,
    required String patternId,
    required DateTime startedAt,
    required int durationMs,
    required int fullReps,
    required int partialReps,
    this.holdMs = const Value.absent(),
    required double meanConfidence,
    required double observedRatio,
    required String status,
    this.eventsJson = const Value.absent(),
    this.techniqueScore = const Value.absent(),
  }) : exerciseKey = Value(exerciseKey),
       patternId = Value(patternId),
       startedAt = Value(startedAt),
       durationMs = Value(durationMs),
       fullReps = Value(fullReps),
       partialReps = Value(partialReps),
       meanConfidence = Value(meanConfidence),
       observedRatio = Value(observedRatio),
       status = Value(status);
  static Insertable<MotionAnalysisRecord> custom({
    Expression<int>? id,
    Expression<String>? exerciseKey,
    Expression<String>? patternId,
    Expression<DateTime>? startedAt,
    Expression<int>? durationMs,
    Expression<int>? fullReps,
    Expression<int>? partialReps,
    Expression<int>? holdMs,
    Expression<double>? meanConfidence,
    Expression<double>? observedRatio,
    Expression<String>? status,
    Expression<String>? eventsJson,
    Expression<double>? techniqueScore,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseKey != null) 'exercise_key': exerciseKey,
      if (patternId != null) 'pattern_id': patternId,
      if (startedAt != null) 'started_at': startedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (fullReps != null) 'full_reps': fullReps,
      if (partialReps != null) 'partial_reps': partialReps,
      if (holdMs != null) 'hold_ms': holdMs,
      if (meanConfidence != null) 'mean_confidence': meanConfidence,
      if (observedRatio != null) 'observed_ratio': observedRatio,
      if (status != null) 'status': status,
      if (eventsJson != null) 'events_json': eventsJson,
      if (techniqueScore != null) 'technique_score': techniqueScore,
    });
  }

  MotionAnalysesCompanion copyWith({
    Value<int>? id,
    Value<String>? exerciseKey,
    Value<String>? patternId,
    Value<DateTime>? startedAt,
    Value<int>? durationMs,
    Value<int>? fullReps,
    Value<int>? partialReps,
    Value<int>? holdMs,
    Value<double>? meanConfidence,
    Value<double>? observedRatio,
    Value<String>? status,
    Value<String>? eventsJson,
    Value<double?>? techniqueScore,
  }) {
    return MotionAnalysesCompanion(
      id: id ?? this.id,
      exerciseKey: exerciseKey ?? this.exerciseKey,
      patternId: patternId ?? this.patternId,
      startedAt: startedAt ?? this.startedAt,
      durationMs: durationMs ?? this.durationMs,
      fullReps: fullReps ?? this.fullReps,
      partialReps: partialReps ?? this.partialReps,
      holdMs: holdMs ?? this.holdMs,
      meanConfidence: meanConfidence ?? this.meanConfidence,
      observedRatio: observedRatio ?? this.observedRatio,
      status: status ?? this.status,
      eventsJson: eventsJson ?? this.eventsJson,
      techniqueScore: techniqueScore ?? this.techniqueScore,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (exerciseKey.present) {
      map['exercise_key'] = Variable<String>(exerciseKey.value);
    }
    if (patternId.present) {
      map['pattern_id'] = Variable<String>(patternId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (fullReps.present) {
      map['full_reps'] = Variable<int>(fullReps.value);
    }
    if (partialReps.present) {
      map['partial_reps'] = Variable<int>(partialReps.value);
    }
    if (holdMs.present) {
      map['hold_ms'] = Variable<int>(holdMs.value);
    }
    if (meanConfidence.present) {
      map['mean_confidence'] = Variable<double>(meanConfidence.value);
    }
    if (observedRatio.present) {
      map['observed_ratio'] = Variable<double>(observedRatio.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (eventsJson.present) {
      map['events_json'] = Variable<String>(eventsJson.value);
    }
    if (techniqueScore.present) {
      map['technique_score'] = Variable<double>(techniqueScore.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MotionAnalysesCompanion(')
          ..write('id: $id, ')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('patternId: $patternId, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('fullReps: $fullReps, ')
          ..write('partialReps: $partialReps, ')
          ..write('holdMs: $holdMs, ')
          ..write('meanConfidence: $meanConfidence, ')
          ..write('observedRatio: $observedRatio, ')
          ..write('status: $status, ')
          ..write('eventsJson: $eventsJson, ')
          ..write('techniqueScore: $techniqueScore')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoodEntriesTable foodEntries = $FoodEntriesTable(this);
  late final $CachedProductsTable cachedProducts = $CachedProductsTable(this);
  late final $WorkoutPlansTable workoutPlans = $WorkoutPlansTable(this);
  late final $WorkoutDaysTable workoutDays = $WorkoutDaysTable(this);
  late final $ExerciseCatalogTable exerciseCatalog = $ExerciseCatalogTable(
    this,
  );
  late final $PlanExercisesTable planExercises = $PlanExercisesTable(this);
  late final $WorkoutSessionsTable workoutSessions = $WorkoutSessionsTable(
    this,
  );
  late final $ExerciseSetsTable exerciseSets = $ExerciseSetsTable(this);
  late final $BodyMeasurementsTable bodyMeasurements = $BodyMeasurementsTable(
    this,
  );
  late final $ScheduleSkipsTable scheduleSkips = $ScheduleSkipsTable(this);
  late final $MotionAnalysesTable motionAnalyses = $MotionAnalysesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    foodEntries,
    cachedProducts,
    workoutPlans,
    workoutDays,
    exerciseCatalog,
    planExercises,
    workoutSessions,
    exerciseSets,
    bodyMeasurements,
    scheduleSkips,
    motionAnalyses,
  ];
}

typedef $$FoodEntriesTableCreateCompanionBuilder =
    FoodEntriesCompanion Function({
      Value<int> id,
      required String day,
      required String mealType,
      required String name,
      Value<String?> brand,
      required double quantityGrams,
      Value<double?> kcalPer100g,
      Value<double?> proteinPer100g,
      Value<double?> carbsPer100g,
      Value<double?> fatPer100g,
      Value<String> source,
      Value<String?> portionUnit,
      Value<double?> portionCount,
      Value<DateTime> createdAt,
    });
typedef $$FoodEntriesTableUpdateCompanionBuilder =
    FoodEntriesCompanion Function({
      Value<int> id,
      Value<String> day,
      Value<String> mealType,
      Value<String> name,
      Value<String?> brand,
      Value<double> quantityGrams,
      Value<double?> kcalPer100g,
      Value<double?> proteinPer100g,
      Value<double?> carbsPer100g,
      Value<double?> fatPer100g,
      Value<String> source,
      Value<String?> portionUnit,
      Value<double?> portionCount,
      Value<DateTime> createdAt,
    });

class $$FoodEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FoodEntriesTable> {
  $$FoodEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantityGrams => $composableBuilder(
    column: $table.quantityGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcalPer100g => $composableBuilder(
    column: $table.kcalPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinPer100g => $composableBuilder(
    column: $table.proteinPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsPer100g => $composableBuilder(
    column: $table.carbsPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatPer100g => $composableBuilder(
    column: $table.fatPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portionUnit => $composableBuilder(
    column: $table.portionUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get portionCount => $composableBuilder(
    column: $table.portionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoodEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodEntriesTable> {
  $$FoodEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantityGrams => $composableBuilder(
    column: $table.quantityGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcalPer100g => $composableBuilder(
    column: $table.kcalPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinPer100g => $composableBuilder(
    column: $table.proteinPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsPer100g => $composableBuilder(
    column: $table.carbsPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatPer100g => $composableBuilder(
    column: $table.fatPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portionUnit => $composableBuilder(
    column: $table.portionUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get portionCount => $composableBuilder(
    column: $table.portionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodEntriesTable> {
  $$FoodEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get mealType =>
      $composableBuilder(column: $table.mealType, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<double> get quantityGrams => $composableBuilder(
    column: $table.quantityGrams,
    builder: (column) => column,
  );

  GeneratedColumn<double> get kcalPer100g => $composableBuilder(
    column: $table.kcalPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get proteinPer100g => $composableBuilder(
    column: $table.proteinPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbsPer100g => $composableBuilder(
    column: $table.carbsPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fatPer100g => $composableBuilder(
    column: $table.fatPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get portionUnit => $composableBuilder(
    column: $table.portionUnit,
    builder: (column) => column,
  );

  GeneratedColumn<double> get portionCount => $composableBuilder(
    column: $table.portionCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FoodEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodEntriesTable,
          FoodEntryRecord,
          $$FoodEntriesTableFilterComposer,
          $$FoodEntriesTableOrderingComposer,
          $$FoodEntriesTableAnnotationComposer,
          $$FoodEntriesTableCreateCompanionBuilder,
          $$FoodEntriesTableUpdateCompanionBuilder,
          (
            FoodEntryRecord,
            BaseReferences<_$AppDatabase, $FoodEntriesTable, FoodEntryRecord>,
          ),
          FoodEntryRecord,
          PrefetchHooks Function()
        > {
  $$FoodEntriesTableTableManager(_$AppDatabase db, $FoodEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<String> mealType = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<double> quantityGrams = const Value.absent(),
                Value<double?> kcalPer100g = const Value.absent(),
                Value<double?> proteinPer100g = const Value.absent(),
                Value<double?> carbsPer100g = const Value.absent(),
                Value<double?> fatPer100g = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> portionUnit = const Value.absent(),
                Value<double?> portionCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FoodEntriesCompanion(
                id: id,
                day: day,
                mealType: mealType,
                name: name,
                brand: brand,
                quantityGrams: quantityGrams,
                kcalPer100g: kcalPer100g,
                proteinPer100g: proteinPer100g,
                carbsPer100g: carbsPer100g,
                fatPer100g: fatPer100g,
                source: source,
                portionUnit: portionUnit,
                portionCount: portionCount,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String day,
                required String mealType,
                required String name,
                Value<String?> brand = const Value.absent(),
                required double quantityGrams,
                Value<double?> kcalPer100g = const Value.absent(),
                Value<double?> proteinPer100g = const Value.absent(),
                Value<double?> carbsPer100g = const Value.absent(),
                Value<double?> fatPer100g = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> portionUnit = const Value.absent(),
                Value<double?> portionCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FoodEntriesCompanion.insert(
                id: id,
                day: day,
                mealType: mealType,
                name: name,
                brand: brand,
                quantityGrams: quantityGrams,
                kcalPer100g: kcalPer100g,
                proteinPer100g: proteinPer100g,
                carbsPer100g: carbsPer100g,
                fatPer100g: fatPer100g,
                source: source,
                portionUnit: portionUnit,
                portionCount: portionCount,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoodEntriesTable, FoodEntryRecord>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FoodEntriesTable,
                    FoodEntryRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoodEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodEntriesTable,
      FoodEntryRecord,
      $$FoodEntriesTableFilterComposer,
      $$FoodEntriesTableOrderingComposer,
      $$FoodEntriesTableAnnotationComposer,
      $$FoodEntriesTableCreateCompanionBuilder,
      $$FoodEntriesTableUpdateCompanionBuilder,
      (
        FoodEntryRecord,
        BaseReferences<_$AppDatabase, $FoodEntriesTable, FoodEntryRecord>,
      ),
      FoodEntryRecord,
      PrefetchHooks Function()
    >;
typedef $$CachedProductsTableCreateCompanionBuilder =
    CachedProductsCompanion Function({
      required String barcode,
      required String name,
      Value<String?> brand,
      Value<String?> quantity,
      Value<double?> kcalPer100g,
      Value<double?> proteinPer100g,
      Value<double?> carbsPer100g,
      Value<double?> fatPer100g,
      Value<String?> nutriScore,
      Value<String?> servingSize,
      Value<double?> servingGrams,
      Value<double?> packageGrams,
      Value<bool> liquid,
      required DateTime lastFetchedAt,
      Value<int> rowid,
    });
typedef $$CachedProductsTableUpdateCompanionBuilder =
    CachedProductsCompanion Function({
      Value<String> barcode,
      Value<String> name,
      Value<String?> brand,
      Value<String?> quantity,
      Value<double?> kcalPer100g,
      Value<double?> proteinPer100g,
      Value<double?> carbsPer100g,
      Value<double?> fatPer100g,
      Value<String?> nutriScore,
      Value<String?> servingSize,
      Value<double?> servingGrams,
      Value<double?> packageGrams,
      Value<bool> liquid,
      Value<DateTime> lastFetchedAt,
      Value<int> rowid,
    });

class $$CachedProductsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcalPer100g => $composableBuilder(
    column: $table.kcalPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinPer100g => $composableBuilder(
    column: $table.proteinPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbsPer100g => $composableBuilder(
    column: $table.carbsPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatPer100g => $composableBuilder(
    column: $table.fatPer100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nutriScore => $composableBuilder(
    column: $table.nutriScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingSize => $composableBuilder(
    column: $table.servingSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servingGrams => $composableBuilder(
    column: $table.servingGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get packageGrams => $composableBuilder(
    column: $table.packageGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get liquid => $composableBuilder(
    column: $table.liquid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcalPer100g => $composableBuilder(
    column: $table.kcalPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinPer100g => $composableBuilder(
    column: $table.proteinPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbsPer100g => $composableBuilder(
    column: $table.carbsPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatPer100g => $composableBuilder(
    column: $table.fatPer100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nutriScore => $composableBuilder(
    column: $table.nutriScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingSize => $composableBuilder(
    column: $table.servingSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servingGrams => $composableBuilder(
    column: $table.servingGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get packageGrams => $composableBuilder(
    column: $table.packageGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get liquid => $composableBuilder(
    column: $table.liquid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedProductsTable> {
  $$CachedProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get kcalPer100g => $composableBuilder(
    column: $table.kcalPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get proteinPer100g => $composableBuilder(
    column: $table.proteinPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbsPer100g => $composableBuilder(
    column: $table.carbsPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fatPer100g => $composableBuilder(
    column: $table.fatPer100g,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nutriScore => $composableBuilder(
    column: $table.nutriScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servingSize => $composableBuilder(
    column: $table.servingSize,
    builder: (column) => column,
  );

  GeneratedColumn<double> get servingGrams => $composableBuilder(
    column: $table.servingGrams,
    builder: (column) => column,
  );

  GeneratedColumn<double> get packageGrams => $composableBuilder(
    column: $table.packageGrams,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get liquid =>
      $composableBuilder(column: $table.liquid, builder: (column) => column);

  GeneratedColumn<DateTime> get lastFetchedAt => $composableBuilder(
    column: $table.lastFetchedAt,
    builder: (column) => column,
  );
}

class $$CachedProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedProductsTable,
          CachedProduct,
          $$CachedProductsTableFilterComposer,
          $$CachedProductsTableOrderingComposer,
          $$CachedProductsTableAnnotationComposer,
          $$CachedProductsTableCreateCompanionBuilder,
          $$CachedProductsTableUpdateCompanionBuilder,
          (
            CachedProduct,
            BaseReferences<_$AppDatabase, $CachedProductsTable, CachedProduct>,
          ),
          CachedProduct,
          PrefetchHooks Function()
        > {
  $$CachedProductsTableTableManager(
    _$AppDatabase db,
    $CachedProductsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> barcode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> quantity = const Value.absent(),
                Value<double?> kcalPer100g = const Value.absent(),
                Value<double?> proteinPer100g = const Value.absent(),
                Value<double?> carbsPer100g = const Value.absent(),
                Value<double?> fatPer100g = const Value.absent(),
                Value<String?> nutriScore = const Value.absent(),
                Value<String?> servingSize = const Value.absent(),
                Value<double?> servingGrams = const Value.absent(),
                Value<double?> packageGrams = const Value.absent(),
                Value<bool> liquid = const Value.absent(),
                Value<DateTime> lastFetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedProductsCompanion(
                barcode: barcode,
                name: name,
                brand: brand,
                quantity: quantity,
                kcalPer100g: kcalPer100g,
                proteinPer100g: proteinPer100g,
                carbsPer100g: carbsPer100g,
                fatPer100g: fatPer100g,
                nutriScore: nutriScore,
                servingSize: servingSize,
                servingGrams: servingGrams,
                packageGrams: packageGrams,
                liquid: liquid,
                lastFetchedAt: lastFetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String barcode,
                required String name,
                Value<String?> brand = const Value.absent(),
                Value<String?> quantity = const Value.absent(),
                Value<double?> kcalPer100g = const Value.absent(),
                Value<double?> proteinPer100g = const Value.absent(),
                Value<double?> carbsPer100g = const Value.absent(),
                Value<double?> fatPer100g = const Value.absent(),
                Value<String?> nutriScore = const Value.absent(),
                Value<String?> servingSize = const Value.absent(),
                Value<double?> servingGrams = const Value.absent(),
                Value<double?> packageGrams = const Value.absent(),
                Value<bool> liquid = const Value.absent(),
                required DateTime lastFetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedProductsCompanion.insert(
                barcode: barcode,
                name: name,
                brand: brand,
                quantity: quantity,
                kcalPer100g: kcalPer100g,
                proteinPer100g: proteinPer100g,
                carbsPer100g: carbsPer100g,
                fatPer100g: fatPer100g,
                nutriScore: nutriScore,
                servingSize: servingSize,
                servingGrams: servingGrams,
                packageGrams: packageGrams,
                liquid: liquid,
                lastFetchedAt: lastFetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedProductsTable, CachedProduct>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedProductsTable,
                    CachedProduct
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedProductsTable,
      CachedProduct,
      $$CachedProductsTableFilterComposer,
      $$CachedProductsTableOrderingComposer,
      $$CachedProductsTableAnnotationComposer,
      $$CachedProductsTableCreateCompanionBuilder,
      $$CachedProductsTableUpdateCompanionBuilder,
      (
        CachedProduct,
        BaseReferences<_$AppDatabase, $CachedProductsTable, CachedProduct>,
      ),
      CachedProduct,
      PrefetchHooks Function()
    >;
typedef $$WorkoutPlansTableCreateCompanionBuilder =
    WorkoutPlansCompanion Function({
      Value<int> id,
      required String title,
      required String goal,
      Value<bool> active,
      Value<DateTime> createdAt,
    });
typedef $$WorkoutPlansTableUpdateCompanionBuilder =
    WorkoutPlansCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> goal,
      Value<bool> active,
      Value<DateTime> createdAt,
    });

class $$WorkoutPlansTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutPlansTable> {
  $$WorkoutPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkoutPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutPlansTable> {
  $$WorkoutPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutPlansTable> {
  $$WorkoutPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WorkoutPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutPlansTable,
          WorkoutPlan,
          $$WorkoutPlansTableFilterComposer,
          $$WorkoutPlansTableOrderingComposer,
          $$WorkoutPlansTableAnnotationComposer,
          $$WorkoutPlansTableCreateCompanionBuilder,
          $$WorkoutPlansTableUpdateCompanionBuilder,
          (
            WorkoutPlan,
            BaseReferences<_$AppDatabase, $WorkoutPlansTable, WorkoutPlan>,
          ),
          WorkoutPlan,
          PrefetchHooks Function()
        > {
  $$WorkoutPlansTableTableManager(_$AppDatabase db, $WorkoutPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> goal = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WorkoutPlansCompanion(
                id: id,
                title: title,
                goal: goal,
                active: active,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String goal,
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WorkoutPlansCompanion.insert(
                id: id,
                title: title,
                goal: goal,
                active: active,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutPlansTable, WorkoutPlan>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkoutPlansTable,
                    WorkoutPlan
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutPlansTable,
      WorkoutPlan,
      $$WorkoutPlansTableFilterComposer,
      $$WorkoutPlansTableOrderingComposer,
      $$WorkoutPlansTableAnnotationComposer,
      $$WorkoutPlansTableCreateCompanionBuilder,
      $$WorkoutPlansTableUpdateCompanionBuilder,
      (
        WorkoutPlan,
        BaseReferences<_$AppDatabase, $WorkoutPlansTable, WorkoutPlan>,
      ),
      WorkoutPlan,
      PrefetchHooks Function()
    >;
typedef $$WorkoutDaysTableCreateCompanionBuilder =
    WorkoutDaysCompanion Function({
      Value<int> id,
      required int planId,
      required int dayNumber,
      required String namePt,
      required String nameEn,
      Value<int?> weekday,
    });
typedef $$WorkoutDaysTableUpdateCompanionBuilder =
    WorkoutDaysCompanion Function({
      Value<int> id,
      Value<int> planId,
      Value<int> dayNumber,
      Value<String> namePt,
      Value<String> nameEn,
      Value<int?> weekday,
    });

class $$WorkoutDaysTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutDaysTable> {
  $$WorkoutDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayNumber => $composableBuilder(
    column: $table.dayNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get namePt => $composableBuilder(
    column: $table.namePt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkoutDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutDaysTable> {
  $$WorkoutDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayNumber => $composableBuilder(
    column: $table.dayNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get namePt => $composableBuilder(
    column: $table.namePt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutDaysTable> {
  $$WorkoutDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<int> get dayNumber =>
      $composableBuilder(column: $table.dayNumber, builder: (column) => column);

  GeneratedColumn<String> get namePt =>
      $composableBuilder(column: $table.namePt, builder: (column) => column);

  GeneratedColumn<String> get nameEn =>
      $composableBuilder(column: $table.nameEn, builder: (column) => column);

  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);
}

class $$WorkoutDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutDaysTable,
          WorkoutDay,
          $$WorkoutDaysTableFilterComposer,
          $$WorkoutDaysTableOrderingComposer,
          $$WorkoutDaysTableAnnotationComposer,
          $$WorkoutDaysTableCreateCompanionBuilder,
          $$WorkoutDaysTableUpdateCompanionBuilder,
          (
            WorkoutDay,
            BaseReferences<_$AppDatabase, $WorkoutDaysTable, WorkoutDay>,
          ),
          WorkoutDay,
          PrefetchHooks Function()
        > {
  $$WorkoutDaysTableTableManager(_$AppDatabase db, $WorkoutDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> planId = const Value.absent(),
                Value<int> dayNumber = const Value.absent(),
                Value<String> namePt = const Value.absent(),
                Value<String> nameEn = const Value.absent(),
                Value<int?> weekday = const Value.absent(),
              }) => WorkoutDaysCompanion(
                id: id,
                planId: planId,
                dayNumber: dayNumber,
                namePt: namePt,
                nameEn: nameEn,
                weekday: weekday,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int planId,
                required int dayNumber,
                required String namePt,
                required String nameEn,
                Value<int?> weekday = const Value.absent(),
              }) => WorkoutDaysCompanion.insert(
                id: id,
                planId: planId,
                dayNumber: dayNumber,
                namePt: namePt,
                nameEn: nameEn,
                weekday: weekday,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutDaysTable, WorkoutDay>(table),
                  BaseReferences<_$AppDatabase, $WorkoutDaysTable, WorkoutDay>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutDaysTable,
      WorkoutDay,
      $$WorkoutDaysTableFilterComposer,
      $$WorkoutDaysTableOrderingComposer,
      $$WorkoutDaysTableAnnotationComposer,
      $$WorkoutDaysTableCreateCompanionBuilder,
      $$WorkoutDaysTableUpdateCompanionBuilder,
      (
        WorkoutDay,
        BaseReferences<_$AppDatabase, $WorkoutDaysTable, WorkoutDay>,
      ),
      WorkoutDay,
      PrefetchHooks Function()
    >;
typedef $$ExerciseCatalogTableCreateCompanionBuilder =
    ExerciseCatalogCompanion Function({
      required String exerciseKey,
      required String namePt,
      required String nameEn,
      required String muscleGroup,
      required String instructionsPt,
      required String instructionsEn,
      required String equipment,
      required String difficulty,
      Value<int> rowid,
    });
typedef $$ExerciseCatalogTableUpdateCompanionBuilder =
    ExerciseCatalogCompanion Function({
      Value<String> exerciseKey,
      Value<String> namePt,
      Value<String> nameEn,
      Value<String> muscleGroup,
      Value<String> instructionsPt,
      Value<String> instructionsEn,
      Value<String> equipment,
      Value<String> difficulty,
      Value<int> rowid,
    });

class $$ExerciseCatalogTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseCatalogTable> {
  $$ExerciseCatalogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get namePt => $composableBuilder(
    column: $table.namePt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instructionsPt => $composableBuilder(
    column: $table.instructionsPt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instructionsEn => $composableBuilder(
    column: $table.instructionsEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseCatalogTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseCatalogTable> {
  $$ExerciseCatalogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get namePt => $composableBuilder(
    column: $table.namePt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameEn => $composableBuilder(
    column: $table.nameEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instructionsPt => $composableBuilder(
    column: $table.instructionsPt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instructionsEn => $composableBuilder(
    column: $table.instructionsEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseCatalogTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseCatalogTable> {
  $$ExerciseCatalogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get namePt =>
      $composableBuilder(column: $table.namePt, builder: (column) => column);

  GeneratedColumn<String> get nameEn =>
      $composableBuilder(column: $table.nameEn, builder: (column) => column);

  GeneratedColumn<String> get muscleGroup => $composableBuilder(
    column: $table.muscleGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instructionsPt => $composableBuilder(
    column: $table.instructionsPt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instructionsEn => $composableBuilder(
    column: $table.instructionsEn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );
}

class $$ExerciseCatalogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseCatalogTable,
          ExerciseCatalogData,
          $$ExerciseCatalogTableFilterComposer,
          $$ExerciseCatalogTableOrderingComposer,
          $$ExerciseCatalogTableAnnotationComposer,
          $$ExerciseCatalogTableCreateCompanionBuilder,
          $$ExerciseCatalogTableUpdateCompanionBuilder,
          (
            ExerciseCatalogData,
            BaseReferences<
              _$AppDatabase,
              $ExerciseCatalogTable,
              ExerciseCatalogData
            >,
          ),
          ExerciseCatalogData,
          PrefetchHooks Function()
        > {
  $$ExerciseCatalogTableTableManager(
    _$AppDatabase db,
    $ExerciseCatalogTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseCatalogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseCatalogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseCatalogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> exerciseKey = const Value.absent(),
                Value<String> namePt = const Value.absent(),
                Value<String> nameEn = const Value.absent(),
                Value<String> muscleGroup = const Value.absent(),
                Value<String> instructionsPt = const Value.absent(),
                Value<String> instructionsEn = const Value.absent(),
                Value<String> equipment = const Value.absent(),
                Value<String> difficulty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseCatalogCompanion(
                exerciseKey: exerciseKey,
                namePt: namePt,
                nameEn: nameEn,
                muscleGroup: muscleGroup,
                instructionsPt: instructionsPt,
                instructionsEn: instructionsEn,
                equipment: equipment,
                difficulty: difficulty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String exerciseKey,
                required String namePt,
                required String nameEn,
                required String muscleGroup,
                required String instructionsPt,
                required String instructionsEn,
                required String equipment,
                required String difficulty,
                Value<int> rowid = const Value.absent(),
              }) => ExerciseCatalogCompanion.insert(
                exerciseKey: exerciseKey,
                namePt: namePt,
                nameEn: nameEn,
                muscleGroup: muscleGroup,
                instructionsPt: instructionsPt,
                instructionsEn: instructionsEn,
                equipment: equipment,
                difficulty: difficulty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExerciseCatalogTable, ExerciseCatalogData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ExerciseCatalogTable,
                    ExerciseCatalogData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseCatalogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseCatalogTable,
      ExerciseCatalogData,
      $$ExerciseCatalogTableFilterComposer,
      $$ExerciseCatalogTableOrderingComposer,
      $$ExerciseCatalogTableAnnotationComposer,
      $$ExerciseCatalogTableCreateCompanionBuilder,
      $$ExerciseCatalogTableUpdateCompanionBuilder,
      (
        ExerciseCatalogData,
        BaseReferences<
          _$AppDatabase,
          $ExerciseCatalogTable,
          ExerciseCatalogData
        >,
      ),
      ExerciseCatalogData,
      PrefetchHooks Function()
    >;
typedef $$PlanExercisesTableCreateCompanionBuilder =
    PlanExercisesCompanion Function({
      Value<int> id,
      required int dayId,
      required String exerciseKey,
      required int sortOrder,
      Value<int> sets,
      Value<int> repTarget,
      Value<int> restSeconds,
    });
typedef $$PlanExercisesTableUpdateCompanionBuilder =
    PlanExercisesCompanion Function({
      Value<int> id,
      Value<int> dayId,
      Value<String> exerciseKey,
      Value<int> sortOrder,
      Value<int> sets,
      Value<int> repTarget,
      Value<int> restSeconds,
    });

class $$PlanExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $PlanExercisesTable> {
  $$PlanExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sets => $composableBuilder(
    column: $table.sets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repTarget => $composableBuilder(
    column: $table.repTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlanExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanExercisesTable> {
  $$PlanExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sets => $composableBuilder(
    column: $table.sets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repTarget => $composableBuilder(
    column: $table.repTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlanExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanExercisesTable> {
  $$PlanExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dayId =>
      $composableBuilder(column: $table.dayId, builder: (column) => column);

  GeneratedColumn<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get sets =>
      $composableBuilder(column: $table.sets, builder: (column) => column);

  GeneratedColumn<int> get repTarget =>
      $composableBuilder(column: $table.repTarget, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );
}

class $$PlanExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanExercisesTable,
          PlanExercise,
          $$PlanExercisesTableFilterComposer,
          $$PlanExercisesTableOrderingComposer,
          $$PlanExercisesTableAnnotationComposer,
          $$PlanExercisesTableCreateCompanionBuilder,
          $$PlanExercisesTableUpdateCompanionBuilder,
          (
            PlanExercise,
            BaseReferences<_$AppDatabase, $PlanExercisesTable, PlanExercise>,
          ),
          PlanExercise,
          PrefetchHooks Function()
        > {
  $$PlanExercisesTableTableManager(_$AppDatabase db, $PlanExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dayId = const Value.absent(),
                Value<String> exerciseKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> sets = const Value.absent(),
                Value<int> repTarget = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
              }) => PlanExercisesCompanion(
                id: id,
                dayId: dayId,
                exerciseKey: exerciseKey,
                sortOrder: sortOrder,
                sets: sets,
                repTarget: repTarget,
                restSeconds: restSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int dayId,
                required String exerciseKey,
                required int sortOrder,
                Value<int> sets = const Value.absent(),
                Value<int> repTarget = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
              }) => PlanExercisesCompanion.insert(
                id: id,
                dayId: dayId,
                exerciseKey: exerciseKey,
                sortOrder: sortOrder,
                sets: sets,
                repTarget: repTarget,
                restSeconds: restSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlanExercisesTable, PlanExercise>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PlanExercisesTable,
                    PlanExercise
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlanExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanExercisesTable,
      PlanExercise,
      $$PlanExercisesTableFilterComposer,
      $$PlanExercisesTableOrderingComposer,
      $$PlanExercisesTableAnnotationComposer,
      $$PlanExercisesTableCreateCompanionBuilder,
      $$PlanExercisesTableUpdateCompanionBuilder,
      (
        PlanExercise,
        BaseReferences<_$AppDatabase, $PlanExercisesTable, PlanExercise>,
      ),
      PlanExercise,
      PrefetchHooks Function()
    >;
typedef $$WorkoutSessionsTableCreateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      Value<int> id,
      required String day,
      required String planName,
      required String workoutName,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      Value<String> status,
    });
typedef $$WorkoutSessionsTableUpdateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      Value<int> id,
      Value<String> day,
      Value<String> planName,
      Value<String> workoutName,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      Value<String> status,
    });

class $$WorkoutSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planName => $composableBuilder(
    column: $table.planName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workoutName => $composableBuilder(
    column: $table.workoutName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkoutSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planName => $composableBuilder(
    column: $table.planName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workoutName => $composableBuilder(
    column: $table.workoutName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get planName =>
      $composableBuilder(column: $table.planName, builder: (column) => column);

  GeneratedColumn<String> get workoutName => $composableBuilder(
    column: $table.workoutName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$WorkoutSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSessionsTable,
          WorkoutSession,
          $$WorkoutSessionsTableFilterComposer,
          $$WorkoutSessionsTableOrderingComposer,
          $$WorkoutSessionsTableAnnotationComposer,
          $$WorkoutSessionsTableCreateCompanionBuilder,
          $$WorkoutSessionsTableUpdateCompanionBuilder,
          (
            WorkoutSession,
            BaseReferences<
              _$AppDatabase,
              $WorkoutSessionsTable,
              WorkoutSession
            >,
          ),
          WorkoutSession,
          PrefetchHooks Function()
        > {
  $$WorkoutSessionsTableTableManager(
    _$AppDatabase db,
    $WorkoutSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<String> planName = const Value.absent(),
                Value<String> workoutName = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => WorkoutSessionsCompanion(
                id: id,
                day: day,
                planName: planName,
                workoutName: workoutName,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String day,
                required String planName,
                required String workoutName,
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => WorkoutSessionsCompanion.insert(
                id: id,
                day: day,
                planName: planName,
                workoutName: workoutName,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutSessionsTable, WorkoutSession>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkoutSessionsTable,
                    WorkoutSession
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSessionsTable,
      WorkoutSession,
      $$WorkoutSessionsTableFilterComposer,
      $$WorkoutSessionsTableOrderingComposer,
      $$WorkoutSessionsTableAnnotationComposer,
      $$WorkoutSessionsTableCreateCompanionBuilder,
      $$WorkoutSessionsTableUpdateCompanionBuilder,
      (
        WorkoutSession,
        BaseReferences<_$AppDatabase, $WorkoutSessionsTable, WorkoutSession>,
      ),
      WorkoutSession,
      PrefetchHooks Function()
    >;
typedef $$ExerciseSetsTableCreateCompanionBuilder =
    ExerciseSetsCompanion Function({
      Value<int> id,
      required int sessionId,
      required String exerciseKey,
      required int setNumber,
      required int targetReps,
      Value<int?> reps,
      Value<double?> weightKg,
      Value<bool> completed,
      Value<DateTime?> completedAt,
    });
typedef $$ExerciseSetsTableUpdateCompanionBuilder =
    ExerciseSetsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<String> exerciseKey,
      Value<int> setNumber,
      Value<int> targetReps,
      Value<int?> reps,
      Value<double?> weightKg,
      Value<bool> completed,
      Value<DateTime?> completedAt,
    });

class $$ExerciseSetsTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseSetsTable> {
  $$ExerciseSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseSetsTable> {
  $$ExerciseSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseSetsTable> {
  $$ExerciseSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get setNumber =>
      $composableBuilder(column: $table.setNumber, builder: (column) => column);

  GeneratedColumn<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$ExerciseSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseSetsTable,
          ExerciseSet,
          $$ExerciseSetsTableFilterComposer,
          $$ExerciseSetsTableOrderingComposer,
          $$ExerciseSetsTableAnnotationComposer,
          $$ExerciseSetsTableCreateCompanionBuilder,
          $$ExerciseSetsTableUpdateCompanionBuilder,
          (
            ExerciseSet,
            BaseReferences<_$AppDatabase, $ExerciseSetsTable, ExerciseSet>,
          ),
          ExerciseSet,
          PrefetchHooks Function()
        > {
  $$ExerciseSetsTableTableManager(_$AppDatabase db, $ExerciseSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<String> exerciseKey = const Value.absent(),
                Value<int> setNumber = const Value.absent(),
                Value<int> targetReps = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => ExerciseSetsCompanion(
                id: id,
                sessionId: sessionId,
                exerciseKey: exerciseKey,
                setNumber: setNumber,
                targetReps: targetReps,
                reps: reps,
                weightKg: weightKg,
                completed: completed,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required String exerciseKey,
                required int setNumber,
                required int targetReps,
                Value<int?> reps = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
              }) => ExerciseSetsCompanion.insert(
                id: id,
                sessionId: sessionId,
                exerciseKey: exerciseKey,
                setNumber: setNumber,
                targetReps: targetReps,
                reps: reps,
                weightKg: weightKg,
                completed: completed,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExerciseSetsTable, ExerciseSet>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ExerciseSetsTable,
                    ExerciseSet
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseSetsTable,
      ExerciseSet,
      $$ExerciseSetsTableFilterComposer,
      $$ExerciseSetsTableOrderingComposer,
      $$ExerciseSetsTableAnnotationComposer,
      $$ExerciseSetsTableCreateCompanionBuilder,
      $$ExerciseSetsTableUpdateCompanionBuilder,
      (
        ExerciseSet,
        BaseReferences<_$AppDatabase, $ExerciseSetsTable, ExerciseSet>,
      ),
      ExerciseSet,
      PrefetchHooks Function()
    >;
typedef $$BodyMeasurementsTableCreateCompanionBuilder =
    BodyMeasurementsCompanion Function({
      Value<int> id,
      Value<DateTime> measuredAt,
      required double weightKg,
      Value<String?> note,
    });
typedef $$BodyMeasurementsTableUpdateCompanionBuilder =
    BodyMeasurementsCompanion Function({
      Value<int> id,
      Value<DateTime> measuredAt,
      Value<double> weightKg,
      Value<String?> note,
    });

class $$BodyMeasurementsTableFilterComposer
    extends Composer<_$AppDatabase, $BodyMeasurementsTable> {
  $$BodyMeasurementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BodyMeasurementsTableOrderingComposer
    extends Composer<_$AppDatabase, $BodyMeasurementsTable> {
  $$BodyMeasurementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodyMeasurementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BodyMeasurementsTable> {
  $$BodyMeasurementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$BodyMeasurementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BodyMeasurementsTable,
          BodyMeasurement,
          $$BodyMeasurementsTableFilterComposer,
          $$BodyMeasurementsTableOrderingComposer,
          $$BodyMeasurementsTableAnnotationComposer,
          $$BodyMeasurementsTableCreateCompanionBuilder,
          $$BodyMeasurementsTableUpdateCompanionBuilder,
          (
            BodyMeasurement,
            BaseReferences<
              _$AppDatabase,
              $BodyMeasurementsTable,
              BodyMeasurement
            >,
          ),
          BodyMeasurement,
          PrefetchHooks Function()
        > {
  $$BodyMeasurementsTableTableManager(
    _$AppDatabase db,
    $BodyMeasurementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodyMeasurementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BodyMeasurementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BodyMeasurementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> measuredAt = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => BodyMeasurementsCompanion(
                id: id,
                measuredAt: measuredAt,
                weightKg: weightKg,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> measuredAt = const Value.absent(),
                required double weightKg,
                Value<String?> note = const Value.absent(),
              }) => BodyMeasurementsCompanion.insert(
                id: id,
                measuredAt: measuredAt,
                weightKg: weightKg,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BodyMeasurementsTable, BodyMeasurement>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BodyMeasurementsTable,
                    BodyMeasurement
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BodyMeasurementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BodyMeasurementsTable,
      BodyMeasurement,
      $$BodyMeasurementsTableFilterComposer,
      $$BodyMeasurementsTableOrderingComposer,
      $$BodyMeasurementsTableAnnotationComposer,
      $$BodyMeasurementsTableCreateCompanionBuilder,
      $$BodyMeasurementsTableUpdateCompanionBuilder,
      (
        BodyMeasurement,
        BaseReferences<_$AppDatabase, $BodyMeasurementsTable, BodyMeasurement>,
      ),
      BodyMeasurement,
      PrefetchHooks Function()
    >;
typedef $$ScheduleSkipsTableCreateCompanionBuilder =
    ScheduleSkipsCompanion Function({
      required String date,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ScheduleSkipsTableUpdateCompanionBuilder =
    ScheduleSkipsCompanion Function({
      Value<String> date,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ScheduleSkipsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduleSkipsTable> {
  $$ScheduleSkipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduleSkipsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduleSkipsTable> {
  $$ScheduleSkipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduleSkipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduleSkipsTable> {
  $$ScheduleSkipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ScheduleSkipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduleSkipsTable,
          ScheduleSkip,
          $$ScheduleSkipsTableFilterComposer,
          $$ScheduleSkipsTableOrderingComposer,
          $$ScheduleSkipsTableAnnotationComposer,
          $$ScheduleSkipsTableCreateCompanionBuilder,
          $$ScheduleSkipsTableUpdateCompanionBuilder,
          (
            ScheduleSkip,
            BaseReferences<_$AppDatabase, $ScheduleSkipsTable, ScheduleSkip>,
          ),
          ScheduleSkip,
          PrefetchHooks Function()
        > {
  $$ScheduleSkipsTableTableManager(_$AppDatabase db, $ScheduleSkipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleSkipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduleSkipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduleSkipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleSkipsCompanion(
                date: date,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleSkipsCompanion.insert(
                date: date,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScheduleSkipsTable, ScheduleSkip>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ScheduleSkipsTable,
                    ScheduleSkip
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduleSkipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduleSkipsTable,
      ScheduleSkip,
      $$ScheduleSkipsTableFilterComposer,
      $$ScheduleSkipsTableOrderingComposer,
      $$ScheduleSkipsTableAnnotationComposer,
      $$ScheduleSkipsTableCreateCompanionBuilder,
      $$ScheduleSkipsTableUpdateCompanionBuilder,
      (
        ScheduleSkip,
        BaseReferences<_$AppDatabase, $ScheduleSkipsTable, ScheduleSkip>,
      ),
      ScheduleSkip,
      PrefetchHooks Function()
    >;
typedef $$MotionAnalysesTableCreateCompanionBuilder =
    MotionAnalysesCompanion Function({
      Value<int> id,
      required String exerciseKey,
      required String patternId,
      required DateTime startedAt,
      required int durationMs,
      required int fullReps,
      required int partialReps,
      Value<int> holdMs,
      required double meanConfidence,
      required double observedRatio,
      required String status,
      Value<String> eventsJson,
      Value<double?> techniqueScore,
    });
typedef $$MotionAnalysesTableUpdateCompanionBuilder =
    MotionAnalysesCompanion Function({
      Value<int> id,
      Value<String> exerciseKey,
      Value<String> patternId,
      Value<DateTime> startedAt,
      Value<int> durationMs,
      Value<int> fullReps,
      Value<int> partialReps,
      Value<int> holdMs,
      Value<double> meanConfidence,
      Value<double> observedRatio,
      Value<String> status,
      Value<String> eventsJson,
      Value<double?> techniqueScore,
    });

class $$MotionAnalysesTableFilterComposer
    extends Composer<_$AppDatabase, $MotionAnalysesTable> {
  $$MotionAnalysesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patternId => $composableBuilder(
    column: $table.patternId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fullReps => $composableBuilder(
    column: $table.fullReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get partialReps => $composableBuilder(
    column: $table.partialReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get holdMs => $composableBuilder(
    column: $table.holdMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get meanConfidence => $composableBuilder(
    column: $table.meanConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get observedRatio => $composableBuilder(
    column: $table.observedRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventsJson => $composableBuilder(
    column: $table.eventsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get techniqueScore => $composableBuilder(
    column: $table.techniqueScore,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MotionAnalysesTableOrderingComposer
    extends Composer<_$AppDatabase, $MotionAnalysesTable> {
  $$MotionAnalysesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patternId => $composableBuilder(
    column: $table.patternId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fullReps => $composableBuilder(
    column: $table.fullReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get partialReps => $composableBuilder(
    column: $table.partialReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holdMs => $composableBuilder(
    column: $table.holdMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get meanConfidence => $composableBuilder(
    column: $table.meanConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get observedRatio => $composableBuilder(
    column: $table.observedRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventsJson => $composableBuilder(
    column: $table.eventsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get techniqueScore => $composableBuilder(
    column: $table.techniqueScore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MotionAnalysesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MotionAnalysesTable> {
  $$MotionAnalysesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get patternId =>
      $composableBuilder(column: $table.patternId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fullReps =>
      $composableBuilder(column: $table.fullReps, builder: (column) => column);

  GeneratedColumn<int> get partialReps => $composableBuilder(
    column: $table.partialReps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get holdMs =>
      $composableBuilder(column: $table.holdMs, builder: (column) => column);

  GeneratedColumn<double> get meanConfidence => $composableBuilder(
    column: $table.meanConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<double> get observedRatio => $composableBuilder(
    column: $table.observedRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get eventsJson => $composableBuilder(
    column: $table.eventsJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get techniqueScore => $composableBuilder(
    column: $table.techniqueScore,
    builder: (column) => column,
  );
}

class $$MotionAnalysesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MotionAnalysesTable,
          MotionAnalysisRecord,
          $$MotionAnalysesTableFilterComposer,
          $$MotionAnalysesTableOrderingComposer,
          $$MotionAnalysesTableAnnotationComposer,
          $$MotionAnalysesTableCreateCompanionBuilder,
          $$MotionAnalysesTableUpdateCompanionBuilder,
          (
            MotionAnalysisRecord,
            BaseReferences<
              _$AppDatabase,
              $MotionAnalysesTable,
              MotionAnalysisRecord
            >,
          ),
          MotionAnalysisRecord,
          PrefetchHooks Function()
        > {
  $$MotionAnalysesTableTableManager(
    _$AppDatabase db,
    $MotionAnalysesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MotionAnalysesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MotionAnalysesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MotionAnalysesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> exerciseKey = const Value.absent(),
                Value<String> patternId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> fullReps = const Value.absent(),
                Value<int> partialReps = const Value.absent(),
                Value<int> holdMs = const Value.absent(),
                Value<double> meanConfidence = const Value.absent(),
                Value<double> observedRatio = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> eventsJson = const Value.absent(),
                Value<double?> techniqueScore = const Value.absent(),
              }) => MotionAnalysesCompanion(
                id: id,
                exerciseKey: exerciseKey,
                patternId: patternId,
                startedAt: startedAt,
                durationMs: durationMs,
                fullReps: fullReps,
                partialReps: partialReps,
                holdMs: holdMs,
                meanConfidence: meanConfidence,
                observedRatio: observedRatio,
                status: status,
                eventsJson: eventsJson,
                techniqueScore: techniqueScore,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String exerciseKey,
                required String patternId,
                required DateTime startedAt,
                required int durationMs,
                required int fullReps,
                required int partialReps,
                Value<int> holdMs = const Value.absent(),
                required double meanConfidence,
                required double observedRatio,
                required String status,
                Value<String> eventsJson = const Value.absent(),
                Value<double?> techniqueScore = const Value.absent(),
              }) => MotionAnalysesCompanion.insert(
                id: id,
                exerciseKey: exerciseKey,
                patternId: patternId,
                startedAt: startedAt,
                durationMs: durationMs,
                fullReps: fullReps,
                partialReps: partialReps,
                holdMs: holdMs,
                meanConfidence: meanConfidence,
                observedRatio: observedRatio,
                status: status,
                eventsJson: eventsJson,
                techniqueScore: techniqueScore,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MotionAnalysesTable, MotionAnalysisRecord>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $MotionAnalysesTable,
                    MotionAnalysisRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MotionAnalysesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MotionAnalysesTable,
      MotionAnalysisRecord,
      $$MotionAnalysesTableFilterComposer,
      $$MotionAnalysesTableOrderingComposer,
      $$MotionAnalysesTableAnnotationComposer,
      $$MotionAnalysesTableCreateCompanionBuilder,
      $$MotionAnalysesTableUpdateCompanionBuilder,
      (
        MotionAnalysisRecord,
        BaseReferences<
          _$AppDatabase,
          $MotionAnalysesTable,
          MotionAnalysisRecord
        >,
      ),
      MotionAnalysisRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoodEntriesTableTableManager get foodEntries =>
      $$FoodEntriesTableTableManager(_db, _db.foodEntries);
  $$CachedProductsTableTableManager get cachedProducts =>
      $$CachedProductsTableTableManager(_db, _db.cachedProducts);
  $$WorkoutPlansTableTableManager get workoutPlans =>
      $$WorkoutPlansTableTableManager(_db, _db.workoutPlans);
  $$WorkoutDaysTableTableManager get workoutDays =>
      $$WorkoutDaysTableTableManager(_db, _db.workoutDays);
  $$ExerciseCatalogTableTableManager get exerciseCatalog =>
      $$ExerciseCatalogTableTableManager(_db, _db.exerciseCatalog);
  $$PlanExercisesTableTableManager get planExercises =>
      $$PlanExercisesTableTableManager(_db, _db.planExercises);
  $$WorkoutSessionsTableTableManager get workoutSessions =>
      $$WorkoutSessionsTableTableManager(_db, _db.workoutSessions);
  $$ExerciseSetsTableTableManager get exerciseSets =>
      $$ExerciseSetsTableTableManager(_db, _db.exerciseSets);
  $$BodyMeasurementsTableTableManager get bodyMeasurements =>
      $$BodyMeasurementsTableTableManager(_db, _db.bodyMeasurements);
  $$ScheduleSkipsTableTableManager get scheduleSkips =>
      $$ScheduleSkipsTableTableManager(_db, _db.scheduleSkips);
  $$MotionAnalysesTableTableManager get motionAnalyses =>
      $$MotionAnalysesTableTableManager(_db, _db.motionAnalyses);
}
