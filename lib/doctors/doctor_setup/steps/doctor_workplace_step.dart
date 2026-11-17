import 'package:flutter/material.dart';
import '/services/medical_centers_service.dart';
import '/services/venezuela_locations.dart';
import '/services/location_maps_service.dart';
import '/components/map_location_picker_dialog.dart';
import '../components/doctor_setup_ui_helpers.dart';

class DoctorWorkplaceStep extends StatelessWidget {
  const DoctorWorkplaceStep({
    super.key,
    required this.tipoLugar,
    required this.onTipoLugarChanged,
    required this.estadoSeleccionado,
    required this.onEstadoChanged,
    required this.ciudadSeleccionada,
    required this.onCiudadChanged,
    required this.ciudadesDisponibles,
    required this.centrosMedicos,
    required this.centroSeleccionado,
    required this.onCentroChanged,
    required this.cargandoCentros,
    required this.onMostrarModalCrearCentro,
    required this.nombreSedeCtrl,
    required this.pisoCtrl,
    required this.numeroLocalCtrl,
    required this.direccionCtrl,
    required this.telefonoCtrl,
    required this.telefonoVisible,
    required this.onTelefonoVisibleChanged,
    required this.doctorNombre,
    required this.latitud,
    required this.longitud,
    required this.onLocationSelected,
  });

  final String tipoLugar;
  final ValueChanged<String> onTipoLugarChanged;
  final String estadoSeleccionado;
  final ValueChanged<String?> onEstadoChanged;
  final String ciudadSeleccionada;
  final ValueChanged<String?> onCiudadChanged;
  final List<String> ciudadesDisponibles;
  final List<CentroMedicoItem> centrosMedicos;
  final CentroMedicoItem? centroSeleccionado;
  final ValueChanged<CentroMedicoItem?> onCentroChanged;
  final bool cargandoCentros;
  final VoidCallback onMostrarModalCrearCentro;
  final TextEditingController nombreSedeCtrl;
  final TextEditingController pisoCtrl;
  final TextEditingController numeroLocalCtrl;
  final TextEditingController direccionCtrl;
  final TextEditingController telefonoCtrl;
  final bool telefonoVisible;
  final ValueChanged<bool> onTelefonoVisibleChanged;
  final String doctorNombre;
  final double? latitud;
  final double? longitud;
  final Function(String direccion, double? lat, double? lng, String? matchedEstado, String? matchedCiudad) onLocationSelected;

  String getUbicacionEspecificaTexto() {
    final piso = pisoCtrl.text.trim();
    final local = numeroLocalCtrl.text.trim();

    if (piso.isNotEmpty && local.isNotEmpty) {
      final pisoFmt = (piso.toLowerCase().startsWith('piso') ||
              piso.toLowerCase().startsWith('nivel') ||
              piso.toUpperCase() == 'PB' ||
              piso.toLowerCase().startsWith('planta'))
          ? piso
          : 'Piso $piso';
      final localFmt = (local.toLowerCase().startsWith('consultorio') ||
              local.toLowerCase().startsWith('local') ||
              local.toLowerCase().startsWith('oficina'))
          ? local
          : 'Consultorio $local';
      return '$pisoFmt, $localFmt';
    } else if (piso.isNotEmpty) {
      return (piso.toLowerCase().startsWith('piso') || piso.toUpperCase() == 'PB')
          ? piso
          : 'Piso $piso';
    } else if (local.isNotEmpty) {
      return (local.toLowerCase().startsWith('consultorio') || local.toLowerCase().startsWith('local'))
          ? local
          : 'Consultorio $local';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final estados = VenezuelaLocations.getEstados();

    return DoctorSetupCardWrapper(
      icon: Icons.location_on_rounded,
      iconColor: const Color(0xFF0284C7),
      title: '1. Lugar de Trabajo y Consultorio',
      subtitle: 'Indica si atiendes en una clínica, hospital o en un consultorio privado.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DoctorSetupChoiceChip(
                  label: 'Clínica / Hospital',
                  subtitle: 'Público o Privado',
                  icon: Icons.local_hospital_rounded,
                  selected: tipoLugar == 'clinica',
                  onTap: () => onTipoLugarChanged('clinica'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DoctorSetupChoiceChip(
                  label: 'Consultorio Privado',
                  subtitle: 'Oficina personal',
                  icon: Icons.business_rounded,
                  selected: tipoLugar == 'privado',
                  onTap: () {
                    onTipoLugarChanged('privado');
                    if (nombreSedeCtrl.text.isEmpty || nombreSedeCtrl.text.startsWith('Consultorio de')) {
                      nombreSedeCtrl.text = 'Consultorio de ${doctorNombre.isNotEmpty ? doctorNombre : "Doctor"}';
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: estados.contains(estadoSeleccionado) ? estadoSeleccionado : (estados.isNotEmpty ? estados.first : null),
                  decoration: const InputDecoration(
                    labelText: 'Estado *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: estados.map((estado) {
                    return DropdownMenuItem(value: estado, child: Text(estado, style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: onEstadoChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: ciudadesDisponibles.contains(ciudadSeleccionada)
                      ? ciudadSeleccionada
                      : (ciudadesDisponibles.isNotEmpty ? ciudadesDisponibles.first : null),
                  decoration: const InputDecoration(
                    labelText: 'Ciudad *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: ciudadesDisponibles.map((ciudad) {
                    return DropdownMenuItem(value: ciudad, child: Text(ciudad, style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: onCiudadChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (tipoLugar == 'clinica') ...[
            if (cargandoCentros)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<CentroMedicoItem>(
                      initialValue: centroSeleccionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Selecciona la Institución Médica *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                      ),
                      items: centrosMedicos.map((centro) {
                        return DropdownMenuItem(
                          value: centro,
                          child: Text(
                            centro.nombre,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        onCentroChanged(val);
                        if (val?.telefono != null && val!.telefono!.isNotEmpty) {
                          telefonoCtrl.text = val.telefono!;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Agregar nueva clínica u hospital',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: onMostrarModalCrearCentro,
                  ),
                ],
              ),
              if (centroSeleccionado != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF16A34A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          centroSeleccionado!.direccion?.isNotEmpty == true
                              ? centroSeleccionado!.direccion!
                              : '$ciudadSeleccionada, $estadoSeleccionado',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF00796B)),
                        label: const Text('Google Maps', style: TextStyle(fontSize: 11.5, color: Color(0xFF00796B), fontWeight: FontWeight.bold)),
                        onPressed: () {
                          LocationMapsService.abrirEnGoogleMaps(
                            nombreLugar: centroSeleccionado!.nombre,
                            direccion: centroSeleccionado!.direccion,
                            ciudad: ciudadSeleccionada,
                            estado: estadoSeleccionado,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: pisoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Piso / Nivel *',
                      hintText: 'Ej. 2, PB, 1',
                      helperText: 'Piso o planta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.layers_rounded, size: 20),
                    ),
                    validator: (v) {
                      if (tipoLugar == 'clinica' && (v == null || v.trim().isEmpty)) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    controller: numeroLocalCtrl,
                    decoration: const InputDecoration(
                      labelText: 'N° / Letra Consultorio *',
                      hintText: 'Ej. 4B, 102, A',
                      helperText: 'Número o letra',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.meeting_room_rounded, size: 20),
                    ),
                    validator: (v) {
                      if (tipoLugar == 'clinica' && (v == null || v.trim().isEmpty)) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            TextFormField(
              controller: nombreSedeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del Consultorio Privado *',
                hintText: 'Ej. Consultorio de Dr. Carlos Mendoza',
                helperText: 'Sugerencia automática para que tus pacientes ubiquen tu consulta privada.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home_work_rounded, size: 20),
              ),
              validator: (v) {
                if (tipoLugar == 'privado' && (v == null || v.trim().isEmpty)) {
                  return 'Ingresa el nombre del consultorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: direccionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección o Punto de Referencia *',
                      hintText: 'Ej. Av. Bolívar, Centro Profesional Los Andes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_drop_rounded, size: 20),
                    ),
                    validator: (v) {
                      if (tipoLugar == 'privado' && (v == null || v.trim().isEmpty)) {
                        return 'Ingresa la dirección de tu consultorio';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00796B).withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    tooltip: 'Ubicar en el mapa interactivo',
                    icon: const Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 24),
                    onPressed: () async {
                      final dir = direccionCtrl.text.trim();
                      final nombre = nombreSedeCtrl.text.trim();

                      final result = await MapLocationPickerDialog.mostrar(
                        context,
                        direccionInicial: dir.isNotEmpty ? dir : nombre,
                        ciudadInicial: ciudadSeleccionada,
                        estadoInicial: estadoSeleccionado,
                        latitudInicial: latitud,
                        longitudInicial: longitud,
                      );

                      if (result == null) return;
                      if (!context.mounted) return;

                      final matchedEstado = VenezuelaLocations.matchEstado(result.estado);
                      final matchedCiudad = VenezuelaLocations.matchCiudad(result.ciudad, matchedEstado ?? estadoSeleccionado);

                      onLocationSelected(result.direccion, result.latitud, result.longitud, matchedEstado, matchedCiudad);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('📍 Ubicación fijada: ${result.direccion}'),
                          backgroundColor: const Color(0xFF00796B),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: pisoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Piso / Nivel (Opcional)',
                      hintText: 'Ej. 2, PB, 1',
                      helperText: 'Piso o planta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.layers_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    controller: numeroLocalCtrl,
                    decoration: const InputDecoration(
                      labelText: 'N° / Letra Consultorio (Opcional)',
                      hintText: 'Ej. 4B, 102, A',
                      helperText: 'Número o letra',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.meeting_room_rounded, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (latitud != null && longitud != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () {
                  LocationMapsService.abrirGoogleMaps(
                    latitud: latitud,
                    longitud: longitud,
                    direccion: tipoLugar == 'clinica' ? getUbicacionEspecificaTexto() : direccionCtrl.text,
                    ciudad: ciudadSeleccionada,
                    estado: estadoSeleccionado,
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Coordenadas GPS fijadas (${latitud!.toStringAsFixed(4)}, ${longitud!.toStringAsFixed(4)}). Toca para previsualizar en Google Maps.',
                        style: TextStyle(fontSize: 11.5, color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          TextFormField(
            controller: telefonoCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono de Contacto del Consultorio',
              hintText: 'Ej. 0414-1234567 o 0271-2250000',
              helperText: 'Sugerido de tu registro. Puedes cambiarlo si el consultorio tiene otra línea.',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '¿Mostrar este número a los pacientes?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                telefonoVisible
                    ? 'Visible en la ficha de tu consultorio para consultas de pacientes.'
                    : 'Oculto: Los pacientes solo podrán comunicarse a través de la aplicación.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              value: telefonoVisible,
              activeThumbColor: const Color(0xFF0284C7),
              onChanged: onTelefonoVisibleChanged,
            ),
          ),
        ],
      ),
    );
  }
}
