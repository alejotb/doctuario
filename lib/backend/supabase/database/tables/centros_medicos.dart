import '../database.dart';

class CentrosMedicosTable extends SupabaseTable<CentrosMedicosRow> {
  @override
  String get tableName => 'centros_medicos';

  @override
  CentrosMedicosRow createRow(Map<String, dynamic> data) =>
      CentrosMedicosRow(data);
}

class CentrosMedicosRow extends SupabaseDataRow {
  CentrosMedicosRow(super.data);

  @override
  SupabaseTable get table => CentrosMedicosTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get nombre => getField<String>('nombre');
  set nombre(String? value) => setField<String>('nombre', value);

  String? get tipo => getField<String>('tipo');
  set tipo(String? value) => setField<String>('tipo', value);

  String? get estado => getField<String>('estado');
  set estado(String? value) => setField<String>('estado', value);

  String? get ciudad => getField<String>('ciudad');
  set ciudad(String? value) => setField<String>('ciudad', value);

  String? get direccion => getField<String>('direccion');
  set direccion(String? value) => setField<String>('direccion', value);

  String? get telefono => getField<String>('telefono');
  set telefono(String? value) => setField<String>('telefono', value);

  String? get registradoPorDoctorId =>
      getField<String>('registrado_por_doctor_id');
  set registradoPorDoctorId(String? value) =>
      setField<String>('registrado_por_doctor_id', value);
}
