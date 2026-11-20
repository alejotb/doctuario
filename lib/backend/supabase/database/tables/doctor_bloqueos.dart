import '../database.dart';

class DoctorBloqueosTable extends SupabaseTable<DoctorBloqueosRow> {
  @override
  String get tableName => 'doctor_bloqueos';

  @override
  DoctorBloqueosRow createRow(Map<String, dynamic> data) =>
      DoctorBloqueosRow(data);
}

class DoctorBloqueosRow extends SupabaseDataRow {
  DoctorBloqueosRow(super.data);

  @override
  SupabaseTable get table => DoctorBloqueosTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String get idDoctor => getField<String>('id_doctor')!;
  set idDoctor(String value) => setField<String>('id_doctor', value);

  DateTime get fecha => getField<DateTime>('fecha')!;
  set fecha(DateTime value) => setField<DateTime>('fecha', value);

  String? get motivo => getField<String>('motivo');
  set motivo(String? value) => setField<String>('motivo', value);
}
