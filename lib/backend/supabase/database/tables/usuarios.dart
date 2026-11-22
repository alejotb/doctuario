import '../database.dart';

class UsuariosTable extends SupabaseTable<UsuariosRow> {
  @override
  String get tableName => 'usuarios';

  @override
  UsuariosRow createRow(Map<String, dynamic> data) => UsuariosRow(data);
}

class UsuariosRow extends SupabaseDataRow {
  UsuariosRow(super.data);

  @override
  SupabaseTable get table => UsuariosTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get nombre => getField<String>('nombre');
  set nombre(String? value) => setField<String>('nombre', value);

  String? get cedula => getField<String>('cedula');
  set cedula(String? value) => setField<String>('cedula', value);

  String? get telefono => getField<String>('telefono');
  set telefono(String? value) => setField<String>('telefono', value);

  String? get email => getField<String>('email');
  set email(String? value) => setField<String>('email', value);

  String? get rol => getField<String>('rol');
  set rol(String? value) => setField<String>('rol', value);

  String? get fotoUrl => getField<String>('foto_url');
  set fotoUrl(String? value) => setField<String>('foto_url', value);

  bool? get esFamiliarMedico => getField<bool>('es_familiar_medico');
  set esFamiliarMedico(bool? value) =>
      setField<bool>('es_familiar_medico', value);

  String? get doctorReferenciaNombre =>
      getField<String>('doctor_referencia_nombre');
  set doctorReferenciaNombre(String? value) =>
      setField<String>('doctor_referencia_nombre', value);

  String? get ciudadOrigen => getField<String>('ciudad_origen');
  set ciudadOrigen(String? value) => setField<String>('ciudad_origen', value);

  bool? get esForaneo => getField<bool>('es_foraneo');
  set esForaneo(bool? value) => setField<bool>('es_foraneo', value);

  DateTime? get fechaNacimiento => getField<DateTime>('fecha_nacimiento');
  set fechaNacimiento(DateTime? value) =>
      setField<DateTime>('fecha_nacimiento', value);

  String? get lazoFamiliar => getField<String>('lazo_familiar');
  set lazoFamiliar(String? value) => setField<String>('lazo_familiar', value);

  String? get nombreDoctorColega => getField<String>('nombre_doctor_colega');
  set nombreDoctorColega(String? value) =>
      setField<String>('nombre_doctor_colega', value);

  String? get tipoExoneracion => getField<String>('tipo_exoneracion');
  set tipoExoneracion(String? value) =>
      setField<String>('tipo_exoneracion', value);

  double? get montoExoneracion => getField<double>('monto_exoneracion');
  set montoExoneracion(double? value) =>
      setField<double>('monto_exoneracion', value);

  String? get genero => getField<String>('genero');
  set genero(String? value) => setField<String>('genero', value);
}
