import 'package:flutter/foundation.dart';
import '/backend/supabase/supabase.dart';
import 'i18n_service.dart';

/// Modelo de secretaria o usuario candidato disponible para ser seleccionado por el doctor.
class SecretaryCandidate {
  final String id;
  final String nombre;
  final String email;
  final String? fotoUrl;
  final String? telefono;
  final String rolActual;

  const SecretaryCandidate({
    required this.id,
    required this.nombre,
    required this.email,
    this.fotoUrl,
    this.telefono,
    this.rolActual = 'paciente',
  });
}

/// Modelo representativo de la vinculación entre un médico y una secretaria.
class SecretaryAssignment {
  final String linkId;
  final String idSecretaria;
  final String idDoctor;
  final String? idSede;
  final String? nombreSede;
  final String nombre;
  final String email;
  final String? telefono;
  final String? fotoUrl;
  final bool activo;
  final DateTime? vinculadaDesde;

  const SecretaryAssignment({
    required this.linkId,
    required this.idSecretaria,
    required this.idDoctor,
    this.idSede,
    this.nombreSede,
    required this.nombre,
    required this.email,
    this.telefono,
    this.fotoUrl,
    required this.activo,
    this.vinculadaDesde,
  });
}

/// Modelo de contexto de doctor para el panel de la secretaria.
class SecretaryDoctorContext {
  final UsuariosRow doctor;
  final String? idSedeAsignada;
  final String? nombreSedeAsignada;
  final bool activo;

  const SecretaryDoctorContext({
    required this.doctor,
    this.idSedeAsignada,
    this.nombreSedeAsignada,
    required this.activo,
  });
}

/// Servicio integral para gestionar la asignación, solicitudes y aprobación
/// de secretarias en relación con múltiples doctores y sedes.
class SecretaryManagementService {
  static final SecretaryManagementService _instance =
      SecretaryManagementService._internal();
  factory SecretaryManagementService() => _instance;
  SecretaryManagementService._internal();

  /// Busca usuarios registrados (con rol secretaria o paciente) por nombre, correo o cédula
  /// para que el doctor pueda asignarlos y darles permisos de secretaria.
  Future<List<SecretaryCandidate>> buscarSecretarias({
    required String idDoctor,
    String? query,
  }) async {
    try {
      final vinculosActivos = await SecretariaDoctoresTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', idDoctor).eq('activo', true),
      );
      final idsActivos = vinculosActivos
          .map((v) => v.idSecretaria)
          .whereType<String>()
          .toSet();

      final cleanQ = query?.trim().toLowerCase() ?? '';

      final users = await UsuariosTable().queryRows(
        queryFn: (q) => q.inFilter('rol', ['secretaria', 'paciente']).limit(100),
      );

      final candidatos = users.where((u) {
        if (u.id == idDoctor || idsActivos.contains(u.id)) return false;
        if (cleanQ.isEmpty) return true;
        final name = (u.nombre ?? '').toLowerCase();
        final email = (u.email ?? '').toLowerCase();
        final cedula = (u.cedula ?? '').toLowerCase();
        return name.contains(cleanQ) || email.contains(cleanQ) || cedula.contains(cleanQ);
      }).map((u) => SecretaryCandidate(
            id: u.id,
            nombre: (u.nombre != null && u.nombre!.trim().isNotEmpty)
                ? u.nombre!.trim()
                : (u.email ?? 'Usuario'),
            email: u.email ?? '',
            fotoUrl: u.fotoUrl,
            telefono: u.telefono,
            rolActual: (u.rol ?? 'paciente').toLowerCase(),
          )).toList();

      return candidatos;
    } catch (e) {
      debugPrint('Error buscando secretarias candidatas: $e');
      return [];
    }
  }

  /// Asigna o invita una secretaria seleccionada directamente por el médico.
  Future<SecretaryAssignment> invitarOAsignarSecretaria({
    required String idDoctor,
    required String email,
    required String idSede,
    String? idSecretaria,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final isEs = I18nService.instance.isSpanish;

    UsuariosRow? secretariaUser;
    if (idSecretaria != null && idSecretaria.isNotEmpty) {
      final rows = await UsuariosTable().queryRows(
        queryFn: (q) => q.eq('id', idSecretaria),
      );
      if (rows.isNotEmpty) secretariaUser = rows.first;
    }

    if (secretariaUser == null) {
      final usuariosExistentes = await UsuariosTable().queryRows(
        queryFn: (q) => q.eq('email', cleanEmail),
      );
      if (usuariosExistentes.isEmpty) {
        throw Exception(isEs
            ? 'No existe cuenta con el correo "$cleanEmail". La secretaria debe registrarse primero en Doctuario.'
            : 'No account with email "$cleanEmail". The secretary must first register in Doctuario.');
      }
      secretariaUser = usuariosExistentes.first;
    }

    if (secretariaUser.rol != 'secretaria') {
      try {
        await UsuariosTable().update(
          data: {'rol': 'secretaria'},
          matchingRows: (q) => q.eq('id', secretariaUser!.id),
        );
      } catch (_) {}
    }

    final vinculosExistentes = await SecretariaDoctoresTable().queryRows(
      queryFn: (q) => q
          .eq('id_doctor', idDoctor)
          .eq('id_secretaria', secretariaUser!.id),
    );

    SecretariaDoctoresRow linkRow;
    if (vinculosExistentes.isNotEmpty) {
      linkRow = vinculosExistentes.first;
      await SecretariaDoctoresTable().update(
        data: {'id_sede': idSede, 'activo': true},
        matchingRows: (q) => q.eq('id', linkRow.id),
      );
    } else {
      linkRow = await SecretariaDoctoresTable().insert({
        'id_doctor': idDoctor,
        'id_secretaria': secretariaUser.id,
        'id_sede': idSede,
        'activo': true,
      });
    }

    String? nombreSede;
    try {
      final sedeRows = await DoctorSedesTable().queryRows(
        queryFn: (q) => q.eq('id', idSede),
      );
      if (sedeRows.isNotEmpty) nombreSede = sedeRows.first.nombreSede;
    } catch (_) {}

    return SecretaryAssignment(
      linkId: linkRow.id,
      idSecretaria: secretariaUser.id,
      idDoctor: idDoctor,
      idSede: idSede,
      nombreSede: nombreSede,
      nombre: secretariaUser.nombre ?? cleanEmail,
      email: cleanEmail,
      telefono: secretariaUser.telefono,
      fotoUrl: secretariaUser.fotoUrl,
      activo: true,
      vinculadaDesde: linkRow.createdAt,
    );
  }

  /// Retorna la lista de secretarias vinculadas y activas de un médico.
  Future<List<SecretaryAssignment>> obtenerSecretariasDelDoctor(
    String idDoctor,
  ) async {
    return _obtenerVinculos(idDoctor: idDoctor, activo: true);
  }

  /// Retorna las solicitudes pendientes de secretarias que piden vincularse al médico.
  Future<List<SecretaryAssignment>> obtenerSolicitudesPendientesDelDoctor(
    String idDoctor,
  ) async {
    return _obtenerVinculos(idDoctor: idDoctor, activo: false);
  }

  Future<List<SecretaryAssignment>> _obtenerVinculos({
    required String idDoctor,
    required bool activo,
  }) async {
    try {
      final vinculos = await SecretariaDoctoresTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', idDoctor).eq('activo', activo),
      );
      if (vinculos.isEmpty) return [];

      final idsSecretarias = vinculos
          .map((v) => v.idSecretaria)
          .whereType<String>()
          .toSet()
          .toList();

      final idsSedes =
          vinculos.map((v) => v.idSede).whereType<String>().toSet().toList();

      final usuariosMap = <String, UsuariosRow>{};
      if (idsSecretarias.isNotEmpty) {
        final users = await UsuariosTable().queryRows(
          queryFn: (q) => q.inFilter('id', idsSecretarias),
        );
        for (final u in users) {
          usuariosMap[u.id] = u;
        }
      }

      final sedesMap = <String, DoctorSedesRow>{};
      if (idsSedes.isNotEmpty) {
        final sedes = await DoctorSedesTable().queryRows(
          queryFn: (q) => q.inFilter('id', idsSedes),
        );
        for (final s in sedes) {
          sedesMap[s.id] = s;
        }
      }

      return vinculos.map((v) {
        final secUser =
            v.idSecretaria != null ? usuariosMap[v.idSecretaria!] : null;
        final sede = v.idSede != null ? sedesMap[v.idSede!] : null;

        return SecretaryAssignment(
          linkId: v.id,
          idSecretaria: v.idSecretaria ?? '',
          idDoctor: idDoctor,
          idSede: v.idSede,
          nombreSede: sede?.nombreSede ?? 'Sin sede asignada',
          nombre: (secUser?.nombre != null && secUser!.nombre!.trim().isNotEmpty)
              ? secUser.nombre!.trim()
              : (secUser?.email ?? 'Secretaria'),
          email: secUser?.email ?? '',
          telefono: secUser?.telefono,
          fotoUrl: secUser?.fotoUrl,
          activo: v.activo ?? activo,
          vinculadaDesde: v.createdAt,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener vínculos de secretarias ($activo): $e');
      return [];
    }
  }

  /// Aprueba una solicitud de vinculación de secretaria asignándole una sede.
  Future<void> aprobarSolicitudSecretaria({
    required String linkId,
    required String idSede,
  }) async {
    await SecretariaDoctoresTable().update(
      data: {'activo': true, 'id_sede': idSede},
      matchingRows: (q) => q.eq('id', linkId),
    );
  }

  /// Rechaza y elimina la solicitud de vinculación de una secretaria.
  Future<void> rechazarSolicitudSecretaria(String linkId) async {
    await SecretariaDoctoresTable().delete(
      matchingRows: (q) => q.eq('id', linkId),
    );
  }

  /// Desvincula y remueve definitivamente a una secretaria del doctor.
  Future<void> desvincularSecretaria({
    required String idDoctor,
    required String idSecretaria,
  }) async {
    await SecretariaDoctoresTable().delete(
      matchingRows: (q) => q
          .eq('id_doctor', idDoctor)
          .eq('id_secretaria', idSecretaria),
    );
  }

  /// Actualiza la sede asignada a una secretaria para este doctor.
  Future<void> actualizarSedeSecretaria({
    required String idDoctor,
    required String idSecretaria,
    required String nuevaSedeId,
  }) async {
    await SecretariaDoctoresTable().update(
      data: {'id_sede': nuevaSedeId},
      matchingRows: (q) => q
          .eq('id_doctor', idDoctor)
          .eq('id_secretaria', idSecretaria),
    );
  }

  /// Obtiene los doctores activos para los cuales trabaja una secretaria.
  Future<List<SecretaryDoctorContext>> obtenerDoctoresDeSecretaria(
    String idSecretaria,
  ) async {
    try {
      final vinculos = await SecretariaDoctoresTable().queryRows(
        queryFn: (q) => q.eq('id_secretaria', idSecretaria).eq('activo', true),
      );
      if (vinculos.isEmpty) return [];

      final idsDoctores = vinculos
          .map((v) => v.idDoctor)
          .whereType<String>()
          .toSet()
          .toList();
      final idsSedes =
          vinculos.map((v) => v.idSede).whereType<String>().toSet().toList();

      final doctoresMap = <String, UsuariosRow>{};
      if (idsDoctores.isNotEmpty) {
        final docs = await UsuariosTable().queryRows(
          queryFn: (q) => q.inFilter('id', idsDoctores),
        );
        for (final d in docs) {
          doctoresMap[d.id] = d;
        }
      }

      final sedesMap = <String, DoctorSedesRow>{};
      if (idsSedes.isNotEmpty) {
        final sedes = await DoctorSedesTable().queryRows(
          queryFn: (q) => q.inFilter('id', idsSedes),
        );
        for (final s in sedes) {
          sedesMap[s.id] = s;
        }
      }

      return vinculos
          .where((v) => v.idDoctor != null && doctoresMap.containsKey(v.idDoctor))
          .map((v) {
        final doctor = doctoresMap[v.idDoctor!]!;
        final sede = v.idSede != null ? sedesMap[v.idSede!] : null;

        return SecretaryDoctorContext(
          doctor: doctor,
          idSedeAsignada: v.idSede,
          nombreSedeAsignada: sede?.nombreSede,
          activo: v.activo ?? true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener doctores de la secretaria: $e');
      return [];
    }
  }

  /// Permite a una secretaria solicitar vinculación a un doctor (queda pendiente: activo=false).
  Future<void> vincularSecretariaConDoctorPorEmail({
    required String idSecretaria,
    required String emailDoctor,
  }) async {
    final cleanEmail = emailDoctor.trim().toLowerCase();
    final isEs = I18nService.instance.isSpanish;
    final docs = await UsuariosTable().queryRows(
      queryFn: (q) => q.eq('email', cleanEmail).inFilter('rol', ['doctor', 'Doctor']),
    );
    if (docs.isEmpty) {
      throw Exception(isEs
          ? 'No se encontró ningún médico registrado con el correo "$cleanEmail".'
          : 'No doctor found with email "$cleanEmail".');
    }
    final doc = docs.first;
    try {
      final vinculos = await SecretariaDoctoresTable().queryRows(
        queryFn: (q) => q.eq('id_doctor', doc.id).eq('id_secretaria', idSecretaria),
      );
      if (vinculos.isNotEmpty) {
        if (vinculos.first.activo == true) {
          throw Exception(isEs
              ? 'Ya estás vinculada activamente con este médico.'
              : 'You are already actively linked with this doctor.');
        }
        await SecretariaDoctoresTable().update(
          data: {'activo': false},
          matchingRows: (q) => q.eq('id', vinculos.first.id),
        );
      } else {
        await SecretariaDoctoresTable().insert({
          'id_doctor': doc.id,
          'id_secretaria': idSecretaria,
          'activo': false,
        });
      }
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('row-level security') || err.contains('42501')) {
        throw Exception(isEs
            ? 'Error de permisos RLS en Supabase: La tabla "secretaria_doctores" requiere aplicar las políticas de seguridad para que la secretaria pueda enviar solicitudes. Por favor ejecuta el script SQL de RLS en Supabase, o pide a tu médico que te vincule desde su panel de Secretarias.'
            : 'RLS permission error in Supabase: Table "secretaria_doctores" requires applying security policies for secretaries. Please run the RLS SQL script in Supabase or have your doctor link you directly.');
      }
      rethrow;
    }
  }
}
