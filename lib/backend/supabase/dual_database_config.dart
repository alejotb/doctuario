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

  /// El sistema opera en arquitectura de Base de Datos Única (sin instancias separadas).
  bool get isDistinctDualDatabase => false;

  /// Retorna si la configuración ya completó su inicialización.
  bool get isInitialized => _initialized;

  /// Cliente unificado de Supabase para todo el sistema médico.
  SupabaseClient get doctorClient => Supabase.instance.client;

  /// Cliente unificado de Supabase para el catálogo y pacientes.
  SupabaseClient get patientClient => Supabase.instance.client;

  /// Inicializa los clientes de la base de datos unificada.
  Future<void> initializeClients() async {
    try {
      _patientClient = Supabase.instance.client;
      _doctorClient = Supabase.instance.client;
      await loadPersistedViewMode();
      _initialized = true;
      debugPrint('DualDatabaseConfig: Operando en arquitectura de Base de Datos Única.');
    } catch (e) {
      debugPrint('Error inicializando cliente de base de datos unificada: $e');
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

  /// Retorna el cliente unificado de Supabase para cualquier tabla del sistema.
  SupabaseClient getClientForTable(String tableName) => Supabase.instance.client;

  /// Asegura el uso del cliente unificado de Supabase para el doctor.
  void conectarBaseDatosDoctor({
    required String dbUrl,
    required String dbAnonKey,
  }) {
    _doctorClient = Supabase.instance.client;
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
        String dbRole = normalize((rows.first as Map)['rol']?.toString());
        if (dbRole.isNotEmpty) {
          // Para usuarios paciente o secretaria, el acceso como secretaria se activa
          // únicamente cuando al menos un doctor ha confirmado su vínculo (activo = true).
          if (dbRole == 'paciente' || dbRole == 'secretaria') {
            try {
              final activeSecLinks = await patientClient
                  .from('secretaria_doctores')
                  .select('id')
                  .eq('id_secretaria', uid)
                  .eq('activo', true)
                  .limit(1);
              if (activeSecLinks.isNotEmpty) {
                if (dbRole != 'secretaria') {
                  try {
                    await patientClient
                        .from('usuarios')
                        .update({'rol': 'secretaria'})
                        .eq('id', uid);
                  } catch (_) {}
                }
                dbRole = 'secretaria';
              } else {
                // Sin doctor que la haya aceptado todavía: ingresa con vista de paciente
                dbRole = 'paciente';
              }
            } catch (_) {}
          }

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
    if (metaRole.isNotEmpty && metaRole != 'paciente' && metaRole != 'secretaria') return metaRole;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRole = normalize(prefs.getString('prontudoc_user_role_$uid'));
      if (savedRole.isNotEmpty && savedRole != 'paciente' && savedRole != 'secretaria') return savedRole;
    } catch (_) {}

    try {
      final docRows = await patientClient.from('doctores').select('id').eq('id', uid).limit(1);
      if (docRows.isNotEmpty) return 'doctor';
    } catch (_) {}

    try {
      final secRows = await patientClient
          .from('secretaria_doctores')
          .select('id')
          .eq('id_secretaria', uid)
          .eq('activo', true)
          .limit(1);
      if (secRows.isNotEmpty) return 'secretaria';
    } catch (_) {}

    final persistedMode = normalize(_activeViewMode);
    if (persistedMode == 'administrador' || persistedMode == 'doctor') {
      return persistedMode;
    }
    return metaRole.isNotEmpty && metaRole != 'secretaria' ? metaRole : 'paciente';
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
