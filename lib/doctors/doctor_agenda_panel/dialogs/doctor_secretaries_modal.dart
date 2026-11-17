import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/supabase/supabase.dart';
import '/services/secretary_management_service.dart';

/// Modal para que el médico gestione sus secretarias, las invite por correo electrónico
/// y las asigne a sus sedes de consulta médica.
class DoctorSecretariesModal extends StatefulWidget {
  const DoctorSecretariesModal({
    super.key,
    required this.idDoctor,
    required this.sedes,
  });

  final String idDoctor;
  final List<DoctorSedesRow> sedes;

  static Future<void> show(
    BuildContext context, {
    required String idDoctor,
    required List<DoctorSedesRow> sedes,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DoctorSecretariesModal(
        idDoctor: idDoctor,
        sedes: sedes,
      ),
    );
  }

  @override
  State<DoctorSecretariesModal> createState() => _DoctorSecretariesModalState();
}

class _DoctorSecretariesModalState extends State<DoctorSecretariesModal> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedSedeId;
  bool _isLoading = true;
  bool _isSaving = false;
  List<SecretaryAssignment> _secretarias = [];

  @override
  void initState() {
    super.initState();
    if (widget.sedes.isNotEmpty) {
      _selectedSedeId = widget.sedes.first.id;
    }
    _cargarSecretarias();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _cargarSecretarias() async {
    setState(() => _isLoading = true);
    try {
      final list = await SecretaryManagementService()
          .obtenerSecretariasDelDoctor(widget.idDoctor);
      if (mounted) {
        setState(() {
          _secretarias = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _vincularSecretaria() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSedeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione una sede para la secretaria')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SecretaryManagementService().invitarOAsignarSecretaria(
        idDoctor: widget.idDoctor,
        email: _emailController.text.trim(),
        idSede: _selectedSedeId!,
      );

      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0284C7),
            content: Text('Secretaria asignada exitosamente.'),
          ),
        );
      }
      await _cargarSecretarias();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error vinculando secretaria: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _desvincular(SecretaryAssignment sec) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular Secretaria'),
        content: Text(
          '¿Desea desvincular a ${sec.nombre} (${sec.email}) de su consulta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await SecretaryManagementService().desvincularSecretaria(
        idDoctor: widget.idDoctor,
        idSecretaria: sec.idSecretaria,
      );
      await _cargarSecretarias();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Barra de agarre
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Color(0xFF0284C7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis Secretarias',
                          style: GoogleFonts.mooli(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Asigna asistentes para recepción y triaje',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Formulario para invitar/asignar
                  _buildInviteSection(),
                  const SizedBox(height: 24),

                  // Lista de secretarias vinculadas
                  Text(
                    'Secretarias Asignadas (${_secretarias.length})',
                    style: GoogleFonts.mooli(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_secretarias.isEmpty)
                    _buildEmptyState()
                  else
                    ..._secretarias.map((s) => _buildSecretaryCard(s)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vincular o Invitar Asistente',
                  style: GoogleFonts.mooli(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa el correo electrónico. Si la secretaria ya trabaja para otros médicos, se vinculará de inmediato a tu sede.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),

            // Campo Correo
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo electrónico de la secretaria',
                hintText: 'ejemplo@asistente.com',
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El correo es requerido';
                if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Selector de Sede
            DropdownButtonFormField<String>(
              key: ValueKey('modal_sede_${_selectedSedeId}_${widget.sedes.length}'),
              initialValue: _selectedSedeId,
              decoration: InputDecoration(
                labelText: 'Sede de Atención Asignada',
                prefixIcon: const Icon(Icons.business_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: widget.sedes.map((s) {
                return DropdownMenuItem(
                  value: s.id,
                  child: Text(_nombreDeSede(s), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedSedeId = val),
            ),
            const SizedBox(height: 14),

            // Botón de Enviar Invitación
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.link_rounded, color: Colors.white),
                label: Text(
                  _isSaving ? 'Vinculando...' : 'Asignar a mi Consulta',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isSaving ? null : _vincularSecretaria,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecretaryCard(SecretaryAssignment sec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
            backgroundImage: (sec.fotoUrl != null && sec.fotoUrl!.isNotEmpty)
                ? NetworkImage(sec.fotoUrl!)
                : null,
            child: (sec.fotoUrl == null || sec.fotoUrl!.isEmpty)
                ? const Icon(Icons.person, color: Color(0xFF0284C7), size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sec.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  sec.email,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF14B8A6)),
                    const SizedBox(width: 4),
                    Text(
                      sec.nombreSede ?? 'Sin sede',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Desvincular',
            icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
            onPressed: () => _desvincular(sec),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text(
            'Aún no has asignado secretarias',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Invita a tu asistente para que gestione la sala de espera y las llegadas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String _nombreDeSede(DoctorSedesRow s) {
    if (s.nombreSede != null && s.nombreSede!.trim().isNotEmpty) return s.nombreSede!.trim();
    if (s.numeroConsultorio != null && s.numeroConsultorio!.trim().isNotEmpty) return s.numeroConsultorio!.trim();
    if (s.direccion != null && s.direccion!.trim().isNotEmpty) return s.direccion!.trim();
    if (s.ciudad != null && s.ciudad!.trim().isNotEmpty) return 'Consultorio en ${s.ciudad}';
    return 'Consultorio Principal';
  }
}
