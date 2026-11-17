import '../database.dart';

class DoctoresTable extends SupabaseTable<DoctoresRow> {
  @override
  String get tableName => 'doctores';

  @override
  DoctoresRow createRow(Map<String, dynamic> data) => DoctoresRow(data);
}

class DoctoresRow extends SupabaseDataRow {
  DoctoresRow(super.data);

  @override
  SupabaseTable get table => DoctoresTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get especialidad => getField<String>('especialidad');
  set especialidad(String? value) => setField<String>('especialidad', value);

  String? get biografia => getField<String>('biografia');
  set biografia(String? value) => setField<String>('biografia', value);

  double? get costoConsulta => getField<double>('costo_consulta');
  set costoConsulta(double? value) => setField<double>('costo_consulta', value);

  bool? get estaAprobado => getField<bool>('esta_aprobado');
  set estaAprobado(bool? value) => setField<bool>('esta_aprobado', value);

  String? get nroColegiatura => getField<String>('nro_colegiatura');
  set nroColegiatura(String? value) =>
      setField<String>('nro_colegiatura', value);

  String? get credencialUrl => getField<String>('credencial_url');
  set credencialUrl(String? value) => setField<String>('credencial_url', value);

  String? get estadoVerificacion => getField<String>('estado_verificacion');
  set estadoVerificacion(String? value) =>
      setField<String>('estado_verificacion', value);

  int? get duracionCitaMinutos => getField<int>('duracion_cita_minutos');
  set duracionCitaMinutos(int? value) =>
      setField<int>('duracion_cita_minutos', value);

  bool? get permiteSobrecupo => getField<bool>('permite_sobrecupo');
  set permiteSobrecupo(bool? value) =>
      setField<bool>('permite_sobrecupo', value);

  String? get clinicasReferencia => getField<String>('clinicas_referencia');
  set clinicasReferencia(String? value) =>
      setField<String>('clinicas_referencia', value);

  int? get limitePacientesDia => getField<int>('limite_pacientes_dia');
  set limitePacientesDia(int? value) =>
      setField<int>('limite_pacientes_dia', value);

  String? get logoUrl => getField<String>('logo_url');
  set logoUrl(String? value) => setField<String>('logo_url', value);

  bool? get visibleEnCatalogo => getField<bool>('visible_en_catalogo');
  set visibleEnCatalogo(bool? value) =>
      setField<bool>('visible_en_catalogo', value);
}
