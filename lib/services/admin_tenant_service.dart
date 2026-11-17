import 'package:flutter/foundation.dart';
import '/backend/supabase/supabase.dart';
import 'doctor_database_provisioner.dart';
import 'security_vault_service.dart';

/// Modelo de datos para representar una solicitud de aprobación de un doctor.
class DoctorPendingRequest {
  final String idDoctor;
  final String nombre;
  final String email;
  final String telefono;
  final String especialidad;
  final String estado;
  final DateTime createdAt;
  final String? dbUrl;
  final String? dbAnonKey;
  final bool estaAprobado;
  final bool tenantActivo;
  final String? credencialRecuperacionEnc;
  final String plan;
  final double precioMensual;
  final String estadoPago;
  final bool modoSoloLectura;
  final String intervaloPago;
  final int limiteDoctores;

  DoctorPendingRequest({
    required this.idDoctor,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.especialidad,
    required this.estado,
    required this.createdAt,
    this.dbUrl,
    this.dbAnonKey,
    this.estaAprobado = false,
    this.tenantActivo = false,
    this.credencialRecuperacionEnc,
    this.plan = 'fundador',
    this.precioMensual = 35.0,
    this.estadoPago = 'al_dia',
    this.modoSoloLectura = false,
    this.intervaloPago = 'mensual',
    this.limiteDoctores = 1,
  });

  /// Determina si el doctor ya cuenta con su consultorio o cuenta aprobada y activa.
  bool get isAprobado =>
      estaAprobado ||
      tenantActivo ||
      estado.toLowerCase() == 'aprobado' ||
      estado.toLowerCase() == 'activo';

  factory DoctorPendingRequest.fromMap(Map<String, dynamic> map) {
    final bool estaAprobado = map['esta_aprobado'] == true || map['activo'] == true;
    final bool tenantActivo = map['tenant_activo'] == true;
    final String estadoVerif = map['estado_verificacion']?.toString() ??
        map['estado']?.toString() ??
        (estaAprobado ? 'aprobado' : 'pendiente');
    final String rawPlan = map['plan']?.toString().toLowerCase().trim() ?? 'fundador';
    final double precio = double.tryParse(map['precio_mensual']?.toString() ?? '') ??
        (rawPlan == 'individual' ? 50.0 : (rawPlan == 'duo' ? 70.0 : (rawPlan == 'grupo' ? 160.0 : (rawPlan == 'clinica' ? 280.0 : 35.0))));

    return DoctorPendingRequest(
      idDoctor: map['id']?.toString() ?? map['id_doctor']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? 'Sin nombre',
      email: map['email']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
      especialidad: map['especialidad']?.toString() ?? 'Medicina General',
      estado: estadoVerif,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dbUrl: map['db_url']?.toString(),
      dbAnonKey: map['db_anon_key']?.toString(),
      estaAprobado: estaAprobado,
      tenantActivo: tenantActivo,
      credencialRecuperacionEnc: map['credencial_recuperacion_enc']?.toString() ?? map['credencial_recuperacion']?.toString(),
      plan: rawPlan,
      precioMensual: precio,
      estadoPago: map['estado_pago']?.toString() ?? 'al_dia',
      modoSoloLectura: map['modo_solo_lectura'] == true,
      intervaloPago: map['intervalo_pago']?.toString() ?? 'mensual',
      limiteDoctores: int.tryParse(map['limite_doctores']?.toString() ?? '') ?? 1,
    );
  }
}

/// Servicio administrativo para la gestión de tenants de doctores en la Base Central.
class AdminTenantService {
  AdminTenantService._();

  static AdminTenantService? _instance;
  static AdminTenantService get instance => _instance ??= AdminTenantService._();

  final _dualConfig = DualDatabaseConfig.instance;

  /// Retorna si el usuario actual tiene privilegios de administrador.
  bool esUsuarioAdmin(String? userRole, String? email) {
    final r = (userRole ?? '').toLowerCase().trim();
    if (r == 'admin' || r == 'administrador') return true;
    return false;
  }

  /// Obtiene el conteo de doctores que están pendientes de activación.
  Future<int> obtenerConteoPendientes() async {
    try {
      final items = await listarSolicitudesDoctores(soloPendientes: true);
      return items.length;
    } catch (e) {
      debugPrint('AdminTenantService: Error contando pendientes: $e');
      return 0;
    }
  }

  /// Lista todas las solicitudes de doctores (pendientes y aprobadas).
  Future<List<DoctorPendingRequest>> listarSolicitudesDoctores({bool soloPendientes = true}) async {
    final client = _dualConfig.patientClient;
    final List<DoctorPendingRequest> solicitudes = [];

    try {
      // 1. Obtener registros de doctores de la base central
      final Map<String, Map<String, dynamic>> doctorRecords = {};
      try {
        final List<dynamic> docRows = await client
            .from('doctores')
            .select()
            .order('created_at', ascending: false);
        for (final d in docRows) {
          final idDoc = d['id']?.toString() ?? '';
          if (idDoc.isNotEmpty) {
            doctorRecords[idDoc] = Map<String, dynamic>.from(d as Map);
          }
        }
      } catch (e) {
        debugPrint('AdminTenantService: Consulta doctores en base central: $e');
      }

      // 2. Obtener datos y estado de planes en doctores_tenants
      final Map<String, Map<String, dynamic>> tenantsMap = {};
      try {
        final List<dynamic> tenantRows = await client.from('doctores_tenants').select();
        for (final t in tenantRows) {
          final idDoc = t['id_doctor']?.toString() ?? '';
          if (idDoc.isNotEmpty) tenantsMap[idDoc] = Map<String, dynamic>.from(t as Map);
        }
      } catch (_) {
        try {
          final List<dynamic> fb = await client.from('doctores_tenants').select('id_doctor, plan, activo, estado_pago, modo_solo_lectura');
          for (final t in fb) {
            final idDoc = t['id_doctor']?.toString() ?? '';
            if (idDoc.isNotEmpty) tenantsMap[idDoc] = Map<String, dynamic>.from(t as Map);
          }
        } catch (_) {}
      }

      // 3. Obtener usuarios registrados como 'doctor' en la base central
      final Set<String> allDoctorIds = {};
      final Map<String, Map<String, dynamic>> userMap = {};
      try {
        final List<dynamic> userDocs = await client
            .from('usuarios')
            .select('id, nombre, email, telefono, rol, created_at');
        for (final u in userDocs) {
          final idU = u['id']?.toString() ?? '';
          if (idU.isEmpty) continue;
          userMap[idU] = Map<String, dynamic>.from(u as Map);
          if ((u['rol']?.toString().toLowerCase().trim() ?? '') == 'doctor') {
            allDoctorIds.add(idU);
          }
        }
      } catch (_) {}

      // Incluir registros de doctores o planes que correspondan a un usuario válido
      for (final idDoc in doctorRecords.keys) {
        if (userMap.containsKey(idDoc)) {
          allDoctorIds.add(idDoc);
        }
      }
      for (final idDoc in tenantsMap.keys) {
        if (userMap.containsKey(idDoc)) {
          allDoctorIds.add(idDoc);
        }
      }

      // 4. Construir la lista consolidada evaluando estado activo y aprobación
      for (final idDoc in allDoctorIds) {
        final doc = doctorRecords[idDoc];
        final user = userMap[idDoc];
        final tenant = tenantsMap[idDoc];

        final rawEstado = (doc?['estado_verificacion']?.toString() ?? '').toLowerCase().trim();
        final bool estaAprobadoCol = doc?['esta_aprobado'] == true;
        final bool activoCol = doc?['activo'] == true;
        final bool tenantActivo = tenant?['activo'] == true;

        final bool isApproved = estaAprobadoCol ||
            activoCol ||
            tenantActivo ||
            rawEstado == 'aprobado' ||
            rawEstado == 'activo';

        // Si el filtro solo pide pendientes y el doctor ya está activo/aprobado, excluirlo
        if (soloPendientes && isApproved) {
          continue;
        }

        final String estadoFinal = isApproved
            ? 'aprobado'
            : (rawEstado.isNotEmpty ? rawEstado : 'pendiente');

        final DateTime createdAt = DateTime.tryParse(
              doc?['created_at']?.toString() ??
                  user?['created_at']?.toString() ??
                  '',
            ) ??
            DateTime.now();

        final String? credencialEnc = tenant?['credencial_recuperacion_enc']?.toString() ??
            tenant?['credencial_recuperacion']?.toString() ??
            doc?['credencial_recuperacion_enc']?.toString();
        final String rawPlan = tenant?['plan']?.toString().toLowerCase().trim() ?? 'fundador';
        final double precio = double.tryParse(tenant?['precio_mensual']?.toString() ?? '') ??
            (rawPlan == 'individual' ? 50.0 : (rawPlan == 'duo' ? 70.0 : (rawPlan == 'grupo' ? 160.0 : (rawPlan == 'clinica' ? 280.0 : 35.0))));

        solicitudes.add(DoctorPendingRequest(
          idDoctor: idDoc,
          nombre: user?['nombre']?.toString() ?? 'Dr(a). Sin Nombre',
          email: user?['email']?.toString() ?? '',
          telefono: user?['telefono']?.toString() ?? '',
          especialidad: doc?['especialidad']?.toString() ?? 'Medicina General',
          estado: estadoFinal,
          createdAt: createdAt,
          dbUrl: null,
          dbAnonKey: null,
          estaAprobado: isApproved,
          tenantActivo: tenantActivo,
          credencialRecuperacionEnc: credencialEnc,
          plan: rawPlan,
          precioMensual: precio,
          estadoPago: tenant?['estado_pago']?.toString() ?? 'al_dia',
          modoSoloLectura: tenant?['modo_solo_lectura'] == true,
          intervaloPago: tenant?['intervalo_pago']?.toString() ?? 'mensual',
          limiteDoctores: int.tryParse(tenant?['limite_doctores']?.toString() ?? '') ?? 1,
        ));
      }

      // Ordenar por fecha de registro descendente
      solicitudes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('AdminTenantService: Error listando solicitudes de doctores: $e');
    }

    return solicitudes;
  }

  /// Aprueba, activa y configura la cuenta, plan y facturación del doctor en la Base Central.
  Future<bool> aprobarYConfigurarDoctor({
    required String idDoctor,
    required String nombreDoctor,
    bool activo = true,
    String? emailDoctor,
    String? dbUrl,
    String? dbAnonKey,
    String? initialPassword,
    String plan = 'fundador',
    double? precioMensual,
    String estadoPago = 'al_dia',
    bool modoSoloLectura = false,
  }) async {
    final client = _dualConfig.patientClient;
    final cleanUrl = dbUrl?.trim() ?? '';
    final cleanKey = dbAnonKey?.trim() ?? '';

    try {
      debugPrint('AdminTenantService: Configurando doctor $idDoctor (activo=$activo, plan=$plan)...');

      String? encryptedPassword;
      if (initialPassword != null && initialPassword.trim().isNotEmpty && emailDoctor != null && emailDoctor.isNotEmpty) {
        encryptedPassword = SecurityVaultService.instance.cifrarCredencial(
          password: initialPassword.trim(),
          idDoctor: idDoctor,
          emailDoctor: emailDoctor,
        );
        if (encryptedPassword.isNotEmpty) {
          await SecurityVaultService.instance.respaldarCredencialLocalmente(
            idDoctor: idDoctor,
            payloadCifrado: encryptedPassword,
          );
        }
      }

      final double finalPrecio = precioMensual ??
          (plan == 'individual' ? 50.0 : (plan == 'duo' ? 70.0 : (plan == 'grupo' ? 160.0 : (plan == 'clinica' ? 280.0 : 35.0))));

      final existingTenant = await client
          .from('doctores_tenants')
          .select('id_doctor')
          .eq('id_doctor', idDoctor)
          .limit(1);

      final Map<String, dynamic> tenantData = {
        'id_doctor': idDoctor,
        'activo': activo,
        'plan': plan,
        'estado_pago': estadoPago,
        'precio_mensual': finalPrecio,
        'modo_solo_lectura': modoSoloLectura,
      };

      if (encryptedPassword != null && encryptedPassword.isNotEmpty) {
        tenantData['credencial_recuperacion_enc'] = encryptedPassword;
      }

      Future<void> doUpsert(Map<String, dynamic> data) async {
        if ((existingTenant as List).isNotEmpty) {
          await client.from('doctores_tenants').update(data).eq('id_doctor', idDoctor);
        } else {
          await client.from('doctores_tenants').insert({
            ...data,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }

      try {
        await doUpsert(tenantData);
      } catch (errCol) {
        debugPrint('AdminTenantService: Fallback sin columnas extendidas: $errCol');
        tenantData.remove('credencial_recuperacion_enc');
        tenantData.remove('precio_mensual');
        tenantData.remove('modo_solo_lectura');
        try {
          await doUpsert(tenantData);
        } catch (errPlan) {
          debugPrint('AdminTenantService: Fallback con plan compatible: $errPlan');
          tenantData['plan'] = 'individual';
          await doUpsert(tenantData);
        }
      }

      // Marcar doctor como aprobado o pendiente en la tabla doctores
      try {
        await client.from('doctores').upsert({
          'id': idDoctor,
          'estado_verificacion': activo ? 'aprobado' : 'pendiente',
          'esta_aprobado': activo,
        });
      } catch (e) {
        debugPrint('AdminTenantService: Aviso actualizando tabla doctores central: $e');
      }

      // Asegurar rol doctor en usuarios
      try {
        await client.from('usuarios').update({'rol': 'doctor'}).eq('id', idDoctor);
      } catch (_) {}

      // Sincronizar con servidor privado si fue especificado
      if (cleanUrl.isNotEmpty && cleanKey.isNotEmpty) {
        try {
          final privateClient = SupabaseClient(cleanUrl, cleanKey);
          await privateClient.from('usuarios').upsert({
            'id': idDoctor,
            'nombre': nombreDoctor,
            'email': emailDoctor ?? '',
            'rol': 'doctor',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (errDb) {
          debugPrint('AdminTenantService: Nota servidor privado: $errDb');
        }
      }

      debugPrint('AdminTenantService: ¡Doctor $idDoctor configurado con éxito! (activo=$activo)');
      return true;
    } catch (e) {
      debugPrint('AdminTenantService: Error configurando doctor: $e');
      return false;
    }
  }

  /// Alias de compatibilidad
  Future<bool> activarYVincularDoctor({
    required String idDoctor,
    required String nombreDoctor,
    required String emailDoctor,
    required String dbUrl,
    required String dbAnonKey,
    String? initialPassword,
    String plan = 'fundador',
    double? precioMensual,
    String estadoPago = 'al_dia',
    bool modoSoloLectura = false,
  }) =>
      aprobarYConfigurarDoctor(
        idDoctor: idDoctor,
        nombreDoctor: nombreDoctor,
        emailDoctor: emailDoctor,
        dbUrl: dbUrl,
        dbAnonKey: dbAnonKey,
        initialPassword: initialPassword,
        plan: plan,
        precioMensual: precioMensual,
        estadoPago: estadoPago,
        modoSoloLectura: modoSoloLectura,
        activo: true,
      );

  /// Actualiza los parámetros del plan, precio mensual y estado de facturación del doctor.
  Future<bool> actualizarPlanYSuscripcionDoctor({
    required String idDoctor,
    required String plan,
    required double precioMensual,
    required String estadoPago,
    required bool modoSoloLectura,
    String intervaloPago = 'mensual',
    int limiteDoctores = 1,
  }) async {
    try {
      final client = _dualConfig.patientClient;
      await client.from('doctores_tenants').update({
        'plan': plan,
        'precio_mensual': precioMensual,
        'estado_pago': estadoPago,
        'modo_solo_lectura': modoSoloLectura,
      }).eq('id_doctor', idDoctor);
      return true;
    } catch (e) {
      debugPrint('AdminTenantService: Error actualizando plan: $e');
      return false;
    }
  }

  /// Valida y comprueba la conectividad a la base de datos privada antes de guardar.
  Future<Map<String, dynamic>> probarConexionBaseDatos({
    required String dbUrl,
    required String dbAnonKey,
  }) async {
    final cleanUrl = dbUrl.trim();
    final cleanKey = dbAnonKey.trim();

    if (cleanUrl.isEmpty || cleanKey.isEmpty) {
      return {'valido': false, 'mensaje': 'La URL y la Anon Key no pueden estar vacías.'};
    }
    if (!cleanUrl.startsWith('https://') || !cleanUrl.contains('.supabase.co')) {
      return {'valido': false, 'mensaje': 'La URL debe tener formato válido de Supabase (https://xxx.supabase.co).'};
    }

    try {
      final testClient = SupabaseClient(cleanUrl, cleanKey);
      await testClient.from('usuarios').select('id').limit(1);
      return {'valido': true, 'mensaje': 'Conexión exitosa. El servidor de Supabase y las tablas responden correctamente.'};
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('relation "usuarios" does not exist') || errStr.contains('404')) {
        return {'valido': true, 'tablasPendientes': true, 'mensaje': 'Conexión alcanzada, pero falta ejecutar el script DDL.'};
      }
      return {'valido': false, 'mensaje': 'No se pudo conectar a la base de datos: $e'};
    }
  }

  /// Desactiva temporalmente el acceso de un doctor a su tenant.
  Future<bool> alternarEstadoTenant({required String idDoctor, required bool activo}) async {
    try {
      await _dualConfig.patientClient.from('doctores_tenants').update({'activo': activo}).eq('id_doctor', idDoctor);
      return true;
    } catch (e) {
      debugPrint('AdminTenantService: Error alternando estado de tenant: $e');
      return false;
    }
  }

  /// Retorna el script DDL maestro para crear las tablas en el nuevo Supabase.
  String obtenerScriptDDLMaestro() => DoctorDatabaseProvisioner.fullSchemaSql;
}
