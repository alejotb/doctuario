import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sección para configurar la duración de la cita y seleccionar o añadir estudios/exámenes médicos.
class AppointmentDurationStudiesSection extends StatefulWidget {
  const AppointmentDurationStudiesSection({
    super.key,
    required this.duracionMinutos,
    required this.onDuracionChanged,
    required this.estudiosSeleccionados,
    required this.onEstudiosChanged,
    this.especialidadDoctor,
  });

  final int duracionMinutos;
  final ValueChanged<int> onDuracionChanged;
  final List<String> estudiosSeleccionados;
  final ValueChanged<List<String>> onEstudiosChanged;
  final String? especialidadDoctor;

  @override
  State<AppointmentDurationStudiesSection> createState() =>
      _AppointmentDurationStudiesSectionState();
}

class _AppointmentDurationStudiesSectionState
    extends State<AppointmentDurationStudiesSection> {
  final TextEditingController _nuevoEstudioCtrl = TextEditingController();
  final TextEditingController _duracionPersonalizadaCtrl =
      TextEditingController();
  bool _mostrarCampoPersonalizado = false;

  @override
  void dispose() {
    _nuevoEstudioCtrl.dispose();
    _duracionPersonalizadaCtrl.dispose();
    super.dispose();
  }

  /// Catálogo inteligente de estudios frecuentes según especialidades del médico
  List<_EstudioFrecuente> _obtenerEstudiosRecomendados() {
    final espRaw = (widget.especialidadDoctor ?? '').toLowerCase();

    final List<_EstudioFrecuente> lista = [];

    // Cardiología (o Cardiopediatría)
    if (espRaw.contains('cardio')) {
      lista.addAll([
        const _EstudioFrecuente('Electrocardiograma (ECG)', 15, 'Cardiología'),
        const _EstudioFrecuente('Ecocardiograma Transtorácico', 35, 'Cardiología'),
        const _EstudioFrecuente('Ecocardiograma Doppler Color', 40, 'Cardiología'),
        const _EstudioFrecuente('Holter de Ritmo 24h', 20, 'Cardiología'),
        const _EstudioFrecuente('MAPA (Presión Arterial 24h)', 20, 'Cardiología'),
        const _EstudioFrecuente('Prueba de Esfuerzo / Ergometría', 45, 'Cardiología'),
      ]);
    }

    // Pediatría / Puericultura / Cardiopediatría
    if (espRaw.contains('pediat') ||
        espRaw.contains('infant') ||
        espRaw.contains('puericult') ||
        espRaw.contains('neonat')) {
      lista.addAll([
        const _EstudioFrecuente('Control de Crecimiento y Neurodesarrollo', 30, 'Pediatría'),
        const _EstudioFrecuente('Ecocardiograma Pediátrico', 35, 'Pediatría'),
        const _EstudioFrecuente('Tamizaje Pediátrico / Reflejos', 20, 'Pediatría'),
        const _EstudioFrecuente('Esquema de Inmunización / Vacunas', 20, 'Pediatría'),
      ]);
    }

    // Ginecología / Obstetricia
    if (espRaw.contains('ginec') || espRaw.contains('obstet')) {
      lista.addAll([
        const _EstudioFrecuente('Ecografía Pélvica / Transvaginal', 30, 'Ginecología'),
        const _EstudioFrecuente('Citología Cervical (Papanicolaou)', 20, 'Ginecología'),
        const _EstudioFrecuente('Ecografía Obstétrica Doppler', 35, 'Ginecología'),
        const _EstudioFrecuente('Colposcopia Diagnóstica', 30, 'Ginecología'),
      ]);
    }

    // Neumonología
    if (espRaw.contains('neumo')) {
      lista.addAll([
        const _EstudioFrecuente('Espirometría Simple', 20, 'Neumonología'),
        const _EstudioFrecuente('Espirometría con Broncodilatador', 35, 'Neumonología'),
        const _EstudioFrecuente('Test de Marcha de 6 Minutos', 30, 'Neumonología'),
      ]);
    }

    // Gastroenterología
    if (espRaw.contains('gastro')) {
      lista.addAll([
        const _EstudioFrecuente('Endoscopia Digestiva Alta', 45, 'Gastroenterología'),
        const _EstudioFrecuente('Colonoscopia Diagnóstica', 60, 'Gastroenterología'),
        const _EstudioFrecuente('Test de Aliento para Helicobacter', 20, 'Gastroenterología'),
      ]);
    }

    // Estudios Generales y Procedimientos comunes para cualquier especialidad
    final generales = [
      const _EstudioFrecuente('Electrocardiograma (ECG)', 15, 'General'),
      const _EstudioFrecuente('Ecografía Abdominal / Partes Blandas', 30, 'General'),
      const _EstudioFrecuente('Espirometría', 25, 'General'),
      const _EstudioFrecuente('Evaluación Preoperatoria / Riesgo Quirúrgico', 40, 'General'),
      const _EstudioFrecuente('Curación / Retiro de Puntos', 20, 'Procedimiento'),
      const _EstudioFrecuente('Lavado de Oídos / Limpieza', 20, 'Procedimiento'),
      const _EstudioFrecuente('Infiltración Articular / Bloqueo', 25, 'Procedimiento'),
    ];

    for (final gen in generales) {
      if (!lista.any((e) => e.nombre == gen.nombre)) {
        lista.add(gen);
      }
    }

    return lista;
  }

  void _agregarEstudioManual() {
    final txt = _nuevoEstudioCtrl.text.trim();
    if (txt.isEmpty) return;

    if (!widget.estudiosSeleccionados.contains(txt)) {
      final nueva = List<String>.from(widget.estudiosSeleccionados)..add(txt);
      widget.onEstudiosChanged(nueva);

      // Si la duración actual es de 30 min estándar, sugerir aumentar a 45 min
      if (widget.duracionMinutos <= 30) {
        widget.onDuracionChanged(45);
      }
    }
    _nuevoEstudioCtrl.clear();
  }

  void _toggleEstudio(_EstudioFrecuente estudio) {
    final nueva = List<String>.from(widget.estudiosSeleccionados);
    if (nueva.contains(estudio.nombre)) {
      nueva.remove(estudio.nombre);
    } else {
      nueva.add(estudio.nombre);
      // Ajustar inteligentemente duración si se requiere más tiempo
      if (estudio.minutosSugeridos > widget.duracionMinutos) {
        widget.onDuracionChanged(estudio.minutosSugeridos);
      }
    }
    widget.onEstudiosChanged(nueva);
  }

  @override
  Widget build(BuildContext context) {
    final estudiosRecomendados = _obtenerEstudiosRecomendados();
    final presetsDuracion = [15, 30, 45, 60, 90, 120];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Selector de Duración
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Duración de la Cita:',
                  style: GoogleFonts.mooli(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.duracionMinutos} min',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'El estándar es 30 min. Para estudios o procedimientos puedes extender el tiempo:',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),

          // Chips rápidos de duración
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ...presetsDuracion.map((mins) {
                final esActivo = widget.duracionMinutos == mins && !_mostrarCampoPersonalizado;
                String label;
                if (mins == 30) {
                  label = '30 min (Estándar)';
                } else if (mins == 60) {
                  label = '60 min (1 h)';
                } else if (mins == 90) {
                  label = '90 min (1.5 h)';
                } else if (mins == 120) {
                  label = '120 min (2 h)';
                } else {
                  label = '$mins min';
                }

                return ChoiceChip(
                  label: Text(label, style: TextStyle(fontSize: 11, fontWeight: esActivo ? FontWeight.bold : FontWeight.normal)),
                  selected: esActivo,
                  selectedColor: const Color(0xFF0284C7),
                  labelStyle: TextStyle(color: esActivo ? Colors.white : const Color(0xFF334155)),
                  onSelected: (_) {
                    setState(() => _mostrarCampoPersonalizado = false);
                    widget.onDuracionChanged(mins);
                  },
                );
              }),
              ChoiceChip(
                label: const Text('⏱️ Otro', style: TextStyle(fontSize: 11)),
                selected: _mostrarCampoPersonalizado,
                onSelected: (val) {
                  setState(() => _mostrarCampoPersonalizado = val);
                },
              ),
            ],
          ),

          // Campo para duración personalizada si se elige "Otro"
          if (_mostrarCampoPersonalizado) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _duracionPersonalizadaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutos personalizados (ej: 40, 75)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final mins = int.tryParse(_duracionPersonalizadaCtrl.text.trim());
                    if (mins != null && mins > 0) {
                      widget.onDuracionChanged(mins);
                    }
                  },
                  child: const Text('Aplicar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),

          // 2. Estudios y Procedimientos
          Row(
            children: [
              const Icon(Icons.biotech_rounded, size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Estudios o Procedimientos:',
                  style: GoogleFonts.mooli(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.estudiosSeleccionados.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.estudiosSeleccionados.length} selec.',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Selecciona los exámenes que se le realizarán al paciente para preparar los insumos y ajustar el tiempo:',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),

          // Chips de estudios recomendados
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: estudiosRecomendados.map((est) {
              final seleccionado = widget.estudiosSeleccionados.contains(est.nombre);
              return FilterChip(
                selected: seleccionado,
                selectedColor: const Color(0xFFEDE9FE),
                checkmarkColor: const Color(0xFF7C3AED),
                label: Text(
                  '${est.nombre} (+${est.minutosSugeridos}m)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                    color: seleccionado ? const Color(0xFF6D28D9) : const Color(0xFF334155),
                  ),
                ),
                onSelected: (_) => _toggleEstudio(est),
              );
            }).toList(),
          ),

          // Estudios agregados manualmente que no están en el catálogo predeterminado
          if (widget.estudiosSeleccionados.any((nombre) => !estudiosRecomendados.any((e) => e.nombre == nombre))) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.estudiosSeleccionados
                  .where((nombre) => !estudiosRecomendados.any((e) => e.nombre == nombre))
                  .map((custom) => Chip(
                        label: Text(custom, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9))),
                        backgroundColor: const Color(0xFFF3E8FF),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          final nueva = List<String>.from(widget.estudiosSeleccionados)..remove(custom);
                          widget.onEstudiosChanged(nueva);
                        },
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 10),

          // Input para agregar estudio personalizado
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nuevoEstudioCtrl,
                  decoration: InputDecoration(
                    hintText: 'Añadir otro estudio o procedimiento...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.add_task_rounded, size: 16),
                  ),
                  onSubmitted: (_) => _agregarEstudioManual(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                tooltip: 'Agregar a la lista',
                onPressed: _agregarEstudioManual,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstudioFrecuente {
  final String nombre;
  final int minutosSugeridos;
  final String categoria;

  const _EstudioFrecuente(this.nombre, this.minutosSugeridos, this.categoria);
}
