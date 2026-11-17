import 'package:flutter/foundation.dart';
import 'database.dart';

abstract class SupabaseTable<T extends SupabaseDataRow> {
  String get tableName;
  T createRow(Map<String, dynamic> data);

  /// Cliente activo seleccionado según la arquitectura de bases de datos dual
  SupabaseClient get client =>
      DualDatabaseConfig.instance.getClientForTable(tableName);

  SupabaseClient get _fallbackClient => DualDatabaseConfig.instance.patientClient;

  bool get _hasDistinctFallback =>
      !identical(client, _fallbackClient) &&
      DualDatabaseConfig.instance.isDistinctDualDatabase;

  PostgrestFilterBuilder _select([SupabaseClient? c]) =>
      (c ?? client).from(tableName).select();

  Future<List<T>> queryRows({
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder) queryFn,
    int? limit,
  }) async {
    try {
      final select = _select();
      var query = queryFn(select);
      query = limit != null ? query.limit(limit) : query;
      final rows = await query.select();
      final list = rows.map(createRow).toList();
      if (list.isNotEmpty || !_hasDistinctFallback) return list;
    } catch (e) {
      debugPrint('Nota queryRows ($tableName) en cliente primario: $e');
      if (!_hasDistinctFallback) rethrow;
    }
    try {
      var fbQuery = queryFn(_select(_fallbackClient));
      fbQuery = limit != null ? fbQuery.limit(limit) : fbQuery;
      final fbRows = await fbQuery.select();
      return fbRows.map(createRow).toList();
    } catch (e) {
      debugPrint('Error queryRows ($tableName) en fallback: $e');
      return [];
    }
  }

  /// Fetches one page of rows, starting at row [offset] and returning at most
  /// [pageSize] rows. A page shorter than [pageSize] means the query is
  /// exhausted.
  Future<List<T>> queryRowsPage({
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder) queryFn,
    required int offset,
    required int pageSize,
  }) async {
    try {
      final select = _select();
      final rows = await queryFn(select).range(offset, offset + pageSize - 1).select();
      final list = rows.map(createRow).toList();
      if (list.isNotEmpty || !_hasDistinctFallback) return list;
    } catch (_) {
      if (!_hasDistinctFallback) rethrow;
    }
    final fbRows = await queryFn(_select(_fallbackClient))
        .range(offset, offset + pageSize - 1)
        .select();
    return fbRows.map(createRow).toList();
  }

  Future<List<T>> querySingleRow({
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder) queryFn,
  }) async {
    try {
      final r = await queryFn(_select()).limit(1).select().maybeSingle();
      if (r != null) return [createRow(r)];
    } catch (e) {
      debugPrint('Error querying row ($tableName): $e');
    }
    if (_hasDistinctFallback) {
      try {
        final fb = await queryFn(_select(_fallbackClient)).limit(1).select().maybeSingle();
        if (fb != null) return [createRow(fb)];
      } catch (_) {}
    }
    return [];
  }

  Future<T> insert(Map<String, dynamic> data) async {
    try {
      final row = await client.from(tableName).insert(data).select().limit(1).single();
      return createRow(row);
    } catch (e) {
      if (_hasDistinctFallback) {
        final row = await _fallbackClient.from(tableName).insert(data).select().limit(1).single();
        return createRow(row);
      }
      rethrow;
    }
  }

  Future<T> _upsertOnClient(
    SupabaseClient targetClient,
    Map<String, dynamic> data, {
    String? onConflict,
  }) async {
    final rowId = data['id'];
    if (rowId != null && rowId.toString().isNotEmpty) {
      try {
        final existing = await targetClient
            .from(tableName)
            .select()
            .eq('id', rowId)
            .limit(1)
            .maybeSingle();
        if (existing != null) {
          final updatePayload = Map<String, dynamic>.from(data)
            ..remove('id')
            ..remove('created_at');
          final updated = await targetClient
              .from(tableName)
              .update(updatePayload)
              .eq('id', rowId)
              .select()
              .limit(1)
              .maybeSingle();
          return createRow(updated ?? {...existing, ...updatePayload});
        }
      } catch (_) {}
    }
    try {
      final res = await targetClient
          .from(tableName)
          .upsert(data, onConflict: onConflict)
          .select()
          .limit(1)
          .single();
      return createRow(res);
    } catch (e) {
      if (rowId != null && rowId.toString().isNotEmpty) {
        final updatePayload = Map<String, dynamic>.from(data)
          ..remove('id')
          ..remove('created_at');
        final updated = await targetClient
            .from(tableName)
            .update(updatePayload)
            .eq('id', rowId)
            .select()
            .limit(1)
            .maybeSingle();
        if (updated != null) return createRow(updated);
      }
      rethrow;
    }
  }

  Future<T> upsert(Map<String, dynamic> data, {String? onConflict}) async {
    try {
      return await _upsertOnClient(client, data, onConflict: onConflict);
    } catch (e) {
      if (_hasDistinctFallback) {
        return await _upsertOnClient(_fallbackClient, data, onConflict: onConflict);
      }
      rethrow;
    }
  }

  Future<List<T>> update({
    required Map<String, dynamic> data,
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder)
        matchingRows,
    bool returnRows = false,
  }) async {
    try {
      final updateQuery = matchingRows(client.from(tableName).update(data));
      if (!returnRows) {
        await updateQuery;
        if (_hasDistinctFallback) {
          try {
            await matchingRows(_fallbackClient.from(tableName).update(data));
          } catch (_) {}
        }
        return [];
      }
      final rows = await updateQuery.select();
      return rows.map(createRow).toList();
    } catch (e) {
      if (_hasDistinctFallback) {
        final fbUpdate = matchingRows(_fallbackClient.from(tableName).update(data));
        if (!returnRows) {
          await fbUpdate;
          return [];
        }
        final rows = await fbUpdate.select();
        return rows.map(createRow).toList();
      }
      rethrow;
    }
  }

  Future<List<T>> delete({
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder)
        matchingRows,
    bool returnRows = false,
  }) async {
    try {
      final deleteQuery = matchingRows(client.from(tableName).delete());
      if (!returnRows) {
        await deleteQuery;
        return [];
      }
      final rows = await deleteQuery.select();
      return rows.map(createRow).toList();
    } catch (e) {
      if (_hasDistinctFallback) {
        final fbDelete = matchingRows(_fallbackClient.from(tableName).delete());
        if (!returnRows) {
          await fbDelete;
          return [];
        }
        final rows = await fbDelete.select();
        return rows.map(createRow).toList();
      }
      rethrow;
    }
  }
}

String ftsOrFilterValue(String? query) {
  final escaped =
      (query?.trim() ?? '').replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

extension NullSafePostgrestFilters on PostgrestFilterBuilder {
  PostgrestFilterBuilder eqOrNull(String column, dynamic value) =>
      value != null ? eq(column, value) : this;
  PostgrestFilterBuilder neqOrNull(String column, dynamic value) =>
      value != null ? neq(column, value) : this;
  PostgrestFilterBuilder ltOrNull(String column, dynamic value) =>
      value != null ? lt(column, value) : this;
  PostgrestFilterBuilder lteOrNull(String column, dynamic value) =>
      value != null ? lte(column, value) : this;
  PostgrestFilterBuilder gtOrNull(String column, dynamic value) =>
      value != null ? gt(column, value) : this;
  PostgrestFilterBuilder gteOrNull(String column, dynamic value) =>
      value != null ? gte(column, value) : this;
  PostgrestFilterBuilder containsOrNull(String column, dynamic value) =>
      value != null ? contains(column, value) : this;
  PostgrestFilterBuilder overlapsOrNull(String column, dynamic value) =>
      value != null ? overlaps(column, value) : this;
  PostgrestFilterBuilder inFilterOrNull(String column, List<dynamic>? values) =>
      values != null ? inFilter(column, values) : this;
  PostgrestFilterBuilder textSearchOrNull(
    String column,
    String? query, {
    String? config,
    TextSearchType? type,
  }) =>
      query != null && query.trim().isNotEmpty
          ? textSearch(column, query, config: config, type: type)
          : this;

  PostgrestFilterBuilder requiredTextSearch(
    String column,
    String? query, {
    String? config,
    TextSearchType? type,
  }) =>
      textSearch(column, query?.trim() ?? '', config: config, type: type);
}

extension NullSafeSupabaseStreamFilters on SupabaseStreamFilterBuilder {
  SupabaseStreamBuilder eqOrNull(String column, dynamic value) =>
      value != null ? eq(column, value) : this;
  SupabaseStreamBuilder neqOrNull(String column, dynamic value) =>
      value != null ? neq(column, value) : this;
  SupabaseStreamBuilder ltOrNull(String column, dynamic value) =>
      value != null ? lt(column, value) : this;
  SupabaseStreamBuilder lteOrNull(String column, dynamic value) =>
      value != null ? lte(column, value) : this;
  SupabaseStreamBuilder gtOrNull(String column, dynamic value) =>
      value != null ? gt(column, value) : this;
  SupabaseStreamBuilder gteOrNull(String column, dynamic value) =>
      value != null ? gte(column, value) : this;
  SupabaseStreamBuilder inFilterOrNull(String column, List<Object>? values) =>
      values != null ? inFilter(column, values) : this;
}

class PostgresTime {
  PostgresTime(this.time);
  DateTime? time;

  static PostgresTime? tryParse(String formattedString) {
    final datePrefix = DateTime.now().toIso8601String().split('T').first;
    return PostgresTime(
        DateTime.tryParse('${datePrefix}T$formattedString')?.toLocal());
  }

  String? toIso8601String() => time?.toIso8601String().split('T').last;
  dynamic toJson() => toIso8601String();
  @override
  String toString() => toIso8601String() ?? '';
}
