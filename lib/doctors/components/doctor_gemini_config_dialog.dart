import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/gemini_ai_service.dart';
import '/services/i18n_service.dart';

/// Diálogo de configuración de Google Gemini 3.8 Flash para doctores.
///
/// Permite al especialista:
/// 1. Ingresar o actualizar su clave personal (BYOK) de Google AI Studio.
/// 2. Validar en vivo la conexión con el modelo oficial `gemini-3.8-flash`.
/// 3. Leer la guía completa paso a paso con enlace directo compatible con móviles.
/// 4. Habilitar funciones inteligentes con privacidad médica total.
class DoctorGeminiConfigDialog extends StatefulWidget {
  const DoctorGeminiConfigDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const DoctorGeminiConfigDialog(),
    );
  }

  @override
  State<DoctorGeminiConfigDialog> createState() => _DoctorGeminiConfigDialogState();
}

class _DoctorGeminiConfigDialogState extends State<DoctorGeminiConfigDialog> {
  final TextEditingController _keyController = TextEditingController();
  final FocusNode _keyFocusNode = FocusNode();
  bool _obscureText = true;
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testResult;
  bool? _isSuccess;

  @override
  void initState() {
    super.initState();
    _cargarClaveExistente();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _keyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarClaveExistente() async {
    await GeminiAiService.instance.init();
    final currentKey = GeminiAiService.instance.currentKey;
    if (currentKey != null && currentKey.isNotEmpty) {
      setState(() => _keyController.text = currentKey);
    }
  }

  /// Abre la consola oficial en el navegador del dispositivo (compatible con móvil y escritorio)
  Future<void> _abrirGoogleAiStudio() async {
    final uri = Uri.parse('https://aistudio.google.com/app/apikey');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        debugPrint('Error abriendo enlace en móvil: $e');
      }
    }
  }

  /// Despliega la guía paso a paso para que el doctor la lea completa antes de abrir el enlace
  Future<void> _mostrarGuiaPasoAPaso() async {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(ctx);
        final isEs = I18nService.instance.isSpanish;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
          backgroundColor: theme.secondaryBackground,
          titlePadding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
          actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10.0)),
                child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF0284C7), size: 22.0),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEs ? 'Guía: Cómo Obtener tu Clave' : 'Guide: How to Get Your Key', style: theme.titleMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold))),
                    Text('Google AI Studio (Cloud) • 100% Gratis', style: GoogleFonts.mooli(fontSize: 12.0, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440.0,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'Sigue estos 3 pasos sencillos para activar tu asistente médico inteligente:' : 'Follow these 3 easy steps:',
                    style: GoogleFonts.mooli(fontSize: 13.0, color: theme.secondaryText),
                  ),
                  const SizedBox(height: 14.0),
                  _buildGuiaPaso(
                    numero: '1',
                    titulo: isEs ? 'Abre Google AI Studio' : 'Open Google AI Studio',
                    detalle: isEs
                        ? 'Inicia sesión con tu Gmail habitual. Toca el enlace abajo para ir a la página:'
                        : 'Sign in with your Gmail. Tap the link below to open the page:',
                    theme: theme,
                    extraWidget: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: InkWell(
                        onTap: _abrirGoogleAiStudio,
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.open_in_new_rounded, size: 14.0, color: Color(0xFF0284C7)),
                              const SizedBox(width: 6.0),
                              Text('aistudio.google.com/app/apikey', style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7), decoration: TextDecoration.underline)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  _buildGuiaPaso(
                    numero: '2',
                    titulo: isEs ? 'Presiona "Create API key"' : 'Click "Create API key"',
                    detalle: isEs ? 'Toca el botón azul en la pantalla de Google para generar tu clave en un clic.' : 'Click the blue button.',
                    theme: theme,
                  ),
                  const SizedBox(height: 10.0),
                  _buildGuiaPaso(
                    numero: '3',
                    titulo: isEs ? 'Copia y pega tu clave en Doctuario' : 'Copy and paste into Doctuario',
                    detalle: isEs ? 'Copia el código (empieza por AIzaSy...) y pégalo en el campo de texto.' : 'Copy code and paste it here.',
                    theme: theme,
                  ),
                  const SizedBox(height: 14.0),
                  Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18.0),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            isEs
                                ? 'Es 100% gratis con 1.500 consultas médicas diarias. No requiere tarjeta ni suscripción.'
                                : '100% free with 1,500 daily requests. No credit card required.',
                            style: GoogleFonts.mooli(fontSize: 11.5, color: theme.primaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted) _keyFocusNode.requestFocus();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
              child: Text(
                isEs ? 'Entendido' : 'Understood',
                style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 13.0),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuiaPaso({
    required String numero,
    required String titulo,
    required String detalle,
    required FlutterFlowTheme theme,
    Widget? extraWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12.0,
          backgroundColor: const Color(0xFF4F46E5),
          child: Text(numero, style: GoogleFonts.mooli(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: GoogleFonts.mooli(fontWeight: FontWeight.bold, fontSize: 12.5, color: theme.primaryText)),
              Text(detalle, style: GoogleFonts.mooli(fontSize: 12.0, color: theme.secondaryText)),
              if (extraWidget != null) extraWidget,
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _probarConexion() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testResult = 'Por favor, ingresa una clave de API antes de probar.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _isSuccess = null;
    });

    final res = await GeminiAiService.instance.validateApiKey(key);
    if (mounted) {
      setState(() {
        _isTesting = false;
        _isSuccess = res['valid'] as bool;
        _testResult = res['message'] as String;
      });
    }
  }

  Future<void> _guardarClave() async {
    final key = _keyController.text.trim();
    setState(() => _isSaving = true);
    await GeminiAiService.instance.saveApiKey(key);

    if (mounted) {
      setState(() => _isSaving = false);
      final isEs = I18nService.instance.isSpanish;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs ? 'Configuración de Gemini 3.8 Flash guardada con éxito.' : 'Gemini 3.8 Flash settings saved.',
            style: GoogleFonts.mooli(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _eliminarClave() async {
    await GeminiAiService.instance.removeApiKey();
    if (mounted) {
      final isEs = I18nService.instance.isSpanish;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEs ? 'Clave eliminada.' : 'Key removed.', style: GoogleFonts.mooli(color: Colors.white)),
          backgroundColor: Colors.grey.shade700,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isEs = I18nService.instance.isSpanish;
    final hasExistingKey = GeminiAiService.instance.hasKey;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: theme.secondaryBackground,
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]), borderRadius: BorderRadius.circular(10.0)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEs ? 'Inteligencia Artificial Médica' : 'Medical Artificial Intelligence', style: theme.titleMedium.override(font: GoogleFonts.mooli(fontWeight: FontWeight.bold))),
                Text('Google Gemini 3.8 Flash', style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: FontWeight.w600, color: const Color(0xFF06B6D4))),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480.0,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEs
                    ? 'Conecta tu clave personal (BYOK) para habilitar lectura de documentos clínicos, importación masiva de pacientes y resúmenes automáticos con privacidad total.'
                    : 'Connect your personal API key (BYOK) to enable reading clinical documents, bulk patient imports and summaries with complete privacy.',
                style: theme.bodyMedium.override(font: GoogleFonts.mooli(), color: theme.secondaryText, fontSize: 13.0),
              ),
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20.0),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        isEs ? 'Google ofrece 1.500 peticiones diarias gratis por cuenta.' : 'Google offers 1,500 daily requests free.',
                        style: GoogleFonts.mooli(fontSize: 12.0, fontWeight: FontWeight.w500, color: theme.primaryText),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _mostrarGuiaPasoAPaso,
                      icon: const Icon(Icons.help_outline_rounded, size: 14.0),
                      label: Text(
                        isEs ? 'Obtener Clave' : 'Get Key',
                        style: GoogleFonts.mooli(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                isEs ? 'Clave de API de Gemini' : 'Gemini API Key',
                style: GoogleFonts.mooli(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.primaryText),
              ),
              const SizedBox(height: 6.0),
              TextField(
                controller: _keyController,
                focusNode: _keyFocusNode,
                obscureText: _obscureText,
                style: GoogleFonts.mooli(fontSize: 13.0),
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: GoogleFonts.mooli(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: theme.primaryBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: theme.alternate)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: theme.alternate)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20.0),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _probarConexion,
                    icon: _isTesting
                        ? const SizedBox(width: 14.0, height: 14.0, child: CircularProgressIndicator(strokeWidth: 2.0))
                        : const Icon(Icons.bolt_rounded, size: 16.0),
                    label: Text(isEs ? 'Probar Conexión' : 'Test Connection', style: GoogleFonts.mooli(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                  if (hasExistingKey) ...[
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _eliminarClave,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16.0, color: Colors.redAccent),
                      label: Text(isEs ? 'Eliminar' : 'Remove', style: GoogleFonts.mooli(fontSize: 12.0, color: Colors.redAccent)),
                    ),
                  ],
                ],
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 12.0),
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: (_isSuccess == true ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: (_isSuccess == true ? Colors.green : Colors.red).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: _isSuccess == true ? Colors.green : Colors.red,
                        size: 18.0,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(_testResult!, style: GoogleFonts.mooli(fontSize: 12.0, color: _isSuccess == true ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isEs ? 'Cerrar' : 'Close', style: GoogleFonts.mooli(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _guardarClave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16.0,
                  height: 16.0,
                  child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation(Colors.white)),
                )
              : Text(isEs ? 'Guardar Clave' : 'Save Key', style: GoogleFonts.mooli(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
