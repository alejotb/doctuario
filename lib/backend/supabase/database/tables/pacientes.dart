import '../database.dart';

class PacientesTable extends SupabaseTable<PacientesRow> {
  @override
  String get tableName => 'pacientes';

  @override
  PacientesRow createRow(Map<String, dynamic> data) => PacientesRow(data);
}

class PacientesRow extends SupabaseDataRow {
  PacientesRow(super.data);

  @override
  SupabaseTable get table => PacientesTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  DateTime? get fechaNacimiento => getField<DateTime>('fecha_nacimiento');
  set fechaNacimiento(DateTime? value) =>
      setField<DateTime>('fecha_nacimiento', value);

  String? get tipoSangre => getField<String>('tipo_sangre');
  set tipoSangre(String? value) => setField<String>('tipo_sangre', value);

  String? get idDoctor => getField<String>('id_doctor');
  set idDoctor(String? value) => setField<String>('id_doctor', value);
}
