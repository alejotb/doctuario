import 'package:flutter/material.dart';
import '/services/medical_centers_service.dart';

/// Modelo de datos que representa una Sede de atención médica
/// configurada durante el proceso de registro del doctor.
class DoctorSetupSedeEntry {
  final String id;
  String tipoLugar; // 'clinica' | 'privado'
  String estado;
  String ciudad;
  List<String> ciudadesDisponibles;
  CentroMedicoItem? centroSeleccionado;

  final TextEditingController nombreSedeCtrl;
  final TextEditingController pisoCtrl;
  final TextEditingController numeroLocalCtrl;
  final TextEditingController direccionCtrl;
  final TextEditingController telefonoCtrl;

  bool telefonoVisible;
  double? latitud;
  double? longitud;

  // Días y Horarios asignados exclusivamente a esta sede
  Set<int> diasSeleccionados;
  TimeOfDay horaInicio;
  TimeOfDay horaFin;
  bool tienePausaAlmuerzo;
  TimeOfDay horaInicioAlmuerzo;
  TimeOfDay horaFinAlmuerzo;
  String modalidadAtencion; // 'cita_previa' | 'orden_llegada'
  int duracionMinutos;

  DoctorSetupSedeEntry({
    required this.id,
    this.tipoLugar = 'clinica',
    this.estado = 'Trujillo',
    this.ciudad = 'Valera',
    this.ciudadesDisponibles = const [],
    this.centroSeleccionado,
    TextEditingController? nombreSedeCtrl,
    TextEditingController? pisoCtrl,
    TextEditingController? numeroLocalCtrl,
    TextEditingController? direccionCtrl,
    TextEditingController? telefonoCtrl,
    this.telefonoVisible = true,
    this.latitud,
    this.longitud,
    Set<int>? diasSeleccionados,
    this.horaInicio = const TimeOfDay(hour: 8, minute: 0),
    this.horaFin = const TimeOfDay(hour: 17, minute: 0),
    this.tienePausaAlmuerzo = true,
    this.horaInicioAlmuerzo = const TimeOfDay(hour: 12, minute: 0),
    this.horaFinAlmuerzo = const TimeOfDay(hour: 13, minute: 0),
    this.modalidadAtencion = 'cita_previa',
    this.duracionMinutos = 30,
  })  : nombreSedeCtrl = nombreSedeCtrl ?? TextEditingController(),
        pisoCtrl = pisoCtrl ?? TextEditingController(),
        numeroLocalCtrl = numeroLocalCtrl ?? TextEditingController(),
        direccionCtrl = direccionCtrl ?? TextEditingController(),
        telefonoCtrl = telefonoCtrl ?? TextEditingController(),
        diasSeleccionados = diasSeleccionados ?? {1, 2, 3, 4, 5};

  void dispose() {
    nombreSedeCtrl.dispose();
    pisoCtrl.dispose();
    numeroLocalCtrl.dispose();
    direccionCtrl.dispose();
    telefonoCtrl.dispose();
  }

  String getUbicacionEspecificaTexto() {
    final piso = pisoCtrl.text.trim();
    final local = numeroLocalCtrl.text.trim();

    if (piso.isNotEmpty && local.isNotEmpty) {
      final pisoFmt = (piso.toLowerCase().startsWith('piso') ||
              piso.toLowerCase().startsWith('nivel') ||
              piso.toUpperCase() == 'PB' ||
              piso.toLowerCase().startsWith('planta'))
          ? piso
          : 'Piso $piso';
      final localFmt = (local.toLowerCase().startsWith('consultorio') ||
              local.toLowerCase().startsWith('local') ||
              local.toLowerCase().startsWith('oficina'))
          ? local
          : 'Consultorio $local';
      return '$pisoFmt, $localFmt';
    } else if (piso.isNotEmpty) {
      return (piso.toLowerCase().startsWith('piso') || piso.toUpperCase() == 'PB')
          ? piso
          : 'Piso $piso';
    } else if (local.isNotEmpty) {
      return (local.toLowerCase().startsWith('consultorio') ||
              local.toLowerCase().startsWith('local'))
          ? local
          : 'Consultorio $local';
    }
    return '';
  }

  String getNombreVisual(int index) {
    if (tipoLugar == 'clinica' && centroSeleccionado != null) {
      return centroSeleccionado!.nombre;
    }
    if (nombreSedeCtrl.text.trim().isNotEmpty) {
      return nombreSedeCtrl.text.trim();
    }
    return 'Sede #${index + 1}';
  }

  static String nombreDiaCorto(int dia) {
    switch (dia) {
      case 1:
        return 'Lun';
      case 2:
        return 'Mar';
      case 3:
        return 'Mié';
      case 4:
        return 'Jue';
      case 5:
        return 'Vie';
      case 6:
        return 'Sáb';
      case 7:
        return 'Dom';
      default:
        return 'Día $dia';
    }
  }

  static String nombreDiaCompleto(int dia) {
    switch (dia) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return 'Día $dia';
    }
  }

  static String formatearTime(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Genera sugerencias de nombres profesionales para consultorio privado basadas en el nombre del doctor
  static List<String> generarSugerenciasNombreConsultorio(String doctorNombre) {
    final clean = doctorNombre.replaceAll(RegExp(r'^(dr\.|dra\.|doctor|doctora)\s+', caseSensitive: false), '').trim();
    if (clean.isEmpty) {
      return ['Consultorio Médico Privado', 'Consultorio de Doctor'];
    }
    final parts = clean.split(RegExp(r'\s+'));
    final apellido = parts.length > 1 ? parts.last : parts.first;
    return [
      'Consultorio de Dr. $apellido',
      'Consultorio de Dr. $clean',
      'Centro Médico $apellido',
    ];
  }

  /// Verifica si existe un solapamiento horario en un mismo día entre dos sedes diferentes
  static String? verificarConflictoHorario({
    required List<DoctorSetupSedeEntry> todasLasSedes,
    required int indexSedeActual,
    required int dia,
    required TimeOfDay inicio,
    required TimeOfDay fin,
  }) {
    final inicioMin = inicio.hour * 60 + inicio.minute;
    final finMin = fin.hour * 60 + fin.minute;

    for (int i = 0; i < todasLasSedes.length; i++) {
      if (i == indexSedeActual) continue;
      final otra = todasLasSedes[i];

      if (otra.diasSeleccionados.contains(dia)) {
        final otraInicioMin = otra.horaInicio.hour * 60 + otra.horaInicio.minute;
        final otraFinMin = otra.horaFin.hour * 60 + otra.horaFin.minute;

        // Comprobar intersección de rangos de minutos: max(ini1, ini2) < min(fin1, fin2)
        final maxInicio = inicioMin > otraInicioMin ? inicioMin : otraInicioMin;
        final minFin = finMin < otraFinMin ? finMin : otraFinMin;

        if (maxInicio < minFin) {
          final nombreOtra = otra.getNombreVisual(i);
          final diaTexto = nombreDiaCompleto(dia);
          return 'El $diaTexto ya tienes consulta en "$nombreOtra" de '
              '${formatearTime(otra.horaInicio)} a ${formatearTime(otra.horaFin)}. '
              'No puedes estar en ambas sedes a la misma vez.';
        }
      }
    }
    return null;
  }

  /// Obtiene los días que aún están totalmente libres (no asignados a ninguna sede)
  static Set<int> getDiasLibresRestantes(List<DoctorSetupSedeEntry> sedes, {int? excluirIndex}) {
    final ocupados = <int>{};
    for (int i = 0; i < sedes.length; i++) {
      if (excluirIndex != null && i == excluirIndex) continue;
      ocupados.addAll(sedes[i].diasSeleccionados);
    }
    return {1, 2, 3, 4, 5, 6, 7}.difference(ocupados);
  }

  /// Retorna un resumen legible del horario de esta sede
  String getResumenHorario() {
    final diasOrdenados = diasSeleccionados.toList()..sort();
    final diasStr = diasOrdenados.map((d) => nombreDiaCorto(d)).join(', ');
    return '$diasStr: ${formatearTime(horaInicio)} - ${formatearTime(horaFin)}';
  }

  /// Mapa que asocia cada día de la semana con la sede que lo tiene asignado
  static Map<int, String> getMapaDiasOcupados(
    List<DoctorSetupSedeEntry> todasLasSedes, {
    int? excluirIndex,
  }) {
    final mapa = <int, String>{};
    for (int i = 0; i < todasLasSedes.length; i++) {
      if (excluirIndex != null && i == excluirIndex) continue;
      final sede = todasLasSedes[i];
      for (final d in sede.diasSeleccionados) {
        mapa[d] = sede.getNombreVisual(i);
      }
    }
    return mapa;
  }
}
