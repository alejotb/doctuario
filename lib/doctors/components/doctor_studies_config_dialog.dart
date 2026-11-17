import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../services/doctor_studies_service.dart';

/// Diálogo interactivo para que los doctores configuren qué estudios o procedimientos
/// realizan en su consultorio y asignen el tiempo adicional que cada uno suma a la consulta.
class DoctorStudiesConfigDialog extends StatefulWidget {
  final String idDoctor;
  final VoidCallback? onActualizado;

  const DoctorStudiesConfigDialog({
    super.key,
    required this.idDoctor,
    this.onActualizado,
  });

  static Future<void> show(
    BuildContext context, {
    required String idDoctor,
    VoidCallback? onActualizado,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DoctorStudiesConfigDialog(
        idDoctor: idDoctor,
        onActualizado: onActualizado,
      ),
    );
  }

  @override
  State<DoctorStudiesConfigDialog> createState() =>
      _DoctorStudiesConfigDialogState();
}

class _DoctorStudiesConfigDialogState extends State<DoctorStudiesConfigDialog> {
  List<DoctorEstudioConfig> _estudios = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() => _isLoading = true);
    final lista = await DoctorStudiesService.instance
        .obtenerEstudiosConfigurados(widget.idDoctor);
    if (mounted) {
      setState(() {
        _estudios = lista;
        _isLoading = false;
      });
    }
  }

  Future<void> _guardarCambios() async {
    setState(() => _isSaving = true);
    final ok = await DoctorStudiesService.instance.guardarEstudiosDoctor(
      idDoctor: widget.idDoctor,
      estudios: _estudios,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Estudios y tiempos guardados con éxito.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        widget.onActualizado?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar configuración.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _abrirDialogoNuevoEstudio() {
    final tituloCtrl = TextEditingController();
    final categoriaCtrl = TextEditingController(text: 'Procedimientos en Consulta');
    int minutos = 15;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Agregar Nuevo Estudio / Procedimiento',
            style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Estudio o Procedimiento',
                  hintText: 'Ej: Fondo de Ojo, Biopsia Punch',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoriaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Categoría o Área',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tiempo que suma:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF0284C7)),
                        onPressed: () {
                          if (minutos > 5) setDlgState(() => minutos -= 5);
                        },
                      ),
                      Text('$minutos min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0284C7)),
                        onPressed: () {
                          if (minutos < 180) setDlgState(() => minutos += 5);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final nombre = tituloCtrl.text.trim();
                if (nombre.isNotEmpty) {
                  setState(() {
                    _estudios.add(
                      DoctorEstudioConfig(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        titulo: nombre,
                        categoria: categoriaCtrl.text.trim(),
                        duracionMinutos: minutos,
                        activo: true,
                        icono: Icons.star_rounded,
                      ),
                    );
                  });
                  Navigator.pop(dlgCtx);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.biotech_rounded, color: Color(0xFF0284C7), size: 24),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estudios y Procedimientos',
                          style: GoogleFonts.mooli(fontSize: 16.5, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Personaliza qué estudios realizas y sus tiempos',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Barra de acciones superiores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_estudios.where((e) => e.activo).length} de ${_estudios.length} activos',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0369A1)),
                ),
                TextButton.icon(
                  onPressed: _abrirDialogoNuevoEstudio,
                  icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF0284C7)),
                  label: const Text('Crear Estudio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                ),
              ],
            ),
            const Divider(height: 16),

            // Lista con selector de switch y tiempo
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _estudios.length,
                      itemBuilder: (ctx, idx) {
                        final e = _estudios[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: e.activo ? const Color(0xFFF8FAFC) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: e.activo ? const Color(0xFFBAE6FD) : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Switch(
                                value: e.activo,
                                activeThumbColor: const Color(0xFF0284C7),
                                onChanged: (val) {
                                  setState(() => e.activo = val);
                                },
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.titulo,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: e.activo ? const Color(0xFF0F172A) : Colors.grey.shade500,
                                      ),
                                    ),
                                    Text(
                                      e.categoria,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                              // Selector de tiempo incremental
                              if (e.activo)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        if (e.duracionMinutos > 5) {
                                          setState(() => e.duracionMinutos -= 5);
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF0284C7)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '+${e.duracionMinutos}m',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        if (e.duracionMinutos < 180) {
                                          setState(() => e.duracionMinutos += 5);
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF0284C7)),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final res = await DoctorStudiesService.instance
                        .restablecerPredeterminados(widget.idDoctor);
                    setState(() => _estudios = res);
                  },
                  child: const Text('Restablecer', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _guardarCambios,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Guardar Estudios', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
