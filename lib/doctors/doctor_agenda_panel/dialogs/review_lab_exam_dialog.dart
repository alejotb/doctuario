import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../backend/supabase/supabase.dart';
import '../../../services/medical_exam_service.dart';

/// Diálogo para revisar, dictaminar y validar con firma médica un estudio de laboratorio o imagen.
class ReviewLabExamDialog extends StatefulWidget {
  final ExamenesMedicosRow examen;
  final UsuariosRow? paciente;
  final VoidCallback onExamenRevisado;

  const ReviewLabExamDialog({
    super.key,
    required this.examen,
    required this.paciente,
    required this.onExamenRevisado,
  });

  static Future<void> show(
    BuildContext context, {
    required ExamenesMedicosRow examen,
    required UsuariosRow? paciente,
    required VoidCallback onExamenRevisado,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ReviewLabExamDialog(
        examen: examen,
        paciente: paciente,
        onExamenRevisado: onExamenRevisado,
      ),
    );
  }

  @override
  State<ReviewLabExamDialog> createState() => _ReviewLabExamDialogState();
}

class _ReviewLabExamDialogState extends State<ReviewLabExamDialog> {
  late TextEditingController _hallazgosCtrl;
  late TextEditingController _correoFamiliarCtrl;
  late DateTime _fechaEntrega;
  late bool _compartirConPaciente;
  bool _isSaving = false;
  String? _secureImageUrl;

  @override
  void initState() {
    super.initState();
    _hallazgosCtrl = TextEditingController(
      text: widget.examen.hallazgos ?? widget.examen.notas ?? '',
    );
    _correoFamiliarCtrl = TextEditingController(
      text: widget.examen.getField<String>('correo_familiar') ?? '',
    );
    _compartirConPaciente = widget.examen.getField<bool>('compartir_con_paciente') ?? true;
    _fechaEntrega = widget.examen.fechaEntrega ?? DateTime.now();
    if (widget.examen.archivoUrl != null && widget.examen.archivoUrl!.isNotEmpty) {
      MedicalExamService.getSecureExamUrl(widget.examen.archivoUrl!).then((url) {
        if (mounted) setState(() => _secureImageUrl = url);
      });
    }
  }

  @override
  void dispose() {
    _hallazgosCtrl.dispose();
    _correoFamiliarCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarYFirmar() async {
    setState(() => _isSaving = true);
    try {
      await MedicalExamService().guardarHallazgosYRevisar(
        idExamen: widget.examen.id,
        hallazgos: _hallazgosCtrl.text.trim(),
        fechaEntrega: _fechaEntrega,
        compartirConPaciente: _compartirConPaciente,
        correoFamiliar: _correoFamiliarCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Estudio revisado y firmado correctamente.'),
            backgroundColor: Colors.teal,
          ),
        );
        widget.onExamenRevisado();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al revisar estudio: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.biotech_rounded,
                color: Color(0xFFE11D48), size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.examen.titulo ?? 'Revisión de Estudio Médico',
              style:
                  GoogleFonts.mooli(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paciente: ${widget.paciente?.nombre ?? "Paciente"}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            if (widget.examen.tipoExamen != null)
              Text('Tipo: ${widget.examen.tipoExamen}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            if (widget.examen.fechaEstudio != null)
              Text(
                'Fecha de Estudio: ${DateFormat('dd/MM/yyyy').format(widget.examen.fechaEstudio!)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            const SizedBox(height: 12),
            if (widget.examen.archivoUrl != null &&
                widget.examen.archivoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _secureImageUrl ?? widget.examen.archivoUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: Text('Documento adjunto (PDF / Imagen médica)',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _hallazgosCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Hallazgos Clínicos / Dictamen',
                hintText: 'Ingresa los hallazgos médicos observados...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaEntrega,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _fechaEntrega = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'Fecha de Entrega: ${DateFormat('dd/MM/yyyy').format(_fechaEntrega)}',
                        style: const TextStyle(fontSize: 12)),
                    const Icon(Icons.calendar_today, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          '¿Compartir con el paciente?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: _compartirConPaciente,
                        activeThumbColor: const Color(0xFF0284C7),
                        onChanged: (val) {
                          setState(() => _compartirConPaciente = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Si el paciente es un adulto mayor o menor sin correo, asocia la cuenta del familiar responsable:',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _correoFamiliarCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo del familiar / tutor responsable',
                      hintText: 'familiar@correo.com',
                      prefixIcon: Icon(Icons.family_restroom, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7)),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 16, color: Colors.white),
          label: const Text('Firmar y Validar',
              style: TextStyle(color: Colors.white)),
          onPressed: _isSaving ? null : _guardarYFirmar,
        ),
      ],
    );
  }
}
