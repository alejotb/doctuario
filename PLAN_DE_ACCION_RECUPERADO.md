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

### Módulo 3: Agenda, Modalidad "Orden de Llegada" y UX de Escritorio  [ESTADO: COMPLETADO ✅]
- [x] **Paso 3.1:** Limpieza visual en escritorio (quitar lápiz y botón redundante debajo del paciente en `doctor_agenda_desktop_view.dart`) y cambiar mensajes de vacaciones por *"El doctor no estará disponible"*.
- [x] **Paso 3.2:** Modalidad "Por Orden de Llegada" sin exigir hora fija en citas manuales (`ManualAppointmentDialog` + `AppointmentVenueDatetimeSection`), asignación automática de turno/cola, corrección de filtro de sede en secretaría y sincronización en tiempo real (Supabase Realtime) entre doctor y secretaria.
- [x] **Paso 3.3:** Cancelación y reprogramación con motivo obligatorio/explícito (`AgendaAppointmentActions.pedirMotivoYCancelar`, `EditAppointmentDialog` y `ManageDayAppointmentsDialog` para día completo), unificación de `AppointmentCancellationService` a base única y aislamiento estricto de citas por `widget.idDoctor` conservando el historial permanente.

---

### Módulo 4: Consulta Médica, Historias, Récipes y Exámenes  [ESTADO: COMPLETADO ✅]
- [x] **Paso 4.1:** Aislamiento estricto en `DoctorPacientesListWidget` (mostrar únicamente pacientes con citas/historias o asignados al doctor) y preservación de nombres reales de pacientes manuales en `DoctorPacientesListWidget` y `DoctorConsultasRealizadasWidget` (incluyendo estado `atendida`).
- [x] **Paso 4.2:** Récipe médico (`MedicalReportPrinterService` + `PatientHistoryTab`): carga automática de `logo_url` y especialidad real del médico, selector de impresión en Hoja Completa o Media Hoja, y alternancia entre formato Por Bloques o Texto Completo editable.
- [x] **Paso 4.3:** Exámenes médicos: vinculación a `id_cita` (`ManualAppointmentDialog`), soporte para descarga directa de formatos especiales como ECG/DICOM/XML (`MedicalExamViewerDialog` + `FileType.any`), y búsqueda/ordenamiento por fecha, nombre o tipo (`PatientExamsWidget`).
- [x] **Paso 4.4:** Resolución de desbordamiento horizontal y duplicados de *"Consulta del..."* en `PatientInBoxCard` (con modal de detalle al hacer clic) y apartado de Borradores en `DoctorConsultasRealizadasWidget`.

---

### Módulo 5: Compartir Perfil, Modo "Burbuja" y Soporte Técnico  [ESTADO: COMPLETADO ✅]
- [x] **Paso 5.1:** Enlace público con `alias` en lugar de UUID (`DoctorShareHelper` + `DoctorPublicProfileWidget` + `nav.dart`), formato limpio de horas en WhatsApp (*"8:00 AM a 5:00 PM"*), desbloqueo de navegación de regreso al inicio y eliminación de botones duplicados de compartir.
- [x] **Paso 5.2:** Switch de Modo "Burbuja" + editor de `alias` público (`DoctorSoloModeDialog`) y control de colisión de horarios al crear/editar sedes con opciones *Sobreescribir*, *Omitir días repetidos* o *Cancelar* (`DoctorSedesConfigWidget`).
- [x] **Paso 5.3:** Módulo de Soporte Técnico en el perfil del médico (`MyAccountWidget` + `DoctorSupportDialog`) con envío a `soporte_tickets`, notificación a administradores y panel de SuperAdmin para visualización y resolución (`AdminSupportTicketsModal`).

---

### Módulo 6: Planes SaaS y Verificación de Médicos  [ESTADO: COMPLETADO ✅]
- [x] **Paso 6.1:** Panel administrativo para verificar/aprobar credenciales médicas o solicitar número de registro (`AdminDoctorTenantsModalWidget` + `AdminTenantService.solicitarCredencialesDoctor`), precios SaaS ajustados ($25/mes individual y planes grupales con descuento) e invitación por correo (`invitarDoctorAPlanGrupo`).
