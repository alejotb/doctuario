import '../database.dart';

class HistoriasClinicasTable extends SupabaseTable<HistoriasClinicasRow> {
  @override
  String get tableName => 'historias_clinicas';

  @override
  HistoriasClinicasRow createRow(Map<String, dynamic> data) =>
      HistoriasClinicasRow(data);
}

class HistoriasClinicasRow extends SupabaseDataRow {
  HistoriasClinicasRow(super.data);

  @override
  SupabaseTable get table => HistoriasClinicasTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idPaciente => getField<String>('id_paciente');
  set idPaciente(String? value) => setField<String>('id_paciente', value);

  String? get idDoctor => getField<String>('id_doctor');
  set idDoctor(String? value) => setField<String>('id_doctor', value);

  String? get idCita => getField<String>('id_cita');
  set idCita(String? value) => setField<String>('id_cita', value);

  String? get idPlantilla => getField<String>('id_plantilla');
  set idPlantilla(String? value) => setField<String>('id_plantilla', value);

  dynamic get datosHistoriaJson => getField<dynamic>('datos_historia_json');
  set datosHistoriaJson(dynamic value) =>
      setField<dynamic>('datos_historia_json', value);

  String? get motivoConsulta => getField<String>('motivo_consulta');
  set motivoConsulta(String? value) =>
      setField<String>('motivo_consulta', value);

  String? get sintomas => getField<String>('sintomas');
  set sintomas(String? value) => setField<String>('sintomas', value);

  String? get examenFisico => getField<String>('examen_fisico');
  set examenFisico(String? value) => setField<String>('examen_fisico', value);

  String? get diagnostico => getField<String>('diagnostico');
  set diagnostico(String? value) => setField<String>('diagnostico', value);

  String? get tratamiento => getField<String>('tratamiento');
  set tratamiento(String? value) => setField<String>('tratamiento', value);

  String? get notasPrivadas => getField<String>('notas_privadas');
  set notasPrivadas(String? value) => setField<String>('notas_privadas', value);

  bool? get esPrivado => getField<bool>('es_privado');
  set esPrivado(bool? value) => setField<bool>('es_privado', value);
}
