import 'package:flutter/foundation.dart';
import '../backend/supabase/database/database.dart';
import 'venezuela_locations.dart';

class CentroMedicoItem {
  final String id;
  final String nombre;
  final String tipo; // 'Clinica' | 'Hospital' | 'Centro Medico' | 'Policlinica' | 'Ambulatorio' | 'Otro'
  final String estado;
  final String ciudad;
  final String? direccion;
  final String? telefono;
  final bool esPersonalizado;

  const CentroMedicoItem({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.estado,
    required this.ciudad,
    this.direccion,
    this.telefono,
    this.esPersonalizado = false,
  });

  factory CentroMedicoItem.fromRow(CentrosMedicosRow row) {
    return CentroMedicoItem(
      id: row.id,
      nombre: row.nombre ?? 'Centro Médico',
      tipo: row.tipo ?? 'Clinica',
      estado: row.estado ?? 'Trujillo',
      ciudad: row.ciudad ?? 'Valera',
      direccion: row.direccion,
      telefono: row.telefono,
      esPersonalizado: row.registradoPorDoctorId != null,
    );
  }
}

class MedicalCentersService {
  /// Catálogo inicial con centros de salud de referencia en Valera (Trujillo) y principales ciudades de Venezuela.
  static final List<CentroMedicoItem> _catalogoBase = [
    // --- VALERA, TRUJILLO ---
    const CentroMedicoItem(
      id: 'base_valera_1',
      nombre: 'Centro Médico Valera',
      tipo: 'Centro Medico',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Av. Bolívar, entre Calles 8 y 9, Casco Central, Valera',
      telefono: '0271-2211000',
    ),
    const CentroMedicoItem(
      id: 'base_valera_2',
      nombre: 'Clínica Sucre',
      tipo: 'Clinica',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Calle 10 con Av. 5, Sector Centro, Valera',
      telefono: '0271-2313200',
    ),
    const CentroMedicoItem(
      id: 'base_valera_3',
      nombre: 'Policlínica Valera',
      tipo: 'Policlinica',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Calle 13 con Av. Santa Bárbara, Valera',
      telefono: '0271-2254500',
    ),
    const CentroMedicoItem(
      id: 'base_valera_4',
      nombre: 'Hospital Universitario Dr. Pedro Emilio Carrillo',
      tipo: 'Hospital',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Av. Principal de La Beatriz / San Luis, Valera',
      telefono: '0271-2210511',
    ),
    const CentroMedicoItem(
      id: 'base_valera_5',
      nombre: 'Clínica María Mater',
      tipo: 'Clinica',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Av. 4 entre Calles 14 y 15, Valera',
      telefono: '0271-2215888',
    ),
    const CentroMedicoItem(
      id: 'base_valera_6',
      nombre: 'Clínica La Floresta',
      tipo: 'Clinica',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Urb. La Floresta, Av. Principal, Valera',
      telefono: '0271-2319011',
    ),
    const CentroMedicoItem(
      id: 'base_valera_7',
      nombre: 'Centro de Especialidades Los Ilustres',
      tipo: 'Centro Medico',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Av. Las Delicias frente a Parque Los Ilustres, Valera',
      telefono: '0271-2256677',
    ),
    const CentroMedicoItem(
      id: 'base_valera_8',
      nombre: 'Unidad Médico Quirúrgica San Rafael',
      tipo: 'Clinica',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Urb. Las Acacias, Calle 2, Valera',
      telefono: '0271-2217744',
    ),
    const CentroMedicoItem(
      id: 'base_valera_9',
      nombre: 'Centro Clínico Las Acacias',
      tipo: 'Clinica',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Av. Santa Bárbara, Las Acacias, Valera',
      telefono: '0271-2315512',
    ),
    const CentroMedicoItem(
      id: 'base_valera_10',
      nombre: 'Instituto Médico del Prado',
      tipo: 'Centro Medico',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Sector El Prado, Vía Carvajal, Valera',
      telefono: '0271-2318899',
    ),
    const CentroMedicoItem(
      id: 'base_valera_11',
      nombre: 'Cruz Roja Seccional Trujillo (Valera)',
      tipo: 'Ambulatorio',
      estado: 'Trujillo',
      ciudad: 'Valera',
      direccion: 'Av. Bolívar cruce con Calle 6, Valera',
      telefono: '0271-2213344',
    ),

    // --- CARACAS (DISTRITO CAPITAL) ---
    const CentroMedicoItem(
      id: 'base_ccs_1',
      nombre: 'Centro Médico de Caracas',
      tipo: 'Centro Medico',
      estado: 'Distrito Capital',
      ciudad: 'Caracas',
      direccion: 'Plaza del Panteón, San Bernardino, Caracas',
    ),
    const CentroMedicoItem(
      id: 'base_ccs_2',
      nombre: 'Clínica El Ávila',
      tipo: 'Clinica',
      estado: 'Distrito Capital',
      ciudad: 'Caracas',
      direccion: '6ta transversal de Altamira, Caracas',
    ),
    const CentroMedicoItem(
      id: 'base_ccs_3',
      nombre: 'Hospital Universitario de Caracas',
      tipo: 'Hospital',
      estado: 'Distrito Capital',
      ciudad: 'Caracas',
      direccion: 'Ciudad Universitaria de Caracas, Los Chaguaramos',
    ),

    // --- MARACAIBO (ZULIA) ---
    const CentroMedicoItem(
      id: 'base_mcbo_1',
      nombre: 'Centro Médico Paraíso',
      tipo: 'Centro Medico',
      estado: 'Zulia',
      ciudad: 'Maracaibo',
      direccion: 'Av. Universidad con Calle 70, Maracaibo',
    ),
    const CentroMedicoItem(
      id: 'base_mcbo_2',
      nombre: 'Hospital Universitario de Maracaibo',
      tipo: 'Hospital',
      estado: 'Zulia',
      ciudad: 'Maracaibo',
      direccion: 'Av. 16 Guajira, Maracaibo',
    ),

    // --- BARQUISIMETO (LARA) ---
    const CentroMedicoItem(
      id: 'base_bqto_1',
      nombre: 'Clínica Acosta Ortiz',
      tipo: 'Clinica',
      estado: 'Lara',
      ciudad: 'Barquisimeto',
      direccion: 'Carrera 19 con Calle 30, Barquisimeto',
    ),
    const CentroMedicoItem(
      id: 'base_bqto_2',
      nombre: 'Hospital Central Antonio María Pineda',
      tipo: 'Hospital',
      estado: 'Lara',
      ciudad: 'Barquisimeto',
      direccion: 'Av. Las Palmas con Av. Vargas, Barquisimeto',
    ),
  ];

  /// Tipos de centros de salud permitidos
  static const List<String> tiposDeCentro = [
    'Centro Médico',
    'Clínica',
    'Hospital',
    'Policlínica',
    'Ambulatorio / Unidad de Salud',
    'Otro Centro de Salud',
  ];

  /// Obtiene los centros médicos disponibles filtrados por estado y/o ciudad.
  /// Lee primero los registrados en Supabase (compartidos por todos los doctores)
  /// y los complementa con el catálogo base de referencia.
  static Future<List<CentroMedicoItem>> getCentrosMedicos({
    String? estado,
    String? ciudad,
  }) async {
    final List<CentroMedicoItem> resultados = [];
    final Set<String> nombresVistos = {};

    // 1. Intentar cargar desde Supabase
    try {
      final rows = await CentrosMedicosTable().queryRows(
        queryFn: (q) {
          var query = q;
          if (estado != null && estado.trim().isNotEmpty) {
            query = query.ilike('estado', '%${estado.trim()}%');
          }
          if (ciudad != null && ciudad.trim().isNotEmpty) {
            query = query.ilike('ciudad', '%${ciudad.trim()}%');
          }
          return query.order('nombre', ascending: true);
        },
      );

      for (final row in rows) {
        final item = CentroMedicoItem.fromRow(row);
        final clave = VenezuelaLocations.normalize('${item.nombre}_${item.ciudad}');
        if (!nombresVistos.contains(clave)) {
          nombresVistos.add(clave);
          resultados.add(item);
        }
      }
    } catch (e) {
      debugPrint('Nota: Consulta centros_medicos en Supabase (usando base local): $e');
    }

    // 2. Incorporar centros de base local que coincidan con el filtro
    final estadoNorm = estado != null ? VenezuelaLocations.normalize(estado) : '';
    final ciudadNorm = ciudad != null ? VenezuelaLocations.normalize(ciudad) : '';

    for (final baseItem in _catalogoBase) {
      final matchEstado = estadoNorm.isEmpty ||
          VenezuelaLocations.normalize(baseItem.estado).contains(estadoNorm);
      final matchCiudad = ciudadNorm.isEmpty ||
          VenezuelaLocations.normalize(baseItem.ciudad).contains(ciudadNorm);

      if (matchEstado && matchCiudad) {
        final clave = VenezuelaLocations.normalize('${baseItem.nombre}_${baseItem.ciudad}');
        if (!nombresVistos.contains(clave)) {
          nombresVistos.add(clave);
          resultados.add(baseItem);
        }
      }
    }

    return resultados;
  }

  /// Registra un nuevo centro médico en Supabase y lo deja disponible globalmente para todos los doctores.
  static Future<CentroMedicoItem?> registrarNuevoCentro({
    required String nombre,
    required String tipo,
    required String estado,
    required String ciudad,
    String? direccion,
    String? telefono,
    String? registradoPorDoctorId,
  }) async {
    try {
      final row = await CentrosMedicosTable().insert({
        'nombre': nombre.trim(),
        'tipo': tipo.trim(),
        'estado': estado.trim(),
        'ciudad': ciudad.trim(),
        'direccion': direccion?.trim(),
        'telefono': telefono?.trim(),
        'registrado_por_doctor_id': registradoPorDoctorId,
      });

      return CentroMedicoItem.fromRow(row);
    } catch (e) {
      debugPrint('Error registrando nuevo centro médico en Supabase: $e');
    }

    // Fallback local en memoria si la tabla de supabase estuviese offline
    final nuevoItem = CentroMedicoItem(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      nombre: nombre.trim(),
      tipo: tipo.trim(),
      estado: estado.trim(),
      ciudad: ciudad.trim(),
      direccion: direccion?.trim(),
      telefono: telefono?.trim(),
      esPersonalizado: true,
    );
    _catalogoBase.insert(0, nuevoItem);
    return nuevoItem;
  }
}
