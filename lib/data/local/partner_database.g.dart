// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'partner_database.dart';

// ignore_for_file: type=lint
class $OrdersCacheTable extends OrdersCache
    with TableInfo<$OrdersCacheTable, OrdersCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrdersCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  late final GeneratedColumnWithTypeConverter<CachedOrderSyncStatus, int>
  syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  ).withConverter<CachedOrderSyncStatus>(
    $OrdersCacheTable.$convertersyncStatus,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    payload,
    updatedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'orders_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrdersCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
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
  OrdersCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrdersCacheData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      payload:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}payload'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
      syncStatus: $OrdersCacheTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
    );
  }

  @override
  $OrdersCacheTable createAlias(String alias) {
    return $OrdersCacheTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CachedOrderSyncStatus, int, int>
  $convertersyncStatus = const EnumIndexConverter<CachedOrderSyncStatus>(
    CachedOrderSyncStatus.values,
  );
}

class OrdersCacheData extends DataClass implements Insertable<OrdersCacheData> {
  final int id;
  final String status;
  final String payload;
  final DateTime updatedAt;
  final CachedOrderSyncStatus syncStatus;
  const OrdersCacheData({
    required this.id,
    required this.status,
    required this.payload,
    required this.updatedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['status'] = Variable<String>(status);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    {
      map['sync_status'] = Variable<int>(
        $OrdersCacheTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    return map;
  }

  OrdersCacheCompanion toCompanion(bool nullToAbsent) {
    return OrdersCacheCompanion(
      id: Value(id),
      status: Value(status),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory OrdersCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrdersCacheData(
      id: serializer.fromJson<int>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncStatus: $OrdersCacheTable.$convertersyncStatus.fromJson(
        serializer.fromJson<int>(json['syncStatus']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'status': serializer.toJson<String>(status),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncStatus': serializer.toJson<int>(
        $OrdersCacheTable.$convertersyncStatus.toJson(syncStatus),
      ),
    };
  }

  OrdersCacheData copyWith({
    int? id,
    String? status,
    String? payload,
    DateTime? updatedAt,
    CachedOrderSyncStatus? syncStatus,
  }) => OrdersCacheData(
    id: id ?? this.id,
    status: status ?? this.status,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  OrdersCacheData copyWithCompanion(OrdersCacheCompanion data) {
    return OrdersCacheData(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrdersCacheData(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, status, payload, updatedAt, syncStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrdersCacheData &&
          other.id == this.id &&
          other.status == this.status &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus);
}

class OrdersCacheCompanion extends UpdateCompanion<OrdersCacheData> {
  final Value<int> id;
  final Value<String> status;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<CachedOrderSyncStatus> syncStatus;
  const OrdersCacheCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  OrdersCacheCompanion.insert({
    this.id = const Value.absent(),
    required String status,
    required String payload,
    required DateTime updatedAt,
    this.syncStatus = const Value.absent(),
  }) : status = Value(status),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<OrdersCacheData> custom({
    Expression<int>? id,
    Expression<String>? status,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  OrdersCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? status,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<CachedOrderSyncStatus>? syncStatus,
  }) {
    return OrdersCacheCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(
        $OrdersCacheTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrdersCacheCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $QueuedActionsTable extends QueuedActions
    with TableInfo<$QueuedActionsTable, QueuedAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueuedActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<QueuedActionType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<QueuedActionType>($QueuedActionsTable.$convertertype);
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<int> orderId = GeneratedColumn<int>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _enqueuedAtMeta = const VerificationMeta(
    'enqueuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> enqueuedAt = GeneratedColumn<DateTime>(
    'enqueued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<QueuedActionStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<QueuedActionStatus>($QueuedActionsTable.$converterstatus);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    orderId,
    payload,
    enqueuedAt,
    lastAttemptAt,
    attempts,
    lastError,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queued_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueuedAction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('enqueued_at')) {
      context.handle(
        _enqueuedAtMeta,
        enqueuedAt.isAcceptableOrUnknown(data['enqueued_at']!, _enqueuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_enqueuedAtMeta);
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueuedAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueuedAction(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      type: $QueuedActionsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      orderId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}order_id'],
          )!,
      payload:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}payload'],
          )!,
      enqueuedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}enqueued_at'],
          )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      attempts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}attempts'],
          )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      status: $QueuedActionsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
    );
  }

  @override
  $QueuedActionsTable createAlias(String alias) {
    return $QueuedActionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<QueuedActionType, int, int> $convertertype =
      const EnumIndexConverter<QueuedActionType>(QueuedActionType.values);
  static JsonTypeConverter2<QueuedActionStatus, int, int> $converterstatus =
      const EnumIndexConverter<QueuedActionStatus>(QueuedActionStatus.values);
}

class QueuedAction extends DataClass implements Insertable<QueuedAction> {
  final String id;
  final QueuedActionType type;
  final int orderId;
  final String payload;
  final DateTime enqueuedAt;
  final DateTime? lastAttemptAt;
  final int attempts;
  final String? lastError;
  final QueuedActionStatus status;
  const QueuedAction({
    required this.id,
    required this.type,
    required this.orderId,
    required this.payload,
    required this.enqueuedAt,
    this.lastAttemptAt,
    required this.attempts,
    this.lastError,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<int>(
        $QueuedActionsTable.$convertertype.toSql(type),
      );
    }
    map['order_id'] = Variable<int>(orderId);
    map['payload'] = Variable<String>(payload);
    map['enqueued_at'] = Variable<DateTime>(enqueuedAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    {
      map['status'] = Variable<int>(
        $QueuedActionsTable.$converterstatus.toSql(status),
      );
    }
    return map;
  }

  QueuedActionsCompanion toCompanion(bool nullToAbsent) {
    return QueuedActionsCompanion(
      id: Value(id),
      type: Value(type),
      orderId: Value(orderId),
      payload: Value(payload),
      enqueuedAt: Value(enqueuedAt),
      lastAttemptAt:
          lastAttemptAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastAttemptAt),
      attempts: Value(attempts),
      lastError:
          lastError == null && nullToAbsent
              ? const Value.absent()
              : Value(lastError),
      status: Value(status),
    );
  }

  factory QueuedAction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueuedAction(
      id: serializer.fromJson<String>(json['id']),
      type: $QueuedActionsTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      orderId: serializer.fromJson<int>(json['orderId']),
      payload: serializer.fromJson<String>(json['payload']),
      enqueuedAt: serializer.fromJson<DateTime>(json['enqueuedAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      status: $QueuedActionsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<int>(
        $QueuedActionsTable.$convertertype.toJson(type),
      ),
      'orderId': serializer.toJson<int>(orderId),
      'payload': serializer.toJson<String>(payload),
      'enqueuedAt': serializer.toJson<DateTime>(enqueuedAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'status': serializer.toJson<int>(
        $QueuedActionsTable.$converterstatus.toJson(status),
      ),
    };
  }

  QueuedAction copyWith({
    String? id,
    QueuedActionType? type,
    int? orderId,
    String? payload,
    DateTime? enqueuedAt,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    QueuedActionStatus? status,
  }) => QueuedAction(
    id: id ?? this.id,
    type: type ?? this.type,
    orderId: orderId ?? this.orderId,
    payload: payload ?? this.payload,
    enqueuedAt: enqueuedAt ?? this.enqueuedAt,
    lastAttemptAt:
        lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    status: status ?? this.status,
  );
  QueuedAction copyWithCompanion(QueuedActionsCompanion data) {
    return QueuedAction(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      payload: data.payload.present ? data.payload.value : this.payload,
      enqueuedAt:
          data.enqueuedAt.present ? data.enqueuedAt.value : this.enqueuedAt,
      lastAttemptAt:
          data.lastAttemptAt.present
              ? data.lastAttemptAt.value
              : this.lastAttemptAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueuedAction(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('orderId: $orderId, ')
          ..write('payload: $payload, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    orderId,
    payload,
    enqueuedAt,
    lastAttemptAt,
    attempts,
    lastError,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueuedAction &&
          other.id == this.id &&
          other.type == this.type &&
          other.orderId == this.orderId &&
          other.payload == this.payload &&
          other.enqueuedAt == this.enqueuedAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.status == this.status);
}

class QueuedActionsCompanion extends UpdateCompanion<QueuedAction> {
  final Value<String> id;
  final Value<QueuedActionType> type;
  final Value<int> orderId;
  final Value<String> payload;
  final Value<DateTime> enqueuedAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<QueuedActionStatus> status;
  final Value<int> rowid;
  const QueuedActionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.orderId = const Value.absent(),
    this.payload = const Value.absent(),
    this.enqueuedAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueuedActionsCompanion.insert({
    required String id,
    required QueuedActionType type,
    required int orderId,
    this.payload = const Value.absent(),
    required DateTime enqueuedAt,
    this.lastAttemptAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       orderId = Value(orderId),
       enqueuedAt = Value(enqueuedAt);
  static Insertable<QueuedAction> custom({
    Expression<String>? id,
    Expression<int>? type,
    Expression<int>? orderId,
    Expression<String>? payload,
    Expression<DateTime>? enqueuedAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (orderId != null) 'order_id': orderId,
      if (payload != null) 'payload': payload,
      if (enqueuedAt != null) 'enqueued_at': enqueuedAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueuedActionsCompanion copyWith({
    Value<String>? id,
    Value<QueuedActionType>? type,
    Value<int>? orderId,
    Value<String>? payload,
    Value<DateTime>? enqueuedAt,
    Value<DateTime?>? lastAttemptAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<QueuedActionStatus>? status,
    Value<int>? rowid,
  }) {
    return QueuedActionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      orderId: orderId ?? this.orderId,
      payload: payload ?? this.payload,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $QueuedActionsTable.$convertertype.toSql(type.value),
      );
    }
    if (orderId.present) {
      map['order_id'] = Variable<int>(orderId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (enqueuedAt.present) {
      map['enqueued_at'] = Variable<DateTime>(enqueuedAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $QueuedActionsTable.$converterstatus.toSql(status.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueuedActionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('orderId: $orderId, ')
          ..write('payload: $payload, ')
          ..write('enqueuedAt: $enqueuedAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PartnerDatabase extends GeneratedDatabase {
  _$PartnerDatabase(QueryExecutor e) : super(e);
  $PartnerDatabaseManager get managers => $PartnerDatabaseManager(this);
  late final $OrdersCacheTable ordersCache = $OrdersCacheTable(this);
  late final $QueuedActionsTable queuedActions = $QueuedActionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    ordersCache,
    queuedActions,
  ];
}

typedef $$OrdersCacheTableCreateCompanionBuilder =
    OrdersCacheCompanion Function({
      Value<int> id,
      required String status,
      required String payload,
      required DateTime updatedAt,
      Value<CachedOrderSyncStatus> syncStatus,
    });
typedef $$OrdersCacheTableUpdateCompanionBuilder =
    OrdersCacheCompanion Function({
      Value<int> id,
      Value<String> status,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<CachedOrderSyncStatus> syncStatus,
    });

class $$OrdersCacheTableFilterComposer
    extends Composer<_$PartnerDatabase, $OrdersCacheTable> {
  $$OrdersCacheTableFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    CachedOrderSyncStatus,
    CachedOrderSyncStatus,
    int
  >
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$OrdersCacheTableOrderingComposer
    extends Composer<_$PartnerDatabase, $OrdersCacheTable> {
  $$OrdersCacheTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrdersCacheTableAnnotationComposer
    extends Composer<_$PartnerDatabase, $OrdersCacheTable> {
  $$OrdersCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CachedOrderSyncStatus, int> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );
}

class $$OrdersCacheTableTableManager
    extends
        RootTableManager<
          _$PartnerDatabase,
          $OrdersCacheTable,
          OrdersCacheData,
          $$OrdersCacheTableFilterComposer,
          $$OrdersCacheTableOrderingComposer,
          $$OrdersCacheTableAnnotationComposer,
          $$OrdersCacheTableCreateCompanionBuilder,
          $$OrdersCacheTableUpdateCompanionBuilder,
          (
            OrdersCacheData,
            BaseReferences<
              _$PartnerDatabase,
              $OrdersCacheTable,
              OrdersCacheData
            >,
          ),
          OrdersCacheData,
          PrefetchHooks Function()
        > {
  $$OrdersCacheTableTableManager(_$PartnerDatabase db, $OrdersCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$OrdersCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$OrdersCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$OrdersCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<CachedOrderSyncStatus> syncStatus = const Value.absent(),
              }) => OrdersCacheCompanion(
                id: id,
                status: status,
                payload: payload,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String status,
                required String payload,
                required DateTime updatedAt,
                Value<CachedOrderSyncStatus> syncStatus = const Value.absent(),
              }) => OrdersCacheCompanion.insert(
                id: id,
                status: status,
                payload: payload,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrdersCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$PartnerDatabase,
      $OrdersCacheTable,
      OrdersCacheData,
      $$OrdersCacheTableFilterComposer,
      $$OrdersCacheTableOrderingComposer,
      $$OrdersCacheTableAnnotationComposer,
      $$OrdersCacheTableCreateCompanionBuilder,
      $$OrdersCacheTableUpdateCompanionBuilder,
      (
        OrdersCacheData,
        BaseReferences<_$PartnerDatabase, $OrdersCacheTable, OrdersCacheData>,
      ),
      OrdersCacheData,
      PrefetchHooks Function()
    >;
typedef $$QueuedActionsTableCreateCompanionBuilder =
    QueuedActionsCompanion Function({
      required String id,
      required QueuedActionType type,
      required int orderId,
      Value<String> payload,
      required DateTime enqueuedAt,
      Value<DateTime?> lastAttemptAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<QueuedActionStatus> status,
      Value<int> rowid,
    });
typedef $$QueuedActionsTableUpdateCompanionBuilder =
    QueuedActionsCompanion Function({
      Value<String> id,
      Value<QueuedActionType> type,
      Value<int> orderId,
      Value<String> payload,
      Value<DateTime> enqueuedAt,
      Value<DateTime?> lastAttemptAt,
      Value<int> attempts,
      Value<String?> lastError,
      Value<QueuedActionStatus> status,
      Value<int> rowid,
    });

class $$QueuedActionsTableFilterComposer
    extends Composer<_$PartnerDatabase, $QueuedActionsTable> {
  $$QueuedActionsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<QueuedActionType, QueuedActionType, int>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<QueuedActionStatus, QueuedActionStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$QueuedActionsTableOrderingComposer
    extends Composer<_$PartnerDatabase, $QueuedActionsTable> {
  $$QueuedActionsTableOrderingComposer({
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

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueuedActionsTableAnnotationComposer
    extends Composer<_$PartnerDatabase, $QueuedActionsTable> {
  $$QueuedActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<QueuedActionType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get enqueuedAt => $composableBuilder(
    column: $table.enqueuedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumnWithTypeConverter<QueuedActionStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$QueuedActionsTableTableManager
    extends
        RootTableManager<
          _$PartnerDatabase,
          $QueuedActionsTable,
          QueuedAction,
          $$QueuedActionsTableFilterComposer,
          $$QueuedActionsTableOrderingComposer,
          $$QueuedActionsTableAnnotationComposer,
          $$QueuedActionsTableCreateCompanionBuilder,
          $$QueuedActionsTableUpdateCompanionBuilder,
          (
            QueuedAction,
            BaseReferences<
              _$PartnerDatabase,
              $QueuedActionsTable,
              QueuedAction
            >,
          ),
          QueuedAction,
          PrefetchHooks Function()
        > {
  $$QueuedActionsTableTableManager(
    _$PartnerDatabase db,
    $QueuedActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$QueuedActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$QueuedActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$QueuedActionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<QueuedActionType> type = const Value.absent(),
                Value<int> orderId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> enqueuedAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<QueuedActionStatus> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueuedActionsCompanion(
                id: id,
                type: type,
                orderId: orderId,
                payload: payload,
                enqueuedAt: enqueuedAt,
                lastAttemptAt: lastAttemptAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required QueuedActionType type,
                required int orderId,
                Value<String> payload = const Value.absent(),
                required DateTime enqueuedAt,
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<QueuedActionStatus> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueuedActionsCompanion.insert(
                id: id,
                type: type,
                orderId: orderId,
                payload: payload,
                enqueuedAt: enqueuedAt,
                lastAttemptAt: lastAttemptAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueuedActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$PartnerDatabase,
      $QueuedActionsTable,
      QueuedAction,
      $$QueuedActionsTableFilterComposer,
      $$QueuedActionsTableOrderingComposer,
      $$QueuedActionsTableAnnotationComposer,
      $$QueuedActionsTableCreateCompanionBuilder,
      $$QueuedActionsTableUpdateCompanionBuilder,
      (
        QueuedAction,
        BaseReferences<_$PartnerDatabase, $QueuedActionsTable, QueuedAction>,
      ),
      QueuedAction,
      PrefetchHooks Function()
    >;

class $PartnerDatabaseManager {
  final _$PartnerDatabase _db;
  $PartnerDatabaseManager(this._db);
  $$OrdersCacheTableTableManager get ordersCache =>
      $$OrdersCacheTableTableManager(_db, _db.ordersCache);
  $$QueuedActionsTableTableManager get queuedActions =>
      $$QueuedActionsTableTableManager(_db, _db.queuedActions);
}
