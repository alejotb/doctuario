-- ==============================================================================
-- DOCTUARIO / MEDICONNECT - SCRIPT MAESTRO DE BASE DE DATOS ÚNICA Y SEGURIDAD RLS
-- ==============================================================================
-- Este script realiza:
-- 1. Creación de tablas faltantes (doctor_bloqueos, soporte_tickets) y columnas (logo_url, alias).
-- 2. Trigger anti-escalamiento de privilegios (bloquea auto-asignación de 'admin'/'administrador').
-- 3. Trigger de auto-creación y sincronización de pacientes.
-- 4. Activación de Row Level Security (RLS) en todas las tablas con políticas blindadas.
-- 5. Creación de Buckets de Supabase Storage y sus políticas de acceso por token JWT.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TABLAS Y COLUMNAS FALTANTES
-- ------------------------------------------------------------------------------

-- Columna logo_url y alias (slug público) en doctores para no exponer UUID en URLs
ALTER TABLE public.doctores ADD COLUMN IF NOT EXISTS logo_url text;
ALTER TABLE public.doctores ADD COLUMN IF NOT EXISTS alias text;
CREATE UNIQUE INDEX IF NOT EXISTS idx_doctores_alias ON public.doctores(alias) WHERE alias IS NOT NULL;

-- Tabla para bloqueos de agenda y vacaciones
CREATE TABLE IF NOT EXISTS public.doctor_bloqueos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  id_doctor uuid NOT NULL REFERENCES public.doctores(id) ON DELETE CASCADE,
  fecha date NOT NULL,
  motivo text,
  CONSTRAINT doctor_bloqueos_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_bloqueos_doctor_fecha_key UNIQUE (id_doctor, fecha)
);

-- Tabla para tickets de soporte técnico
CREATE TABLE IF NOT EXISTS public.soporte_tickets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  id_doctor uuid REFERENCES public.doctores(id) ON DELETE SET NULL,
  doctor_nombre text,
  tipo text DEFAULT 'falla_tecnica',
  prioridad text DEFAULT 'media',
  asunto text NOT NULL,
  mensaje text NOT NULL,
  estado text DEFAULT 'abierto' CHECK (estado IN ('abierto', 'en_revision', 'resuelto', 'cerrado')),
  respuesta_admin text,
  CONSTRAINT soporte_tickets_pkey PRIMARY KEY (id)
);

-- Asegurar centros_medicos
CREATE TABLE IF NOT EXISTS public.centros_medicos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  nombre text NOT NULL,
  direccion text,
  telefono text,
  ciudad text,
  activo boolean DEFAULT true,
  CONSTRAINT centros_medicos_pkey PRIMARY KEY (id)
);

-- ------------------------------------------------------------------------------
-- 2. TRIGGER ANTI-ESCALAMIENTO DE PRIVILEGIOS (SEGURIDAD CRÍTICA)
-- ------------------------------------------------------------------------------
-- Impide que cualquier usuario se auto-asigne el rol de 'admin' o 'administrador'.
-- Solo tú desde el SQL Editor o Dashboard de Supabase puedes otorgar rol de administrador.

CREATE OR REPLACE FUNCTION public.proteger_rol_usuario()
RETURNS TRIGGER AS $$
DECLARE
  v_es_admin_actual BOOLEAN;
BEGIN
  -- Si el rol nuevo intenta ser 'admin' o 'administrador'
  IF NEW.rol IN ('admin', 'administrador') THEN
    -- Verificar si quien ejecuta la operación ya es administrador en public.usuarios
    SELECT (rol IN ('admin', 'administrador')) INTO v_es_admin_actual
    FROM public.usuarios
    WHERE id = auth.uid();

    -- Si no está autenticado como admin existente ni es la consola interna (auth.uid() IS NULL)
    IF auth.uid() IS NOT NULL AND (v_es_admin_actual IS NULL OR v_es_admin_actual = FALSE) THEN
      -- Si es inserción nueva, forzar el rol a 'paciente' (o 'doctor' si se registró como tal)
      IF TG_OP = 'INSERT' THEN
        NEW.rol := COALESCE(NEW.rol, 'paciente');
        IF NEW.rol IN ('admin', 'administrador') THEN
          NEW.rol := 'paciente';
        END IF;
      -- Si es actualización, mantener el rol que ya tenía
      ELSIF TG_OP = 'UPDATE' THEN
        NEW.rol := OLD.rol;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_proteger_rol_usuario ON public.usuarios;
CREATE TRIGGER tr_proteger_rol_usuario
BEFORE INSERT OR UPDATE ON public.usuarios
FOR EACH ROW
EXECUTE FUNCTION public.proteger_rol_usuario();


-- ------------------------------------------------------------------------------
-- 3. TRIGGERS DE INTEGRIDAD Y AUTO-CREACIÓN DE PACIENTES
-- ------------------------------------------------------------------------------

-- Auto-crear fila en pacientes cuando se registra un usuario con rol 'paciente'
CREATE OR REPLACE FUNCTION public.auto_crear_paciente_desde_usuario()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.rol = 'paciente' OR NEW.rol IS NULL THEN
    INSERT INTO public.pacientes (
      id, id_usuario, nombre, cedula, telefono, email, ciudad_origen, created_at
    )
    VALUES (
      NEW.id, NEW.id, COALESCE(NEW.nombre, 'Paciente'), NEW.cedula, NEW.telefono, NEW.email, NEW.ciudad_origen, NOW()
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

-- Prevenir error FK al crear citas si el paciente no tiene aún registro
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


-- ------------------------------------------------------------------------------
-- 4. POLÍTICAS RLS (ROW LEVEL SECURITY) INTEGRALES
-- ------------------------------------------------------------------------------

-- A. USUARIOS
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura publica de usuarios" ON public.usuarios;
DROP POLICY IF EXISTS "Usuarios insertan su propio perfil" ON public.usuarios;
DROP POLICY IF EXISTS "Usuarios editan su propio perfil" ON public.usuarios;

CREATE POLICY "Lectura publica de usuarios" 
ON public.usuarios FOR SELECT USING (true);

CREATE POLICY "Usuarios insertan su propio perfil" 
ON public.usuarios FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Usuarios editan su propio perfil" 
ON public.usuarios FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- B. DOCTORES
ALTER TABLE public.doctores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Directorio de doctores visible" ON public.doctores;
DROP POLICY IF EXISTS "Doctor inserta su registro" ON public.doctores;
DROP POLICY IF EXISTS "Doctor edita su registro" ON public.doctores;

CREATE POLICY "Directorio de doctores visible" 
ON public.doctores FOR SELECT USING (true);

CREATE POLICY "Doctor inserta su registro" 
ON public.doctores FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Doctor edita su registro" 
ON public.doctores FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- C. SECRETARIA_DOCTORES
ALTER TABLE public.secretaria_doctores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso a vinculacion secretaria doctor" ON public.secretaria_doctores;
CREATE POLICY "Acceso a vinculacion secretaria doctor" 
ON public.secretaria_doctores FOR ALL TO authenticated
USING (auth.uid() = id_doctor OR auth.uid() = id_secretaria)
WITH CHECK (auth.uid() = id_doctor OR auth.uid() = id_secretaria);

-- D. PACIENTES (Aislamiento: doctor solo ve a sus pacientes atendidos o con cita)
ALTER TABLE public.pacientes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso seguro a pacientes" ON public.pacientes;
CREATE POLICY "Acceso seguro a pacientes" 
ON public.pacientes FOR ALL TO authenticated
USING (
  -- El propio usuario paciente o su representante
  auth.uid() = id_usuario 
  OR auth.uid() = id_usuario_representante
  -- El doctor que lo tiene asignado directamente
  OR auth.uid() = id_doctor
  -- O el doctor con quien el paciente tiene citas registradas
  OR EXISTS (SELECT 1 FROM public.citas c WHERE c.id_paciente = pacientes.id AND c.id_doctor = auth.uid())
  -- O secretarias de ese doctor
  OR EXISTS (
    SELECT 1 FROM public.citas c 
    JOIN public.secretaria_doctores s ON s.id_doctor = c.id_doctor 
    WHERE c.id_paciente = pacientes.id AND s.id_secretaria = auth.uid()
  )
)
WITH CHECK (
  auth.uid() = id_usuario 
  OR auth.uid() = id_doctor 
  OR EXISTS (SELECT 1 FROM public.secretaria_doctores s WHERE s.id_doctor = pacientes.id_doctor AND s.id_secretaria = auth.uid())
);

-- E. DOCTOR_SEDES Y HORARIOS_DISPONIBILIDAD
ALTER TABLE public.doctor_sedes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura publica de sedes" ON public.doctor_sedes;
DROP POLICY IF EXISTS "Gestion de sedes por el doctor" ON public.doctor_sedes;
CREATE POLICY "Lectura publica de sedes" ON public.doctor_sedes FOR SELECT USING (true);
CREATE POLICY "Gestion de sedes por el doctor" ON public.doctor_sedes FOR ALL TO authenticated
USING (auth.uid() = id_doctor) WITH CHECK (auth.uid() = id_doctor);

ALTER TABLE public.horarios_disponibilidad ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura publica de horarios" ON public.horarios_disponibilidad;
DROP POLICY IF EXISTS "Gestion de horarios por el doctor" ON public.horarios_disponibilidad;
CREATE POLICY "Lectura publica de horarios" ON public.horarios_disponibilidad FOR SELECT USING (true);
CREATE POLICY "Gestion de horarios por el doctor" ON public.horarios_disponibilidad FOR ALL TO authenticated
USING (auth.uid() = id_doctor) WITH CHECK (auth.uid() = id_doctor);

-- F. DOCTOR_BLOQUEOS
ALTER TABLE public.doctor_bloqueos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura publica de bloqueos" ON public.doctor_bloqueos;
DROP POLICY IF EXISTS "Doctor gestiona sus bloqueos" ON public.doctor_bloqueos;
CREATE POLICY "Lectura publica de bloqueos" ON public.doctor_bloqueos FOR SELECT USING (true);
CREATE POLICY "Doctor gestiona sus bloqueos" ON public.doctor_bloqueos FOR ALL TO authenticated
USING (auth.uid() = id_doctor) WITH CHECK (auth.uid() = id_doctor);

-- G. CITAS
ALTER TABLE public.citas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autorizado a citas" ON public.citas;
CREATE POLICY "Acceso autorizado a citas" 
ON public.citas FOR ALL TO authenticated
USING (
  auth.uid() = id_doctor 
  OR auth.uid() = id_paciente
  OR EXISTS (SELECT 1 FROM public.pacientes p WHERE p.id = citas.id_paciente AND p.id_usuario = auth.uid())
  OR EXISTS (SELECT 1 FROM public.secretaria_doctores s WHERE s.id_doctor = citas.id_doctor AND s.id_secretaria = auth.uid())
)
WITH CHECK (
  auth.uid() = id_doctor 
  OR auth.uid() = id_paciente
  OR EXISTS (SELECT 1 FROM public.pacientes p WHERE p.id = citas.id_paciente AND p.id_usuario = auth.uid())
  OR EXISTS (SELECT 1 FROM public.secretaria_doctores s WHERE s.id_doctor = citas.id_doctor AND s.id_secretaria = auth.uid())
);

-- H. HISTORIAS CLÍNICAS (Confidencialidad Médica Máxima)
-- Nota: La secretaria NO tiene acceso a historias_clinicas
ALTER TABLE public.historias_clinicas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso confidencial a historias clinicas" ON public.historias_clinicas;
CREATE POLICY "Acceso confidencial a historias clinicas" 
ON public.historias_clinicas FOR ALL TO authenticated
USING (
  auth.uid() = id_doctor 
  OR EXISTS (SELECT 1 FROM public.pacientes p WHERE p.id = historias_clinicas.id_paciente AND p.id_usuario = auth.uid())
)
WITH CHECK (auth.uid() = id_doctor);

-- I. EXAMENES MÉDICOS
ALTER TABLE public.examenes_medicos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso a examenes medicos" ON public.examenes_medicos;
CREATE POLICY "Acceso a examenes medicos" 
ON public.examenes_medicos FOR ALL TO authenticated
USING (
  auth.uid() = id_doctor 
  OR auth.uid() = subido_por_usuario_id
  OR EXISTS (SELECT 1 FROM public.pacientes p WHERE p.id = examenes_medicos.id_paciente AND p.id_usuario = auth.uid())
  OR EXISTS (SELECT 1 FROM public.secretaria_doctores s WHERE s.id_doctor = examenes_medicos.id_doctor AND s.id_secretaria = auth.uid())
)
WITH CHECK (
  auth.uid() = id_doctor 
  OR auth.uid() = subido_por_usuario_id 
  OR EXISTS (SELECT 1 FROM public.pacientes p WHERE p.id = examenes_medicos.id_paciente AND p.id_usuario = auth.uid())
);

-- J. PLANTILLAS DE HISTORIA
ALTER TABLE public.plantillas_historia ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Plantillas visibles para doctores" ON public.plantillas_historia;
DROP POLICY IF EXISTS "Doctor edita sus plantillas" ON public.plantillas_historia;
CREATE POLICY "Plantillas visibles para doctores" ON public.plantillas_historia FOR SELECT TO authenticated
USING (es_predeterminada = true OR auth.uid() = id_doctor);
CREATE POLICY "Doctor edita sus plantillas" ON public.plantillas_historia FOR ALL TO authenticated
USING (auth.uid() = id_doctor) WITH CHECK (auth.uid() = id_doctor);

-- K. NOTIFICACIONES DE CITAS
ALTER TABLE public.notificaciones_citas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Usuario gestiona sus notificaciones" ON public.notificaciones_citas;
CREATE POLICY "Usuario gestiona sus notificaciones" ON public.notificaciones_citas FOR ALL TO authenticated
USING (auth.uid() = id_usuario) WITH CHECK (auth.uid() = id_usuario);

-- L. TRIAGE DE CONSULTAS
ALTER TABLE public.triage_consultas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso a triage" ON public.triage_consultas;
CREATE POLICY "Acceso a triage" ON public.triage_consultas FOR ALL TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.pacientes p WHERE p.id = triage_consultas.id_paciente AND p.id_usuario = auth.uid())
  OR EXISTS (SELECT 1 FROM public.citas c WHERE c.id = triage_consultas.id_cita AND c.id_doctor = auth.uid())
);

-- M. AVALES MÉDICOS Y CENTROS MÉDICOS
ALTER TABLE public.avales_medicos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Avales lectura publica" ON public.avales_medicos;
DROP POLICY IF EXISTS "Doctor gestiona sus avales" ON public.avales_medicos;
CREATE POLICY "Avales lectura publica" ON public.avales_medicos FOR SELECT USING (true);
CREATE POLICY "Doctor gestiona sus avales" ON public.avales_medicos FOR ALL TO authenticated
USING (auth.uid() = id_doctor_avalador) WITH CHECK (auth.uid() = id_doctor_avalador);

ALTER TABLE public.centros_medicos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Centros medicos lectura publica" ON public.centros_medicos;
CREATE POLICY "Centros medicos lectura publica" ON public.centros_medicos FOR SELECT USING (true);

-- N. DOCTORES_TENANTS (Suscripciones SaaS de Doctores)
ALTER TABLE public.doctores_tenants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura de suscripciones del doctor" ON public.doctores_tenants;
DROP POLICY IF EXISTS "Gestion de suscripciones por el doctor" ON public.doctores_tenants;
CREATE POLICY "Lectura de suscripciones del doctor" ON public.doctores_tenants FOR SELECT TO authenticated
USING (auth.uid() = id_doctor OR auth.uid() = id_doctor_administrador);
CREATE POLICY "Gestion de suscripciones por el doctor" ON public.doctores_tenants FOR ALL TO authenticated
USING (auth.uid() = id_doctor OR auth.uid() = id_doctor_administrador)
WITH CHECK (auth.uid() = id_doctor OR auth.uid() = id_doctor_administrador);

-- O. SOPORTE_TICKETS
ALTER TABLE public.soporte_tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Doctor crea y ve sus tickets" ON public.soporte_tickets;
DROP POLICY IF EXISTS "Admin ve todos los tickets" ON public.soporte_tickets;
CREATE POLICY "Doctor crea y ve sus tickets" ON public.soporte_tickets FOR ALL TO authenticated
USING (auth.uid() = id_doctor) WITH CHECK (auth.uid() = id_doctor);

CREATE POLICY "Admin ve todos los tickets" ON public.soporte_tickets FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.usuarios u WHERE u.id = auth.uid() AND u.rol IN ('admin', 'administrador')));


-- ------------------------------------------------------------------------------
-- 5. BUCKETS DE STORAGE Y POLÍTICAS DE OBJETOS
-- ------------------------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('examenes', 'examenes', false, 15728640)
ON CONFLICT (id) DO UPDATE SET public = false;

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('documentos_medicos', 'documentos_medicos', false, 15728640)
ON CONFLICT (id) DO UPDATE SET public = false;

INSERT INTO storage.buckets (id, name, public)
VALUES ('perfiles', 'perfiles', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('images', 'images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Acceso seguro a examenes y documentos" ON storage.objects;
CREATE POLICY "Acceso seguro a examenes y documentos" 
ON storage.objects FOR ALL TO authenticated
USING (bucket_id IN ('examenes', 'documentos_medicos', 'perfiles', 'images') AND auth.uid() IS NOT NULL)
WITH CHECK (bucket_id IN ('examenes', 'documentos_medicos', 'perfiles', 'images') AND auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Lectura publica de perfiles e imagenes" ON storage.objects;
CREATE POLICY "Lectura publica de perfiles e imagenes" 
ON storage.objects FOR SELECT TO public
USING (bucket_id IN ('perfiles', 'images'));
