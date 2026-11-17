import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modal para registrar una nueva evolución o consulta médica.
class NewEvolutionDialog extends StatefulWidget {
  final Future<void> Function({
    required String motivo,
    required String sintomas,
    required String examenFisico,
    required String diagnostico,
    required String tratamiento,
    required String notasPrivadas,
  }) onGuardar;

  const NewEvolutionDialog({
    super.key,
    required this.onGuardar,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function({
      required String motivo,
      required String sintomas,
      required String examenFisico,
      required String diagnostico,
      required String tratamiento,
      required String notasPrivadas,
    }) onGuardar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NewEvolutionDialog(onGuardar: onGuardar),
    );
  }

  @override
  State<NewEvolutionDialog> createState() => _NewEvolutionDialogState();
}

class _NewEvolutionDialogState extends State<NewEvolutionDialog> {
  final _motivoCtrl = TextEditingController();
  final _sintomasCtrl = TextEditingController();
  final _examenFisicoCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _tratamientoCtrl = TextEditingController();
  final _notasPrivadasCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _sintomasCtrl.dispose();
    _examenFisicoCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _tratamientoCtrl.dispose();
    _notasPrivadasCtrl.dispose();
    super.dispose();
  }

  Widget _buildCampoTexto(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 2,
    bool requerido = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.mooli(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF334155),
                ),
              ),
              if (requerido)
                const Text(' *',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_edu,
                color: Color(0xFF0284C7), size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            'Nueva Evolución Médica',
            style: GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCampoTexto(
                  'Motivo de Consulta / Anamnesis',
                  _motivoCtrl,
                  'Describa la razón principal por la que acude el paciente...',
                  requerido: true),
              _buildCampoTexto('Síntomas Actuales', _sintomasCtrl,
                  'Fiebre, dolor de cabeza, evolución...'),
              _buildCampoTexto('Exploración Física', _examenFisicoCtrl,
                  'Hallazgos clínicos, auscultación, palpación...'),
              _buildCampoTexto('Diagnóstico Clínico', _diagnosticoCtrl,
                  'Impresión diagnóstica o diagnóstico definitivo...',
                  requerido: true),
              _buildCampoTexto('Plan Terapéutico / Órdenes Médicas',
                  _tratamientoCtrl, 'Fármacos recetados, dosis y recomendaciones...',
                  maxLines: 3),
              _buildCampoTexto(
                  'Notas Confidenciales (Solo para ti)',
                  _notasPrivadasCtrl,
                  'Comentarios privados no visibles para el paciente...'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando
              ? null
              : () async {
                  if (_motivoCtrl.text.trim().isEmpty ||
                      _diagnosticoCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Por favor complete el Motivo de Consulta y el Diagnóstico.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() => _guardando = true);
                  await widget.onGuardar(
                    motivo: _motivoCtrl.text.trim(),
                    sintomas: _sintomasCtrl.text.trim(),
                    examenFisico: _examenFisicoCtrl.text.trim(),
                    diagnostico: _diagnosticoCtrl.text.trim(),
                    tratamiento: _tratamientoCtrl.text.trim(),
                    notasPrivadas: _notasPrivadasCtrl.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
          ),
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar Evolución'),
        ),
      ],
    );
  }
}
