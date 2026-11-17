import '../database.dart';

class HorariosDisponibilidadTable
    extends SupabaseTable<HorariosDisponibilidadRow> {
  @override
  String get tableName => 'horarios_disponibilidad';

  @override
  HorariosDisponibilidadRow createRow(Map<String, dynamic> data) =>
      HorariosDisponibilidadRow(data);
}

class HorariosDisponibilidadRow extends SupabaseDataRow {
  HorariosDisponibilidadRow(super.data);

  @override
  SupabaseTable get table => HorariosDisponibilidadTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idDoctor => getField<String>('id_doctor');
  set idDoctor(String? value) => setField<String>('id_doctor', value);

  String? get idSede => getField<String>('id_sede');
  set idSede(String? value) => setField<String>('id_sede', value);

  int? get diaSemana => getField<int>('dia_semana');
  set diaSemana(int? value) => setField<int>('dia_semana', value);

  PostgresTime? get horaInicio => getField<PostgresTime>('hora_inicio');
  set horaInicio(PostgresTime? value) =>
      setField<PostgresTime>('hora_inicio', value);

  PostgresTime? get horaFin => getField<PostgresTime>('hora_fin');
  set horaFin(PostgresTime? value) => setField<PostgresTime>('hora_fin', value);

  String? get modalidadAtencion => getField<String>('modalidad_atencion');
  set modalidadAtencion(String? value) =>
      setField<String>('modalidad_atencion', value);

  int? get cupoMaximo => getField<int>('cupo_maximo');
  set cupoMaximo(int? value) => setField<int>('cupo_maximo', value);

  bool? get activo => getField<bool>('activo');
  set activo(bool? value) => setField<bool>('activo', value);
}
