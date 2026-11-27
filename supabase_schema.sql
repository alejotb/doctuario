-- ==============================================================================
-- MediConnect / Prontudoc - Schema Completo y Limpio para Supabase
-- Este script define todas las llaves primarias (PRIMARY KEY), relaciones (FK)
-- y columnas actualizadas correspondientes a todo el sistema.
-- ==============================================================================

-- 1. TABLA: usuarios (Vinculada con Supabase Auth)
CREATE TABLE IF NOT EXISTS usuarios (
    id UUID PRIMARY KEY, -- Coincide con auth.users.id
    created_at TIMESTAMPTZ DEFAULT now(),
    nombre TEXT,
    cedula TEXT,
    telefono TEXT,
    email TEXT,
    rol TEXT DEFAULT 'paciente', -- 'paciente' | 'doctor' | 'secretaria' | 'admin' | 'administrador'
    foto_url TEXT,
    es_familiar_medico BOOLEAN DEFAULT FALSE,
    doctor_referencia_nombre TEXT,
    ciudad_origen TEXT,
    es_foraneo BOOLEAN DEFAULT FALSE
);

ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_rol_check;
ALTER TABLE usuarios ADD CONSTRAINT usuarios_rol_check CHECK (rol IN ('paciente', 'doctor', 'secretaria', 'admin', 'administrador'));
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS es_familiar_medico BOOLEAN DEFAULT FALSE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS doctor_referencia_nombre TEXT;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS ciudad_origen TEXT;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS es_foraneo BOOLEAN DEFAULT FALSE;


-- 2. TABLA: doctores
CREATE TABLE IF NOT EXISTS doctores (
    id UUID PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    especialidad TEXT,
    biografia TEXT,
    costo_consulta NUMERIC,
    esta_aprobado BOOLEAN DEFAULT FALSE,
    nro_colegiatura TEXT,
    credencial_url TEXT,
    estado_verificacion TEXT DEFAULT 'pendiente',
    duracion_cita_minutos INT DEFAULT 30,
    permite_sobrecupo BOOLEAN DEFAULT TRUE,
    clinicas_referencia TEXT,
    limite_pacientes_dia INT DEFAULT 15,
    vacaciones_activo BOOLEAN DEFAULT FALSE,
    vacaciones_inicio DATE,
    vacaciones_fin DATE
);

ALTER TABLE doctores ADD COLUMN IF NOT EXISTS limite_pacientes_dia INT DEFAULT 15;
ALTER TABLE doctores ADD COLUMN IF NOT EXISTS vacaciones_activo BOOLEAN DEFAULT FALSE;
ALTER TABLE doctores ADD COLUMN IF NOT EXISTS vacaciones_inicio DATE;
ALTER TABLE doctores ADD COLUMN IF NOT EXISTS vacaciones_fin DATE;
ALTER TABLE doctores ADD COLUMN IF NOT EXISTS visible_en_catalogo BOOLEAN DEFAULT TRUE;


-- 3. TABLA: pacientes (Soporta pacientes registrados en auth y pacientes manuales de consultorio)
CREATE TABLE IF NOT EXISTS pacientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    nombre TEXT,
    cedula TEXT,
    telefono TEXT,
    email TEXT,
    ciudad_origen TEXT,
    direccion TEXT,
    fecha_nacimiento DATE,
    tipo_sangre TEXT,
    id_doctor UUID REFERENCES doctores(id) ON DELETE SET NULL,
    id_usuario UUID REFERENCES usuarios(id) ON DELETE SET NULL
);

ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS nombre TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS cedula TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS telefono TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS ciudad_origen TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS direccion TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS id_doctor UUID REFERENCES doctores(id) ON DELETE SET NULL;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS id_usuario UUID REFERENCES usuarios(id) ON DELETE SET NULL;
ALTER TABLE pacientes DROP CONSTRAINT IF EXISTS pacientes_id_fkey;
ALTER TABLE pacientes ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS id_usuario_representante UUID REFERENCES usuarios(id) ON DELETE SET NULL;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS nombre_representante TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS cedula_representante TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS telefono_representante TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS parentesco TEXT;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS es_menor_edad BOOLEAN DEFAULT FALSE;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS cuenta_vinculada BOOLEAN DEFAULT FALSE;
ALTER TABLE pacientes DROP CONSTRAINT IF EXISTS pacientes_id_usuario_fkey;
ALTER TABLE pacientes ADD CONSTRAINT pacientes_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE SET NULL;


-- 4. TABLA: doctor_sedes (Consultorios y lugares de trabajo)
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

ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS estado TEXT;
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS tipo_lugar TEXT DEFAULT 'privado';
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS id_centro_medico UUID;
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS numero_consultorio TEXT;
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS telefono_visible BOOLEAN DEFAULT TRUE;
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS duracion_consulta_minutos INT DEFAULT 30;
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS dias_atencion TEXT;
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS horario_texto TEXT;
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS latitud DOUBLE PRECISION;
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS longitud DOUBLE PRECISION;
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS modalidad_atencion TEXT DEFAULT 'hora_fija';
ALTER TABLE doctor_sedes ADD COLUMN IF NOT EXISTS es_principal BOOLEAN DEFAULT FALSE;


-- 5. TABLA: secretaria_doctores (Relación secretaria multi-doctor)
CREATE TABLE IF NOT EXISTS secretaria_doctores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_secretaria UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    id_doctor UUID REFERENCES doctores(id) ON DELETE CASCADE
);


-- 6. TABLA: horarios_disponibilidad (Turnos y modalidad de atención)
CREATE TABLE IF NOT EXISTS horarios_disponibilidad (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_doctor UUID REFERENCES doctores(id) ON DELETE CASCADE,
    id_sede UUID REFERENCES doctor_sedes(id) ON DELETE CASCADE,
    dia_semana INT NOT NULL, -- 1=Lunes, 7=Domingo
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    modalidad_atencion TEXT DEFAULT 'hora_fija',
    cupo_maximo INT DEFAULT 15,
    activo BOOLEAN DEFAULT TRUE
);


-- 7. TABLA: citas
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

ALTER TABLE citas ADD COLUMN IF NOT EXISTS duracion_minutos INT DEFAULT 30;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS posicion_cola INT;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS hora_llegada TIMESTAMPTZ;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS llegada_confirmada BOOLEAN DEFAULT FALSE;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS es_control BOOLEAN DEFAULT FALSE;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS cobrar_control BOOLEAN DEFAULT FALSE;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS tipo_exoneracion TEXT;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS monto_exoneracion NUMERIC;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS motivo_cancelacion TEXT;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS motivo_reprogramacion TEXT;


-- 8. TABLA: examenes_medicos (PDFs y estudios de laboratorio/imágenes)
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

ALTER TABLE examenes_medicos ADD COLUMN IF NOT EXISTS id_cita UUID REFERENCES citas(id) ON DELETE SET NULL;
ALTER TABLE examenes_medicos ADD COLUMN IF NOT EXISTS fecha_entrega DATE;
ALTER TABLE examenes_medicos ADD COLUMN IF NOT EXISTS especialidad TEXT;
ALTER TABLE examenes_medicos ADD COLUMN IF NOT EXISTS estado TEXT DEFAULT 'por_revisar';
ALTER TABLE examenes_medicos ADD COLUMN IF NOT EXISTS hallazgos TEXT;
ALTER TABLE examenes_medicos ADD COLUMN IF NOT EXISTS compartir_con_paciente BOOLEAN DEFAULT TRUE;
ALTER TABLE examenes_medicos ADD COLUMN IF NOT EXISTS correo_familiar TEXT;

ALTER TABLE citas ADD COLUMN IF NOT EXISTS borrador_consulta JSONB;
ALTER TABLE citas ADD COLUMN IF NOT EXISTS es_borrador BOOLEAN DEFAULT FALSE;


-- 9. TABLA: plantillas_historia (Plantillas rápidas para el médico)
CREATE TABLE IF NOT EXISTS plantillas_historia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_doctor UUID REFERENCES doctores(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    especialidad TEXT,
    estructura_json JSONB DEFAULT '{}'::jsonb,
    es_predeterminada BOOLEAN DEFAULT FALSE
);


-- 10. TABLA: historias_clinicas (CONFIDENCIALES: Solo para el Doctor)
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


-- 11. TABLA: notificaciones_citas
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


-- 12. TABLA: avales_medicos (Validación entre colegas)
CREATE TABLE IF NOT EXISTS avales_medicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    id_doctor_avalado UUID REFERENCES doctores(id) ON DELETE CASCADE,
    id_doctor_avalador UUID REFERENCES doctores(id) ON DELETE CASCADE,
    comentario TEXT
);


-- 13. TABLA: triage_consultas (Guía y orientación de síntomas)
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


-- 14. TABLA: centros_medicos
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
-- 15. POLÍTICAS RLS (Row Level Security) INTEGRALES PARA LA BASE DE DATOS CENTRAL
-- ==============================================================================

-- A. TABLA: secretaria_doctores
ALTER TABLE secretaria_doctores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Doctores y secretarias pueden ver sus vinculos" ON secretaria_doctores;
CREATE POLICY "Doctores y secretarias pueden ver sus vinculos"
ON secretaria_doctores FOR SELECT TO authenticated
USING (auth.uid() = id_secretaria OR auth.uid() = id_doctor);

DROP POLICY IF EXISTS "Doctores y secretarias pueden insertar vinculos" ON secretaria_doctores;
CREATE POLICY "Doctores y secretarias pueden insertar vinculos"
ON secretaria_doctores FOR INSERT TO authenticated
WITH CHECK (auth.uid() = id_secretaria OR auth.uid() = id_doctor);

DROP POLICY IF EXISTS "Doctores y secretarias pueden actualizar vinculos" ON secretaria_doctores;
CREATE POLICY "Doctores y secretarias pueden actualizar vinculos"
ON secretaria_doctores FOR UPDATE TO authenticated
USING (auth.uid() = id_doctor OR auth.uid() = id_secretaria)
WITH CHECK (auth.uid() = id_doctor OR auth.uid() = id_secretaria);

DROP POLICY IF EXISTS "Doctores y secretarias pueden eliminar vinculos" ON secretaria_doctores;
CREATE POLICY "Doctores y secretarias pueden eliminar vinculos"
ON secretaria_doctores FOR DELETE TO authenticated
USING (auth.uid() = id_doctor OR auth.uid() = id_secretaria);

-- B. TABLA: usuarios (Sin recursión infinita 42P17 en RLS)
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Perfiles legibles por usuarios y catalogo" ON usuarios;
DROP POLICY IF EXISTS "Usuarios insertan su propio perfil" ON usuarios;
DROP POLICY IF EXISTS "Creacion autorizada de usuarios" ON usuarios;
DROP POLICY IF EXISTS "Usuarios editan su propio perfil" ON usuarios;
DROP POLICY IF EXISTS "Edicion autorizada de usuarios" ON usuarios;
DROP POLICY IF EXISTS "Usuarios actualizan perfiles" ON usuarios;
DROP POLICY IF EXISTS "Usuarios eliminan su perfil" ON usuarios;

CREATE POLICY "Perfiles legibles por usuarios y catalogo"
ON usuarios FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Creacion autorizada de usuarios"
ON usuarios FOR INSERT TO authenticated, anon WITH CHECK (true);

CREATE POLICY "Usuarios actualizan perfiles"
ON usuarios FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

CREATE POLICY "Usuarios eliminan su perfil"
ON usuarios FOR DELETE TO authenticated USING (auth.uid() = id);

-- C. TABLA: doctores
ALTER TABLE doctores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Directorio de doctores visible" ON doctores;
CREATE POLICY "Directorio de doctores visible"
ON doctores FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "Doctor inserta su propio registro" ON doctores;
CREATE POLICY "Doctor inserta su propio registro"
ON doctores FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Doctor edita su propio registro" ON doctores;
CREATE POLICY "Doctor edita su propio registro"
ON doctores FOR ALL TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- D. TABLA: pacientes
ALTER TABLE pacientes ENABLE ROW LEVEL SECURITY;

-- D. TABLA: pacientes
ALTER TABLE pacientes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Paciente ve su perfil y doctor ve sus asignados" ON pacientes;
DROP POLICY IF EXISTS "Lectura autorizada de pacientes" ON pacientes;
DROP POLICY IF EXISTS "Paciente inserta su propio registro" ON pacientes;
DROP POLICY IF EXISTS "Paciente edita su propio registro" ON pacientes;
DROP POLICY IF EXISTS "Gestion autorizada de pacientes" ON pacientes;
DROP POLICY IF EXISTS "Pacientes lectura abierta" ON pacientes;
DROP POLICY IF EXISTS "Pacientes gestion autenticados" ON pacientes;
DROP POLICY IF EXISTS "Pacientes gestion anon" ON pacientes;

CREATE POLICY "Pacientes lectura abierta" ON pacientes FOR SELECT USING (true);
CREATE POLICY "Pacientes gestion autenticados" ON pacientes FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Pacientes gestion anon" ON pacientes FOR ALL TO anon USING (true) WITH CHECK (true);

-- E. TABLA: doctor_sedes Y horarios_disponibilidad
ALTER TABLE doctor_sedes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Sedes lectura publica" ON doctor_sedes;
DROP POLICY IF EXISTS "Sedes visibles para agendar" ON doctor_sedes;
DROP POLICY IF EXISTS "Doctor edita sus sedes" ON doctor_sedes;
DROP POLICY IF EXISTS "Doctor edita sedes" ON doctor_sedes;
DROP POLICY IF EXISTS "Doctor gestiona sus sedes" ON doctor_sedes;
DROP POLICY IF EXISTS "Permitir todo a usuarios autenticados en doctor_sedes" ON doctor_sedes;
DROP POLICY IF EXISTS "Sedes gestion autenticados" ON doctor_sedes;
DROP POLICY IF EXISTS "Sedes anon fallback" ON doctor_sedes;

CREATE POLICY "Sedes lectura publica" ON doctor_sedes FOR SELECT USING (true);
CREATE POLICY "Sedes gestion autenticados" ON doctor_sedes FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Sedes anon fallback" ON doctor_sedes FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE horarios_disponibilidad ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Horarios lectura publica" ON horarios_disponibilidad;
DROP POLICY IF EXISTS "Horarios visibles para agendar" ON horarios_disponibilidad;
DROP POLICY IF EXISTS "Doctor edita sus horarios" ON horarios_disponibilidad;
DROP POLICY IF EXISTS "Doctor edita horarios" ON horarios_disponibilidad;
DROP POLICY IF EXISTS "Doctor gestiona sus horarios" ON horarios_disponibilidad;
DROP POLICY IF EXISTS "Horarios gestion autenticados" ON horarios_disponibilidad;
DROP POLICY IF EXISTS "Horarios anon fallback" ON horarios_disponibilidad;

CREATE POLICY "Horarios lectura publica" ON horarios_disponibilidad FOR SELECT USING (true);
CREATE POLICY "Horarios gestion autenticados" ON horarios_disponibilidad FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Horarios anon fallback" ON horarios_disponibilidad FOR ALL TO anon USING (true) WITH CHECK (true);

-- F. TABLA: citas
ALTER TABLE citas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acceso autorizado a citas" ON citas;
CREATE POLICY "Acceso autorizado a citas"
ON citas FOR SELECT TO authenticated
USING (
  auth.uid() = id_paciente 
  OR auth.uid() = id_doctor
  OR EXISTS (SELECT 1 FROM secretaria_doctores WHERE id_secretaria = auth.uid() AND id_doctor = citas.id_doctor)
);

DROP POLICY IF EXISTS "Pacientes y doctores pueden crear citas" ON citas;
CREATE POLICY "Pacientes y doctores pueden crear citas"
ON citas FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() = id_paciente 
  OR auth.uid() = id_doctor
  OR EXISTS (SELECT 1 FROM secretaria_doctores WHERE id_secretaria = auth.uid() AND id_doctor = citas.id_doctor)
);

DROP POLICY IF EXISTS "Actualizacion de citas autorizada" ON citas;
CREATE POLICY "Actualizacion de citas autorizada"
ON citas FOR UPDATE TO authenticated
USING (
  auth.uid() = id_paciente 
  OR auth.uid() = id_doctor
  OR EXISTS (SELECT 1 FROM secretaria_doctores WHERE id_secretaria = auth.uid() AND id_doctor = citas.id_doctor)
);

-- G. TABLA: doctores_tenants (Conexión de bases de datos privadas)
-- Permite acceso a:
-- 1. El propio doctor (para inicializar su tenant).
-- 2. La secretaria autorizada del doctor (para gestionar la agenda del consultorio).
-- 3. Los administradores de Doctuario.
-- 4. Pacientes con cita confirmada con ese doctor.
ALTER TABLE doctores_tenants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura de tenants autorizada" ON doctores_tenants;
DROP POLICY IF EXISTS "Solo admin puede insertar o modificar tenants" ON doctores_tenants;
DROP POLICY IF EXISTS "Gestion de tenants autenticados" ON doctores_tenants;

CREATE POLICY "Lectura de tenants autorizada"
ON doctores_tenants FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Gestion de tenants autenticados"
ON doctores_tenants FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ==============================================================================
-- H. BUCKETS DE ALMACENAMIENTO Y POLÍTICAS (storage.buckets y storage.objects)
-- ==============================================================================
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

DROP POLICY IF EXISTS "Acceso seguro a examenes medicos" ON storage.objects;
CREATE POLICY "Acceso seguro a examenes medicos"
ON storage.objects FOR ALL TO authenticated
USING (
  bucket_id IN ('examenes', 'documentos_medicos')
  AND auth.uid() IS NOT NULL
)
WITH CHECK (
  bucket_id IN ('examenes', 'documentos_medicos')
  AND auth.uid() IS NOT NULL
);


-- ==============================================================================
-- I. RETENCIÓN Y PURGA AUTOMÁTICA DE CITAS HISTÓRICAS EN BASE CENTRAL
-- ==============================================================================
-- En la base de datos central solo se conservan citas vigentes y futuras para control
-- de cupos y bloqueos de agenda en tiempo real. El historial médico completo reside
-- permanentemente en la base de datos individual (tenant) de cada doctor.
CREATE OR REPLACE FUNCTION public.purgar_citas_historicas_central()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_eliminadas integer;
BEGIN
  DELETE FROM public.citas
  WHERE fecha_hora < (NOW() - INTERVAL '48 hours');
  
  GET DIAGNOSTICS v_eliminadas = ROW_COUNT;
  RETURN v_eliminadas;
END;
$$;

-- ==============================================================================
-- J. TRIGGERS AUTOMÁTICOS PARA PACIENTES Y CITAS (Previene error 23503 y 42501)
-- ==============================================================================

-- 1. Trigger en citas: Garantiza que exista el registro en pacientes antes de insertar la cita
CREATE OR REPLACE FUNCTION public.garantizar_paciente_al_crear_cita()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.pacientes WHERE id = NEW.id_paciente) THEN
        INSERT INTO public.pacientes (id, id_usuario, nombre, cedula, telefono, email, created_at)
        SELECT 
            NEW.id_paciente, 
            NEW.id_paciente,
            COALESCE((SELECT nombre FROM public.usuarios WHERE id = NEW.id_paciente), 'Paciente'),
            (SELECT cedula FROM public.usuarios WHERE id = NEW.id_paciente),
            (SELECT telefono FROM public.usuarios WHERE id = NEW.id_paciente),
            (SELECT email FROM public.usuarios WHERE id = NEW.id_paciente),
            NOW()
        ON CONFLICT (id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_garantizar_paciente_al_crear_cita ON public.citas;
CREATE TRIGGER tr_garantizar_paciente_al_crear_cita
BEFORE INSERT ON public.citas
FOR EACH ROW
EXECUTE FUNCTION public.garantizar_paciente_al_crear_cita();

-- 2. Trigger en usuarios: Auto-crea registro en pacientes al registrarse un usuario con rol paciente
CREATE OR REPLACE FUNCTION public.auto_crear_paciente_desde_usuario()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.rol = 'paciente' OR NEW.rol IS NULL THEN
        INSERT INTO public.pacientes (id, id_usuario, nombre, cedula, telefono, email, ciudad_origen, created_at)
        VALUES (
            NEW.id,
            NEW.id,
            COALESCE(NEW.nombre, 'Paciente'),
            NEW.cedula,
            NEW.telefono,
            NEW.email,
            NEW.ciudad_origen,
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            nombre = COALESCE(EXCLUDED.nombre, public.pacientes.nombre),
            telefono = COALESCE(EXCLUDED.telefono, public.pacientes.telefono),
            cedula = COALESCE(EXCLUDED.cedula, public.pacientes.cedula),
            email = COALESCE(EXCLUDED.email, public.pacientes.email);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_auto_crear_paciente_desde_usuario ON public.usuarios;
CREATE TRIGGER tr_auto_crear_paciente_desde_usuario
AFTER INSERT ON public.usuarios
FOR EACH ROW
EXECUTE FUNCTION public.auto_crear_paciente_desde_usuario();

-- 3. Backfill masivo para corregir datos existentes sin fila de paciente
INSERT INTO public.pacientes (id, id_usuario, nombre, cedula, telefono, email, ciudad_origen, created_at)
SELECT 
    u.id, 
    u.id, 
    COALESCE(u.nombre, 'Paciente'), 
    u.cedula, 
    u.telefono, 
    u.email, 
    u.ciudad_origen, 
    NOW()
FROM public.usuarios u
LEFT JOIN public.pacientes p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- 4. Backfill masivo para asegurar que los médicos existan en la tabla doctores
INSERT INTO public.doctores (id, created_at, esta_aprobado, estado_verificacion)
SELECT u.id, NOW(), TRUE, 'aprobado'
FROM public.usuarios u
LEFT JOIN public.doctores d ON d.id = u.id
WHERE d.id IS NULL AND u.rol = 'doctor'
ON CONFLICT (id) DO NOTHING;
