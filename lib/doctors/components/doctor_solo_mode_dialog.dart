import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/i18n_service.dart';
import '../doctor_public_profile/doctor_public_profile_widget.dart';
import '../doctor_share_helper.dart';

/// Diálogo para configurar el Modo "Doctor Solo" (visibilidad en el catálogo público)
/// y compartir o copiar el enlace exclusivo de agendamiento directo del médico.
class DoctorSoloModeDialog extends StatefulWidget {
  const DoctorSoloModeDialog({
    super.key,
    required this.idDoctor,
    required this.initialVisible,
    this.doctorUsuario,
    this.doctorInfo,
  });

  final String idDoctor;
  final bool initialVisible;
  final UsuariosRow? doctorUsuario;
  final DoctoresRow? doctorInfo;

  static Future<bool?> show(
    BuildContext context, {
    required String idDoctor,
    required bool initialVisible,
    UsuariosRow? doctorUsuario,
    DoctoresRow? doctorInfo,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DoctorSoloModeDialog(
        idDoctor: idDoctor,
        initialVisible: initialVisible,
        doctorUsuario: doctorUsuario,
        doctorInfo: doctorInfo,
      ),
    );
  }

  @override
  State<DoctorSoloModeDialog> createState() => _DoctorSoloModeDialogState();
}

class _DoctorSoloModeDialogState extends State<DoctorSoloModeDialog> {
  late bool _visibleEnCatalogo;
  late TextEditingController _aliasCtrl;
  String? _aliasGuardado;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _visibleEnCatalogo = widget.initialVisible;
    _aliasGuardado = widget.doctorInfo?.alias;
    _aliasCtrl = TextEditingController(text: _aliasGuardado ?? '');
  }

  @override
  void dispose() {
    _aliasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarAlias() async {
    final limpio = _aliasCtrl.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-_]'), '-');
    if (limpio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un alias válido (ej. dr-perez).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await SupaFlow.client
          .from('doctores')
          .update({'alias': limpio})
          .eq('id', widget.idDoctor);
      if (mounted) {
        setState(() {
          _aliasGuardado = limpio;
          _aliasCtrl.text = limpio;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Alias público actualizado. Tu UUID permanece oculto.'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el alias (puede estar en uso): $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _actualizarVisibilidad(bool nuevoValor) async {
    setState(() {
      _visibleEnCatalogo = nuevoValor;
      _guardando = true;
    });
    try {
      await SupaFlow.client
          .from('doctores')
          .update({'visible_en_catalogo': nuevoValor})
          .eq('id', widget.idDoctor);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoValor
                  ? 'Ahora eres visible en el catálogo público de Doctuario.'
                  : 'Modo Burbuja activado: trabajas en tu consultorio privado oculto del catálogo.',
            ),
            backgroundColor: nuevoValor ? const Color(0xFF10B981) : const Color(0xFF0284C7),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _visibleEnCatalogo = !nuevoValor);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar visibilidad: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _copiarEnlace() async {
    final enlace = DoctorShareHelper.generarEnlaceExclusivo(
      widget.idDoctor,
      alias: _aliasGuardado,
    );
    await DoctorShareHelper.copiarAlPortapapeles(enlace);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enlace exclusivo copiado al portapapeles.'),
          backgroundColor: Color(0xFF0284C7),
        ),
      );
    }
  }

  Future<void> _compartirWhatsApp() async {
    final nombre = widget.doctorUsuario?.nombre ?? 'Especialista';
    final esp = widget.doctorInfo?.especialidad ?? 'Consulta Médica';
    final enlace = DoctorShareHelper.generarEnlaceExclusivo(
      widget.idDoctor,
      alias: _aliasGuardado,
    );
    final texto =
        '👨‍⚕️ *Dr(a). $nombre* ($esp)\n📲 Agenda tu cita médica directamente en mi consultorio usando este enlace exclusivo:\n$enlace';
    await DoctorShareHelper.compartirPorWhatsApp(texto);
  }

  void _abrirVistaPrevia() {
    Navigator.pop(context, _visibleEnCatalogo);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPublicProfileWidget(
          idDoctor: widget.idDoctor,
          alias: _aliasGuardado,
          nombreDoctor: widget.doctorUsuario?.nombre,
          especialidadDoctor: widget.doctorInfo?.especialidad,
          fotoUrlDoctor: widget.doctorUsuario?.fotoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;
    final enlace = DoctorShareHelper.generarEnlaceExclusivo(
      widget.idDoctor,
      alias: _aliasGuardado,
    );
    final modoSoloActivo = !_visibleEnCatalogo;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            modoSoloActivo ? Icons.visibility_off_rounded : Icons.public_rounded,
            color: modoSoloActivo ? const Color(0xFF7C3AED) : theme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEs ? 'Modo Doctor Solo y Enlace' : 'Solo Doctor Mode & Link',
              style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (modoSoloActivo ? const Color(0xFF7C3AED) : theme.primary).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (modoSoloActivo ? const Color(0xFF7C3AED) : theme.primary).withValues(alpha: 0.25),
                  ),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: modoSoloActivo,
                  activeTrackColor: const Color(0xFF7C3AED),
                  title: Text(
                    isEs ? 'Ocultar del catálogo público (Modo Solo)' : 'Hide from public catalog (Solo Mode)',
                    style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    modoSoloActivo
                        ? (isEs
                            ? 'Solo pacientes con tu enlace exclusivo o agendados por ti podrán verte.'
                            : 'Only patients with your exclusive link can view and book with you.')
                        : (isEs
                            ? 'Apareces en el directorio general para nuevos pacientes.'
                            : 'You appear in the public directory for all patients.'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  onChanged: _guardando ? null : (val) => _actualizarVisibilidad(!val),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEs ? 'Tu alias público (protege tu ID interno):' : 'Your public alias (protects your internal ID):',
                style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aliasCtrl,
                      decoration: InputDecoration(
                        hintText: 'ej. dr-alejandro-perez',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _guardando ? null : _guardarAlias,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isEs ? 'Guardar' : 'Save', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                isEs ? 'Tu enlace exclusivo de agendamiento:' : 'Your exclusive booking link:',
                style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: SelectableText(
                  enlace,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copiarEnlace,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(isEs ? 'Copiar enlace' : 'Copy link'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _compartirWhatsApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _abrirVistaPrevia,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(isEs ? 'Ver mi perfil exclusivo como paciente' : 'Preview exclusive patient view'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _visibleEnCatalogo),
          child: Text(isEs ? 'Cerrar' : 'Close'),
        ),
      ],
    );
  }
}
