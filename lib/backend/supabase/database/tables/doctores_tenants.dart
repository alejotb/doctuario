import '../database.dart';

class DoctoresTenantsTable extends SupabaseTable<DoctoresTenantsRow> {
  @override
  String get tableName => 'doctores_tenants';

  @override
  DoctoresTenantsRow createRow(Map<String, dynamic> data) =>
      DoctoresTenantsRow(data);
}

class DoctoresTenantsRow extends SupabaseDataRow {
  DoctoresTenantsRow(super.data);

  @override
  SupabaseTable get table => DoctoresTenantsTable();

  String get id => getField<String>('id')!;
  set id(String value) => setField<String>('id', value);

  String get idDoctor => getField<String>('id_doctor')!;
  set idDoctor(String value) => setField<String>('id_doctor', value);

  bool? get activo => getField<bool>('activo');
  set activo(bool? value) => setField<bool>('activo', value);

  String? get plan => getField<String>('plan');
  set plan(String? value) => setField<String>('plan', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get estadoPago => getField<String>('estado_pago');
  set estadoPago(String? value) => setField<String>('estado_pago', value);

  double? get precioMensual => getField<double>('precio_mensual');
  set precioMensual(double? value) => setField<double>('precio_mensual', value);

  String? get moneda => getField<String>('moneda');
  set moneda(String? value) => setField<String>('moneda', value);

  String? get intervaloPago => getField<String>('intervalo_pago');
  set intervaloPago(String? value) => setField<String>('intervalo_pago', value);

  DateTime? get fechaProximoPago => getField<DateTime>('fecha_proximo_pago');
  set fechaProximoPago(DateTime? value) =>
      setField<DateTime>('fecha_proximo_pago', value);

  int? get limiteDoctores => getField<int>('limite_doctores');
  set limiteDoctores(int? value) => setField<int>('limite_doctores', value);

  String? get idDoctorAdministrador =>
      getField<String>('id_doctor_administrador');
  set idDoctorAdministrador(String? value) =>
      setField<String>('id_doctor_administrador', value);

  bool? get modoSoloLectura => getField<bool>('modo_solo_lectura');
  set modoSoloLectura(bool? value) =>
      setField<bool>('modo_solo_lectura', value);
}
