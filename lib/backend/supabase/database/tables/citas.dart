import '../database.dart';

class CitasTable extends SupabaseTable<CitasRow> {
  @override
  String get tableName => 'citas';

  @override
  CitasRow createRow(Map<String, dynamic> data) => CitasRow(data);
}

class CitasRow extends SupabaseDataRow {
  CitasRow(super.data);

  @override
  SupabaseTable get table => CitasTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idDoctor => getField<String>('id_doctor');
  set idDoctor(String? value) => setField<String>('id_doctor', value);

  String? get idPaciente => getField<String>('id_paciente');
  set idPaciente(String? value) => setField<String>('id_paciente', value);

  String? get idSede => getField<String>('id_sede');
  set idSede(String? value) => setField<String>('id_sede', value);

  DateTime? get fechaHora => getField<DateTime>('fecha_hora');
  set fechaHora(DateTime? value) => setField<DateTime>('fecha_hora', value);

  DateTime? get fechaHoraEstimadaActual =>
      getField<DateTime>('fecha_hora_estimada_actual');
  set fechaHoraEstimadaActual(DateTime? value) =>
      setField<DateTime>('fecha_hora_estimada_actual', value);

  String? get estado => getField<String>('estado');
  set estado(String? value) => setField<String>('estado', value);

  String? get motivo => getField<String>('motivo');
  set motivo(String? value) => setField<String>('motivo', value);

  String? get notasMedicas => getField<String>('notas_medicas');
  set notasMedicas(String? value) => setField<String>('notas_medicas', value);

  bool? get esEmergencia => getField<bool>('es_emergencia');
  set esEmergencia(bool? value) => setField<bool>('es_emergencia', value);

  bool? get tratoEspecial => getField<bool>('trato_especial');
  set tratoEspecial(bool? value) => setField<bool>('trato_especial', value);

  int? get minutosRetrasoAcumulados =>
      getField<int>('minutos_retraso_acumulados');
  set minutosRetrasoAcumulados(int? value) =>
      setField<int>('minutos_retraso_acumulados', value);

  int? get turnoNumero => getField<int>('turno_numero');
  set turnoNumero(int? value) => setField<int>('turno_numero', value);

  String? get modalidadAtencion => getField<String>('modalidad_atencion');
  set modalidadAtencion(String? value) =>
      setField<String>('modalidad_atencion', value);

  int? get duracionMinutos => getField<int>('duracion_minutos');
  set duracionMinutos(int? value) => setField<int>('duracion_minutos', value);

  bool? get llegadaConfirmada => getField<bool>('llegada_confirmada');
  set llegadaConfirmada(bool? value) =>
      setField<bool>('llegada_confirmada', value);

  DateTime? get horaLlegada => getField<DateTime>('hora_llegada');
  set horaLlegada(DateTime? value) => setField<DateTime>('hora_llegada', value);

  int? get posicionCola => getField<int>('posicion_cola');
  set posicionCola(int? value) => setField<int>('posicion_cola', value);

  bool? get esControl => getField<bool>('es_control');
  set esControl(bool? value) => setField<bool>('es_control', value);

  bool? get cobrarControl => getField<bool>('cobrar_control');
  set cobrarControl(bool? value) => setField<bool>('cobrar_control', value);

  String? get tipoExoneracion => getField<String>('tipo_exoneracion');
  set tipoExoneracion(String? value) =>
      setField<String>('tipo_exoneracion', value);

  double? get montoExoneracion => getField<double>('monto_exoneracion');
  set montoExoneracion(double? value) =>
      setField<double>('monto_exoneracion', value);
}
