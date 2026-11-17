import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../backend/supabase/supabase.dart';

/// Modal para configurar si el paciente es familiar de colega médico,
/// su lazo sanguíneo y el porcentaje o monto de exoneración de la consulta.
class EditFamiliarColegaDialog extends StatefulWidget {
  final UsuariosRow? paciente;
  final Function({
    required bool esFamiliar,
    required String? lazo,
    required String? colegaNombre,
    required String? tipoExoneracion,
    required double? montoExoneracion,
  }) onGuardar;

  const EditFamiliarColegaDialog({
    super.key,
    required this.paciente,
    required this.onGuardar,
  });

  static Future<void> show(
    BuildContext context, {
    required UsuariosRow? paciente,
    required Function({
      required bool esFamiliar,
      required String? lazo,
      required String? colegaNombre,
      required String? tipoExoneracion,
      required double? montoExoneracion,
    }) onGuardar,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => EditFamiliarColegaDialog(
        paciente: paciente,
        onGuardar: onGuardar,
      ),
    );
  }

  @override
  State<EditFamiliarColegaDialog> createState() =>
      _EditFamiliarColegaDialogState();
}

class _EditFamiliarColegaDialogState extends State<EditFamiliarColegaDialog> {
  late bool _esFamiliar;
  late String _lazo;
  late TextEditingController _colegaCtrl;
  late String _tipoExoneracion;
  late TextEditingController _montoCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.paciente;
    _esFamiliar = p?.esFamiliarMedico ?? false;
    _lazo = p?.lazoFamiliar ?? 'Hijo(a)';
    _colegaCtrl = TextEditingController(text: p?.nombreDoctorColega ?? '');
    _tipoExoneracion = p?.tipoExoneracion ?? 'porcentaje';
    _montoCtrl = TextEditingController(
      text: p?.montoExoneracion != null ? '${p!.montoExoneracion}' : '100',
    );
  }

  @override
  void dispose() {
    _colegaCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
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
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.favorite, color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Familiar de Colega',
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Es familiar de un colega médico?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              value: _esFamiliar,
              onChanged: (val) => setState(() => _esFamiliar = val),
              activeThumbColor: const Color(0xFF16A34A),
            ),
            if (_esFamiliar) ...[
              const SizedBox(height: 8),
              const Text('Lazo sanguíneo:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _lazo,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: ['Hijo(a)', 'Padre/Madre', 'Cónyuge', 'Hermano(a)', 'Otro']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (val) => setState(() => _lazo = val ?? 'Otro'),
              ),
              const SizedBox(height: 12),
              const Text('Nombre del Doctor Colega:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextField(
                controller: _colegaCtrl,
                decoration: InputDecoration(
                  hintText: 'Ej: Dr. Alejandro Morales',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 6),
              const Text('¿Desea exonerar parte o total del costo?',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              RadioGroup<String>(
                groupValue: _tipoExoneracion,
                onChanged: (val) {
                  if (val != null) setState(() => _tipoExoneracion = val);
                },
                child: const Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Porcentaje (%)',
                            style: TextStyle(fontSize: 12)),
                        value: 'porcentaje',
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Monto Fijo (\$)',
                            style: TextStyle(fontSize: 12)),
                        value: 'monto',
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: _montoCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _tipoExoneracion == 'porcentaje'
                      ? 'Porcentaje a exonerar (0 - 100%)'
                      : 'Monto a exonerar (\$)',
                  suffixText: _tipoExoneracion == 'porcentaje' ? '%' : '\$',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final monto = double.tryParse(_montoCtrl.text);
            widget.onGuardar(
              esFamiliar: _esFamiliar,
              lazo: _esFamiliar ? _lazo : null,
              colegaNombre: _esFamiliar ? _colegaCtrl.text.trim() : null,
              tipoExoneracion: _esFamiliar ? _tipoExoneracion : null,
              montoExoneracion: _esFamiliar ? monto : null,
            );
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar Cambios'),
        ),
      ],
    );
  }
}
