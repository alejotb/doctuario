# MediConnect / Doctuario - Master Plan de Acción, Auditoría de Seguridad y Especificación Funcional

**Fecha de Actualización:** 2026-11-20  
**Ubicación de Respaldo Local:** `PLAN_DE_ACCION_RECUPERADO.md` (Raíz del proyecto)  
**Estado de la Base de Datos:** **100% VERIFICADA Y ASEGURADA EN SUPABASE**  
- 17 tablas activas (incluyendo `doctor_bloqueos`, `soporte_tickets`, `centros_medicos`).
- Columnas `logo_url` y `alias` integradas en `doctores`.
- 4 Buckets de Storage configurados (`examenes`, `documentos_medicos` privados; `perfiles`, `images` públicos).
- Políticas RLS y Triggers de protección de rol admin activos.

---

## 1. Regla Inquebrantable de Historial: Citas Permanentes (Cero Purgas)

> [!IMPORTANT]
> **Las citas son el registro médico y legal de atención: NUNCA se eliminan por antigüedad.**
> En la arquitectura anterior con base central temporal existía una función (`purgar_citas_historicas_central`) que borraba citas mayores a 48 horas.
> **En la Base de Datos Única, las citas se conservan permanentemente.**
> El ciclo de vida de una cita solo se maneja por su columna `estado`:
> `'solicitada'` | `'confirmada'` | `'en_espera'` | `'atendida'` | `'cancelada'` | `'reprogramada'`.

---

## 2. Hoja de Ruta de Implementación en Código (Flutter / Dart)

### Módulo 1: Unificación de Backend y Eliminación de Base Dual  [ESTADO: COMPLETADO ✅]
- [x] Unificar `DualDatabaseConfig`: todas las llamadas hacia el cliente principal de Supabase (`SupaFlow.client` / `Supabase.instance.client`).
- [x] Eliminar cualquier intento de inicializar clientes secundarios o URLs remotas separadas.
- [x] Crear las clases de modelo en `lib/backend/supabase/database/tables/` para `doctor_bloqueos`, `soporte_tickets` y `doctores_tenants`.
- [x] Actualizar el modelo de `doctores` para incluir `alias`.
- [x] Exportar todas las tablas en `database.dart`.
- [x] Actualizar `DoctorDatabaseProvisioner` para verificar la salud de las 17 tablas unificadas.

---

### Módulo 2: Autenticación, Roles y Enrutamiento Directo  [ESTADO: COMPLETADO ✅]
- [x] **Paso 2.1:** Corregir la navegación en `main.dart` (`NavBarPage`) y agregar `SkeletonPageLoader` con variantes correlacionadas por página (`agenda`, `list`, `profile`, `generic`).
- [x] **Paso 2.2:** Flujo de registro médico: estado inicial `'pendiente'`, bloqueo estricto hasta aprobación del SuperAdmin, pantalla amigable *"Estamos configurando tu cuenta"* y soporte para solicitud de número de registro médico (`solicitud_credenciales`).
- [x] **Paso 2.3:** Flujo de secretarias: ingreso con vista de paciente hasta confirmación activa del doctor (`activo = true` en `secretaria_doctores`), búsqueda de usuarios con rol `paciente` o `secretaria` (por nombre, correo o cédula) para asignar permisos, y solicitud bidireccional desde *Mi Cuenta*.

---

### Módulo 3: Agenda, Modalidad "Orden de Llegada" y UX de Escritorio  [EN PROGRESO]
- [x] **Paso 3.1:** Limpieza visual en escritorio (quitar lápiz y botón redundante debajo del paciente en `doctor_agenda_desktop_view.dart`) y cambiar mensajes de vacaciones por *"El doctor no estará disponible"*.
- [ ] **Paso 3.2:** Soporte para modalidad "Por Orden de Llegada": no solicitar hora fija, agrupar pacientes del día en lista de espera, confirmación de llegada y Drag & Drop sincronizado en tiempo real entre doctor y secretaria.
- [ ] **Paso 3.3:** Cancelación y reprogramación con motivo (individual y masiva para el día completo) e historial permanente de citas en agenda.

---

### Módulo 4: Consulta Médica, Historias, Récipes y Exámenes
- [ ] Inmutabilidad de nombres: evitar que pacientes manuales no registrados sean renombrados como "Paciente".
- [ ] Corrección en `DoctorPacientesListWidget`: consultar exclusivamente pacientes asociados a citas o historias del doctor, conservando sus nombres y fichas completas.
- [ ] Récipe médico: cargar `logo_url`, especialidad real (no "médico general"), opciones de media hoja/hoja completa y bloques vs texto libre.
- [ ] Exámenes médicos: vinculación a `id_cita` y soporte para descarga de formatos especiales (ECG, etc.).
- [ ] Resolver desbordamiento visual y texto duplicado ("Consulta del...") en el resumen del paciente.
- [ ] Apartado dedicado de Borradores para notas y récipes.

---

### Módulo 5: Compartir Perfil, Modo "Burbuja" y Soporte Técnico
- [ ] Enlace público con `alias` en lugar de UUID.
- [ ] Mensaje de WhatsApp limpio (ejemplo: *"8:00 AM a 5:00 PM"*), sin timestamps ISO.
- [ ] Resolver bloqueo de navegación al visualizar un perfil compartido.
- [ ] Quitar botones duplicados de compartir (dejar 1) y de agendar (dejar 1).
- [ ] Switch de Modo "Burbuja" (software privado vs catálogo público).
- [ ] Módulo de Soporte Técnico en el perfil con envío a `soporte_tickets` y panel de SuperAdmin para visualización y resolución.

---

### Módulo 6: Planes SaaS y Verificación de Médicos
- [ ] Panel administrativo para verificar y aprobar credenciales médicas.
- [ ] Planes de suscripción mensual ($25 - $30 / mes: individual, dúo, clínica) con invitaciones por correo.
