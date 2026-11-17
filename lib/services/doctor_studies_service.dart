import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase/supabase.dart';

/// Modelo de configuración de un estudio o procedimiento clínico que realiza el doctor.
class DoctorEstudioConfig {
  final String id;
  String titulo;
  String categoria;
  int duracionMinutos;
  bool activo;
  IconData? icono;

  DoctorEstudioConfig({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.duracionMinutos,
    this.activo = true,
    this.icono,
  });

  static IconData obtenerIconoParaCategoria(String categoria) {
    if (categoria.contains('Cardio')) return Icons.monitor_heart_rounded;
    if (categoria.contains('Eco') || categoria.contains('Ultra')) return Icons.waves_rounded;
    if (categoria.contains('Lab')) return Icons.biotech_rounded;
    if (categoria.contains('Patol') || categoria.contains('Biop')) return Icons.science_rounded;
    if (categoria.contains('Pulmon') || categoria.contains('Espiro')) return Icons.air_rounded;
    if (categoria.contains('Sutura') || categoria.contains('Herida')) return Icons.healing_rounded;
    return Icons.medical_services_rounded;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'categoria': categoria,
        'duracionMinutos': duracionMinutos,
        'activo': activo,
      };

  factory DoctorEstudioConfig.fromJson(Map<String, dynamic> json) {
    final cat = json['categoria'] as String? ?? 'General';
    return DoctorEstudioConfig(
      id: json['id'] as String? ?? UniqueKey().toString(),
      titulo: json['titulo'] as String? ?? 'Estudio Clínico',
      categoria: cat,
      duracionMinutos: (json['duracionMinutos'] as num?)?.toInt() ?? 15,
      activo: json['activo'] as bool? ?? true,
      icono: obtenerIconoParaCategoria(cat),
    );
  }

  DoctorEstudioConfig copyWith({
    String? id,
    String? titulo,
    String? categoria,
    int? duracionMinutos,
    bool? activo,
    IconData? icono,
  }) {
    return DoctorEstudioConfig(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      categoria: categoria ?? this.categoria,
      duracionMinutos: duracionMinutos ?? this.duracionMinutos,
      activo: activo ?? this.activo,
      icono: icono ?? this.icono,
    );
  }
}

/// Servicio que administra los estudios y procedimientos clínicos que realiza cada doctor,
/// permitiendo personalizar tiempos estimados y filtrar las opciones que se muestran en consulta.
class DoctorStudiesService {
  DoctorStudiesService._();
  static final DoctorStudiesService instance = DoctorStudiesService._();

  static String _storageKey(String idDoctor) =>
      'prontudoc_doctor_estudios_catalogo_$idDoctor';

  /// Catálogo predeterminado sugerido con duraciones estándar en minutos
  static final List<DoctorEstudioConfig> estudiosPredeterminados = [
    DoctorEstudioConfig(
      id: 'ecg_cardio',
      titulo: 'Electrocardiograma (ECG)',
      categoria: 'Cardiología y Función Cardiovascular',
      duracionMinutos: 15,
      activo: true,
      icono: Icons.monitor_heart_rounded,
    ),
    DoctorEstudioConfig(
      id: 'eco_abdominal',
      titulo: 'Ecografía Abdominal / Pélvica',
      categoria: 'Ecografía y Ultrasonido',
      duracionMinutos: 20,
      activo: true,
      icono: Icons.waves_rounded,
    ),
    DoctorEstudioConfig(
      id: 'lab_muestra',
      titulo: 'Toma de Muestra / Laboratorio',
      categoria: 'Laboratorio Clínico',
      duracionMinutos: 10,
      activo: true,
      icono: Icons.biotech_rounded,
    ),
    DoctorEstudioConfig(
      id: 'sutura_curacion',
      titulo: 'Sutura / Curación de Herida',
      categoria: 'Otros Estudios Médicos',
      duracionMinutos: 25,
      activo: true,
      icono: Icons.healing_rounded,
    ),
    DoctorEstudioConfig(
      id: 'biopsia_citologia',
      titulo: 'Biopsia / Citología',
      categoria: 'Anatomía Patológica y Biopsias',
      duracionMinutos: 20,
      activo: false,
      icono: Icons.science_rounded,
    ),
    DoctorEstudioConfig(
      id: 'espirometria',
      titulo: 'Espirometría Pulmonar',
      categoria: 'Otros Estudios Médicos',
      duracionMinutos: 15,
      activo: false,
      icono: Icons.air_rounded,
    ),
    DoctorEstudioConfig(
      id: 'infiltracion',
      titulo: 'Infiltración Articular',
      categoria: 'Otros Estudios Médicos',
      duracionMinutos: 15,
      activo: false,
      icono: Icons.colorize_rounded,
    ),
    DoctorEstudioConfig(
      id: 'cauterizacion',
      titulo: 'Cauterización / Dermatoscopia',
      categoria: 'Otros Estudios Médicos',
      duracionMinutos: 15,
      activo: false,
      icono: Icons.medical_services_rounded,
    ),
    DoctorEstudioConfig(
      id: 'lavado_oido',
      titulo: 'Lavado de Oído / Otoscopia',
      categoria: 'Otros Estudios Médicos',
      duracionMinutos: 15,
      activo: false,
      icono: Icons.hearing_rounded,
    ),
  ];

  /// Obtiene la lista completa de estudios (activos e inactivos) del médico
  Future<List<DoctorEstudioConfig>> obtenerEstudiosConfigurados(
      String idDoctor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_storageKey(idDoctor));

      if (storedJson != null && storedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(storedJson);
        return decoded
            .map((item) =>
                DoctorEstudioConfig.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error leyendo estudios configurados en SharedPreferences: $e');
    }

    // Si aún no ha configurado sus estudios, retornamos la plantilla predeterminada
    return List<DoctorEstudioConfig>.from(
      estudiosPredeterminados.map((e) => e.copyWith()),
    );
  }

  /// Retorna únicamente los estudios que el doctor tiene marcados como activos
  Future<List<DoctorEstudioConfig>> obtenerEstudiosActivos(
      String idDoctor) async {
    final todos = await obtenerEstudiosConfigurados(idDoctor);
    final activos = todos.where((e) => e.activo).toList();

    // Si no tiene ninguno activo, devolvemos al menos los básicos por defecto
    if (activos.isEmpty) {
      return todos.take(4).toList();
    }
    return activos;
  }

  /// Guarda los estudios configurados por el doctor tanto localmente como en base de datos
  Future<bool> guardarEstudiosDoctor({
    required String idDoctor,
    required List<DoctorEstudioConfig> estudios,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = estudios.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey(idDoctor), jsonEncode(jsonList));

      // Replicar en tenant del doctor si la tabla doctores o usuarios lo admite
      try {
        final client = DualDatabaseConfig.instance.doctorClient;
        await client.from('doctores').update({
          'clinicas_referencia': jsonEncode(
            estudios.where((e) => e.activo).map((e) => e.titulo).toList(),
          ),
        }).eq('id', idDoctor);
      } catch (_) {
        // Fallback silencioso si la columna se utiliza para otro fin
      }

      return true;
    } catch (e) {
      debugPrint('Error guardando configuración de estudios del doctor: $e');
      return false;
    }
  }

  /// Añade un nuevo estudio personalizado definido por el médico
  Future<List<DoctorEstudioConfig>> agregarEstudioPersonalizado({
    required String idDoctor,
    required String titulo,
    required String categoria,
    required int duracionMinutos,
  }) async {
    final listaActual = await obtenerEstudiosConfigurados(idDoctor);
    final nuevo = DoctorEstudioConfig(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      titulo: titulo.trim(),
      categoria: categoria.trim().isNotEmpty ? categoria.trim() : 'Estudios Personalizados',
      duracionMinutos: duracionMinutos,
      activo: true,
      icono: Icons.star_border_rounded,
    );

    listaActual.add(nuevo);
    await guardarEstudiosDoctor(idDoctor: idDoctor, estudios: listaActual);
    return listaActual;
  }

  /// Restablece la configuración de estudios a los valores por defecto del sistema
  Future<List<DoctorEstudioConfig>> restablecerPredeterminados(
      String idDoctor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(idDoctor));
    return List<DoctorEstudioConfig>.from(
      estudiosPredeterminados.map((e) => e.copyWith()),
    );
  }
}
