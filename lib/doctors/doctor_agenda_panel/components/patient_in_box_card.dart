import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/gemini_ai_service.dart';
import '../../../services/i18n_service.dart';
import '../../components/doctor_gemini_config_dialog.dart';
import '../../doctor_consultation/doctor_consultation_workspace_widget.dart';
import '../dialogs/edit_vitals_dialog.dart';
import '../dialogs/appointment_studies_procedures_modal.dart';

/// Tarjeta que muestra el paciente en consulta activa / seleccionado con signos vitales y antecedentes.
class PatientInBoxCard extends StatelessWidget {
  final CitasRow? citaSeleccionada;
  final UsuariosRow? pacienteSeleccionado;
  final PacientesRow? pacienteDetalleSeleccionado;
  final bool cargandoHistoriaPaciente;
  final List<HistoriasClinicasRow> historiasPreviasPaciente;
  final String idDoctor;
  final VoidCallback onAbrirFichaReceta;
  final VoidCallback onVerHistoriaCompleta;
  final VoidCallback? onVitalsActualizados;
  final VoidCallback? onIniciarConsulta;

  const PatientInBoxCard({
    super.key,
    required this.citaSeleccionada,
    required this.pacienteSeleccionado,
    required this.pacienteDetalleSeleccionado,
    required this.cargandoHistoriaPaciente,
    required this.historiasPreviasPaciente,
    required this.idDoctor,
    required this.onAbrirFichaReceta,
    required this.onVerHistoriaCompleta,
    this.onVitalsActualizados,
    this.onIniciarConsulta,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = I18nService.instance.isSpanish;
    if (citaSeleccionada == null || pacienteSeleccionado == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.person_pin_circle_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                isEs
                    ? 'Selecciona un paciente en la agenda para ver su ficha y signos.'
                    : 'Select a patient from the schedule to view their chart and vitals.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final p = pacienteSeleccionado!;
    final pDetalle = pacienteDetalleSeleccionado;
    final esEnConsulta = citaSeleccionada?.estado == 'en_consulta';

    String pa = '?', fc = '?', temp = '?', spo2 = '?';
    try {
      if (citaSeleccionada?.notasMedicas != null && citaSeleccionada!.notasMedicas!.isNotEmpty) {
        final d = jsonDecode(citaSeleccionada!.notasMedicas!);
        if (d is Map) {
          pa = d['pa']?.toString() ?? '?'; fc = d['fc']?.toString() ?? '?';
          temp = d['temp']?.toString() ?? '?'; spo2 = d['spo2']?.toString() ?? '?';
        }
      }
    } catch (_) {}

    final sang = pDetalle?.tipoSangre ?? p.data['tipo_sangre']?.toString();
    final unknownBlood = isEs ? 'Desconocido' : 'Unknown';
    final sangreStr = (sang != null && sang.isNotEmpty) ? sang : unknownBlood;
    final tieneSangre = sangreStr != unknownBlood && sangreStr != 'Desconocido';
    final medicamentosActivos = _obtenerMedicamentosActivos(isEs);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: esEnConsulta ? const Color(0xFF34D399) : Colors.amber, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  esEnConsulta
                      ? (isEs ? 'PACIENTE EN CONSULTA ACTIVA' : 'PATIENT IN ACTIVE CONSULTATION')
                      : (isEs ? 'PACIENTE SELECCIONADO' : 'SELECTED PATIENT'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE0F2FE),
                      backgroundImage: (p.fotoUrl != null && p.fotoUrl!.isNotEmpty) ? NetworkImage(p.fotoUrl!) : null,
                      child: (p.fotoUrl == null || p.fotoUrl!.isEmpty) ? const Icon(Icons.person, color: Color(0xFF0284C7), size: 28) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nombre ?? (isEs ? 'Paciente' : 'Patient'),
                              style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          Text('${isEs ? "Cédula" : "ID"}: ${p.cedula ?? "N/A"} • ${p.ciudadOrigen ?? "Valera"}',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.monitor_heart_outlined, size: 14, color: Color(0xFF0284C7)),
                              const SizedBox(width: 5),
                              Text(
                                isEs ? 'Signos Vitales & Grupo Sanguíneo' : 'Vital Signs & Blood Type',
                                style: GoogleFonts.mooli(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              if (citaSeleccionada != null) {
                                EditVitalsDialog.show(
                                  context,
                                  cita: citaSeleccionada!,
                                  idPaciente: citaSeleccionada!.idPaciente,
                                  initialPA: pa == '?' ? '' : pa,
                                  initialFC: fc == '?' ? '' : fc,
                                  initialTemp: temp == '?' ? '' : temp,
                                  initialSpO2: spo2 == '?' ? '' : spo2,
                                  initialTipoSangre: sangreStr,
                                  onVitalsActualizados: onVitalsActualizados ?? () {},
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_note_rounded, size: 15, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 3),
                                  Text(isEs ? 'Rellenar / Editar' : 'Fill / Edit',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildVitalItem(isEs ? 'Presión Art.' : 'Blood Press.', pa, pa != '?' ? 'mmHg' : '', pa != '?' ? const Color(0xFF1E293B) : Colors.grey.shade400),
                          _buildVitalDivider(),
                          _buildVitalItem(isEs ? 'Frec. Card.' : 'Heart Rate', fc, fc != '?' ? (isEs ? 'lpm' : 'bpm') : '', fc != '?' ? const Color(0xFF1E293B) : Colors.grey.shade400),
                          _buildVitalDivider(),
                          _buildVitalItem(isEs ? 'Temperatura' : 'Temperature', temp, temp != '?' ? '°C' : '', temp != '?' ? const Color(0xFF1E293B) : Colors.grey.shade400),
                          _buildVitalDivider(),
                          _buildVitalItem(isEs ? 'Saturación' : 'Saturation', spo2, spo2 != '?' ? '% SpO2' : '', spo2 != '?' ? const Color(0xFF059669) : Colors.grey.shade400),
                          _buildVitalDivider(),
                          _buildVitalItem(isEs ? 'G. Sanguíneo' : 'Blood Type', sangreStr, '', tieneSangre ? const Color(0xFFE11D48) : Colors.grey.shade400),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.medication_liquid_rounded, size: 15, color: Color(0xFF0D9488)),
                    const SizedBox(width: 5),
                    Text(
                      isEs ? 'Medicamentos Actuales & Duración:' : 'Current Medications & Duration:',
                      style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F766E)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (medicamentosActivos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCCFBF1))),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF0D9488)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isEs ? 'Sin medicamentos activos registrados actualmente.' : 'No active medications currently recorded.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF115E59), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(children: medicamentosActivos.take(2).map((m) => _buildMedItem(m, isEs)).toList()),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEs ? 'Síntomas & Consultas Pasadas:' : 'Symptoms & Past Consultations:',
                        style: GoogleFonts.mooli(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                    if (historiasPreviasPaciente.isNotEmpty) _buildIaSummaryTrigger(context, isEs),
                  ],
                ),
                const SizedBox(height: 6),
                if (cargandoHistoriaPaciente)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                else if (historiasPreviasPaciente.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
                    child: Text(
                      isEs
                          ? 'Primera consulta registrada para este paciente o sin antecedentes previos documentados.'
                          : 'First consultation recorded for this patient or no previous history documented.',
                      style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                    ),
                  )
                else ...[
                  Builder(
                    builder: (ctx) {
                      final seenKeys = <String>{};
                      final unicas = <HistoriasClinicasRow>[];
                      for (final h in historiasPreviasPaciente) {
                        final key = (h.idCita != null && h.idCita!.isNotEmpty)
                            ? 'cita_${h.idCita}'
                            : 'id_${h.id}';
                        if (seenKeys.add(key)) {
                          unicas.add(h);
                        }
                      }
                      return Column(
                        children: unicas
                            .take(2)
                            .map((h) => _buildConsultaPreviaItem(ctx, h, isEs))
                            .toList(),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (esEnConsulta || citaSeleccionada?.data['es_borrador'] == true)
                          ? const Color(0xFFD97706)
                          : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    icon: Icon(
                      (esEnConsulta || citaSeleccionada?.data['es_borrador'] == true)
                          ? Icons.edit_note_rounded
                          : Icons.medical_services_rounded,
                      size: 18,
                    ),
                    label: Text(
                      (esEnConsulta || citaSeleccionada?.data['es_borrador'] == true)
                          ? (isEs ? 'Continuar Consulta (Borrador Activo)' : 'Resume Consultation (Draft)')
                          : (isEs ? 'Atender / Iniciar Consulta Médica' : 'Start Medical Consultation'),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (onIniciarConsulta != null) {
                        onIniciarConsulta!();
                      } else if (citaSeleccionada != null) {
                        DoctorConsultationWorkspaceWidget.open(
                          context,
                          idDoctor: idDoctor,
                          cita: citaSeleccionada!,
                          paciente: pacienteSeleccionado,
                          onConsultaFinalizada: onVitalsActualizados ?? () {},
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.edit_note_rounded, size: 15),
                        label: Text(isEs ? 'Receta / Ficha' : 'Prescription', style: const TextStyle(fontSize: 11.5)),
                        onPressed: onAbrirFichaReceta,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.history_edu_rounded, size: 15),
                        label: Text(isEs ? 'Historia Completa' : 'Full History', style: const TextStyle(fontSize: 11.5)),
                        onPressed: onVerHistoriaCompleta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7), side: const BorderSide(color: Color(0xFFBAE6FD)),
                      padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (citaSeleccionada != null) {
                        AppointmentStudiesProceduresModal.show(context, cita: citaSeleccionada!, paciente: pacienteSeleccionado, idDoctor: idDoctor, idUsuarioOperador: idDoctor, onHorariosRecalculados: onVitalsActualizados ?? () {});
                      }
                    },
                    icon: const Icon(Icons.biotech_rounded, size: 16),
                    label: Text(isEs ? 'Estudios & Procedimientos (Recalcular Horarios)' : 'Studies & Procedures (Recalculate)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedItem(Map<String, String> m, bool isEs) => Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
        child: Row(
          children: [
            const Icon(Icons.medication_rounded, size: 15, color: Color(0xFF16A34A)),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['medicamento']!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF14532D)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${isEs ? "Prescrito" : "Prescribed"}: ${m['fecha']}', style: const TextStyle(fontSize: 9.5, color: Color(0xFF166534))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF86EFAC))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 11, color: Color(0xFF15803D)),
                  const SizedBox(width: 3),
                  Text(m['tiempo']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildConsultaPreviaItem(
      BuildContext context, HistoriasClinicasRow h, bool isEs) {
    final fechaStr = DateFormat('dd/MM/yyyy').format(h.createdAt);
    final diag = (h.diagnostico ?? '').trim();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.history_edu_rounded,
                    color: Color(0xFF0284C7), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${isEs ? "Consulta del" : "Visit on"} $fechaStr',
                    style: GoogleFonts.mooli(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (h.motivoConsulta?.isNotEmpty ?? false) ...[
                    Text(isEs ? 'Motivo:' : 'Reason:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(h.motivoConsulta!,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                  ],
                  if (h.sintomas?.isNotEmpty ?? false) ...[
                    Text(isEs ? 'Síntomas:' : 'Symptoms:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(h.sintomas!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                  ],
                  if (h.examenFisico?.isNotEmpty ?? false) ...[
                    Text(isEs ? 'Examen Físico:' : 'Physical Exam:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(h.examenFisico!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                  ],
                  if (diag.isNotEmpty) ...[
                    Text(isEs ? 'Diagnóstico:' : 'Diagnosis:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(diag,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                  ],
                  if (h.tratamiento?.isNotEmpty ?? false) ...[
                    Text(isEs ? 'Tratamiento:' : 'Treatment:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(h.tratamiento!, style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isEs ? 'Cerrar' : 'Close'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onVerHistoriaCompleta();
                },
                child: Text(isEs ? 'Ver Historia Completa' : 'Full History'),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                size: 15, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                diag.isNotEmpty
                    ? '${isEs ? "Consulta del" : "Visit on"} $fechaStr • $diag'
                    : '${isEs ? "Consulta del" : "Visit on"} $fechaStr',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded,
                size: 13, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _obtenerMedicamentosActivos(bool isEs) {
    final List<Map<String, String>> result = [];
    for (final h in historiasPreviasPaciente) {
      String med = '', tiempo = '';
      final fechaStr = DateFormat('dd/MM/yyyy').format(h.createdAt);
      if (h.datosHistoriaJson is Map) {
        final map = h.datosHistoriaJson as Map;
        med = map['medicamentos']?.toString() ?? '';
        tiempo = map['tiempo_tratamiento']?.toString() ?? '';
      }
      if (med.isEmpty && h.tratamiento != null && h.tratamiento!.isNotEmpty) {
        final trat = h.tratamiento!;
        for (final part in trat.split('|')) {
          final t = part.trim();
          if (t.startsWith('Medicamentos:')) med = t.replaceFirst('Medicamentos:', '').trim();
          if (t.startsWith('Duración:')) tiempo = t.replaceFirst('Duración:', '').trim();
        }
        if (med.isEmpty) med = trat;
      }
      if (med.isNotEmpty) {
        result.add({'medicamento': med, 'tiempo': tiempo.isNotEmpty ? tiempo : (isEs ? 'Según indicación' : 'As directed'), 'fecha': fechaStr});
      }
    }
    return result;
  }

  Widget _buildVitalItem(String label, String value, String unit, Color color) => Expanded(
        child: Column(children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
          Text(unit, style: TextStyle(fontSize: 8.5, color: Colors.grey.shade400)),
        ]),
      );

  Widget _buildVitalDivider() => Container(width: 1, height: 28, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 2));

  Widget _buildIaSummaryTrigger(BuildContext context, bool isEs) {
    final hasKey = GeminiAiService.instance.hasKey;
    return InkWell(
      onTap: () {
        if (!hasKey) {
          DoctorGeminiConfigDialog.show(context);
          return;
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(children: [const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5), size: 18), const SizedBox(width: 6), Text(isEs ? 'Evolución con IA (Gemini 3.8)' : 'AI Clinical Summary (Gemini 3.8)', style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold))]),
            content: FutureBuilder<String?>(
              future: GeminiAiService.instance.summarizePatientHistory(historiasPreviasPaciente),
              builder: (ctx, snap) => snap.connectionState == ConnectionState.waiting
                  ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
                  : Text(snap.data ?? (isEs ? 'Sin información suficiente para resumir.' : 'Not enough information to summarize.'), style: const TextStyle(fontSize: 12.5)),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEs ? 'Cerrar' : 'Close'))],
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 12, color: hasKey ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8)),
            const SizedBox(width: 3),
            Text(hasKey ? (isEs ? 'Resumen IA' : 'AI Summary') : (isEs ? 'IA Apagada' : 'AI Off'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: hasKey ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}
