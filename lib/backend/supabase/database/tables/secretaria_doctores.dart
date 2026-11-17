import '../database.dart';

class SecretariaDoctoresTable extends SupabaseTable<SecretariaDoctoresRow> {
  @override
  String get tableName => 'secretaria_doctores';

  @override
  SecretariaDoctoresRow createRow(Map<String, dynamic> data) =>
      SecretariaDoctoresRow(data);
}

class SecretariaDoctoresRow extends SupabaseDataRow {
  SecretariaDoctoresRow(super.data);

  @override
  SupabaseTable get table => SecretariaDoctoresTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idSecretaria => getField<String>('id_secretaria');
  set idSecretaria(String? value) => setField<String>('id_secretaria', value);

  String? get idDoctor => getField<String>('id_doctor');
  set idDoctor(String? value) => setField<String>('id_doctor', value);

  String? get idSede => getField<String>('id_sede');
  set idSede(String? value) => setField<String>('id_sede', value);

  bool? get activo => getField<bool>('activo');
  set activo(bool? value) => setField<bool>('activo', value);
}
