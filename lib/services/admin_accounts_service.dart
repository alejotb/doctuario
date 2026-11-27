import 'package:flutter/foundation.dart';
import '/backend/supabase/supabase.dart';

/// Modelo detallado de una cuenta de usuario o doctor para el administrador.
class AdminAccountItem {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String rol;
  final String? fotoUrl;
  final DateTime createdAt;
  final String? cedula;
  final String? especialidad;
  final String? estadoVerificacion;
  final bool estaAprobado;
  final bool? tenantActivo;
  final String? tenantDbUrl;
  final String? tenantDbAnonKey;
  final String estadoPago;
  final bool estaSuspendido;

  AdminAccountItem({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.rol,
    this.fotoUrl,
    required this.createdAt,
    this.cedula,
    this.especialidad,
    this.estadoVerificacion,
    this.estaAprobado = false,
    this.tenantActivo,
    this.tenantDbUrl,
    this.tenantDbAnonKey,
    this.estadoPago = 'al_dia',
    required this.estaSuspendido,
  });

  bool get esDoctor => rol.toLowerCase() == 'doctor' || especialidad != null;
  bool get esSoloLectura => estadoPago.toLowerCase() == 'solo_lectura';
  bool get esAdmin => rol.toLowerCase() == 'admin' || rol.toLowerCase() == 'administrador';
  bool get esSecretaria => rol.toLowerCase() == 'secretaria';
  bool get esPaciente => !esDoctor && !esAdmin && !esSecretaria;
}

/// Métricas y estadísticas de uso de la plataforma.
class AdminPlatformStats {
  final int totalUsuarios;
  final int totalPacientes;
  final int totalDoctores;
  final int doctoresAprobados;
  final int doctoresPendientes;
  final int doctoresSuspendidos;
  final int totalAdmins;
  final int tenantsActivos;
  final int totalGruposMedicos;
  final int totalSecretarias;

  AdminPlatformStats({
    required this.totalUsuarios,
    required this.totalPacientes,
    required this.totalDoctores,
    required this.doctoresAprobados,
    required this.doctoresPendientes,
    required this.doctoresSuspendidos,
    required this.totalAdmins,
    required this.tenantsActivos,
    this.totalGruposMedicos = 0,
    this.totalSecretarias = 0,
  });

  factory AdminPlatformStats.vacio() {
    return AdminPlatformStats(
      totalUsuarios: 0,
      totalPacientes: 0,
      totalDoctores: 0,
      doctoresAprobados: 0,
      doctoresPendientes: 0,
      doctoresSuspendidos: 0,
      totalAdmins: 0,
      tenantsActivos: 0,
      totalGruposMedicos: 0,
      totalSecretarias: 0,
    );
  }
}

/// Servicio que centraliza las operaciones del administrador sobre las cuentas de usuario y estadísticas.
class AdminAccountsService {
  AdminAccountsService._();
  static final AdminAccountsService instance = AdminAccountsService._();

  final DualDatabaseConfig _dualConfig = DualDatabaseConfig.instance;

  /// Obtiene métricas agregadas de usuarios, pacientes, doctores y consultorios.
  Future<AdminPlatformStats> obtenerEstadisticas() async {
    try {
      final client = _dualConfig.patientClient;

      final usersRes = await client.from('usuarios').select('id, rol');
      final docsRes = await client.from('doctores').select('id, esta_aprobado, estado_verificacion');
      final tenantsRes = await client.from('doctores_tenants').select('id_doctor, activo');

      List centrosList = [];
      try {
        final centrosRes = await client.from('centros_medicos').select('id');
        centrosList = (centrosRes as List?) ?? [];
      } catch (_) {}

      final usersList = (usersRes as List?) ?? [];
      final docsList = (docsRes as List?) ?? [];
      final tenantsList = (tenantsRes as List?) ?? [];

      int totalUsuarios = usersList.length;
      int totalPacientes = 0;
      int totalAdmins = 0;
      int totalSecretarias = 0;
      final doctorUserIds = <String>{};

      for (final u in usersList) {
        final id = u['id']?.toString() ?? '';
        final rol = (u['rol']?.toString() ?? '').toLowerCase().trim();
        if (rol == 'admin' || rol == 'administrador') {
          totalAdmins++;
        } else if (rol == 'doctor') {
          if (id.isNotEmpty) doctorUserIds.add(id);
        } else if (rol == 'secretaria') {
          totalSecretarias++;
        } else if (rol != 'suspendido') {
          totalPacientes++;
        }
      }

      final docStatusMap = <String, String>{};
      for (final d in docsList) {
        final id = d['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          doctorUserIds.add(id);
          final rawSt = (d['estado_verificacion']?.toString() ?? '').toLowerCase().trim();
          final bool? estaAprobadoRaw = d['esta_aprobado'] as bool?;
          final bool isAprobado = estaAprobadoRaw ?? (rawSt == 'aprobado' || rawSt == 'activo');
          docStatusMap[id] = isAprobado ? 'aprobado' : (rawSt.isNotEmpty ? rawSt : 'pendiente');
        }
      }

      int tenantsActivos = 0;
      for (final t in tenantsList) {
        if (t['activo'] == true) {
          tenantsActivos++;
        }
      }

      int totalDoctores = doctorUserIds.length;
      int doctoresAprobados = 0;
      int doctoresPendientes = 0;
      int doctoresSuspendidos = 0;

      for (final id in doctorUserIds) {
        final st = docStatusMap[id] ?? 'pendiente';
        if (st == 'aprobado') {
          doctoresAprobados++;
        } else if (st == 'suspendido') {
          doctoresSuspendidos++;
        } else {
          doctoresPendientes++;
        }
      }

      final totalGrupos = centrosList.isNotEmpty ? centrosList.length : tenantsActivos;

      return AdminPlatformStats(
        totalUsuarios: totalUsuarios,
        totalPacientes: totalPacientes,
        totalDoctores: totalDoctores,
        doctoresAprobados: doctoresAprobados,
        doctoresPendientes: doctoresPendientes,
        doctoresSuspendidos: doctoresSuspendidos,
        totalAdmins: totalAdmins,
        tenantsActivos: tenantsActivos,
        totalGruposMedicos: totalGrupos,
        totalSecretarias: totalSecretarias,
      );
    } catch (e) {
      debugPrint('AdminAccountsService: Error obteniendo estadísticas: $e');
      return AdminPlatformStats.vacio();
    }
  }

  /// Lista y combina las cuentas con sus detalles médicos y de tenant.
  Future<List<AdminAccountItem>> listarCuentas() async {
    final List<AdminAccountItem> cuentas = [];
    try {
      final client = _dualConfig.patientClient;

      final usersRes = await client.from('usuarios').select().order('created_at', ascending: false);
      final docsRes = await client.from('doctores').select();
      final tenantsRes = await client.from('doctores_tenants').select();

      final docsMap = <String, Map<String, dynamic>>{};
      for (final d in (docsRes as List? ?? [])) {
        final id = d['id']?.toString() ?? '';
        if (id.isNotEmpty) docsMap[id] = Map<String, dynamic>.from(d);
      }

      final tenantsMap = <String, Map<String, dynamic>>{};
      for (final t in (tenantsRes as List? ?? [])) {
        final id = t['id_doctor']?.toString() ?? '';
        if (id.isNotEmpty) tenantsMap[id] = Map<String, dynamic>.from(t);
      }

      for (final u in (usersRes as List? ?? [])) {
        final id = u['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        final rol = (u['rol']?.toString() ?? 'paciente').trim();
        final doc = docsMap[id];
        final tenant = tenantsMap[id];

        final String? rawEstadoVerif = doc?['estado_verificacion']?.toString();
        final bool? estaAprobadoRaw = doc?['esta_aprobado'] as bool?;
        final isTenantActive = tenant?['activo'] as bool?;
        final estadoPago = tenant?['estado_pago']?.toString() ?? 'al_dia';

        final bool isDocApproved = estaAprobadoRaw ??
            ((rawEstadoVerif?.toLowerCase() == 'aprobado') || (rawEstadoVerif?.toLowerCase() == 'activo'));

        final estaSuspendido = rol.toLowerCase() == 'suspendido' ||
            rawEstadoVerif?.toLowerCase() == 'suspendido' ||
            (tenant != null && isTenantActive == false);

        cuentas.add(AdminAccountItem(
          id: id,
          nombre: u['nombre']?.toString() ?? 'Sin nombre',
          email: u['email']?.toString() ?? '',
          telefono: u['telefono']?.toString() ?? '',
          rol: rol,
          fotoUrl: u['foto_url']?.toString(),
          createdAt: DateTime.tryParse(u['created_at']?.toString() ?? '') ?? DateTime.now(),
          cedula: u['cedula']?.toString(),
          especialidad: doc?['especialidad']?.toString(),
          estadoVerificacion: isDocApproved ? 'aprobado' : (rawEstadoVerif ?? 'pendiente'),
          estaAprobado: isDocApproved,
          tenantActivo: isTenantActive ?? isDocApproved,
          tenantDbUrl: null,
          tenantDbAnonKey: null,
          estadoPago: estadoPago,
          estaSuspendido: estaSuspendido,
        ));
      }
    } catch (e) {
      debugPrint('AdminAccountsService: Error listando cuentas: $e');
    }
    return cuentas;
  }

  /// Suspende o reactiva una cuenta de usuario o doctor.
  Future<bool> alternarSuspension({
    required String idUsuario,
    required String rolActual,
    required bool suspender,
  }) async {
    try {
      final client = _dualConfig.patientClient;

      if (rolActual.toLowerCase() == 'doctor') {
        final nuevoEstadoDoc = suspender ? 'suspendido' : 'aprobado';
        await client.from('doctores').update({
          'estado_verificacion': nuevoEstadoDoc,
          'esta_aprobado': !suspender,
        }).eq('id', idUsuario);

        await client.from('doctores_tenants').update({
          'activo': !suspender,
        }).eq('id_doctor', idUsuario);
      }

      final nuevoRolUser = suspender
          ? 'suspendido'
          : (rolActual.toLowerCase() == 'suspendido' ? 'paciente' : rolActual);

      await client.from('usuarios').update({
        'rol': nuevoRolUser,
      }).eq('id', idUsuario);

      debugPrint('AdminAccountsService: Cuenta $idUsuario suspendida=$suspender exitosamente.');
      return true;
    } catch (e) {
      debugPrint('AdminAccountsService: Error al alternar suspensión: $e');
      return false;
    }
  }

  /// Cambia el rol de un usuario de forma segura.
  Future<bool> cambiarRol({
    required String idUsuario,
    required String nuevoRol,
  }) async {
    try {
      final client = _dualConfig.patientClient;
      await client.from('usuarios').update({
        'rol': nuevoRol,
      }).eq('id', idUsuario);

      if (nuevoRol.toLowerCase() == 'doctor') {
        await client.from('doctores').upsert({
          'id': idUsuario,
          'estado_verificacion': 'pendiente',
          'esta_aprobado': false,
        });
      }

      return true;
    } catch (e) {
      debugPrint('AdminAccountsService: Error cambiando rol: $e');
      return false;
    }
  }

  /// Cancela o elimina una cuenta de la base de datos central.
  Future<bool> eliminarCuenta({
    required String idUsuario,
    required bool esDoctor,
  }) async {
    try {
      final client = _dualConfig.patientClient;

      if (esDoctor) {
        await client.from('doctores_tenants').delete().eq('id_doctor', idUsuario);
        await client.from('doctores').delete().eq('id', idUsuario);
      }

      await client.from('usuarios').delete().eq('id', idUsuario);
      debugPrint('AdminAccountsService: Cuenta $idUsuario eliminada exitosamente.');
      return true;
    } catch (e) {
      debugPrint('AdminAccountsService: Error eliminando cuenta: $e');
      return false;
    }
  }

  /// Cambia el estado de pago y contingencia de un doctor ('al_dia' o 'solo_lectura').
  Future<bool> cambiarEstadoPago({
    required String idDoctor,
    required String nuevoEstadoPago,
  }) async {
    try {
      final client = _dualConfig.patientClient;
      final esSoloLectura = nuevoEstadoPago.toLowerCase() == 'solo_lectura';

      await client.from('doctores_tenants').update({
        'estado_pago': nuevoEstadoPago,
      }).eq('id_doctor', idDoctor);

      // Si pasa a solo lectura, se desactiva su recepción de nuevas reservas en catálogo público
      await client.from('doctores').update({
        'esta_aprobado': !esSoloLectura,
      }).eq('id', idDoctor);

      debugPrint('AdminAccountsService: Doctor $idDoctor estado de pago actualizado a $nuevoEstadoPago.');
      return true;
    } catch (e) {
      debugPrint('AdminAccountsService: Error cambiando estado de pago: $e');
      return false;
    }
  }
}
