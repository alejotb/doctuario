import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/i18n_service.dart';

/// Diálogo exclusivo para médicos para contactar soporte técnico, reportar fallos
/// o enviar sugerencias de mejora de ProntuDoc.
class DoctorSupportDialog extends StatefulWidget {
  final String idDoctor;
  final String doctorNombre;

  const DoctorSupportDialog({
    super.key,
    required this.idDoctor,
    required this.doctorNombre,
  });

  /// Método estático para desplegar el diálogo de soporte médico
  static Future<void> show(
    BuildContext context, {
    required String idDoctor,
    required String doctorNombre,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DoctorSupportDialog(
        idDoctor: idDoctor,
        doctorNombre: doctorNombre,
      ),
    );
  }

  @override
  State<DoctorSupportDialog> createState() => _DoctorSupportDialogState();
}

class _DoctorSupportDialogState extends State<DoctorSupportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _asuntoController = TextEditingController();
  final _mensajeController = TextEditingController();

  String _tipoContacto = 'fallo'; // 'fallo', 'sugerencia', 'duda'
  final String _prioridad = 'media'; // 'baja', 'media', 'alta'
  bool _enviando = false;

  @override
  void dispose() {
    _asuntoController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _abrirWhatsApp() async {
    final mensaje = Uri.encodeComponent(
      'Hola Soporte Doctuario, soy el/la Dr/a. ${widget.doctorNombre}. Necesito asistencia con la plataforma.',
    );
    final url = Uri.parse('https://wa.me/?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _abrirCorreo() async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'soporte@doctuario.com',
      queryParameters: {
        'subject': 'Soporte Médico Doctuario - Dr/a. ${widget.doctorNombre}',
        'body': 'Hola equipo de soporte de Doctuario,\n\n',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _enviarTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      final docClient = DualDatabaseConfig.instance.doctorClient;

      // Registrar ticket en base de datos y notificar a administradores
      try {
        await docClient.from('soporte_tickets').insert({
          'id_doctor': widget.idDoctor,
          'doctor_nombre': widget.doctorNombre,
          'tipo': _tipoContacto,
          'prioridad': _prioridad,
          'asunto': _asuntoController.text.trim(),
          'mensaje': _mensajeController.text.trim(),
          'estado': 'abierto',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });

        final admins = await SupaFlow.client
            .from('usuarios')
            .select('id')
            .inFilter('rol', ['admin', 'administrador']);
        for (final adm in (admins as List)) {
          final admId = adm['id']?.toString() ?? '';
          if (admId.isEmpty) continue;
          try {
            await SupaFlow.client.from('notificaciones_citas').insert({
              'id_usuario': admId,
              'tipo': 'soporte_ticket',
              'titulo': '🎫 Nuevo Ticket de Soporte (${_prioridad.toUpperCase()})',
              'mensaje':
                  'Dr(a). ${widget.doctorNombre}: ${_asuntoController.text.trim()}',
              'leido': false,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            });
          } catch (_) {}
        }
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0F766E),
            content: Text(
              '¡Gracias! Tu reporte ha sido enviado al equipo técnico de Doctuario.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Error al enviar ticket: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: theme.secondaryBackground,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520.0, maxHeight: 680.0),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(theme, isEs),
                  const SizedBox(height: 16.0),
                  _buildQuickActionButtons(theme, isEs),
                  const SizedBox(height: 16.0),
                  const Divider(height: 1.0),
                  const SizedBox(height: 16.0),
                  _buildTipoSelector(theme, isEs),
                  const SizedBox(height: 14.0),
                  _buildCamposTexto(theme, isEs),
                  const SizedBox(height: 22.0),
                  _buildSubmitButton(theme, isEs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FlutterFlowTheme theme, bool isEs) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: const Icon(
            Icons.headset_mic_rounded,
            color: Color(0xFF0284C7),
            size: 24.0,
          ),
        ),
        const SizedBox(width: 14.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEs ? 'Soporte y Sugerencias' : 'Support & Feedback',
                style: GoogleFonts.mooli(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryText,
                ),
              ),
              Text(
                isEs
                    ? 'Canal prioritario para doctores Doctuario'
                    : 'Priority channel for Doctuario physicians',
                style: GoogleFonts.mooli(
                  fontSize: 12.0,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildQuickActionButtons(FlutterFlowTheme theme, bool isEs) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _abrirWhatsApp,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16.0, color: Color(0xFF16A34A)),
            label: Text(
              'WhatsApp',
              style: GoogleFonts.mooli(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              side: const BorderSide(color: Color(0xFF16A34A)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
          ),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _abrirCorreo,
            icon: const Icon(Icons.email_outlined, size: 16.0, color: Color(0xFF0284C7)),
            label: Text(
              'Email Soporte',
              style: GoogleFonts.mooli(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              side: const BorderSide(color: Color(0xFF0284C7)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipoSelector(FlutterFlowTheme theme, bool isEs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEs ? 'Motivo del contacto:' : 'Contact reason:',
          style: GoogleFonts.mooli(fontSize: 13.0, fontWeight: FontWeight.w600, color: theme.primaryText),
        ),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0,
          children: [
            _buildChoiceChip('⚠️ Fallo / Bug', 'fallo', theme),
            _buildChoiceChip('💡 Sugerencia', 'sugerencia', theme),
            _buildChoiceChip('❓ Consulta', 'duda', theme),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String label, String value, FlutterFlowTheme theme) {
    final selected = _tipoContacto == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: theme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12.0,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? theme.primary : theme.primaryText,
      ),
      onSelected: (val) {
        if (val) setState(() => _tipoContacto = value);
      },
    );
  }

  Widget _buildCamposTexto(FlutterFlowTheme theme, bool isEs) {
    return Column(
      children: [
        TextFormField(
          controller: _asuntoController,
          decoration: InputDecoration(
            labelText: isEs ? 'Asunto o resumen breve' : 'Subject or brief summary',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          ),
          style: GoogleFonts.mooli(fontSize: 13.5),
          validator: (v) => (v == null || v.trim().isEmpty) ? (isEs ? 'Ingresa el asunto' : 'Enter subject') : null,
        ),
        const SizedBox(height: 12.0),
        TextFormField(
          controller: _mensajeController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: isEs ? 'Explica detalladamente qué sucedió o tu idea...' : 'Describe what happened or your idea...',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
            contentPadding: const EdgeInsets.all(14.0),
          ),
          style: GoogleFonts.mooli(fontSize: 13.5),
          validator: (v) => (v == null || v.trim().length < 8) ? (isEs ? 'Escribe al menos 8 caracteres' : 'At least 8 chars') : null,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(FlutterFlowTheme theme, bool isEs) {
    return ElevatedButton(
      onPressed: _enviando ? null : _enviarTicket,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      child: _enviando
          ? const SizedBox(
              height: 20.0,
              width: 20.0,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
            )
          : Text(
              isEs ? 'Enviar Reporte al Equipo' : 'Submit Ticket',
              style: GoogleFonts.mooli(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
    );
  }
}
