import '../database.dart';

class DoctorSedesTable extends SupabaseTable<DoctorSedesRow> {
  @override
  String get tableName => 'doctor_sedes';

  @override
  DoctorSedesRow createRow(Map<String, dynamic> data) => DoctorSedesRow(data);
}

class DoctorSedesRow extends SupabaseDataRow {
  DoctorSedesRow(super.data);

  @override
  SupabaseTable get table => DoctorSedesTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idDoctor => getField<String>('id_doctor');
  set idDoctor(String? value) => setField<String>('id_doctor', value);

  String? get nombreSede => getField<String>('nombre_sede');
  set nombreSede(String? value) => setField<String>('nombre_sede', value);

  String? get direccion => getField<String>('direccion');
  set direccion(String? value) => setField<String>('direccion', value);

  String? get ciudad => getField<String>('ciudad');
  set ciudad(String? value) => setField<String>('ciudad', value);

  String? get estado => getField<String>('estado');
  set estado(String? value) => setField<String>('estado', value);

  String? get telefonoContacto => getField<String>('telefono_contacto');
  set telefonoContacto(String? value) =>
      setField<String>('telefono_contacto', value);

  String? get tipoLugar => getField<String>('tipo_lugar'); // 'privado' | 'centro_medico'
  set tipoLugar(String? value) => setField<String>('tipo_lugar', value);

  String? get idCentroMedico => getField<String>('id_centro_medico');
  set idCentroMedico(String? value) =>
      setField<String>('id_centro_medico', value);

  String? get numeroConsultorio => getField<String>('numero_consultorio');
  set numeroConsultorio(String? value) =>
      setField<String>('numero_consultorio', value);

  int? get duracionConsultaMinutos =>
      getField<int>('duracion_consulta_minutos');
  set duracionConsultaMinutos(int? value) =>
      setField<int>('duracion_consulta_minutos', value);

  String? get diasAtencion => getField<String>('dias_atencion');
  set diasAtencion(String? value) => setField<String>('dias_atencion', value);

  String? get horarioTexto => getField<String>('horario_texto');
  set horarioTexto(String? value) => setField<String>('horario_texto', value);

  double? get latitud => getField<double>('latitud');
  set latitud(double? value) => setField<double>('latitud', value);

  double? get longitud => getField<double>('longitud');
  set longitud(double? value) => setField<double>('longitud', value);

  bool? get telefonoVisible => getField<bool>('telefono_visible');
  set telefonoVisible(bool? value) => setField<bool>('telefono_visible', value);

  bool? get esPrincipal => getField<bool>('es_principal');
  set esPrincipal(bool? value) => setField<bool>('es_principal', value);

  String? get modalidadAtencion => getField<String>('modalidad_atencion');
  set modalidadAtencion(String? value) =>
      setField<String>('modalidad_atencion', value);
}
