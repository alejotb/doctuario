import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración integral de arquitectura de base de datos dual:
/// - Base de Datos Clínica Privada: Doctor Suite / Clínicas individuales o grupales
/// - Base de Datos Central Pública: Plataforma de Pacientes y Catálogo Médico
class DualDatabaseConfig {
  DualDatabaseConfig._();

  static DualDatabaseConfig? _instance;
  static DualDatabaseConfig get instance =>
      _instance ??= DualDatabaseConfig._();

  // URL y clave por defecto de la Base de Datos Central (Prontudoc Central)
  static const String _kDefaultCentralDbUrl =
      'https://zrvpssjlxhumgldltsbq.supabase.co';
  static const String _kDefaultCentralDbAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpydnBzc2pseGh1bWdsZGx0c2JxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0MTE2NzEsImV4cCI6MjEwNjk4NzY3MX0.V3x1oH-Addjv-PkV2V-MPFGoPpfu0QOCcrRRrPWZx40';

  // URL y clave por defecto de la Base de Datos Clínica (apunta a la Base Central unificada)
  static const String _kDefaultDoctorDbUrl = _kDefaultCentralDbUrl;
  static const String _kDefaultDoctorDbAnonKey = _kDefaultCentralDbAnonKey;

  // Variables de entorno para la Base de Datos Central de Pacientes y Auth
  String get patientDbUrl => const String.fromEnvironment(
        'PATIENT_SUPABASE_URL',
        defaultValue: _kDefaultCentralDbUrl,
      );

  String get patientDbAnonKey => const String.fromEnvironment(
        'PATIENT_SUPABASE_ANON_KEY',
        defaultValue: _kDefaultCentralDbAnonKey,
      );

  // Variables de entorno para la Base de Datos Clínica (Médicos / Grupos)
  String get doctorDbUrl => const String.fromEnvironment(
        'DOCTOR_SUPABASE_URL',
        defaultValue: _kDefaultDoctorDbUrl,
      );

  String get doctorDbAnonKey => const String.fromEnvironment(
        'DOCTOR_SUPABASE_ANON_KEY',
        defaultValue: _kDefaultDoctorDbAnonKey,
      );

  SupabaseClient? _doctorClient;
  SupabaseClient? _patientClient;
  bool _initialized = false;

  /// Retorna si el sistema está ejecutándose con dos instancias físicas separadas de Supabase.
  bool get isDistinctDualDatabase =>
      doctorDbUrl.trim().toLowerCase() != patientDbUrl.trim().toLowerCase();

  /// Retorna si la configuración ya completó su inicialización.
  bool get isInitialized => _initialized;

  /// Cliente de Supabase conectado a la base de datos privada del doctor/grupo.
  SupabaseClient get doctorClient {
    if (!isDistinctDualDatabase) {
      return Supabase.instance.client;
    }
    if (_doctorClient != null) {
      final centralUrl = patientDbUrl.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
      final currentDocUrl = doctorDbUrl.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
      if (currentDocUrl == centralUrl) {
        return Supabase.instance.client;
      }
      return _doctorClient!;
    }
    return Supabase.instance.client;
  }

  /// Cliente de Supabase conectado a la base de datos pública/central de pacientes.
  SupabaseClient get patientClient {
    if (_patientClient != null) return _patientClient!;
    return Supabase.instance.client;
  }

  /// Inicializa los clientes de ambas bases de datos.
  Future<void> initializeClients() async {
    try {
      _patientClient = Supabase.instance.client;

      if (isDistinctDualDatabase) {
        debugPrint(
          'Configurando cliente dedicado para Base de Datos Clínica Privada: $doctorDbUrl',
        );
        _doctorClient = SupabaseClient(
          doctorDbUrl,
          doctorDbAnonKey,
          headers: {'X-Client-Info': 'prontudoc-doctor-client'},
        );
      } else {
        debugPrint(
          'DualDatabaseConfig: Modo unificado/desarrollo (Doctor y Paciente comparten instancia).',
        );
        _doctorClient = _patientClient;
      }
      await loadPersistedViewMode();
      _initialized = true;
    } catch (e) {
      debugPrint('Error inicializando clientes de base de datos dual: $e');
    }
  }

  /// Modo de ejecución activo (Doctor Suite vs Pacientes)
  bool isDoctorSuiteMode = false;

  /// Modo de visualización seleccionado por el usuario ('doctor' o 'paciente')
  String _activeViewMode = 'paciente';
  String get activeViewMode => _activeViewMode;
  bool get isDoctorViewActive => _activeViewMode == 'doctor';

  /// Guarda y persiste el modo de vista activo
  Future<void> persistActiveViewMode(String mode) async {
    _activeViewMode = mode;
    isDoctorSuiteMode = (mode == 'doctor');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('prontudoc_active_view_mode', mode);
      debugPrint('DualDatabaseConfig: Modo de vista persistido: $mode');
    } catch (e) {
      debugPrint('Error guardando modo activo de vista: $e');
    }
  }

  /// Carga el modo de vista previamente guardado
  Future<void> loadPersistedViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString('prontudoc_active_view_mode');
      if (mode != null && mode.isNotEmpty) {
        _activeViewMode = mode;
        isDoctorSuiteMode = (mode == 'doctor');
        debugPrint('DualDatabaseConfig: Modo de vista cargado: $mode');
      }
    } catch (_) {}
  }

  /// Cambia el modo de ejecución activo
  void setDoctorSuiteMode(bool value) {
    isDoctorSuiteMode = value;
    _activeViewMode = value ? 'doctor' : 'paciente';
  }

  /// Bandera de compilación o entorno para habilitar el registro público de doctores.
  /// Si es false, solo se permite el registro de pacientes a menos que se use la versión médica
  /// o se use el enlace privado de invitación para doctores (?doctor_invite=true).
  bool get isDoctorRegistrationAllowed {
    const envFlag = bool.fromEnvironment('DOCTOR_REGISTRATION_ENABLED', defaultValue: false);
    return envFlag || isDoctorSuiteMode;
  }

  /// Retorna el cliente adecuado para la tabla especificada según la arquitectura dual.
  SupabaseClient getClientForTable(String tableName) {
    final lowerName = tableName.toLowerCase();

    // Tablas que residen en la Base de Datos Central
    const centralTables = {
      'doctores_tenants',
      'usuarios',
      'secretaria_doctores',
    };
    if (centralTables.contains(lowerName)) {
      return patientClient;
    }

    // Tablas clínicas confidenciales que residen en la Base de Datos Privada del Doctor
    const clinicalTables = {
      'citas',
      'doctores',
      'doctor_sedes',
      'horarios_disponibilidad',
      'historias_clinicas',
      'examenes_medicos',
      'plantillas_historia',
      'avales_medicos',
      'triage_consultas',
      'pacientes',
      'centros_medicos',
      'notificaciones_citas',
    };
    if (clinicalTables.contains(lowerName)) {
      return doctorClient;
    }

    return isDoctorSuiteMode ? doctorClient : patientClient;
  }

  /// Conecta dinámicamente el cliente clínico del doctor a su base de datos privada.
  void conectarBaseDatosDoctor({
    required String dbUrl,
    required String dbAnonKey,
  }) {
    if (dbUrl.trim().isEmpty || dbAnonKey.trim().isEmpty) return;
    final cleanUrl = dbUrl.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
    final cleanCentral = patientDbUrl.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
    if (cleanUrl == cleanCentral) {
      debugPrint('DualDatabaseConfig: URL de doctor coincide con base central. Usando cliente autenticado.');
      _doctorClient = Supabase.instance.client;
      return;
    }
    debugPrint('DualDatabaseConfig: Conectando cliente clínico privado a: $dbUrl');
    _doctorClient = SupabaseClient(
      dbUrl,
      dbAnonKey,
      headers: {'X-Client-Info': 'prontudoc-doctor-client'},
    );
  }

  /// Consulta en la Base de Datos Central la suscripción/tenant del doctor.
  /// En la arquitectura centralizada unificada siempre conecta con el cliente principal.
  Future<Map<String, dynamic>?> consultarYConectarTenantDoctor(
    String idDoctor,
  ) async {
    _doctorClient = Supabase.instance.client;
    try {
      final List<dynamic> rows = await patientClient
          .from('doctores_tenants')
          .select('id_doctor, plan, activo, estado_pago, modo_solo_lectura')
          .eq('id_doctor', idDoctor)
          .limit(1);

      if (rows.isNotEmpty) {
        final data = Map<String, dynamic>.from(rows.first as Map);
        data['activo'] = data['activo'] ?? true;
        return data;
      }
    } catch (e) {
      debugPrint('Aviso consultando suscripción de doctor: $e');
    }
    return {
      'id_doctor': idDoctor,
      'activo': true,
      'plan': 'central',
    };
  }

  /// Resuelve el rol real del usuario con respaldo ante errores RLS (ej. 42P17).
  Future<String> resolveUserRole(User? user) async {
    if (user == null) return 'paciente';
    final uid = user.id;
    String normalize(String? raw) {
      final r = (raw ?? '').toLowerCase().trim();
      if (r == 'admin' || r == 'administrador') return 'administrador';
      if (r == 'doctor' || r == 'medico' || r == 'médico') return 'doctor';
      if (r == 'secretaria' || r == 'asistente') return 'secretaria';
      return r;
    }

    final metaRole = normalize(user.userMetadata?['rol']?.toString());
    final appRole = normalize(user.appMetadata['rol']?.toString());

    try {
      final rows = await patientClient.from('usuarios').select('rol').eq('id', uid).limit(1);
      if (rows.isNotEmpty) {
        final dbRole = normalize((rows.first as Map)['rol']?.toString());
        if (dbRole.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('prontudoc_user_role_$uid', dbRole);
          if (metaRole != dbRole) {
            try {
              await patientClient.auth.updateUser(UserAttributes(data: {'rol': dbRole}));
            } catch (_) {}
          }
          return dbRole;
        }
      }
    } catch (e) {
      debugPrint('Respaldo de rol activado por error en tabla usuarios: $e');
    }

    if (appRole.isNotEmpty && appRole != 'paciente') return appRole;
    if (metaRole.isNotEmpty && metaRole != 'paciente') return metaRole;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRole = normalize(prefs.getString('prontudoc_user_role_$uid'));
      if (savedRole.isNotEmpty && savedRole != 'paciente') return savedRole;
    } catch (_) {}

    try {
      final docRows = await patientClient.from('doctores').select('id').eq('id', uid).limit(1);
      if (docRows.isNotEmpty) return 'doctor';
    } catch (_) {}

    try {
      final secRows = await patientClient.from('secretaria_doctores').select('id').eq('id_secretaria', uid).limit(1);
      if (secRows.isNotEmpty) return 'secretaria';
    } catch (_) {}

    final persistedMode = normalize(_activeViewMode);
    if (persistedMode == 'administrador' || persistedMode == 'doctor' || persistedMode == 'secretaria') {
      return persistedMode;
    }
    return metaRole.isNotEmpty ? metaRole : 'paciente';
  }

  /// Helper para aplicar aislamiento multi-doctor en bases de datos compartidas por grupos médicos.
  /// Añade filtro `id_doctor` a cualquier consulta cuando se trabaja en modalidad de grupo.
  PostgrestFilterBuilder aplicarFiltroGrupoDoctor({
    required PostgrestFilterBuilder query,
    required String? idDoctor,
  }) {
    if (idDoctor != null && idDoctor.isNotEmpty) {
      return query.eq('id_doctor', idDoctor);
    }
    return query;
  }

  /// Valida la conectividad a ambas bases de datos y retorna un reporte de estado.
  Future<Map<String, dynamic>> verificarEstadoConexiones() async {
    final estado = <String, dynamic>{
      'isDistinct': isDistinctDualDatabase,
      'doctorDbUrl': doctorDbUrl,
      'patientDbUrl': patientDbUrl,
      'doctorConectado': false,
      'patientConectado': false,
    };

    try {
      await doctorClient.from('usuarios').select('id').limit(1);
      estado['doctorConectado'] = true;
    } catch (e) {
      estado['doctorError'] = e.toString();
    }

    try {
      await patientClient.from('usuarios').select('id').limit(1);
      estado['patientConectado'] = true;
    } catch (e) {
      estado['patientError'] = e.toString();
    }

    return estado;
  }
}

/// Modelo de datos para soportar Planes y Grupos de Doctores que comparten
/// una misma base de datos clínica con aislamiento mediante `id_doctor`.
class DoctorGroupTenancy {
  final String groupId;
  final String groupName;
  final String? centroMedicoId;
  final double porcentajeDescuentoGrupo;
  final List<String> doctorIds;
  final bool activo;
  final DateTime fechaRegistro;

  const DoctorGroupTenancy({
    required this.groupId,
    required this.groupName,
    this.centroMedicoId,
    this.porcentajeDescuentoGrupo = 0.0,
    required this.doctorIds,
    this.activo = true,
    required this.fechaRegistro,
  });

  /// Verifica si un doctor pertenece a este grupo clínico compartido.
  bool contieneDoctor(String idDoctor) => doctorIds.contains(idDoctor);

  /// Serialización a Map para Supabase.
  Map<String, dynamic> toMap() => {
        'group_id': groupId,
        'group_name': groupName,
        'centro_medico_id': centroMedicoId,
        'porcentaje_descuento_grupo': porcentajeDescuentoGrupo,
        'doctor_ids': doctorIds,
        'activo': activo,
        'fecha_registro': fechaRegistro.toIso8601String(),
      };

  /// Deserialización desde Map de Supabase.
  factory DoctorGroupTenancy.fromMap(Map<String, dynamic> map) {
    return DoctorGroupTenancy(
      groupId: map['group_id'] as String? ?? '',
      groupName: map['group_name'] as String? ?? 'Grupo Médico',
      centroMedicoId: map['centro_medico_id'] as String?,
      porcentajeDescuentoGrupo:
          (map['porcentaje_descuento_grupo'] as num?)?.toDouble() ?? 0.0,
      doctorIds: (map['doctor_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      activo: map['activo'] as bool? ?? true,
      fechaRegistro: map['fecha_registro'] != null
          ? DateTime.tryParse(map['fecha_registro'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Enumeración representativa del origen y destino de sincronización de datos.
enum DatabaseTarget {
  doctorSuite,
  patientPlatform,
  both,
}

/// Metadatos de sincronización entre el expediente clínico y el catálogo de pacientes.
class SyncRecordMetadata {
  final String recordId;
  final String idDoctor;
  final String entityType;
  final DateTime syncTimestamp;
  final bool isSynced;
  final String? errorMessage;

  const SyncRecordMetadata({
    required this.recordId,
    required this.idDoctor,
    required this.entityType,
    required this.syncTimestamp,
    required this.isSynced,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() => {
        'record_id': recordId,
        'id_doctor': idDoctor,
        'entity_type': entityType,
        'sync_timestamp': syncTimestamp.toIso8601String(),
        'is_synced': isSynced,
        'error_message': errorMessage,
      };
}
