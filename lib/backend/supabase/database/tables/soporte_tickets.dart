import '../database.dart';

class SoporteTicketsTable extends SupabaseTable<SoporteTicketsRow> {
  @override
  String get tableName => 'soporte_tickets';

  @override
  SoporteTicketsRow createRow(Map<String, dynamic> data) =>
      SoporteTicketsRow(data);
}

class SoporteTicketsRow extends SupabaseDataRow {
  SoporteTicketsRow(super.data);

  @override
  SupabaseTable get table => SoporteTicketsTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idDoctor => getField<String>('id_doctor');
  set idDoctor(String? value) => setField<String>('id_doctor', value);

  String? get doctorNombre => getField<String>('doctor_nombre');
  set doctorNombre(String? value) => setField<String>('doctor_nombre', value);

  String? get tipo => getField<String>('tipo');
  set tipo(String? value) => setField<String>('tipo', value);

  String? get prioridad => getField<String>('prioridad');
  set prioridad(String? value) => setField<String>('prioridad', value);

  String get asunto => getField<String>('asunto')!;
  set asunto(String value) => setField<String>('asunto', value);

  String get mensaje => getField<String>('mensaje')!;
  set mensaje(String value) => setField<String>('mensaje', value);

  String? get estado => getField<String>('estado');
  set estado(String? value) => setField<String>('estado', value);

  String? get respuestaAdmin => getField<String>('respuesta_admin');
  set respuestaAdmin(String? value) => setField<String>('respuesta_admin', value);
}
