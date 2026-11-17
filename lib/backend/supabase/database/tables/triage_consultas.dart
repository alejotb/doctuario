import '../database.dart';

class TriageConsultasTable extends SupabaseTable<TriageConsultasRow> {
  @override
  String get tableName => 'triage_consultas';

  @override
  TriageConsultasRow createRow(Map<String, dynamic> data) =>
      TriageConsultasRow(data);
}

class TriageConsultasRow extends SupabaseDataRow {
  TriageConsultasRow(super.data);

  @override
  SupabaseTable get table => TriageConsultasTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idPaciente => getField<String>('id_paciente');
  set idPaciente(String? value) => setField<String>('id_paciente', value);

  String? get idCita => getField<String>('id_cita');
  set idCita(String? value) => setField<String>('id_cita', value);

  String? get descripcionSintomas => getField<String>('descripcion_sintomas');
  set descripcionSintomas(String? value) =>
      setField<String>('descripcion_sintomas', value);

  String? get nivelUrgencia => getField<String>('nivel_urgencia');
  set nivelUrgencia(String? value) =>
      setField<String>('nivel_urgencia', value);

  bool? get requiereHospital => getField<bool>('requiere_hospital');
  set requiereHospital(bool? value) =>
      setField<bool>('requiere_hospital', value);

  String? get resumenPreconsulta => getField<String>('resumen_preconsulta');
  set resumenPreconsulta(String? value) =>
      setField<String>('resumen_preconsulta', value);
}
