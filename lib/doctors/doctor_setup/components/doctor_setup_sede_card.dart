import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/components/map_location_picker_dialog.dart';
import '/services/location_maps_service.dart';
import '/services/medical_centers_service.dart';
import '/services/venezuela_locations.dart';
import 'doctor_setup_sede_item_model.dart';
import 'doctor_setup_ui_helpers.dart';

/// Tarjeta configurable para una Sede médica específica con sus propios
/// datos de ubicación, centro médico, días y horarios de atención.
class DoctorSetupSedeCard extends StatelessWidget {
  final int index;
  final DoctorSetupSedeEntry sede;
  final String doctorNombre;
  final List<DoctorSetupSedeEntry> todasLasSedes;
  final List<CentroMedicoItem> centrosMedicos;
  final bool cargandoCentros;
  final VoidCallback onMostrarModalCrearCentro;
  final VoidCallback onEstadoChanged;
  final VoidCallback onCiudadChanged;
  final VoidCallback onEliminarSede;
  final VoidCallback onActualizarUI;

  const DoctorSetupSedeCard({
    super.key,
    required this.index,
    required this.sede,
    this.doctorNombre = '',
    required this.todasLasSedes,
    required this.centrosMedicos,
    required this.cargandoCentros,
    required this.onMostrarModalCrearCentro,
    required this.onEstadoChanged,
    required this.onCiudadChanged,
    required this.onEliminarSede,
    required this.onActualizarUI,
  });

  Future<void> _seleccionarHora(BuildContext context, bool esInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: esInicio ? sede.horaInicio : sede.horaFin,
    );
    if (!context.mounted) return;
    if (picked != null) {
      for (final dia in sede.diasSeleccionados) {
        final conflicto = DoctorSetupSedeEntry.verificarConflictoHorario(
          todasLasSedes: todasLasSedes, indexSedeActual: index, dia: dia,
          inicio: esInicio ? picked : sede.horaInicio, fin: esInicio ? sede.horaFin : picked,
        );
        if (conflicto != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $conflicto'), backgroundColor: Colors.orange.shade800));
          return;
        }
      }
      if (esInicio) { sede.horaInicio = picked; } else { sede.horaFin = picked; }
      onActualizarUI();
    }
  }

  Future<void> _seleccionarHoraAlmuerzo(BuildContext context, bool esInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: esInicio ? sede.horaInicioAlmuerzo : sede.horaFinAlmuerzo,
    );
    if (picked != null) {
      if (esInicio) { sede.horaInicioAlmuerzo = picked; } else { sede.horaFinAlmuerzo = picked; }
      onActualizarUI();
    }
  }

  void _onToggleDia(BuildContext context, int dia, bool selected) {
    if (selected) {
      final conflicto = DoctorSetupSedeEntry.verificarConflictoHorario(
        todasLasSedes: todasLasSedes, indexSedeActual: index, dia: dia,
        inicio: sede.horaInicio, fin: sede.horaFin,
      );
      if (conflicto != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $conflicto'), backgroundColor: Colors.orange.shade800, duration: const Duration(seconds: 4)));
        return;
      }
      sede.diasSeleccionados.add(dia);
    } else {
      if (sede.diasSeleccionados.length > 1) {
        sede.diasSeleccionados.remove(dia);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Cada sede debe tener al menos un día asignado.'), backgroundColor: Colors.orange));
      }
    }
    onActualizarUI();
  }

  @override
  Widget build(BuildContext context) {
    final estados = VenezuelaLocations.getEstados();
    final diasOcupadosOtraSede = DoctorSetupSedeEntry.getMapaDiasOcupados(todasLasSedes, excluirIndex: index);
    final diasLibres = DoctorSetupSedeEntry.getDiasLibresRestantes(todasLasSedes);
    final sugerenciasNombre = DoctorSetupSedeEntry.generarSugerenciasNombreConsultorio(doctorNombre);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: index == 0 ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0), width: index == 0 ? 1.5 : 1.0),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: index == 0 ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.store_mall_directory_rounded, color: index == 0 ? const Color(0xFF0284C7) : const Color(0xFF64748B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    index == 0 ? 'Sede #1 (Sede Principal)' : 'Sede #${index + 1}',
                    style: GoogleFonts.mooli(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ),
                if (index > 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626), visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Quitar Sede', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: onEliminarSede,
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
                    Expanded(
                      child: DoctorSetupChoiceChip(
                        label: 'Clínica / Hospital',
                        subtitle: 'Consultorio en centro de salud',
                        icon: Icons.local_hospital_rounded,
                        selected: sede.tipoLugar == 'clinica',
                        onTap: () { sede.tipoLugar = 'clinica'; onActualizarUI(); },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DoctorSetupChoiceChip(
                        label: 'Consultorio Privado',
                        subtitle: 'Local o centro independiente',
                        icon: Icons.business_rounded,
                        selected: sede.tipoLugar == 'privado',
                        onTap: () {
                          sede.tipoLugar = 'privado';
                          if (sede.nombreSedeCtrl.text.trim().isEmpty && sugerenciasNombre.isNotEmpty) {
                            sede.nombreSedeCtrl.text = sugerenciasNombre.first;
                          }
                          onActualizarUI();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(sede.estado),
                        initialValue: estados.contains(sede.estado) ? sede.estado : estados.first,
                        decoration: const InputDecoration(labelText: 'Estado', isDense: true, border: OutlineInputBorder()),
                        items: estados.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            sede.estado = val;
                            sede.ciudadesDisponibles = VenezuelaLocations.getCiudadesPorEstado(val);
                            sede.ciudad = sede.ciudadesDisponibles.isNotEmpty ? sede.ciudadesDisponibles.first : '';
                            onEstadoChanged();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('${sede.estado}_${sede.ciudad}'),
                        initialValue: sede.ciudadesDisponibles.contains(sede.ciudad) ? sede.ciudad : (sede.ciudadesDisponibles.isNotEmpty ? sede.ciudadesDisponibles.first : null),
                        decoration: const InputDecoration(labelText: 'Ciudad', isDense: true, border: OutlineInputBorder()),
                        items: sede.ciudadesDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            sede.ciudad = val;
                            onCiudadChanged();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sede.tipoLugar == 'clinica') ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<CentroMedicoItem>(
                          key: ValueKey(sede.centroSeleccionado?.id ?? 'none'),
                          initialValue: centrosMedicos.any((c) => c.id == sede.centroSeleccionado?.id)
                              ? centrosMedicos.firstWhere((c) => c.id == sede.centroSeleccionado?.id)
                              : (centrosMedicos.isNotEmpty ? centrosMedicos.first : null),
                          decoration: const InputDecoration(labelText: 'Clínica / Centro Médico', isDense: true, border: OutlineInputBorder()),
                          items: centrosMedicos.map((cm) => DropdownMenuItem(value: cm, child: Text(cm.nombre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))).toList(),
                          onChanged: (val) {
                            sede.centroSeleccionado = val;
                            onActualizarUI();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Crear nuevo centro médico',
                        icon: const Icon(Icons.add_business_rounded, color: Color(0xFF0284C7)),
                        onPressed: onMostrarModalCrearCentro,
                      ),
                    ],
                  ),
                ] else ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: sede.nombreSedeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Consultorio Privado',
                          hintText: 'Ej. Consultorio de Dr. Mendoza',
                          helperText: 'Sugerencia automática de tu consultorio.',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: sugerenciasNombre.map((sug) => ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF0284C7)),
                          label: Text(sug, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0369A1))),
                          backgroundColor: const Color(0xFFF0F9FF),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          onPressed: () {
                            sede.nombreSedeCtrl.text = sug;
                            onActualizarUI();
                          },
                        )).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: sede.direccionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dirección o Punto de Referencia',
                            hintText: 'Calle, avenida, edificio...',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin_drop_rounded, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF0284C7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        tooltip: 'Seleccionar ubicación en el mapa',
                        icon: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                        onPressed: () async {
                          final dir = sede.direccionCtrl.text.trim();
                          final nombre = sede.nombreSedeCtrl.text.trim();
                          final result = await MapLocationPickerDialog.mostrar(
                            context,
                            direccionInicial: dir.isNotEmpty ? dir : nombre,
                            ciudadInicial: sede.ciudad,
                            estadoInicial: sede.estado,
                            latitudInicial: sede.latitud,
                            longitudInicial: sede.longitud,
                          );
                          if (result != null && context.mounted) {
                            sede.direccionCtrl.text = result.direccion;
                            sede.latitud = result.latitud;
                            sede.longitud = result.longitud;
                            final mEstado = VenezuelaLocations.matchEstado(result.estado);
                            if (mEstado != null) {
                              sede.estado = mEstado;
                              sede.ciudadesDisponibles = VenezuelaLocations.getCiudadesPorEstado(mEstado);
                              final mCiudad = VenezuelaLocations.matchCiudad(result.ciudad, mEstado);
                              if (mCiudad != null) sede.ciudad = mCiudad;
                            }
                            onActualizarUI();
                          }
                        },
                      ),
                    ],
                  ),
                  if (sede.latitud != null && sede.longitud != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: InkWell(
                        onTap: () => LocationMapsService.abrirGoogleMaps(
                          latitud: sede.latitud, longitud: sede.longitud,
                          direccion: sede.direccionCtrl.text, ciudad: sede.ciudad, estado: sede.estado,
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'GPS: (${sede.latitud!.toStringAsFixed(4)}, ${sede.longitud!.toStringAsFixed(4)}) • Toca para previsualizar',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]),
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: sede.pisoCtrl,
                        decoration: const InputDecoration(labelText: 'Piso / Nivel (Opcional)', hintText: 'Ej. Piso 3, PB', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: sede.numeroLocalCtrl,
                        decoration: const InputDecoration(labelText: 'Nº Local / Consultorio (Opcional)', hintText: 'Ej. 304, Local 5', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: sede.telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Teléfono de Contacto (Opcional)', isDense: true, border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_rounded, size: 16)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilterChip(
                        label: Text(sede.telefonoVisible ? 'Visible' : 'Oculto', style: const TextStyle(fontSize: 11)),
                        selected: sede.telefonoVisible,
                        selectedColor: const Color(0xFFE0F2FE),
                        onSelected: (val) {
                          sede.telefonoVisible = val;
                          onActualizarUI();
                        },
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                Row(
                  children: [
                    const Icon(Icons.access_time_filled_rounded, size: 18, color: Color(0xFF059669)),
                    const SizedBox(width: 6),
                    Text('Días y Horarios en esta sede:', style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                  ],
                ),
                if (diasLibres.isNotEmpty && index > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text('Días libres restantes: ${diasLibres.map((d) => DoctorSetupSedeEntry.nombreDiaCorto(d)).join(", ")}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(7, (i) {
                    final dia = i + 1;
                    final nombreCorto = DoctorSetupSedeEntry.nombreDiaCorto(dia);
                    final isSelected = sede.diasSeleccionados.contains(dia);
                    final nombreOtraSede = diasOcupadosOtraSede[dia];
                    return FilterChip(
                      label: Text(nombreOtraSede != null && !isSelected ? '$nombreCorto ($nombreOtraSede)' : nombreCorto),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0284C7),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : (nombreOtraSede != null ? Colors.orange.shade800 : const Color(0xFF334155)),
                      ),
                      backgroundColor: nombreOtraSede != null ? Colors.orange.shade50 : const Color(0xFFF1F5F9),
                      side: BorderSide(color: isSelected ? const Color(0xFF0284C7) : (nombreOtraSede != null ? Colors.orange.shade300 : const Color(0xFFCBD5E1))),
                      onSelected: (val) => _onToggleDia(context, dia, val),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DoctorSetupTimePickerBox(
                        label: 'Hora Inicio',
                        timeStr: DoctorSetupSedeEntry.formatearTime(sede.horaInicio),
                        icon: Icons.access_time_rounded,
                        onTap: () => _seleccionarHora(context, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DoctorSetupTimePickerBox(
                        label: 'Hora Fin',
                        timeStr: DoctorSetupSedeEntry.formatearTime(sede.horaFin),
                        icon: Icons.access_time_filled_rounded,
                        onTap: () => _seleccionarHora(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(value: sede.tienePausaAlmuerzo, onChanged: (val) { sede.tienePausaAlmuerzo = val ?? false; onActualizarUI(); }),
                    const Text('Pausa de Almuerzo', style: TextStyle(fontSize: 12)),
                    if (sede.tienePausaAlmuerzo) ...[
                      const SizedBox(width: 8),
                      TextButton(onPressed: () => _seleccionarHoraAlmuerzo(context, true), child: Text(DoctorSetupSedeEntry.formatearTime(sede.horaInicioAlmuerzo), style: const TextStyle(fontSize: 11.5))),
                      const Text('-', style: TextStyle(fontSize: 11)),
                      TextButton(onPressed: () => _seleccionarHoraAlmuerzo(context, false), child: Text(DoctorSetupSedeEntry.formatearTime(sede.horaFinAlmuerzo), style: const TextStyle(fontSize: 11.5))),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(sede.modalidadAtencion),
                        initialValue: sede.modalidadAtencion,
                        decoration: const InputDecoration(labelText: 'Modalidad', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'cita_previa', child: Text('Por Horario (Cita Previa)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'orden_llegada', child: Text('Orden de Llegada (Cupos)', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) { if (val != null) { sede.modalidadAtencion = val; onActualizarUI(); } },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(sede.duracionMinutos),
                        initialValue: sede.duracionMinutos,
                        decoration: const InputDecoration(labelText: 'Duración', isDense: true, border: OutlineInputBorder()),
                        items: const [15, 20, 30, 45, 60].map((m) => DropdownMenuItem(value: m, child: Text('$m min', style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) { if (val != null) { sede.duracionMinutos = val; onActualizarUI(); } },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
