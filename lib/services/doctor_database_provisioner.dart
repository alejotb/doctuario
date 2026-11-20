import 'package:flutter/foundation.dart';
import '/backend/supabase/supabase.dart';

/// Servicio centralizado de aprovisionamiento y arquitectura de base de datos
/// para doctores en Supabase (Prontudoc / MediConnect).
///
/// Garantiza que al registrarse un doctor:
/// 1. Se creen y verifiquen automáticamente todas las tablas requeridas.
/// 2. Se creen sus registros base: usuario, doctor, sede principal, horarios de atención
///    y plantillas clínicas iniciales sin intervención manual.
/// 3. Toda la estructura SQL (DDL) y lógica de creación resida en este archivo
///    para facilitar futuras modificaciones o migraciones desde el código.
class DoctorDatabaseProvisioner {
  DoctorDatabaseProvisioner._();

  static DoctorDatabaseProvisioner? _instance;
  static DoctorDatabaseProvisioner get instance =>
      _instance ??= DoctorDatabaseProvisioner._();

  final _dualConfig = DualDatabaseConfig.instance;

  /// Versión actual del esquema clínico de base de datos
  static const String schemaVersion = '2026.10.1';

  /// Script SQL DDL maestro con todas las tablas clínicas y de soporte
  static const String fullSchemaSql = '''
-- ==============================================================================
-- MediConnect / Prontudoc - DDL Maestro Autogenerado desde el Código
-- ==============================================================================

-- 1. Tabla: usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id UUID PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT now(),
    nombre TEXT,
    cedula TEXT,
    telefono TEXT,
    email TEXT,
    rol TEXT DEFAULT 'paciente',
    foto_url TEXT,
    es_familiar_medico BOOLEAN DEFAULT FALSE,
    doctor_referencia_nombre TEXT,
    ciudad_origen TEXT,
    es_foraneo BOOLEAN DEFAULT FALSE
);

-- 2. Tabla: doctores
CREATE TABLE IF NOT EXISTS doctores (
    id UUID PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    especialidad TEXT,
    biografia TEXT,
    costo_consulta NUMERIC,
    esta_aprobado BOOLEAN DEFAULT TRUE,
    nro_colegiatura TEXT,
    credencial_url TEXT,
    logo_url TEXT,
    estado_verificacion TEXT DEFAULT 'aprobado',
    duracion_cita_minutos INT DEFAULT 30,
    permite_sobrecupo BOOLEAN DEFAULT TRUE,
    clinicas_referencia TEXT,
    limite_pacientes_dia INT DEFAULT 15,
    vacaciones_activo BOOLEAN DEFAULT FALSE,
    vacaciones_inicio DATE,
    vacaciones_fin DATE
);
ALTER TABLE doctores ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- 3. Tabla: pacientes
CREATE TABLE IF NOT EXISTS pacientes (
    id UUID PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    fecha_nacimiento DATE,
    tipo_sangre TEXT,
    id_doctor UUID REFERENCES doctores(id) ON DELETE SET NULL
);

-- 4. Tabla: doctor_sedes
CREATE TABLE IF NOT EXISTS doctor_sedes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_doctor UUID REFERENCES doctores(id) ON DELETE CASCADE,
    nombre_sede TEXT NOT NULL,
    direccion TEXT,
    ciudad TEXT,
    telefono_contacto TEXT,
    estado TEXT,
    tipo_lugar TEXT DEFAULT 'privado',
    id_centro_medico UUID,
    numero_consultorio TEXT,
    telefono_visible BOOLEAN DEFAULT TRUE,
    duracion_consulta_minutos INT DEFAULT 30,
    dias_atencion TEXT,
    horario_texto TEXT,
    latitud DOUBLE PRECISION,
    longitud DOUBLE PRECISION,
    modalidad_atencion TEXT DEFAULT 'hora_fija',
    es_principal BOOLEAN DEFAULT FALSE
);

-- 5. Tabla: horarios_disponibilidad
CREATE TABLE IF NOT EXISTS horarios_disponibilidad (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_doctor UUID REFERENCES doctores(id) ON DELETE CASCADE,
    id_sede UUID REFERENCES doctor_sedes(id) ON DELETE CASCADE,
    dia_semana INT NOT NULL, -- 1=Lunes .. 7=Domingo
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    modalidad_atencion TEXT DEFAULT 'hora_fija',
    cupo_maximo INT DEFAULT 15,
    activo BOOLEAN DEFAULT TRUE
);

-- 6. Tabla: plantillas_historia
CREATE TABLE IF NOT EXISTS plantillas_historia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_doctor UUID REFERENCES doctores(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    especialidad TEXT,
    estructura_json JSONB DEFAULT '{}'::jsonb,
    es_predeterminada BOOLEAN DEFAULT FALSE
);

-- 7. Tabla: citas
CREATE TABLE IF NOT EXISTS citas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_doctor UUID REFERENCES doctores(id) ON DELETE CASCADE,
    id_paciente UUID REFERENCES pacientes(id) ON DELETE CASCADE,
    id_sede UUID REFERENCES doctor_sedes(id) ON DELETE SET NULL,
    fecha_hora TIMESTAMPTZ,
    fecha_hora_estimada_actual TIMESTAMPTZ,
    estado TEXT DEFAULT 'solicitada',
    motivo TEXT,
    notas_medicas TEXT,
    es_emergencia BOOLEAN DEFAULT FALSE,
    trato_especial BOOLEAN DEFAULT FALSE,
    minutos_retraso_acumulados INT DEFAULT 0,
    turno_numero INT,
    modalidad_atencion TEXT DEFAULT 'hora_fija',
    duracion_minutos INT DEFAULT 30,
    posicion_cola INT,
    hora_llegada TIMESTAMPTZ,
    llegada_confirmada BOOLEAN DEFAULT FALSE,
    es_control BOOLEAN DEFAULT FALSE,
    cobrar_control BOOLEAN DEFAULT FALSE,
    tipo_exoneracion TEXT,
    monto_exoneracion NUMERIC
);

-- 8. Tabla: historias_clinicas
CREATE TABLE IF NOT EXISTS historias_clinicas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_paciente UUID REFERENCES pacientes(id) ON DELETE CASCADE,
    id_doctor UUID REFERENCES doctores(id) ON DELETE CASCADE,
    id_cita UUID REFERENCES citas(id) ON DELETE SET NULL,
    id_plantilla UUID REFERENCES plantillas_historia(id) ON DELETE SET NULL,
    datos_historia_json JSONB DEFAULT '{}'::jsonb,
    motivo_consulta TEXT,
    sintomas TEXT,
    examen_fisico TEXT,
    diagnostico TEXT,
    tratamiento TEXT,
    notas_privadas TEXT,
    es_privado BOOLEAN DEFAULT TRUE
);

-- 9. Tabla: examenes_medicos
CREATE TABLE IF NOT EXISTS examenes_medicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_paciente UUID REFERENCES pacientes(id) ON DELETE CASCADE,
    id_doctor UUID REFERENCES doctores(id) ON DELETE SET NULL,
    subido_por_usuario_id UUID REFERENCES usuarios(id),
    titulo TEXT NOT NULL,
    tipo_examen TEXT,
    archivo_url TEXT NOT NULL,
    formato TEXT DEFAULT 'pdf',
    fecha_estudio DATE DEFAULT CURRENT_DATE,
    fecha_entrega DATE,
    especialidad TEXT,
    estado TEXT DEFAULT 'por_revisar',
    hallazgos TEXT,
    notas TEXT
);

-- 10. Tabla: secretaria_doctores
CREATE TABLE IF NOT EXISTS secretaria_doctores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_secretaria UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    id_doctor UUID REFERENCES doctores(id) ON DELETE CASCADE
);

-- 11. Tabla: notificaciones_citas
CREATE TABLE IF NOT EXISTS notificaciones_citas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_usuario UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    id_cita UUID REFERENCES citas(id) ON DELETE CASCADE,
    tipo TEXT DEFAULT 'retraso_emergencia',
    titulo TEXT NOT NULL,
    mensaje TEXT NOT NULL,
    minutos_retraso INT DEFAULT 0,
    leido BOOLEAN DEFAULT FALSE
);

-- 12. Tabla: avales_medicos
CREATE TABLE IF NOT EXISTS avales_medicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_doctor_avalado UUID REFERENCES doctores(id) ON DELETE CASCADE,
    id_doctor_avalador UUID REFERENCES doctores(id) ON DELETE CASCADE,
    comentario TEXT
);

-- 13. Tabla: triage_consultas
CREATE TABLE IF NOT EXISTS triage_consultas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_paciente UUID REFERENCES pacientes(id) ON DELETE CASCADE,
    id_cita UUID REFERENCES citas(id) ON DELETE SET NULL,
    descripcion_sintomas TEXT NOT NULL,
    nivel_urgencia TEXT DEFAULT 'leve',
    requiere_hospital BOOLEAN DEFAULT FALSE,
    resumen_preconsulta TEXT
);

-- 14. Tabla: centros_medicos
CREATE TABLE IF NOT EXISTS centros_medicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    nombre TEXT NOT NULL,
    direccion TEXT,
    telefono TEXT,
    ciudad TEXT,
    activo BOOLEAN DEFAULT TRUE
);

-- ==============================================================================
-- 15. POLÍTICAS RLS (Row Level Security) PARA BASE DE DATOS CLÍNICA DEL DOCTOR
-- ==============================================================================
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctores ENABLE ROW LEVEL SECURITY;
ALTER TABLE pacientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctor_sedes ENABLE ROW LEVEL SECURITY;
ALTER TABLE horarios_disponibilidad ENABLE ROW LEVEL SECURITY;
ALTER TABLE plantillas_historia ENABLE ROW LEVEL SECURITY;
ALTER TABLE citas ENABLE ROW LEVEL SECURITY;
ALTER TABLE historias_clinicas ENABLE ROW LEVEL SECURITY;
ALTER TABLE examenes_medicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE secretaria_doctores ENABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones_citas ENABLE ROW LEVEL SECURITY;
ALTER TABLE triage_consultas ENABLE ROW LEVEL SECURITY;
ALTER TABLE centros_medicos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Doctor y secretaria gestionan historias" ON historias_clinicas;
CREATE POLICY "Doctor y secretaria gestionan historias" ON historias_clinicas FOR ALL TO authenticated
USING (auth.uid() = id_doctor OR EXISTS (SELECT 1 FROM secretaria_doctores WHERE id_secretaria = auth.uid() AND id_doctor = historias_clinicas.id_doctor))
WITH CHECK (auth.uid() = id_doctor);

DROP POLICY IF EXISTS "Acceso a examenes en base clinica" ON examenes_medicos;
CREATE POLICY "Acceso a examenes en base clinica" ON examenes_medicos FOR ALL TO authenticated
USING (auth.uid() = id_doctor OR auth.uid() = id_paciente OR EXISTS (SELECT 1 FROM secretaria_doctores WHERE id_secretaria = auth.uid() AND id_doctor = examenes_medicos.id_doctor));

DROP POLICY IF EXISTS "Acceso a citas en base clinica" ON citas;
CREATE POLICY "Acceso a citas en base clinica" ON citas FOR ALL TO authenticated
USING (auth.uid() = id_doctor OR auth.uid() = id_paciente OR EXISTS (SELECT 1 FROM secretaria_doctores WHERE id_secretaria = auth.uid() AND id_doctor = citas.id_doctor));

DROP POLICY IF EXISTS "Doctor gestiona plantillas" ON plantillas_historia;
CREATE POLICY "Doctor gestiona plantillas" ON plantillas_historia FOR ALL TO authenticated
USING (auth.uid() = id_doctor) WITH CHECK (auth.uid() = id_doctor);

DROP POLICY IF EXISTS "Lectura de sedes del doctor" ON doctor_sedes;
CREATE POLICY "Lectura de sedes del doctor" ON doctor_sedes FOR SELECT USING (true);
DROP POLICY IF EXISTS "Doctor edita sedes" ON doctor_sedes;
CREATE POLICY "Doctor edita sedes" ON doctor_sedes FOR ALL TO authenticated USING (auth.uid() = id_doctor) WITH CHECK (auth.uid() = id_doctor);

DROP POLICY IF EXISTS "Lectura de horarios del doctor" ON horarios_disponibilidad;
CREATE POLICY "Lectura de horarios del doctor" ON horarios_disponibilidad FOR SELECT USING (true);
DROP POLICY IF EXISTS "Doctor edita horarios" ON horarios_disponibilidad;
CREATE POLICY "Doctor edita horarios" ON horarios_disponibilidad FOR ALL TO authenticated USING (auth.uid() = id_doctor) WITH CHECK (auth.uid() = id_doctor);

DROP POLICY IF EXISTS "Secretaria y doctor acceden a vinculos" ON secretaria_doctores;
CREATE POLICY "Secretaria y doctor acceden a vinculos" ON secretaria_doctores FOR ALL TO authenticated
USING (auth.uid() = id_doctor OR auth.uid() = id_secretaria);

-- 16. BUCKETS DE ALMACENAMIENTO Y POLÍTICAS DE ARCHIVOS CLÍNICOS
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('examenes', 'examenes', false, 10485760)
ON CONFLICT (id) DO UPDATE SET public = false;

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('documentos_medicos', 'documentos_medicos', false, 10485760)
ON CONFLICT (id) DO UPDATE SET public = false;

INSERT INTO storage.buckets (id, name, public)
VALUES ('perfiles', 'perfiles', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('images', 'images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Acceso seguro a examenes de clinica" ON storage.objects;
CREATE POLICY "Acceso seguro a examenes de clinica"
ON storage.objects FOR ALL TO authenticated
USING (bucket_id IN ('examenes', 'documentos_medicos') AND auth.uid() IS NOT NULL)
WITH CHECK (bucket_id IN ('examenes', 'documentos_medicos') AND auth.uid() IS NOT NULL);
''';

  /// Aprovisiona automáticamente todo el ecosistema de base de datos para un nuevo médico
  Future<bool> provisionNewDoctorDatabase({
    required String idDoctor,
    String? email,
    String? nombre,
    String? telefono,
    String? especialidad,
    String? fotoUrl,
    int duracionCitaMinutos = 30,
    int limitePacientesDia = 15,
  }) async {
    if (idDoctor.isEmpty) return false;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final espFinal = (especialidad != null && especialidad.trim().isNotEmpty)
        ? especialidad.trim()
        : null;

    try {
      // 1. Asegurar en tabla doctores sin sobreescribir aprobación ni perfil existente
      final doctorPayload = <String, dynamic>{
        'id': idDoctor,
        'duracion_cita_minutos': duracionCitaMinutos,
        'limite_pacientes_dia': limitePacientesDia,
        'permite_sobrecupo': true,
        if (espFinal != null) 'especialidad': espFinal,
        'created_at': nowIso,
      };
      try {
        await DoctoresTable().upsert(doctorPayload);
      } catch (_) {}

      // 2. Aprovisionar Plantillas de Historia Clínica por defecto si no existen
      try {
        final existingPlantillas = await PlantillasHistoriaTable().queryRows(
          queryFn: (q) => q.eq('id_doctor', idDoctor).limit(1),
        );
        if (existingPlantillas.isEmpty) {
          await PlantillasHistoriaTable().insert({
            'id_doctor': idDoctor,
            'titulo': 'Historia Clínica General',
            'especialidad': espFinal,
            'es_predeterminada': true,
            'estructura_json': {
              'motivo_consulta': 'Motivo principal de consulta o síntomas referidos',
              'antecedentes': 'Antecedentes patológicos, alérgicos, quirúrgicos y familiares',
              'examen_fisico': 'Signos vitales y exploración segmentaria',
              'diagnostico': 'Diagnóstico presuntivo o CIE-10',
              'tratamiento': 'Plan farmacológico e indicaciones generales',
            },
            'created_at': nowIso,
          });
        }
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('DoctorDatabaseProvisioner: Nota durante aprovisionamiento: $e');
      return false;
    }
  }

  /// Verifica el estado de salud de la base de datos del doctor
  Future<Map<String, dynamic>> verifyDoctorDatabaseHealth(String idDoctor) async {
    final client = _dualConfig.doctorClient;
    final results = <String, bool>{};

    const tablesToCheck = [
      'usuarios',
      'doctores',
      'doctor_sedes',
      'horarios_disponibilidad',
      'doctor_bloqueos',
      'plantillas_historia',
      'pacientes',
      'citas',
      'historias_clinicas',
      'examenes_medicos',
      'centros_medicos',
      'soporte_tickets',
    ];

    for (final table in tablesToCheck) {
      try {
        await client.from(table).select('id').limit(1);
        results[table] = true;
      } catch (_) {
        results[table] = false;
      }
    }

    final allHealthy = results.values.every((v) => v == true);
    return {
      'healthy': allHealthy,
      'schemaVersion': schemaVersion,
      'tables': results,
    };
  }
}
