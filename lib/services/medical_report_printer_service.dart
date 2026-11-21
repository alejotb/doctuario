import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../backend/supabase/supabase.dart';

/// Servicio para generar, previsualizar e imprimir reportes médicos
/// (Historias Clínicas, Evoluciones y Resultados de Estudios) con membrete/logo.
class MedicalReportPrinterService {
  MedicalReportPrinterService._();
  static final MedicalReportPrinterService instance =
      MedicalReportPrinterService._();

  /// Muestra una vista previa lista para imprimir o compartir.
  /// Permite elegir entre Hoja Completa o Media Hoja y entre formato por Bloques o Texto Libre.
  Future<void> mostrarReporteImprimible({
    required BuildContext context,
    required String tituloDocumento,
    required UsuariosRow? paciente,
    required UsuariosRow? doctorUsuario,
    required DoctoresRow? doctorInfo,
    String? logoUrl,
    required Widget contenidoCuerpo,
    String? textoLibreInicial,
    String? notasPie,
  }) async {
    DoctoresRow? docInfoEfectivo = doctorInfo;
    UsuariosRow? docUsrEfectivo = doctorUsuario;

    // Si faltan datos de especialidad o logo_url, consultarlos directamente del doctor autenticado o indicado
    final docId = docInfoEfectivo?.id ??
        docUsrEfectivo?.id ??
        SupaFlow.client.auth.currentUser?.id;
    if (docId != null &&
        docId.isNotEmpty &&
        ((docInfoEfectivo?.logoUrl?.trim().isEmpty ?? true) ||
            (docInfoEfectivo?.especialidad?.trim().isEmpty ?? true))) {
      try {
        final res = await SupaFlow.client
            .from('doctores')
            .select()
            .eq('id', docId)
            .maybeSingle();
        if (res != null) {
          docInfoEfectivo = DoctoresRow(Map<String, dynamic>.from(res));
        }
      } catch (_) {}
    }

    if (docUsrEfectivo == null && docId != null && docId.isNotEmpty) {
      try {
        final uRes = await SupaFlow.client
            .from('usuarios')
            .select()
            .eq('id', docId)
            .maybeSingle();
        if (uRes != null) {
          docUsrEfectivo = UsuariosRow(Map<String, dynamic>.from(uRes));
        }
      } catch (_) {}
    }

    final effectiveLogo = (logoUrl != null && logoUrl.trim().isNotEmpty)
        ? logoUrl.trim()
        : ((docInfoEfectivo?.logoUrl?.trim().isNotEmpty ?? false)
            ? docInfoEfectivo!.logoUrl!.trim()
            : null);

    bool esMediaHoja = false;
    bool usarTextoLibre = false;
    final textoLibreCtrl = TextEditingController(
      text: textoLibreInicial ?? '',
    );

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final anchoHoja = esMediaHoja ? 460.0 : 650.0;
            final paddingHoja = esMediaHoja ? 16.0 : 24.0;

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 680,
                constraints: const BoxConstraints(maxHeight: 780),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barra de herramientas superior (Imprimir / Cerrar)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.print_outlined,
                                  color: Color(0xFF0284C7), size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tituloDocumento,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.mooli(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      esMediaHoja
                                          ? '📄 Preparando impresión en Media Hoja...'
                                          : '📄 Preparando impresión en Hoja Completa...',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.print, size: 18),
                              label: const Text('Imprimir'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              icon: const Icon(Icons.close, color: Colors.grey),
                              tooltip: 'Cerrar',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Controles de tamaño de hoja y formato (Bloques vs Texto libre)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Hoja Completa',
                              style: TextStyle(fontSize: 11.5)),
                          selected: !esMediaHoja,
                          onSelected: (v) {
                            if (v) setDialogState(() => esMediaHoja = false);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Media Hoja',
                              style: TextStyle(fontSize: 11.5)),
                          selected: esMediaHoja,
                          onSelected: (v) {
                            if (v) setDialogState(() => esMediaHoja = true);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Por Bloques',
                              style: TextStyle(fontSize: 11.5)),
                          selected: !usarTextoLibre,
                          onSelected: (v) {
                            if (v) setDialogState(() => usarTextoLibre = false);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Texto Completo',
                              style: TextStyle(fontSize: 11.5)),
                          selected: usarTextoLibre,
                          onSelected: (v) {
                            if (v) setDialogState(() => usarTextoLibre = true);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Hoja médica con membrete (Área scrolleable)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: anchoHoja,
                            padding: EdgeInsets.all(paddingHoja),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. MEMBRETE / ENCABEZADO INSTITUCIONAL
                                _buildEncabezadoMembrete(
                                  doctorUsuario: docUsrEfectivo,
                                  doctorInfo: docInfoEfectivo,
                                  logoUrl: effectiveLogo,
                                ),
                                const Divider(
                                    thickness: 2, color: Color(0xFF0284C7)),
                                const SizedBox(height: 12),

                                // 2. DATOS DEL PACIENTE
                                _buildFichaPaciente(paciente),
                                const SizedBox(height: 16),
                                const Divider(color: Colors.black12),
                                const SizedBox(height: 12),

                                // 3. CONTENIDO DEL REPORTE (Bloques o Texto Completo editable)
                                if (usarTextoLibre)
                                  TextField(
                                    controller: textoLibreCtrl,
                                    maxLines: null,
                                    minLines: esMediaHoja ? 6 : 10,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Escribe o ajusta el contenido completo del récipe o informe...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      contentPadding: const EdgeInsets.all(12),
                                    ),
                                  )
                                else
                                  contenidoCuerpo,

                                SizedBox(height: esMediaHoja ? 18 : 30),
                                // 4. PIE DE PÁGINA Y FIRMA MÉDICA
                                _buildPieDeFirma(
                                    docUsrEfectivo, docInfoEfectivo, notasPie),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    textoLibreCtrl.dispose();
  }

  /// Construye el membrete superior del reporte
  Widget _buildEncabezadoMembrete({
    required UsuariosRow? doctorUsuario,
    required DoctoresRow? doctorInfo,
    String? logoUrl,
  }) {
    final nombreDoc = doctorUsuario?.nombre ?? 'Doctor Tratante';
    final metaEsp = SupaFlow.client.auth.currentUser?.userMetadata?['especialidad']
        ?.toString()
        .trim();
    final especialidad = (doctorInfo?.especialidad?.trim().isNotEmpty ?? false)
        ? doctorInfo!.especialidad!.trim()
        : ((metaEsp != null && metaEsp.isNotEmpty)
            ? metaEsp
            : 'Especialidad Médica');
    final colegiatura = doctorInfo?.nroColegiatura;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo del consultorio (si el doctor no subió logo, se muestra el emblema con su especialidad)
        if (logoUrl != null && logoUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              logoUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholderLogo(),
            ),
          )
        else
          _buildPlaceholderLogo(),

        const SizedBox(width: 16),

        // Datos del médico y clínica
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dr(a). $nombreDoc',
                style: GoogleFonts.mooli(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                especialidad,
                style: GoogleFonts.mooli(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0284C7),
                ),
              ),
              if (colegiatura != null && colegiatura.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'M.P.P.S / Nro. Colegiatura: $colegiatura',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
              Text(
                'Fecha de emisión: ${DateFormat('dd/MM/yyyy - hh:mm a').format(DateTime.now())}',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderLogo() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: const Icon(Icons.local_hospital_rounded,
          color: Color(0xFF0284C7), size: 36),
    );
  }

  /// Construye la ficha del paciente en el encabezado
  Widget _buildFichaPaciente(UsuariosRow? paciente) {
    final nombre = paciente?.nombre ?? 'Paciente No Identificado';
    final cedula = paciente?.cedula ?? 'No registrada';
    final telefono = paciente?.telefono ?? 'No registrado';
    final fechaNac = paciente?.fechaNacimiento;
    String edadStr = 'No registrada';
    if (fechaNac != null) {
      final ahora = DateTime.now();
      int edad = ahora.year - fechaNac.year;
      if (ahora.month < fechaNac.month ||
          (ahora.month == fechaNac.month && ahora.day < fechaNac.day)) {
        edad--;
      }
      edadStr = '$edad años';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DATOS DEL PACIENTE',
            style: GoogleFonts.mooli(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text('Nombre: $nombre',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text('Cédula: $cedula',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('Edad: $edadStr',
                    style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: Text('Teléfono: $telefono',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construye el pie de firma profesional
  Widget _buildPieDeFirma(
    UsuariosRow? doctorUsuario,
    DoctoresRow? doctorInfo,
    String? notasPie,
  ) {
    final nombreDoc = doctorUsuario?.nombre ?? 'Doctor Tratante';
    final colegiatura = doctorInfo?.nroColegiatura ?? '';

    return Column(
      children: [
        if (notasPie != null && notasPie.isNotEmpty) ...[
          Text(
            notasPie,
            style: const TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
        Center(
          child: Column(
            children: [
              Container(width: 200, height: 1, color: Colors.black87),
              const SizedBox(height: 6),
              Text(
                'Dr(a). $nombreDoc',
                style: GoogleFonts.mooli(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (colegiatura.isNotEmpty)
                Text(
                  'Firma y Sello / Colegiatura: $colegiatura',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
