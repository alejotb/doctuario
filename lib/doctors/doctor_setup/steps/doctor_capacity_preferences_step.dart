import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/doctors/components/doctor_logo_config_dialog.dart';
import '../components/doctor_setup_ui_helpers.dart';

class DoctorCapacityPreferencesStep extends StatelessWidget {
  const DoctorCapacityPreferencesStep({
    super.key,
    required this.pacientesPorDia,
    required this.onPacientesPorDiaChanged,
    required this.aceptaTelemedicina,
    required this.onAceptaTelemedicinaChanged,
    required this.aceptaEmergencias,
    required this.onAceptaEmergenciasChanged,
    required this.logoUrl,
    required this.idDoctor,
    required this.onLogoUpdated,
  });

  final int pacientesPorDia;
  final ValueChanged<int> onPacientesPorDiaChanged;
  final bool aceptaTelemedicina;
  final ValueChanged<bool> onAceptaTelemedicinaChanged;
  final bool aceptaEmergencias;
  final ValueChanged<bool> onAceptaEmergenciasChanged;
  final String? logoUrl;
  final String idDoctor;
  final ValueChanged<String?> onLogoUpdated;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Paso 3: Capacidad de Pacientes Diarios
        DoctorSetupCardWrapper(
          icon: Icons.people_outline_rounded,
          iconColor: const Color(0xFFD97706),
          title: '3. Límite de Pacientes por Jornada',
          subtitle: 'Define cuántos pacientes deseas agendar como máximo en cada turno de consulta.',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pacientes por Día',
                        style: GoogleFonts.mooli(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Evita sobrecupos bloqueando citas automáticamente al llegar al límite.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF92400E),
                      ),
                      onPressed: pacientesPorDia > 1
                          ? () => onPacientesPorDiaChanged(pacientesPorDia - 1)
                          : null,
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 44),
                      alignment: Alignment.center,
                      child: Text(
                        '$pacientesPorDia',
                        style: GoogleFonts.mooli(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF92400E),
                      ),
                      onPressed: () => onPacientesPorDiaChanged(pacientesPorDia + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Paso 4: Preferencias adicionales
        DoctorSetupCardWrapper(
          icon: Icons.tune_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: '4. Preferencias de Atención Iniciales',
          subtitle: 'Configuraciones adicionales para tu práctica médica (podrás editar más adelante).',
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Aceptar Consultas Virtuales / Telemedicina',
                  style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Permitir que los pacientes agenden videoconsultas en tu disponibilidad.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                value: aceptaTelemedicina,
                activeTrackColor: const Color(0xFF0284C7),
                onChanged: onAceptaTelemedicinaChanged,
              ),
              const Divider(),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Aceptar Pacientes de Emergencia / Sin Cita',
                  style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Permite agregar cupos de emergencia directamente desde tu panel de agenda.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                value: aceptaEmergencias,
                activeTrackColor: const Color(0xFF0284C7),
                onChanged: onAceptaEmergenciasChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Paso 5: Membrete o Logotipo Médico
        DoctorSetupCardWrapper(
          icon: Icons.business_rounded,
          iconColor: const Color(0xFF0284C7),
          title: '5. Membrete o Logotipo Institucional (Opcional)',
          subtitle:
              'Logotipo de tu clínica o consultorio privado que se incluirá en tus informes y recetas médicas.',
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: logoUrl != null && logoUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.network(
                              logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_hospital_rounded,
                                color: Color(0xFF0284C7),
                                size: 32,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.local_hospital_rounded,
                            color: Color(0xFF0284C7),
                            size: 32,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          logoUrl != null && logoUrl!.isNotEmpty
                              ? 'Logotipo configurado'
                              : 'Sin logotipo configurado',
                          style: GoogleFonts.mooli(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: logoUrl != null && logoUrl!.isNotEmpty
                                ? const Color(0xFF059669)
                                : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Aparecerá en el encabezado de las historias clínicas impresas.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final nuevoLogo = await DoctorLogoConfigDialog.show(
                              context,
                              idDoctor: idDoctor,
                              initialLogoUrl: logoUrl,
                              onLogoUpdated: onLogoUpdated,
                            );
                            if (nuevoLogo != null) {
                              onLogoUpdated(nuevoLogo);
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                          label: Text(
                            logoUrl != null && logoUrl!.isNotEmpty
                                ? 'Gestionar Logotipo'
                                : 'Subir Logotipo',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
