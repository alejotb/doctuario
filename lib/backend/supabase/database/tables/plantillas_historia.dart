import '../database.dart';

class PlantillasHistoriaTable extends SupabaseTable<PlantillasHistoriaRow> {
  @override
  String get tableName => 'plantillas_historia';

  @override
  PlantillasHistoriaRow createRow(Map<String, dynamic> data) =>
      PlantillasHistoriaRow(data);
}

class PlantillasHistoriaRow extends SupabaseDataRow {
  PlantillasHistoriaRow(super.data);

  @override
  SupabaseTable get table => PlantillasHistoriaTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get idDoctor => getField<String>('id_doctor');
  set idDoctor(String? value) => setField<String>('id_doctor', value);

  String? get titulo => getField<String>('titulo');
  set titulo(String? value) => setField<String>('titulo', value);

  String? get especialidad => getField<String>('especialidad');
  set especialidad(String? value) => setField<String>('especialidad', value);

  dynamic get estructuraJson => getField<dynamic>('estructura_json');
  set estructuraJson(dynamic value) =>
      setField<dynamic>('estructura_json', value);

  bool? get esPredeterminada => getField<bool>('es_predeterminada');
  set esPredeterminada(bool? value) =>
      setField<bool>('es_predeterminada', value);
}
