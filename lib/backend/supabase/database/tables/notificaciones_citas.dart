import '../database.dart';

class NotificacionesCitasTable extends SupabaseTable<NotificacionesCitasRow> {
  @override
  String get tableName => 'notificaciones_citas';

  @override
  NotificacionesCitasRow createRow(Map<String, dynamic> data) =>
      NotificacionesCitasRow(data);
}

class NotificacionesCitasRow extends SupabaseDataRow {
  NotificacionesCitasRow(super.data);

  @override
  SupabaseTable get table => NotificacionesCitasTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idUsuario => getField<String>('id_usuario');
  set idUsuario(String? value) => setField<String>('id_usuario', value);

  String? get idCita => getField<String>('id_cita');
  set idCita(String? value) => setField<String>('id_cita', value);

  String? get tipo => getField<String>('tipo');
  set tipo(String? value) => setField<String>('tipo', value);

  String? get titulo => getField<String>('titulo');
  set titulo(String? value) => setField<String>('titulo', value);

  String? get mensaje => getField<String>('mensaje');
  set mensaje(String? value) => setField<String>('mensaje', value);

  int? get minutosRetraso => getField<int>('minutos_retraso');
  set minutosRetraso(int? value) => setField<int>('minutos_retraso', value);

  bool? get leido => getField<bool>('leido');
  set leido(bool? value) => setField<bool>('leido', value);
}
