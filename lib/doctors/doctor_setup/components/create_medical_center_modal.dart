import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/services/medical_centers_service.dart';

class CreateMedicalCenterModal {
  CreateMedicalCenterModal._();

  static Future<CentroMedicoItem?> show(
    BuildContext context, {
    required String ciudad,
    required String estado,
    required String idDoctor,
  }) async {
    final nombreCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    String tipoInst = 'Clinica';
    bool guardandoCentro = false;
    CentroMedicoItem? centroCreado;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: Color(0xFF0284C7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Agregar Nueva Institución Médica',
                  style: GoogleFonts.mooli(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                  'Se guardará para $ciudad, $estado y estará disponible para todos los médicos.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Clínica u Hospital *',
                    hintText: 'Ej. Clínica San Pedro',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipoInst,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Institución',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Clinica', child: Text('Clínica Privada')),
                    DropdownMenuItem(value: 'Hospital', child: Text('Hospital Público')),
                    DropdownMenuItem(value: 'Centro Medico', child: Text('Centro Médico / Ambulatorio')),
                    DropdownMenuItem(value: 'Policlinica', child: Text('Policlínica')),
                  ],
                  onChanged: (v) => setModalState(() => tipoInst = v ?? 'Clinica'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dirCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección o Referencia',
                    hintText: 'Ej. Av. Principal, Sector Centro',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de Contacto (Opcional)',
                    hintText: 'Ej. 0271-2250000',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: guardandoCentro
                  ? null
                  : () async {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ingresa el nombre del centro médico')),
                        );
                        return;
                      }

                      setModalState(() => guardandoCentro = true);
                      final nuevoCentro = await MedicalCentersService.registrarNuevoCentro(
                        nombre: nombre,
                        tipo: tipoInst,
                        ciudad: ciudad,
                        estado: estado,
                        direccion: dirCtrl.text.trim(),
                        telefono: telCtrl.text.trim(),
                        registradoPorDoctorId: idDoctor,
                      );

                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                      }

                      if (nuevoCentro != null && context.mounted) {
                        centroCreado = nuevoCentro;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Centro "${nuevoCentro.nombre}" añadido con éxito.'),
                            backgroundColor: Colors.teal,
                          ),
                        );
                      }
                    },
              child: guardandoCentro
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Guardar Institución'),
            ),
          ],
        ),
      ),
    );

    return centroCreado;
  }
}
