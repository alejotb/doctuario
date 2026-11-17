import '../database.dart';

class ExamenesMedicosTable extends SupabaseTable<ExamenesMedicosRow> {
  @override
  String get tableName => 'examenes_medicos';

  @override
  ExamenesMedicosRow createRow(Map<String, dynamic> data) =>
      ExamenesMedicosRow(data);
}

class ExamenesMedicosRow extends SupabaseDataRow {
  ExamenesMedicosRow(super.data);

  @override
  SupabaseTable get table => ExamenesMedicosTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idPaciente => getField<String>('id_paciente');
  set idPaciente(String? value) => setField<String>('id_paciente', value);

  String? get idDoctor => getField<String>('id_doctor');
  set idDoctor(String? value) => setField<String>('id_doctor', value);

  String? get subidoPorUsuarioId => getField<String>('subido_por_usuario_id');
  set subidoPorUsuarioId(String? value) =>
      setField<String>('subido_por_usuario_id', value);

  String? get titulo => getField<String>('titulo');
  set titulo(String? value) => setField<String>('titulo', value);

  String? get tipoExamen => getField<String>('tipo_examen');
  set tipoExamen(String? value) => setField<String>('tipo_examen', value);

  String? get archivoUrl => getField<String>('archivo_url');
  set archivoUrl(String? value) => setField<String>('archivo_url', value);

  String? get formato => getField<String>('formato');
  set formato(String? value) => setField<String>('formato', value);

  DateTime? get fechaEstudio => getField<DateTime>('fecha_estudio');
  set fechaEstudio(DateTime? value) =>
      setField<DateTime>('fecha_estudio', value);

  String? get notas => getField<String>('notas');
  set notas(String? value) => setField<String>('notas', value);

  DateTime? get fechaEntrega => getField<DateTime>('fecha_entrega');
  set fechaEntrega(DateTime? value) =>
      setField<DateTime>('fecha_entrega', value);

  String? get especialidad => getField<String>('especialidad');
  set especialidad(String? value) => setField<String>('especialidad', value);

  String? get estado => getField<String>('estado');
  set estado(String? value) => setField<String>('estado', value);

  String? get hallazgos => getField<String>('hallazgos') ?? notas;
  set hallazgos(String? value) => setField<String>('hallazgos', value);
}
