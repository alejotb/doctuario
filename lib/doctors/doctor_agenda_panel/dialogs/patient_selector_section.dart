import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/venezuela_locations.dart';

class PatientSelectorSection extends StatefulWidget {
  const PatientSelectorSection({
    super.key,
    required this.pacienteSel,
    required this.onPacienteSelected,
    required this.crearNuevo,
    required this.onCrearNuevoChanged,
    required this.nombreCtrl,
    required this.cedulaCtrl,
    required this.tlfCtrl,
    required this.ciudadCtrl,
    required this.fechaNacNuevo,
    required this.onFechaNacChanged,
    required this.onAutoFillFamiliar,
    required this.esNino,
    required this.onEsNinoChanged,
    required this.nombreRepCtrl,
    required this.cedulaRepCtrl,
    this.especialidadDoctor,
  });

  final UsuariosRow? pacienteSel;
  final ValueChanged<UsuariosRow?> onPacienteSelected;
  final bool crearNuevo;
  final ValueChanged<bool> onCrearNuevoChanged;
  final TextEditingController nombreCtrl;
  final TextEditingController cedulaCtrl;
  final TextEditingController tlfCtrl;
  final TextEditingController ciudadCtrl;
  final DateTime? fechaNacNuevo;
  final ValueChanged<DateTime?> onFechaNacChanged;
  final Function(bool esFamiliar, String colega, String lazo) onAutoFillFamiliar;
  final bool esNino;
  final ValueChanged<bool> onEsNinoChanged;
  final TextEditingController nombreRepCtrl;
  final TextEditingController cedulaRepCtrl;
  final String? especialidadDoctor;

  @override
  State<PatientSelectorSection> createState() => _PatientSelectorSectionState();
}

class _PatientSelectorSectionState extends State<PatientSelectorSection> {
  List<UsuariosRow> _resultados = [];
  bool _buscando = false;

  Future<void> _buscarPacientes(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (mounted) setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;
      final qNorm = VenezuelaLocations.normalize(q);
      final Map<String, UsuariosRow> mergedById = {};
      final Set<String> seenCedulas = {};

      bool matchesRow(UsuariosRow row) {
        return VenezuelaLocations.containsIgnoreAccents(row.nombre, qNorm) ||
            VenezuelaLocations.containsIgnoreAccents(row.cedula, qNorm) ||
            VenezuelaLocations.containsIgnoreAccents(row.telefono, qNorm);
      }

      try {
        final resPac = await docClient.from('pacientes').select().limit(120);
        for (final d in (resPac as List)) {
          final map = Map<String, dynamic>.from(d as Map);
          final row = UsuariosRow(map);
          if (matchesRow(row)) {
            mergedById[row.id] = row;
            if ((row.cedula ?? '').trim().isNotEmpty) {
              seenCedulas.add(row.cedula!.trim().toLowerCase());
            }
            if (mergedById.length >= 10) break;
          }
        }
      } catch (e) {
        debugPrint('Búsqueda en pacientes fallback: $e');
      }

      try {
        final resUsr = await docClient.from('usuarios').select().limit(120);
        for (final d in (resUsr as List)) {
          final map = Map<String, dynamic>.from(d as Map);
          final row = UsuariosRow(map);
          if (matchesRow(row)) {
            final ced = (row.cedula ?? '').trim().toLowerCase();
            if (!mergedById.containsKey(row.id) && (ced.isEmpty || !seenCedulas.contains(ced))) {
              mergedById[row.id] = row;
              if (ced.isNotEmpty) seenCedulas.add(ced);
            }
            if (mergedById.length >= 15) break;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _resultados = mergedById.values.take(10).toList();
          _buscando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. Datos del Paciente:',
          style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        if (!widget.crearNuevo) ...[
          if (widget.pacienteSel == null) ...[
            TextField(
              onChanged: _buscarPacientes,
              decoration: InputDecoration(
                hintText: 'Buscar por Cédula, Nombre o Teléfono...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_buscando)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            if (_resultados.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _resultados.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final u = _resultados[idx];
                    return ListTile(
                      dense: true,
                      title: Text(u.nombre ?? 'Paciente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      subtitle: Text('Cédula: ${u.cedula ?? "S/C"} • Tlf: ${u.telefono ?? "S/T"} • ${u.ciudadOrigen ?? ""}', style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        widget.onPacienteSelected(u);
                        widget.onAutoFillFamiliar(
                          u.esFamiliarMedico ?? false,
                          u.nombreDoctorColega ?? u.doctorReferenciaNombre ?? '',
                          u.lazoFamiliar ?? 'Hijo(a)',
                        );
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('¿Paciente nuevo? Registrar datos en el sistema', style: TextStyle(fontSize: 11.5)),
              onPressed: () => widget.onCrearNuevoChanged(true),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pacienteSel!.nombre ?? 'Paciente',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Cédula: ${widget.pacienteSel!.cedula ?? "S/C"} • ${widget.pacienteSel!.ciudadOrigen ?? "Sin ciudad"}',
                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () => widget.onPacienteSelected(null),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('Registrar Nuevo Paciente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                    TextButton(
                      onPressed: () => widget.onCrearNuevoChanged(false),
                      child: const Text('Volver a buscar', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                // Selector Adulto o Niño con soporte multi-especialidad y atención flexible
                Builder(
                  builder: (context) {
                    final esp = (widget.especialidadDoctor ?? '').toLowerCase();
                    // Reconocer multi-especialidades (ej: Cardiólogo Pediatra, Pediatría / Cardiología)
                    final esPediatra = esp.contains('pediat') ||
                        esp.contains('infant') ||
                        esp.contains('puericult') ||
                        esp.contains('neonat');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ChoiceChip(
                              label: const Text('👨 Adulto'),
                              selected: !widget.esNino,
                              onSelected: (_) => widget.onEsNinoChanged(false),
                            ),
                            ChoiceChip(
                              label: Text(
                                esPediatra
                                    ? '🧒 Paciente Pediátrico'
                                    : '🧒 Menor de Edad (< 15)',
                              ),
                              selected: widget.esNino,
                              onSelected: (_) => widget.onEsNinoChanged(true),
                            ),
                          ],
                        ),
                        if (widget.esNino) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: esPediatra ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: esPediatra ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  esPediatra ? Icons.child_care_rounded : Icons.verified_user_outlined,
                                  size: 16,
                                  color: esPediatra ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    esPediatra
                                        ? 'Atención Pediátrica Especializada (${widget.especialidadDoctor}).'
                                        : 'Atención a menor autorizada por el médico. Se solicitarán datos del representante.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: esPediatra ? const Color(0xFF1E40AF) : const Color(0xFF166534),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),

                if (widget.esNino) ...[
                  // Datos del Niño
                  TextField(
                    controller: widget.nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del Niño(a)', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildDatePicker(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.cedulaCtrl,
                          decoration: const InputDecoration(labelText: 'Cédula Niño (Opcional/S/C)', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Datos del Padre o Representante:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0369A1))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: widget.nombreRepCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del Representante', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.cedulaRepCtrl,
                          decoration: const InputDecoration(labelText: 'Cédula Representante', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.tlfCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Teléfono Representante', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.ciudadCtrl,
                    decoration: const InputDecoration(labelText: 'Ciudad de Origen', isDense: true),
                  ),
                ] else ...[
                  // Datos del Adulto
                  TextField(
                    controller: widget.nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre y Apellido', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.cedulaCtrl,
                          decoration: const InputDecoration(labelText: 'Cédula / ID', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.tlfCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Teléfono', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildDatePicker(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.ciudadCtrl,
                          decoration: const InputDecoration(labelText: 'Ciudad de Origen', isDense: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: widget.esNino ? DateTime.now().subtract(const Duration(days: 365 * 5)) : DateTime(2000),
          firstDate: DateTime(1920),
          lastDate: DateTime.now(),
        );
        if (picked != null) widget.onFechaNacChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Fecha Nacimiento', isDense: true),
        child: Text(
          widget.fechaNacNuevo != null ? DateFormat('dd/MM/yyyy').format(widget.fechaNacNuevo!) : 'Seleccionar...',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
