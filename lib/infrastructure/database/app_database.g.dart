// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProductIdentitysTable extends ProductIdentitys
    with TableInfo<$ProductIdentitysTable, ProductIdentity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductIdentitysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _janMeta = const VerificationMeta('jan');
  @override
  late final GeneratedColumn<String> jan = GeneratedColumn<String>(
    'jan',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    jan,
    displayName,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_identity';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductIdentity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('jan')) {
      context.handle(
        _janMeta,
        jan.isAcceptableOrUnknown(data['jan']!, _janMeta),
      );
    } else if (isInserting) {
      context.missing(_janMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductIdentity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductIdentity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      jan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jan'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProductIdentitysTable createAlias(String alias) {
    return $ProductIdentitysTable(attachedDatabase, alias);
  }
}

class ProductIdentity extends DataClass implements Insertable<ProductIdentity> {
  final String id;
  final String jan;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProductIdentity({
    required this.id,
    required this.jan,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['jan'] = Variable<String>(jan);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProductIdentitysCompanion toCompanion(bool nullToAbsent) {
    return ProductIdentitysCompanion(
      id: Value(id),
      jan: Value(jan),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProductIdentity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductIdentity(
      id: serializer.fromJson<String>(json['id']),
      jan: serializer.fromJson<String>(json['jan']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'jan': serializer.toJson<String>(jan),
      'displayName': serializer.toJson<String?>(displayName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProductIdentity copyWith({
    String? id,
    String? jan,
    Value<String?> displayName = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProductIdentity(
    id: id ?? this.id,
    jan: jan ?? this.jan,
    displayName: displayName.present ? displayName.value : this.displayName,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProductIdentity copyWithCompanion(ProductIdentitysCompanion data) {
    return ProductIdentity(
      id: data.id.present ? data.id.value : this.id,
      jan: data.jan.present ? data.jan.value : this.jan,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductIdentity(')
          ..write('id: $id, ')
          ..write('jan: $jan, ')
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, jan, displayName, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductIdentity &&
          other.id == this.id &&
          other.jan == this.jan &&
          other.displayName == this.displayName &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProductIdentitysCompanion extends UpdateCompanion<ProductIdentity> {
  final Value<String> id;
  final Value<String> jan;
  final Value<String?> displayName;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProductIdentitysCompanion({
    this.id = const Value.absent(),
    this.jan = const Value.absent(),
    this.displayName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductIdentitysCompanion.insert({
    required String id,
    required String jan,
    this.displayName = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       jan = Value(jan),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProductIdentity> custom({
    Expression<String>? id,
    Expression<String>? jan,
    Expression<String>? displayName,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jan != null) 'jan': jan,
      if (displayName != null) 'display_name': displayName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductIdentitysCompanion copyWith({
    Value<String>? id,
    Value<String>? jan,
    Value<String?>? displayName,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProductIdentitysCompanion(
      id: id ?? this.id,
      jan: jan ?? this.jan,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (jan.present) {
      map['jan'] = Variable<String>(jan.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductIdentitysCompanion(')
          ..write('id: $id, ')
          ..write('jan: $jan, ')
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PriceObservationsTable extends PriceObservations
    with TableInfo<$PriceObservationsTable, PriceObservation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriceObservationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES product_identity (id)',
    ),
  );
  static const VerificationMeta _priceYenMeta = const VerificationMeta(
    'priceYen',
  );
  @override
  late final GeneratedColumn<int> priceYen = GeneratedColumn<int>(
    'price_yen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _observedAtMeta = const VerificationMeta(
    'observedAt',
  );
  @override
  late final GeneratedColumn<DateTime> observedAt = GeneratedColumn<DateTime>(
    'observed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceConfidenceMeta = const VerificationMeta(
    'priceConfidence',
  );
  @override
  late final GeneratedColumn<double> priceConfidence = GeneratedColumn<double>(
    'price_confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isValidMeta = const VerificationMeta(
    'isValid',
  );
  @override
  late final GeneratedColumn<bool> isValid = GeneratedColumn<bool>(
    'is_valid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_valid" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _duplicateKeyMeta = const VerificationMeta(
    'duplicateKey',
  );
  @override
  late final GeneratedColumn<String> duplicateKey = GeneratedColumn<String>(
    'duplicate_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSaleVisibleMeta = const VerificationMeta(
    'isSaleVisible',
  );
  @override
  late final GeneratedColumn<bool> isSaleVisible = GeneratedColumn<bool>(
    'is_sale_visible',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_sale_visible" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isMemberPriceVisibleMeta =
      const VerificationMeta('isMemberPriceVisible');
  @override
  late final GeneratedColumn<bool> isMemberPriceVisible = GeneratedColumn<bool>(
    'is_member_price_visible',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_member_price_visible" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isCouponPriceVisibleMeta =
      const VerificationMeta('isCouponPriceVisible');
  @override
  late final GeneratedColumn<bool> isCouponPriceVisible = GeneratedColumn<bool>(
    'is_coupon_price_visible',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_coupon_price_visible" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isBulkDiscountMeta = const VerificationMeta(
    'isBulkDiscount',
  );
  @override
  late final GeneratedColumn<bool> isBulkDiscount = GeneratedColumn<bool>(
    'is_bulk_discount',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bulk_discount" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isManualEntryMeta = const VerificationMeta(
    'isManualEntry',
  );
  @override
  late final GeneratedColumn<bool> isManualEntry = GeneratedColumn<bool>(
    'is_manual_entry',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_manual_entry" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    priceYen,
    observedAt,
    priceConfidence,
    isValid,
    duplicateKey,
    isSaleVisible,
    isMemberPriceVisible,
    isCouponPriceVisible,
    isBulkDiscount,
    isManualEntry,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'price_observation';
  @override
  VerificationContext validateIntegrity(
    Insertable<PriceObservation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('price_yen')) {
      context.handle(
        _priceYenMeta,
        priceYen.isAcceptableOrUnknown(data['price_yen']!, _priceYenMeta),
      );
    } else if (isInserting) {
      context.missing(_priceYenMeta);
    }
    if (data.containsKey('observed_at')) {
      context.handle(
        _observedAtMeta,
        observedAt.isAcceptableOrUnknown(data['observed_at']!, _observedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_observedAtMeta);
    }
    if (data.containsKey('price_confidence')) {
      context.handle(
        _priceConfidenceMeta,
        priceConfidence.isAcceptableOrUnknown(
          data['price_confidence']!,
          _priceConfidenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_priceConfidenceMeta);
    }
    if (data.containsKey('is_valid')) {
      context.handle(
        _isValidMeta,
        isValid.isAcceptableOrUnknown(data['is_valid']!, _isValidMeta),
      );
    }
    if (data.containsKey('duplicate_key')) {
      context.handle(
        _duplicateKeyMeta,
        duplicateKey.isAcceptableOrUnknown(
          data['duplicate_key']!,
          _duplicateKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_duplicateKeyMeta);
    }
    if (data.containsKey('is_sale_visible')) {
      context.handle(
        _isSaleVisibleMeta,
        isSaleVisible.isAcceptableOrUnknown(
          data['is_sale_visible']!,
          _isSaleVisibleMeta,
        ),
      );
    }
    if (data.containsKey('is_member_price_visible')) {
      context.handle(
        _isMemberPriceVisibleMeta,
        isMemberPriceVisible.isAcceptableOrUnknown(
          data['is_member_price_visible']!,
          _isMemberPriceVisibleMeta,
        ),
      );
    }
    if (data.containsKey('is_coupon_price_visible')) {
      context.handle(
        _isCouponPriceVisibleMeta,
        isCouponPriceVisible.isAcceptableOrUnknown(
          data['is_coupon_price_visible']!,
          _isCouponPriceVisibleMeta,
        ),
      );
    }
    if (data.containsKey('is_bulk_discount')) {
      context.handle(
        _isBulkDiscountMeta,
        isBulkDiscount.isAcceptableOrUnknown(
          data['is_bulk_discount']!,
          _isBulkDiscountMeta,
        ),
      );
    }
    if (data.containsKey('is_manual_entry')) {
      context.handle(
        _isManualEntryMeta,
        isManualEntry.isAcceptableOrUnknown(
          data['is_manual_entry']!,
          _isManualEntryMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {duplicateKey},
  ];
  @override
  PriceObservation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceObservation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      priceYen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_yen'],
      )!,
      observedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}observed_at'],
      )!,
      priceConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_confidence'],
      )!,
      isValid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_valid'],
      )!,
      duplicateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duplicate_key'],
      )!,
      isSaleVisible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sale_visible'],
      ),
      isMemberPriceVisible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_member_price_visible'],
      ),
      isCouponPriceVisible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_coupon_price_visible'],
      ),
      isBulkDiscount: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bulk_discount'],
      ),
      isManualEntry: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_manual_entry'],
      ),
    );
  }

  @override
  $PriceObservationsTable createAlias(String alias) {
    return $PriceObservationsTable(attachedDatabase, alias);
  }
}

class PriceObservation extends DataClass
    implements Insertable<PriceObservation> {
  final String id;
  final String productId;
  final int priceYen;
  final DateTime observedAt;
  final double priceConfidence;
  final bool isValid;
  final String duplicateKey;
  final bool? isSaleVisible;
  final bool? isMemberPriceVisible;
  final bool? isCouponPriceVisible;
  final bool? isBulkDiscount;

  /// True when the price was entered manually by the user instead of OCR.
  /// Null for observations recorded before manual entry existed.
  final bool? isManualEntry;
  const PriceObservation({
    required this.id,
    required this.productId,
    required this.priceYen,
    required this.observedAt,
    required this.priceConfidence,
    required this.isValid,
    required this.duplicateKey,
    this.isSaleVisible,
    this.isMemberPriceVisible,
    this.isCouponPriceVisible,
    this.isBulkDiscount,
    this.isManualEntry,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['price_yen'] = Variable<int>(priceYen);
    map['observed_at'] = Variable<DateTime>(observedAt);
    map['price_confidence'] = Variable<double>(priceConfidence);
    map['is_valid'] = Variable<bool>(isValid);
    map['duplicate_key'] = Variable<String>(duplicateKey);
    if (!nullToAbsent || isSaleVisible != null) {
      map['is_sale_visible'] = Variable<bool>(isSaleVisible);
    }
    if (!nullToAbsent || isMemberPriceVisible != null) {
      map['is_member_price_visible'] = Variable<bool>(isMemberPriceVisible);
    }
    if (!nullToAbsent || isCouponPriceVisible != null) {
      map['is_coupon_price_visible'] = Variable<bool>(isCouponPriceVisible);
    }
    if (!nullToAbsent || isBulkDiscount != null) {
      map['is_bulk_discount'] = Variable<bool>(isBulkDiscount);
    }
    if (!nullToAbsent || isManualEntry != null) {
      map['is_manual_entry'] = Variable<bool>(isManualEntry);
    }
    return map;
  }

  PriceObservationsCompanion toCompanion(bool nullToAbsent) {
    return PriceObservationsCompanion(
      id: Value(id),
      productId: Value(productId),
      priceYen: Value(priceYen),
      observedAt: Value(observedAt),
      priceConfidence: Value(priceConfidence),
      isValid: Value(isValid),
      duplicateKey: Value(duplicateKey),
      isSaleVisible: isSaleVisible == null && nullToAbsent
          ? const Value.absent()
          : Value(isSaleVisible),
      isMemberPriceVisible: isMemberPriceVisible == null && nullToAbsent
          ? const Value.absent()
          : Value(isMemberPriceVisible),
      isCouponPriceVisible: isCouponPriceVisible == null && nullToAbsent
          ? const Value.absent()
          : Value(isCouponPriceVisible),
      isBulkDiscount: isBulkDiscount == null && nullToAbsent
          ? const Value.absent()
          : Value(isBulkDiscount),
      isManualEntry: isManualEntry == null && nullToAbsent
          ? const Value.absent()
          : Value(isManualEntry),
    );
  }

  factory PriceObservation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceObservation(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      priceYen: serializer.fromJson<int>(json['priceYen']),
      observedAt: serializer.fromJson<DateTime>(json['observedAt']),
      priceConfidence: serializer.fromJson<double>(json['priceConfidence']),
      isValid: serializer.fromJson<bool>(json['isValid']),
      duplicateKey: serializer.fromJson<String>(json['duplicateKey']),
      isSaleVisible: serializer.fromJson<bool?>(json['isSaleVisible']),
      isMemberPriceVisible: serializer.fromJson<bool?>(
        json['isMemberPriceVisible'],
      ),
      isCouponPriceVisible: serializer.fromJson<bool?>(
        json['isCouponPriceVisible'],
      ),
      isBulkDiscount: serializer.fromJson<bool?>(json['isBulkDiscount']),
      isManualEntry: serializer.fromJson<bool?>(json['isManualEntry']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'priceYen': serializer.toJson<int>(priceYen),
      'observedAt': serializer.toJson<DateTime>(observedAt),
      'priceConfidence': serializer.toJson<double>(priceConfidence),
      'isValid': serializer.toJson<bool>(isValid),
      'duplicateKey': serializer.toJson<String>(duplicateKey),
      'isSaleVisible': serializer.toJson<bool?>(isSaleVisible),
      'isMemberPriceVisible': serializer.toJson<bool?>(isMemberPriceVisible),
      'isCouponPriceVisible': serializer.toJson<bool?>(isCouponPriceVisible),
      'isBulkDiscount': serializer.toJson<bool?>(isBulkDiscount),
      'isManualEntry': serializer.toJson<bool?>(isManualEntry),
    };
  }

  PriceObservation copyWith({
    String? id,
    String? productId,
    int? priceYen,
    DateTime? observedAt,
    double? priceConfidence,
    bool? isValid,
    String? duplicateKey,
    Value<bool?> isSaleVisible = const Value.absent(),
    Value<bool?> isMemberPriceVisible = const Value.absent(),
    Value<bool?> isCouponPriceVisible = const Value.absent(),
    Value<bool?> isBulkDiscount = const Value.absent(),
    Value<bool?> isManualEntry = const Value.absent(),
  }) => PriceObservation(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    priceYen: priceYen ?? this.priceYen,
    observedAt: observedAt ?? this.observedAt,
    priceConfidence: priceConfidence ?? this.priceConfidence,
    isValid: isValid ?? this.isValid,
    duplicateKey: duplicateKey ?? this.duplicateKey,
    isSaleVisible: isSaleVisible.present
        ? isSaleVisible.value
        : this.isSaleVisible,
    isMemberPriceVisible: isMemberPriceVisible.present
        ? isMemberPriceVisible.value
        : this.isMemberPriceVisible,
    isCouponPriceVisible: isCouponPriceVisible.present
        ? isCouponPriceVisible.value
        : this.isCouponPriceVisible,
    isBulkDiscount: isBulkDiscount.present
        ? isBulkDiscount.value
        : this.isBulkDiscount,
    isManualEntry: isManualEntry.present
        ? isManualEntry.value
        : this.isManualEntry,
  );
  PriceObservation copyWithCompanion(PriceObservationsCompanion data) {
    return PriceObservation(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      priceYen: data.priceYen.present ? data.priceYen.value : this.priceYen,
      observedAt: data.observedAt.present
          ? data.observedAt.value
          : this.observedAt,
      priceConfidence: data.priceConfidence.present
          ? data.priceConfidence.value
          : this.priceConfidence,
      isValid: data.isValid.present ? data.isValid.value : this.isValid,
      duplicateKey: data.duplicateKey.present
          ? data.duplicateKey.value
          : this.duplicateKey,
      isSaleVisible: data.isSaleVisible.present
          ? data.isSaleVisible.value
          : this.isSaleVisible,
      isMemberPriceVisible: data.isMemberPriceVisible.present
          ? data.isMemberPriceVisible.value
          : this.isMemberPriceVisible,
      isCouponPriceVisible: data.isCouponPriceVisible.present
          ? data.isCouponPriceVisible.value
          : this.isCouponPriceVisible,
      isBulkDiscount: data.isBulkDiscount.present
          ? data.isBulkDiscount.value
          : this.isBulkDiscount,
      isManualEntry: data.isManualEntry.present
          ? data.isManualEntry.value
          : this.isManualEntry,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceObservation(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('priceYen: $priceYen, ')
          ..write('observedAt: $observedAt, ')
          ..write('priceConfidence: $priceConfidence, ')
          ..write('isValid: $isValid, ')
          ..write('duplicateKey: $duplicateKey, ')
          ..write('isSaleVisible: $isSaleVisible, ')
          ..write('isMemberPriceVisible: $isMemberPriceVisible, ')
          ..write('isCouponPriceVisible: $isCouponPriceVisible, ')
          ..write('isBulkDiscount: $isBulkDiscount, ')
          ..write('isManualEntry: $isManualEntry')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    priceYen,
    observedAt,
    priceConfidence,
    isValid,
    duplicateKey,
    isSaleVisible,
    isMemberPriceVisible,
    isCouponPriceVisible,
    isBulkDiscount,
    isManualEntry,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceObservation &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.priceYen == this.priceYen &&
          other.observedAt == this.observedAt &&
          other.priceConfidence == this.priceConfidence &&
          other.isValid == this.isValid &&
          other.duplicateKey == this.duplicateKey &&
          other.isSaleVisible == this.isSaleVisible &&
          other.isMemberPriceVisible == this.isMemberPriceVisible &&
          other.isCouponPriceVisible == this.isCouponPriceVisible &&
          other.isBulkDiscount == this.isBulkDiscount &&
          other.isManualEntry == this.isManualEntry);
}

class PriceObservationsCompanion extends UpdateCompanion<PriceObservation> {
  final Value<String> id;
  final Value<String> productId;
  final Value<int> priceYen;
  final Value<DateTime> observedAt;
  final Value<double> priceConfidence;
  final Value<bool> isValid;
  final Value<String> duplicateKey;
  final Value<bool?> isSaleVisible;
  final Value<bool?> isMemberPriceVisible;
  final Value<bool?> isCouponPriceVisible;
  final Value<bool?> isBulkDiscount;
  final Value<bool?> isManualEntry;
  final Value<int> rowid;
  const PriceObservationsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.priceYen = const Value.absent(),
    this.observedAt = const Value.absent(),
    this.priceConfidence = const Value.absent(),
    this.isValid = const Value.absent(),
    this.duplicateKey = const Value.absent(),
    this.isSaleVisible = const Value.absent(),
    this.isMemberPriceVisible = const Value.absent(),
    this.isCouponPriceVisible = const Value.absent(),
    this.isBulkDiscount = const Value.absent(),
    this.isManualEntry = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PriceObservationsCompanion.insert({
    required String id,
    required String productId,
    required int priceYen,
    required DateTime observedAt,
    required double priceConfidence,
    this.isValid = const Value.absent(),
    required String duplicateKey,
    this.isSaleVisible = const Value.absent(),
    this.isMemberPriceVisible = const Value.absent(),
    this.isCouponPriceVisible = const Value.absent(),
    this.isBulkDiscount = const Value.absent(),
    this.isManualEntry = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId),
       priceYen = Value(priceYen),
       observedAt = Value(observedAt),
       priceConfidence = Value(priceConfidence),
       duplicateKey = Value(duplicateKey);
  static Insertable<PriceObservation> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<int>? priceYen,
    Expression<DateTime>? observedAt,
    Expression<double>? priceConfidence,
    Expression<bool>? isValid,
    Expression<String>? duplicateKey,
    Expression<bool>? isSaleVisible,
    Expression<bool>? isMemberPriceVisible,
    Expression<bool>? isCouponPriceVisible,
    Expression<bool>? isBulkDiscount,
    Expression<bool>? isManualEntry,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (priceYen != null) 'price_yen': priceYen,
      if (observedAt != null) 'observed_at': observedAt,
      if (priceConfidence != null) 'price_confidence': priceConfidence,
      if (isValid != null) 'is_valid': isValid,
      if (duplicateKey != null) 'duplicate_key': duplicateKey,
      if (isSaleVisible != null) 'is_sale_visible': isSaleVisible,
      if (isMemberPriceVisible != null)
        'is_member_price_visible': isMemberPriceVisible,
      if (isCouponPriceVisible != null)
        'is_coupon_price_visible': isCouponPriceVisible,
      if (isBulkDiscount != null) 'is_bulk_discount': isBulkDiscount,
      if (isManualEntry != null) 'is_manual_entry': isManualEntry,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PriceObservationsCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<int>? priceYen,
    Value<DateTime>? observedAt,
    Value<double>? priceConfidence,
    Value<bool>? isValid,
    Value<String>? duplicateKey,
    Value<bool?>? isSaleVisible,
    Value<bool?>? isMemberPriceVisible,
    Value<bool?>? isCouponPriceVisible,
    Value<bool?>? isBulkDiscount,
    Value<bool?>? isManualEntry,
    Value<int>? rowid,
  }) {
    return PriceObservationsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      priceYen: priceYen ?? this.priceYen,
      observedAt: observedAt ?? this.observedAt,
      priceConfidence: priceConfidence ?? this.priceConfidence,
      isValid: isValid ?? this.isValid,
      duplicateKey: duplicateKey ?? this.duplicateKey,
      isSaleVisible: isSaleVisible ?? this.isSaleVisible,
      isMemberPriceVisible: isMemberPriceVisible ?? this.isMemberPriceVisible,
      isCouponPriceVisible: isCouponPriceVisible ?? this.isCouponPriceVisible,
      isBulkDiscount: isBulkDiscount ?? this.isBulkDiscount,
      isManualEntry: isManualEntry ?? this.isManualEntry,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (priceYen.present) {
      map['price_yen'] = Variable<int>(priceYen.value);
    }
    if (observedAt.present) {
      map['observed_at'] = Variable<DateTime>(observedAt.value);
    }
    if (priceConfidence.present) {
      map['price_confidence'] = Variable<double>(priceConfidence.value);
    }
    if (isValid.present) {
      map['is_valid'] = Variable<bool>(isValid.value);
    }
    if (duplicateKey.present) {
      map['duplicate_key'] = Variable<String>(duplicateKey.value);
    }
    if (isSaleVisible.present) {
      map['is_sale_visible'] = Variable<bool>(isSaleVisible.value);
    }
    if (isMemberPriceVisible.present) {
      map['is_member_price_visible'] = Variable<bool>(
        isMemberPriceVisible.value,
      );
    }
    if (isCouponPriceVisible.present) {
      map['is_coupon_price_visible'] = Variable<bool>(
        isCouponPriceVisible.value,
      );
    }
    if (isBulkDiscount.present) {
      map['is_bulk_discount'] = Variable<bool>(isBulkDiscount.value);
    }
    if (isManualEntry.present) {
      map['is_manual_entry'] = Variable<bool>(isManualEntry.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PriceObservationsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('priceYen: $priceYen, ')
          ..write('observedAt: $observedAt, ')
          ..write('priceConfidence: $priceConfidence, ')
          ..write('isValid: $isValid, ')
          ..write('duplicateKey: $duplicateKey, ')
          ..write('isSaleVisible: $isSaleVisible, ')
          ..write('isMemberPriceVisible: $isMemberPriceVisible, ')
          ..write('isCouponPriceVisible: $isCouponPriceVisible, ')
          ..write('isBulkDiscount: $isBulkDiscount, ')
          ..write('isManualEntry: $isManualEntry, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProductIdentitysTable productIdentitys = $ProductIdentitysTable(
    this,
  );
  late final $PriceObservationsTable priceObservations =
      $PriceObservationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    productIdentitys,
    priceObservations,
  ];
}

typedef $$ProductIdentitysTableCreateCompanionBuilder =
    ProductIdentitysCompanion Function({
      required String id,
      required String jan,
      Value<String?> displayName,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProductIdentitysTableUpdateCompanionBuilder =
    ProductIdentitysCompanion Function({
      Value<String> id,
      Value<String> jan,
      Value<String?> displayName,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ProductIdentitysTableReferences
    extends
        BaseReferences<_$AppDatabase, $ProductIdentitysTable, ProductIdentity> {
  $$ProductIdentitysTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PriceObservationsTable, List<PriceObservation>>
  _priceObservationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.priceObservations,
        aliasName: 'product_identity__id__price_observation__product_id',
      );

  $$PriceObservationsTableProcessedTableManager get priceObservationsRefs {
    final manager = $$PriceObservationsTableTableManager(
      $_db,
      $_db.priceObservations,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _priceObservationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductIdentitysTableFilterComposer
    extends Composer<_$AppDatabase, $ProductIdentitysTable> {
  $$ProductIdentitysTableFilterComposer({
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

  ColumnFilters<String> get jan => $composableBuilder(
    column: $table.jan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
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

  Expression<bool> priceObservationsRefs(
    Expression<bool> Function($$PriceObservationsTableFilterComposer f) f,
  ) {
    final $$PriceObservationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.priceObservations,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PriceObservationsTableFilterComposer(
            $db: $db,
            $table: $db.priceObservations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductIdentitysTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductIdentitysTable> {
  $$ProductIdentitysTableOrderingComposer({
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

  ColumnOrderings<String> get jan => $composableBuilder(
    column: $table.jan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
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
}

class $$ProductIdentitysTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductIdentitysTable> {
  $$ProductIdentitysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jan =>
      $composableBuilder(column: $table.jan, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> priceObservationsRefs<T extends Object>(
    Expression<T> Function($$PriceObservationsTableAnnotationComposer a) f,
  ) {
    final $$PriceObservationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.priceObservations,
          getReferencedColumn: (t) => t.productId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PriceObservationsTableAnnotationComposer(
                $db: $db,
                $table: $db.priceObservations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ProductIdentitysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductIdentitysTable,
          ProductIdentity,
          $$ProductIdentitysTableFilterComposer,
          $$ProductIdentitysTableOrderingComposer,
          $$ProductIdentitysTableAnnotationComposer,
          $$ProductIdentitysTableCreateCompanionBuilder,
          $$ProductIdentitysTableUpdateCompanionBuilder,
          (ProductIdentity, $$ProductIdentitysTableReferences),
          ProductIdentity,
          PrefetchHooks Function({bool priceObservationsRefs})
        > {
  $$ProductIdentitysTableTableManager(
    _$AppDatabase db,
    $ProductIdentitysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductIdentitysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductIdentitysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductIdentitysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> jan = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductIdentitysCompanion(
                id: id,
                jan: jan,
                displayName: displayName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String jan,
                Value<String?> displayName = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProductIdentitysCompanion.insert(
                id: id,
                jan: jan,
                displayName: displayName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductIdentitysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({priceObservationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (priceObservationsRefs) db.priceObservations,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (priceObservationsRefs)
                    await $_getPrefetchedData<
                      ProductIdentity,
                      $ProductIdentitysTable,
                      PriceObservation
                    >(
                      currentTable: table,
                      referencedTable: $$ProductIdentitysTableReferences
                          ._priceObservationsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ProductIdentitysTableReferences(
                            db,
                            table,
                            p0,
                          ).priceObservationsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.productId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProductIdentitysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductIdentitysTable,
      ProductIdentity,
      $$ProductIdentitysTableFilterComposer,
      $$ProductIdentitysTableOrderingComposer,
      $$ProductIdentitysTableAnnotationComposer,
      $$ProductIdentitysTableCreateCompanionBuilder,
      $$ProductIdentitysTableUpdateCompanionBuilder,
      (ProductIdentity, $$ProductIdentitysTableReferences),
      ProductIdentity,
      PrefetchHooks Function({bool priceObservationsRefs})
    >;
typedef $$PriceObservationsTableCreateCompanionBuilder =
    PriceObservationsCompanion Function({
      required String id,
      required String productId,
      required int priceYen,
      required DateTime observedAt,
      required double priceConfidence,
      Value<bool> isValid,
      required String duplicateKey,
      Value<bool?> isSaleVisible,
      Value<bool?> isMemberPriceVisible,
      Value<bool?> isCouponPriceVisible,
      Value<bool?> isBulkDiscount,
      Value<bool?> isManualEntry,
      Value<int> rowid,
    });
typedef $$PriceObservationsTableUpdateCompanionBuilder =
    PriceObservationsCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<int> priceYen,
      Value<DateTime> observedAt,
      Value<double> priceConfidence,
      Value<bool> isValid,
      Value<String> duplicateKey,
      Value<bool?> isSaleVisible,
      Value<bool?> isMemberPriceVisible,
      Value<bool?> isCouponPriceVisible,
      Value<bool?> isBulkDiscount,
      Value<bool?> isManualEntry,
      Value<int> rowid,
    });

final class $$PriceObservationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PriceObservationsTable,
          PriceObservation
        > {
  $$PriceObservationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductIdentitysTable _productIdTable(_$AppDatabase db) => db
      .productIdentitys
      .createAlias('price_observation__product_id__product_identity__id');

  $$ProductIdentitysTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$ProductIdentitysTableTableManager(
      $_db,
      $_db.productIdentitys,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PriceObservationsTableFilterComposer
    extends Composer<_$AppDatabase, $PriceObservationsTable> {
  $$PriceObservationsTableFilterComposer({
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

  ColumnFilters<int> get priceYen => $composableBuilder(
    column: $table.priceYen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get priceConfidence => $composableBuilder(
    column: $table.priceConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isValid => $composableBuilder(
    column: $table.isValid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duplicateKey => $composableBuilder(
    column: $table.duplicateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSaleVisible => $composableBuilder(
    column: $table.isSaleVisible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMemberPriceVisible => $composableBuilder(
    column: $table.isMemberPriceVisible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCouponPriceVisible => $composableBuilder(
    column: $table.isCouponPriceVisible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBulkDiscount => $composableBuilder(
    column: $table.isBulkDiscount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isManualEntry => $composableBuilder(
    column: $table.isManualEntry,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductIdentitysTableFilterComposer get productId {
    final $$ProductIdentitysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.productIdentitys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductIdentitysTableFilterComposer(
            $db: $db,
            $table: $db.productIdentitys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriceObservationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PriceObservationsTable> {
  $$PriceObservationsTableOrderingComposer({
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

  ColumnOrderings<int> get priceYen => $composableBuilder(
    column: $table.priceYen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get priceConfidence => $composableBuilder(
    column: $table.priceConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isValid => $composableBuilder(
    column: $table.isValid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duplicateKey => $composableBuilder(
    column: $table.duplicateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSaleVisible => $composableBuilder(
    column: $table.isSaleVisible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMemberPriceVisible => $composableBuilder(
    column: $table.isMemberPriceVisible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCouponPriceVisible => $composableBuilder(
    column: $table.isCouponPriceVisible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBulkDiscount => $composableBuilder(
    column: $table.isBulkDiscount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isManualEntry => $composableBuilder(
    column: $table.isManualEntry,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductIdentitysTableOrderingComposer get productId {
    final $$ProductIdentitysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.productIdentitys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductIdentitysTableOrderingComposer(
            $db: $db,
            $table: $db.productIdentitys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriceObservationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PriceObservationsTable> {
  $$PriceObservationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get priceYen =>
      $composableBuilder(column: $table.priceYen, builder: (column) => column);

  GeneratedColumn<DateTime> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get priceConfidence => $composableBuilder(
    column: $table.priceConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isValid =>
      $composableBuilder(column: $table.isValid, builder: (column) => column);

  GeneratedColumn<String> get duplicateKey => $composableBuilder(
    column: $table.duplicateKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSaleVisible => $composableBuilder(
    column: $table.isSaleVisible,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMemberPriceVisible => $composableBuilder(
    column: $table.isMemberPriceVisible,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCouponPriceVisible => $composableBuilder(
    column: $table.isCouponPriceVisible,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBulkDiscount => $composableBuilder(
    column: $table.isBulkDiscount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isManualEntry => $composableBuilder(
    column: $table.isManualEntry,
    builder: (column) => column,
  );

  $$ProductIdentitysTableAnnotationComposer get productId {
    final $$ProductIdentitysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.productIdentitys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductIdentitysTableAnnotationComposer(
            $db: $db,
            $table: $db.productIdentitys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PriceObservationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PriceObservationsTable,
          PriceObservation,
          $$PriceObservationsTableFilterComposer,
          $$PriceObservationsTableOrderingComposer,
          $$PriceObservationsTableAnnotationComposer,
          $$PriceObservationsTableCreateCompanionBuilder,
          $$PriceObservationsTableUpdateCompanionBuilder,
          (PriceObservation, $$PriceObservationsTableReferences),
          PriceObservation,
          PrefetchHooks Function({bool productId})
        > {
  $$PriceObservationsTableTableManager(
    _$AppDatabase db,
    $PriceObservationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PriceObservationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PriceObservationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PriceObservationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<int> priceYen = const Value.absent(),
                Value<DateTime> observedAt = const Value.absent(),
                Value<double> priceConfidence = const Value.absent(),
                Value<bool> isValid = const Value.absent(),
                Value<String> duplicateKey = const Value.absent(),
                Value<bool?> isSaleVisible = const Value.absent(),
                Value<bool?> isMemberPriceVisible = const Value.absent(),
                Value<bool?> isCouponPriceVisible = const Value.absent(),
                Value<bool?> isBulkDiscount = const Value.absent(),
                Value<bool?> isManualEntry = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PriceObservationsCompanion(
                id: id,
                productId: productId,
                priceYen: priceYen,
                observedAt: observedAt,
                priceConfidence: priceConfidence,
                isValid: isValid,
                duplicateKey: duplicateKey,
                isSaleVisible: isSaleVisible,
                isMemberPriceVisible: isMemberPriceVisible,
                isCouponPriceVisible: isCouponPriceVisible,
                isBulkDiscount: isBulkDiscount,
                isManualEntry: isManualEntry,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                required int priceYen,
                required DateTime observedAt,
                required double priceConfidence,
                Value<bool> isValid = const Value.absent(),
                required String duplicateKey,
                Value<bool?> isSaleVisible = const Value.absent(),
                Value<bool?> isMemberPriceVisible = const Value.absent(),
                Value<bool?> isCouponPriceVisible = const Value.absent(),
                Value<bool?> isBulkDiscount = const Value.absent(),
                Value<bool?> isManualEntry = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PriceObservationsCompanion.insert(
                id: id,
                productId: productId,
                priceYen: priceYen,
                observedAt: observedAt,
                priceConfidence: priceConfidence,
                isValid: isValid,
                duplicateKey: duplicateKey,
                isSaleVisible: isSaleVisible,
                isMemberPriceVisible: isMemberPriceVisible,
                isCouponPriceVisible: isCouponPriceVisible,
                isBulkDiscount: isBulkDiscount,
                isManualEntry: isManualEntry,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PriceObservationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
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
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable:
                                    $$PriceObservationsTableReferences
                                        ._productIdTable(db),
                                referencedColumn:
                                    $$PriceObservationsTableReferences
                                        ._productIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$PriceObservationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PriceObservationsTable,
      PriceObservation,
      $$PriceObservationsTableFilterComposer,
      $$PriceObservationsTableOrderingComposer,
      $$PriceObservationsTableAnnotationComposer,
      $$PriceObservationsTableCreateCompanionBuilder,
      $$PriceObservationsTableUpdateCompanionBuilder,
      (PriceObservation, $$PriceObservationsTableReferences),
      PriceObservation,
      PrefetchHooks Function({bool productId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProductIdentitysTableTableManager get productIdentitys =>
      $$ProductIdentitysTableTableManager(_db, _db.productIdentitys);
  $$PriceObservationsTableTableManager get priceObservations =>
      $$PriceObservationsTableTableManager(_db, _db.priceObservations);
}
