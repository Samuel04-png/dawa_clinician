import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' show Color;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';
import 'supabase_offline_cache.dart';

/// Compatibility facade for FlutterFlow-generated Firestore code.
///
/// This class does not use Firebase. It translates the generated Firestore-like
/// API into Supabase table reads and writes through [supabaseClient].
class FirebaseFirestore {
  FirebaseFirestore._();

  static final instance = FirebaseFirestore._();

  CollectionReference collection(String path) => CollectionReference(path);

  DocumentReference doc(String path) {
    final normalized = path.replaceAll(RegExp(r'^/+|/+$'), '');
    final parts = normalized.split('/');
    if (parts.length < 2 || parts.length.isOdd) {
      throw ArgumentError('Invalid document path: $path');
    }
    return DocumentReference(parts[parts.length - 2], parts.last);
  }
}

class CollectionReference<T extends Object?> extends Query<T> {
  CollectionReference(String table) : super._(table: table);

  DocumentReference<T>? get parent => null;

  DocumentReference<T> doc([String? id]) =>
      DocumentReference<T>(table, id ?? _generateDocumentId());
}

class DocumentReference<T extends Object?> {
  DocumentReference(this.collectionName, this.id);

  final String collectionName;
  final String id;

  String get path => '$collectionName/$id';
  CollectionReference<T> get parent => CollectionReference<T>(collectionName);

  Future<DocumentSnapshot<T>> get() async {
    try {
      final response = await runSupabaseRequest(
        () => supabaseClient
            .from(collectionName)
            .select()
            .eq('id', id)
            .maybeSingle(),
      );
      final row = response == null ? null : Map<String, dynamic>.from(response);
      if (row != null) {
        await SupabaseOfflineCache.saveDocumentRow(collectionName, id, row);
      }
      return DocumentSnapshot<T>._(
        reference: this,
        data:
            row == null ? <String, dynamic>{} : _decodeRow(collectionName, row),
        exists: response != null,
      );
    } on FormatException catch (e) {
      // Supabase returned non-JSON (e.g. HTML maintenance page). Treat as not found.
      print('FormatException fetching document $path: $e');
      return _cachedDocumentSnapshot();
    } catch (e) {
      print('Error fetching document $path: $e');
      return _cachedDocumentSnapshot();
    }
  }

  Stream<DocumentSnapshot<T>> snapshots() => Stream.fromFuture(get());

  Future<void> set(
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) async {
    try {
      final payload = _encodeRow(data, collectionName)..['id'] = id;
      await runSupabaseRequest(
        () => supabaseClient
            .from(collectionName)
            .upsert(payload, onConflict: 'id')
            .select()
            .maybeSingle(),
      );
      await SupabaseOfflineCache.saveDocumentRow(collectionName, id, payload);
    } on FormatException catch (e) {
      print('FormatException setting document $path: $e');
    } catch (e) {
      print('Error setting document $path: $e');
    }
  }

  Future<void> update(Map<String, dynamic> data) async {
    try {
      final payload = _encodeRow(data, collectionName);
      if (payload.isEmpty) {
        return;
      }
      await runSupabaseRequest(
        () => supabaseClient.from(collectionName).update(payload).eq('id', id),
      );
      await SupabaseOfflineCache.mergeDocumentRow(collectionName, id, payload);
    } on FormatException catch (e) {
      print('FormatException updating document $path: $e');
    } catch (e) {
      print('Error updating document $path: $e');
    }
  }

  Future<void> delete() async {
    try {
      await runSupabaseRequest(
        () => supabaseClient.from(collectionName).delete().eq('id', id),
      );
    } on FormatException catch (e) {
      print('FormatException deleting document $path: $e');
    } catch (e) {
      print('Error deleting document $path: $e');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentReference && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => path;

  Future<DocumentSnapshot<T>> _cachedDocumentSnapshot() async {
    final cached = await SupabaseOfflineCache.readDocumentRow(
      collectionName,
      id,
    );
    return DocumentSnapshot<T>._(
      reference: this,
      data: cached == null
          ? <String, dynamic>{}
          : _decodeRow(collectionName, cached),
      exists: cached != null,
    );
  }
}

class Query<T extends Object?> {
  const Query._({
    required this.table,
    this.filters = const [],
    this.orders = const [],
    this.limitCount,
    this.startAfterOffset,
  });

  final String table;
  final List<_QueryFilter> filters;
  final List<_QueryOrder> orders;
  final int? limitCount;
  final int? startAfterOffset;

  Query<T> where(
    Object fieldOrFilter, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    List<Object?>? whereIn,
    List<Object?>? whereNotIn,
    Object? arrayContains,
    List<Object?>? arrayContainsAny,
    bool? isNull,
  }) {
    if (fieldOrFilter is Filter) {
      return _copyWith(filters: [...filters, ...fieldOrFilter.filters]);
    }
    final field = fieldOrFilter.toString();
    final next = <_QueryFilter>[];
    if (isNull != null) {
      next.add(_QueryFilter(field, isNull ? 'is' : 'not.is', null));
    }
    if (isEqualTo != null) {
      next.add(_QueryFilter(field, 'eq', isEqualTo));
    }
    if (isNotEqualTo != null) {
      next.add(_QueryFilter(field, 'neq', isNotEqualTo));
    }
    if (isLessThan != null) {
      next.add(_QueryFilter(field, 'lt', isLessThan));
    }
    if (isLessThanOrEqualTo != null) {
      next.add(_QueryFilter(field, 'lte', isLessThanOrEqualTo));
    }
    if (isGreaterThan != null) {
      next.add(_QueryFilter(field, 'gt', isGreaterThan));
    }
    if (isGreaterThanOrEqualTo != null) {
      next.add(_QueryFilter(field, 'gte', isGreaterThanOrEqualTo));
    }
    if (whereIn != null && whereIn.isNotEmpty) {
      next.add(_QueryFilter(field, 'in', whereIn));
    }
    if (whereNotIn != null && whereNotIn.isNotEmpty) {
      next.add(_QueryFilter(field, 'not.in', whereNotIn));
    }
    if (arrayContains != null) {
      next.add(_QueryFilter(field, 'contains', [arrayContains]));
    }
    if (arrayContainsAny != null && arrayContainsAny.isNotEmpty) {
      next.add(_QueryFilter(field, 'overlaps', arrayContainsAny));
    }
    return _copyWith(filters: [...filters, ...next]);
  }

  Query<T> orderBy(String field, {bool descending = false}) =>
      _copyWith(orders: [...orders, _QueryOrder(field, descending)]);

  Query<T> limit(int limit) => _copyWith(limitCount: limit);

  Query<T> startAfterDocument(DocumentSnapshot? snapshot) => snapshot == null
      ? this
      : _copyWith(startAfterOffset: snapshot._rowIndex + 1);

  AggregateQuery count() => AggregateQuery(this);

  Future<QuerySnapshot<T>> get() async {
    final offset = startAfterOffset ?? 0;
    final cacheKey = _cacheKey(offset);
    try {
      final response = await runSupabaseRequest(() {
        dynamic request = supabaseClient.from(table).select();
        for (final filter in filters) {
          request = _applyFilter(request, filter);
        }
        for (final order in orders) {
          request = request.order(order.field, ascending: !order.descending);
        }
        if (limitCount != null) {
          request = request.range(offset, offset + limitCount! - 1);
        } else if (offset > 0) {
          request = request.range(offset, offset + 999);
        }
        return request;
      });
      final rows = (response as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      await SupabaseOfflineCache.saveQueryRows(cacheKey, rows);
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) {
          await SupabaseOfflineCache.saveDocumentRow(table, id, row);
        }
      }
      final docs = rows.asMap().entries.map((entry) {
        final row = _decodeRow(table, entry.value);
        final id = row['id']?.toString() ?? entry.value['id']?.toString() ?? '';
        return QueryDocumentSnapshot<T>._(
          reference: DocumentReference<T>(table, id),
          data: row,
          rowIndex: offset + entry.key,
        );
      }).toList();
      return QuerySnapshot<T>(docs);
    } on FormatException catch (e) {
      // Supabase returned non-JSON (e.g. HTML maintenance page). Return empty.
      print('FormatException querying table $table: $e');
      return _cachedQuerySnapshot(cacheKey, offset);
    } catch (e) {
      print('Error querying table $table: $e');
      return _cachedQuerySnapshot(cacheKey, offset);
    }
  }

  Stream<QuerySnapshot<T>> snapshots() => Stream.fromFuture(get());

  Query<T> _copyWith({
    List<_QueryFilter>? filters,
    List<_QueryOrder>? orders,
    int? limitCount,
    int? startAfterOffset,
  }) =>
      Query<T>._(
        table: table,
        filters: filters ?? this.filters,
        orders: orders ?? this.orders,
        limitCount: limitCount ?? this.limitCount,
        startAfterOffset: startAfterOffset ?? this.startAfterOffset,
      );

  String _cacheKey(int offset) => SupabaseOfflineCache.queryKey({
        'table': table,
        'filters': filters
            .map((filter) => {
                  'field': filter.field,
                  'operator': filter.operator,
                  'value': _cacheSafeValue(filter.value),
                })
            .toList(),
        'orders': orders
            .map((order) => {
                  'field': order.field,
                  'descending': order.descending,
                })
            .toList(),
        'limit': limitCount,
        'offset': offset,
      });

  Future<QuerySnapshot<T>> _cachedQuerySnapshot(
    String cacheKey,
    int offset,
  ) async {
    final rows = await SupabaseOfflineCache.readQueryRows(cacheKey);
    if (rows == null) {
      return QuerySnapshot<T>([]);
    }
    final docs = rows.asMap().entries.map((entry) {
      final row = _decodeRow(table, entry.value);
      final id = row['id']?.toString() ?? entry.value['id']?.toString() ?? '';
      return QueryDocumentSnapshot<T>._(
        reference: DocumentReference<T>(table, id),
        data: row,
        rowIndex: offset + entry.key,
      );
    }).toList();
    return QuerySnapshot<T>(docs);
  }
}

class QuerySnapshot<T extends Object?> {
  QuerySnapshot(this.docs);

  final List<QueryDocumentSnapshot<T>> docs;
}

class DocumentSnapshot<T extends Object?> {
  DocumentSnapshot._({
    required this.reference,
    required Map<String, dynamic>? data,
    required this.exists,
    int rowIndex = 0,
  })  : _data = data,
        _rowIndex = rowIndex;

  final DocumentReference<T> reference;
  final Map<String, dynamic>? _data;
  final bool exists;
  final int _rowIndex;

  String get id => reference.id;

  Map<String, dynamic>? data() => _data;
}

class QueryDocumentSnapshot<T extends Object?> extends DocumentSnapshot<T> {
  QueryDocumentSnapshot._({
    required super.reference,
    required Map<String, dynamic> data,
    required int rowIndex,
  }) : super._(data: data, exists: true, rowIndex: rowIndex);

  @override
  Map<String, dynamic> data() => super.data()!;
}

class AggregateQuery {
  AggregateQuery(this.query);

  final Query query;

  Future<AggregateQuerySnapshot> get() async {
    try {
      final snapshot = await query.get();
      return AggregateQuerySnapshot(snapshot.docs.length);
    } catch (e) {
      print('Error in aggregate query: $e');
      return AggregateQuerySnapshot(0);
    }
  }
}

class AggregateQuerySnapshot {
  AggregateQuerySnapshot(this.count);

  final int? count;
}

class SetOptions {
  const SetOptions({this.merge = false});

  final bool merge;
}

class FieldValue {
  const FieldValue._delete() : isDelete = true;

  final bool isDelete;

  static FieldValue delete() => const FieldValue._delete();
}

class Filter {
  Filter(
    String field, {
    List? whereIn,
    List? whereNotIn,
    List? arrayContainsAny,
  }) : filters = [
          if (whereIn != null && whereIn.isNotEmpty)
            _QueryFilter(field, 'in', whereIn),
          if (whereNotIn != null && whereNotIn.isNotEmpty)
            _QueryFilter(field, 'not.in', whereNotIn),
          if (arrayContainsAny != null && arrayContainsAny.isNotEmpty)
            _QueryFilter(field, 'overlaps', arrayContainsAny),
        ];

  const Filter._(this.filters);

  final List<_QueryFilter> filters;
}

class Timestamp {
  const Timestamp(this._dateTime);

  final DateTime _dateTime;

  DateTime toDate() => _dateTime;
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _QueryFilter {
  const _QueryFilter(this.field, this.operator, this.value);

  final String field;
  final String operator;
  final Object? value;
}

class _QueryOrder {
  const _QueryOrder(this.field, this.descending);

  final String field;
  final bool descending;
}

dynamic _applyFilter(dynamic request, _QueryFilter filter) {
  final value = _encodeValue(filter.value);
  switch (filter.operator) {
    case 'eq':
      return request.eq(filter.field, value);
    case 'neq':
      return request.neq(filter.field, value);
    case 'lt':
      return request.lt(filter.field, value);
    case 'lte':
      return request.lte(filter.field, value);
    case 'gt':
      return request.gt(filter.field, value);
    case 'gte':
      return request.gte(filter.field, value);
    case 'in':
      return request.inFilter(filter.field, _encodeList(filter.value));
    case 'contains':
      return request.contains(filter.field, _encodeList(filter.value));
    case 'overlaps':
      return request.overlaps(filter.field, _encodeList(filter.value));
    case 'is':
      return request.filter(filter.field, 'is', null);
    case 'not.is':
      return request.not(filter.field, 'is', null);
    case 'not.in':
      return request.not(filter.field, 'in', _encodeList(filter.value));
    default:
      return request;
  }
}

Map<String, dynamic> _encodeRow(
  Map<String, dynamic> data,
  String table,
) {
  final encoded = <String, dynamic>{};
  data.forEach((key, value) {
    if (value is FieldValue && value.isDelete) {
      encoded[key] = null;
      return;
    }
    encoded[key] = _encodeValue(value);
  });
  return encoded;
}

dynamic _encodeValue(Object? value) {
  if (value is DocumentReference) {
    return value.path;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Color) {
    return '#${value.value.toRadixString(16).padLeft(8, '0')}';
  }
  if (value is Iterable) {
    return value.map(_encodeValue).toList();
  }
  if (value is Map) {
    return value
        .map((key, item) => MapEntry(key.toString(), _encodeValue(item)));
  }
  return value;
}

dynamic _cacheSafeValue(Object? value) => _encodeValue(value);

List<dynamic> _encodeList(Object? value) {
  if (value is Iterable) {
    return value.map(_encodeValue).toList();
  }
  return [_encodeValue(value)];
}

Map<String, dynamic> _decodeRow(String table, Map<String, dynamic> row) {
  final decoded = <String, dynamic>{};
  row.forEach((key, value) {
    decoded[key] = _decodeValue(table, key, value);
  });
  return decoded;
}

dynamic _decodeValue(String table, String field, dynamic value) {
  if (value == null) {
    return null;
  }
  if (_dateFields[table]?.contains(field) ?? false) {
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }
  final refTable = _referenceFields[table]?[field];
  if (refTable != null) {
    if (value is Iterable) {
      return value
          .map((item) => _referenceFromStoredValue(refTable, item))
          .whereType<DocumentReference>()
          .toList();
    }
    return _referenceFromStoredValue(refTable, value);
  }
  if (value is Iterable) {
    return value.map((item) {
      if (item is String) {
        return DateTime.tryParse(item)?.toLocal() ?? item;
      }
      return item;
    }).toList();
  }
  return value;
}

DocumentReference? _referenceFromStoredValue(String table, dynamic value) {
  if (value == null) {
    return null;
  }
  final raw = value.toString();
  if (raw.isEmpty) {
    return null;
  }
  if (raw.contains('/')) {
    return FirebaseFirestore.instance.doc(raw);
  }
  return FirebaseFirestore.instance.collection(table).doc(raw);
}

String _generateDocumentId() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(20, (_) => chars[random.nextInt(chars.length)]).join();
}

const _dateFields = <String, Set<String>>{
  'user': {'created_time'},
  'mother': {'dateOfBirth'},
  'first_encounter': {
    'estimated_due_date',
    'lnmp',
    'cacx_date_of_screen',
    'booked_date',
    'anc_dates',
  },
  'encounter': {
    'next_visit',
    'date',
    'date_performed',
  },
};

const _referenceFields = <String, Map<String, String>>{
  'doctor': {
    'user_Id': 'user',
  },
  'mother': {
    'user_Id': 'user',
    'first_encounter_id': 'first_encounter',
  },
  'first_encounter': {
    'mother_Id': 'mother',
    'parity_id': 'parity',
  },
  'encounter': {
    'mother_id': 'mother',
    'clinic_id': 'clinic',
    'doctor_id': 'doctor',
    'performed_by': 'doctor',
  },
  'parity': {
    'first_encounter_id': 'first_encounter',
  },
};
