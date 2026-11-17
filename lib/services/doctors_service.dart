import 'package:flutter/foundation.dart';
import '/backend/supabase/supabase.dart';
import '/services/venezuela_locations.dart';

class DoctorItem {
  final String id;
  final String rawName;
  final String name; // e.g. "Doctor Carlos Silva" or "Doctora Gabriela Mendoza"
  final String title; // "Doctor" or "Doctora" (also accessible as "Dr." / "Dra.")
  final String gender; // "Masculino" or "Femenino"
  final String specialty;
  final String? photoUrl;
  final String? biography;
  final double? consultationFee;
  final String? city;
  final String? clinics;
  final String? phone;
  final String? email;

  DoctorItem({
    required this.id,
    required this.rawName,
    required this.name,
    required this.title,
    required this.gender,
    required this.specialty,
    this.photoUrl,
    this.biography,
    this.consultationFee,
    this.city,
    this.clinics,
    this.phone,
    this.email,
  });

  /// Determina si un nombre/género corresponde a Femenino o Masculino
  static bool isFemaleDoctor(String? genderValue, String rawName) {
    if (genderValue != null && genderValue.isNotEmpty) {
      final g = VenezuelaLocations.normalize(genderValue);
      if (g.startsWith('fem') || g.startsWith('muj') || g == 'female' || g == 'f') {
        return true;
      }
      if (g.startsWith('masc') || g.startsWith('hom') || g == 'male' || g == 'm') {
        return false;
      }
    }

    final lower = VenezuelaLocations.normalize(rawName.trim());
    if (lower.startsWith('dra.') || lower.startsWith('doctora')) return true;
    if (lower.startsWith('dr.') || lower.startsWith('doctor')) return false;

    // Heurística de nombres femeninos comunes
    final firstName = lower.split(RegExp(r'[\s_.-]+')).first;
    const femaleNames = {
      'maria', 'maría', 'carmen', 'ana', 'gabriela', 'valentina', 'daniela',
      'sofia', 'sofía', 'laura', 'andrea', 'mariana', 'isabella', 'camila',
      'paula', 'natalia', 'elena', 'meera', 'rosa', 'patricia', 'claudia',
      'adriana', 'alejandra', 'lucia', 'carolina', 'diana', 'vanessa', 'veronica',
      'mariangel', 'genesis', 'stephanie', 'barbara', 'victoria', 'luisa', 'gloria',
      'teresa', 'beatriz', 'isabel', 'mercedes', 'raquel', 'margarita', 'monica',
      'silvia', 'yusmary', 'nayarith', 'coromoto', 'leydis', 'karina', 'susana',
      'michell', 'michelle'
    };

    if (femaleNames.contains(firstName)) return true;
    if (firstName.endsWith('a') &&
        !firstName.endsWith('ma') &&
        firstName != 'luca' &&
        firstName != 'josua' &&
        firstName != 'sasha') {
      return true;
    }
    return false;
  }

  factory DoctorItem.fromMap(Map<String, dynamic> docMap, Map<String, dynamic>? userMap) {
    final docId = docMap['id']?.toString() ?? userMap?['id']?.toString() ?? '';
    final String raw = (userMap?['nombre']?.toString() ??
            docMap['nombre']?.toString() ??
            userMap?['email']?.toString().split('@').first ??
            'Especialista').trim();
    final genderVal = userMap?['genero']?.toString() ?? docMap['genero']?.toString();

    final isFemale = isFemaleDoctor(genderVal, raw);
    final title = isFemale ? 'Doctora' : 'Doctor';
    final gender = isFemale ? 'Femenino' : 'Masculino';

    // Limpiar prefijos existentes para evitar duplicados como "Doctor Doctor Carlos"
    var cleanName = raw.replaceFirst(
      RegExp(r'^(dr\.|dra\.|doctor|doctora)\s+', caseSensitive: false),
      '',
    ).trim();
    if (cleanName.isEmpty) cleanName = 'Especialista';

    final formattedName = '$title $cleanName';
    final specialty = (docMap['especialidad']?.toString() ??
            userMap?['doctor_referencia_nombre']?.toString() ??
            userMap?['especialidad']?.toString() ??
            'Medicina General')
        .trim();
    final photo = userMap?['foto_url']?.toString() ?? docMap['foto_url']?.toString();
    final bio = docMap['biografia']?.toString();
    final fee = docMap['costo_consulta'] != null ? (docMap['costo_consulta'] as num).toDouble() : null;
    final city = userMap?['ciudad_origen']?.toString() ??
        docMap['clinicas_referencia']?.toString() ??
        'Venezuela';
    final clinics = docMap['clinicas_referencia']?.toString() ?? 'Consultorio Médico';
    final phone = userMap?['telefono']?.toString();
    final email = userMap?['email']?.toString();

    return DoctorItem(
      id: docId,
      rawName: cleanName,
      name: formattedName,
      title: title,
      gender: gender,
      specialty: specialty.isNotEmpty ? specialty : 'Medicina General',
      photoUrl: photo,
      biography: bio,
      consultationFee: fee,
      city: city,
      clinics: clinics,
      phone: phone,
      email: email,
    );
  }
}

class DoctorsService {
  static final DoctorsService instance = DoctorsService._internal();
  DoctorsService._internal();

  /// Consulta EXCLUSIVAMENTE los doctores reales registrados en la base de datos de Supabase.
  /// No incluye ninguna plantilla o doctor falso. Si no hay registros, retorna una lista vacía.
  Future<List<DoctorItem>> getDoctors({
    String? filterCity,
    String? filterSpecialty,
    int? limit,
    String? excludeDoctorId,
    bool excludeCurrentDoctor = true,
    bool onlyApproved = true,
    bool onlyCatalogVisible = true,
  }) async {
    try {
      final Map<String, Map<String, dynamic>> userMap = {};
      final Map<String, Map<String, dynamic>> docMap = {};

      // 1. Obtener todos los usuarios con rol de Doctor desde la tabla 'usuarios'
      try {
        final List<dynamic> doctorUsers = await SupaFlow.client
            .from('usuarios')
            .select('*')
            .or('rol.ilike.%doctor%,rol.ilike.%Doctor%,rol.eq.doctor,rol.eq.Doctor,rol.ilike.%medico%,rol.ilike.%Médico%');
        for (var u in doctorUsers) {
          if (u['id'] != null) {
            userMap[u['id'].toString()] = Map<String, dynamic>.from(u);
          }
        }
      } catch (e) {
        debugPrint('Aviso: Error al consultar usuarios con rol doctor: $e');
      }

      // 2. Obtener todos los registros desde la tabla 'doctores'
      try {
        final List<dynamic> docRecords = await SupaFlow.client
            .from('doctores')
            .select('*');
        for (var d in docRecords) {
          if (d['id'] != null) {
            docMap[d['id'].toString()] = Map<String, dynamic>.from(d);
          }
        }
      } catch (e) {
        debugPrint('Aviso: Error al consultar tabla doctores: $e');
      }

      // 3. Completar datos faltantes para IDs que estén en doctores pero no en userMap
      final missingUserIds = docMap.keys.where((id) => !userMap.containsKey(id)).toList();
      if (missingUserIds.isNotEmpty) {
        try {
          final List<dynamic> moreUsers = await SupaFlow.client
              .from('usuarios')
              .select('*')
              .inFilter('id', missingUserIds);
          for (var u in moreUsers) {
            if (u['id'] != null) {
              userMap[u['id'].toString()] = Map<String, dynamic>.from(u);
            }
          }
        } catch (e) {
          debugPrint('Aviso: Error al consultar usuarios por ID de doctores: $e');
        }
      }

      // 4. Completar datos de doctores para IDs que estén en userMap pero no en docMap
      final missingDocIds = userMap.keys.where((id) => !docMap.containsKey(id)).toList();
      if (missingDocIds.isNotEmpty) {
        try {
          final List<dynamic> moreDocs = await SupaFlow.client
              .from('doctores')
              .select('*')
              .inFilter('id', missingDocIds);
          for (var d in moreDocs) {
            if (d['id'] != null) {
              docMap[d['id'].toString()] = Map<String, dynamic>.from(d);
            }
          }
        } catch (e) {
          debugPrint('Aviso: Error al consultar doctores por ID de usuario: $e');
        }
      }

      // 5. Identificar todos los IDs únicos de médicos
      final Set<String> allDoctorIds = {
        ...userMap.keys,
        ...docMap.keys,
      };

      List<DoctorItem> doctors = [];
      for (var id in allDoctorIds) {
        final u = userMap[id];
        final d = docMap[id] ?? <String, dynamic>{};
        if (u != null || d.isNotEmpty) {
          if (onlyApproved) {
            final st = (d['estado_verificacion']?.toString() ?? '').toLowerCase().trim();
            final isSuspended = u?['suspendido'] == true || st == 'suspendido';
            final isApproved = d['esta_aprobado'] == true || st == 'aprobado' || st == 'activo';
            if (isSuspended || !isApproved) continue;
          }
          if (onlyCatalogVisible && d['visible_en_catalogo'] == false) {
            continue;
          }
          doctors.add(DoctorItem.fromMap(d, u));
        }
      }

      // 6. Excluir al doctor actual si está especificado (solo no se puede aparecer a sí mismo en su vista de doctor)
      final effectiveExcludeId = excludeDoctorId ??
          (excludeCurrentDoctor ? SupaFlow.client.auth.currentUser?.id : null);
      if (effectiveExcludeId != null && effectiveExcludeId.isNotEmpty) {
        doctors.removeWhere((doc) => doc.id == effectiveExcludeId);
      }

      // Si no hay doctores registrados en la base de datos, retornar lista vacía
      if (doctors.isEmpty) {
        return [];
      }

      // 7. Filtrar por especialidad si fue especificada
      if (filterSpecialty != null &&
          filterSpecialty.isNotEmpty &&
          !filterSpecialty.toLowerCase().contains('todas')) {
        final specNorm = VenezuelaLocations.normalize(filterSpecialty);
        doctors = doctors
            .where((doc) => VenezuelaLocations.normalize(doc.specialty).contains(specNorm))
            .toList();
      }

      // 8. Priorizar por ciudad si fue especificada
      if (filterCity != null &&
          filterCity.isNotEmpty &&
          !filterCity.toLowerCase().contains('todas')) {
        final cityQuery = VenezuelaLocations.normalize(filterCity.split(',').first.trim());

        final sameCityDoctors = doctors.where((doc) {
          if (doc.city == null) return false;
          return VenezuelaLocations.normalize(doc.city!).contains(cityQuery);
        }).toList();

        final otherCityDoctors = doctors.where((doc) {
          if (doc.city == null) return true;
          return !VenezuelaLocations.normalize(doc.city!).contains(cityQuery);
        }).toList();

        doctors = [...sameCityDoctors, ...otherCityDoctors];
      }

      if (limit != null && limit > 0) {
        return doctors.take(limit).toList();
      }

      return doctors;
    } catch (e) {
      debugPrint('Error en DoctorsService al consultar doctores reales en BD: $e');
      return [];
    }
  }
}
