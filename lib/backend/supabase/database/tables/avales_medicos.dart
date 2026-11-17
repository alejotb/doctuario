import '../database.dart';

class AvalesMedicosTable extends SupabaseTable<AvalesMedicosRow> {
  @override
  String get tableName => 'avales_medicos';

  @override
  AvalesMedicosRow createRow(Map<String, dynamic> data) =>
      AvalesMedicosRow(data);
}

class AvalesMedicosRow extends SupabaseDataRow {
  AvalesMedicosRow(super.data);

  @override
  SupabaseTable get table => AvalesMedicosTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idDoctorAvalado => getField<String>('id_doctor_avalado');
  set idDoctorAvalado(String? value) =>
      setField<String>('id_doctor_avalado', value);

  String? get idDoctorAvalador => getField<String>('id_doctor_avalador');
  set idDoctorAvalador(String? value) =>
      setField<String>('id_doctor_avalador', value);

  String? get comentario => getField<String>('comentario');
  set comentario(String? value) => setField<String>('comentario', value);
}
