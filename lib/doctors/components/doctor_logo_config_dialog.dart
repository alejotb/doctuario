import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/supabase/supabase.dart';
import '../../flutter_flow/flutter_flow_theme.dart';
import '../../flutter_flow/upload_data.dart';

/// Modelo de logotipo de consultorio o clínica para membretes médicos.
class DoctorLogoEntry {
  DoctorLogoEntry({
    required this.url,
    required this.uso,
    this.isActive = false,
  });

  final String url;
  String uso;
  bool isActive;

  Map<String, dynamic> toJson() => {'url': url, 'uso': uso, 'isActive': isActive};

  factory DoctorLogoEntry.fromJson(Map<String, dynamic> json) => DoctorLogoEntry(
        url: json['url'] as String,
        uso: (json['uso'] as String?) ?? 'Recetas e Informes Médicos',
        isActive: (json['isActive'] as bool?) ?? false,
      );
}

/// Diálogo modal interactivo para subir, gestionar y seleccionar logotipos
/// de membrete institucional con asignación de uso (recetas, informes, sedes).
class DoctorLogoConfigDialog extends StatefulWidget {
  final String idDoctor;
  final String? initialLogoUrl;
  final Function(String? newLogoUrl)? onLogoUpdated;

  const DoctorLogoConfigDialog({
    super.key,
    required this.idDoctor,
    this.initialLogoUrl,
    this.onLogoUpdated,
  });

  static Future<String?> show(
    BuildContext context, {
    required String idDoctor,
    String? initialLogoUrl,
    Function(String? newLogoUrl)? onLogoUpdated,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DoctorLogoConfigDialog(
        idDoctor: idDoctor,
        initialLogoUrl: initialLogoUrl,
        onLogoUpdated: onLogoUpdated,
      ),
    );
  }

  @override
  State<DoctorLogoConfigDialog> createState() => _DoctorLogoConfigDialogState();
}

class _DoctorLogoConfigDialogState extends State<DoctorLogoConfigDialog> {
  final List<DoctorLogoEntry> _logos = [];
  String? _activeLogoUrl;
  bool _isLoading = true;
  bool _isUploading = false;

  static const List<String> _opcionesUso = [
    'Recetas e Informes Médicos',
    'Consultorio Principal',
    'Clínica / Sede Secundaria',
    'Facturas y Presupuestos',
    'Membrete General',
  ];

  String get _storageKey => 'prontudoc_doctor_logos_${widget.idDoctor}';

  @override
  void initState() {
    super.initState();
    _activeLogoUrl = widget.initialLogoUrl;
    _cargarLogos();
  }

  Future<void> _cargarLogos() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_storageKey);
      final List<DoctorLogoEntry> loaded = [];

      if (storedJson != null && storedJson.isNotEmpty) {
        final decoded = jsonDecode(storedJson) as List;
        for (final item in decoded) {
          loaded.add(DoctorLogoEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      if (_activeLogoUrl == null || _activeLogoUrl!.isEmpty) {
        final metaLogo = SupaFlow.client.auth.currentUser?.userMetadata?['logo_url']?.toString();
        if (metaLogo != null && metaLogo.trim().isNotEmpty) {
          _activeLogoUrl = metaLogo.trim();
        }
      }

      if (_activeLogoUrl == null || _activeLogoUrl!.isEmpty) {
        try {
          final rows = await DoctoresTable().queryRows(queryFn: (q) => q.eq('id', widget.idDoctor));
          if (rows.isNotEmpty) {
            _activeLogoUrl = (rows.first.logoUrl != null && rows.first.logoUrl!.isNotEmpty)
                ? rows.first.logoUrl
                : rows.first.credencialUrl;
          }
        } catch (_) {}
      }

      if (_activeLogoUrl != null && _activeLogoUrl!.isNotEmpty) {
        final existe = loaded.any((l) => l.url == _activeLogoUrl);
        if (!existe) {
          loaded.insert(0, DoctorLogoEntry(url: _activeLogoUrl!, uso: 'Recetas e Informes Médicos', isActive: true));
        } else {
          for (final l in loaded) {
            l.isActive = (l.url == _activeLogoUrl);
          }
        }
      }

      if (mounted) setState(() { _logos.clear(); _logos.addAll(loaded); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarEnPreferencias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_logos.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _sincronizarLogoRemoto(String? url) async {
    try {
      await SupaFlow.client.auth.updateUser(UserAttributes(data: {'logo_url': url ?? ''}));
    } catch (_) {}
    try {
      await DoctoresTable().update(
        data: {'logo_url': url},
        matchingRows: (q) => q.eq('id', widget.idDoctor),
      );
    } catch (_) {
      try {
        await DoctoresTable().update(
          data: {'credencial_url': url},
          matchingRows: (q) => q.eq('id', widget.idDoctor),
        );
      } catch (_) {}
    }
  }

  Future<void> _seleccionarYSubirLogo() async {
    final mediaList = await selectMediaWithSourceBottomSheet(
      context: context,
      storageFolderPath: 'doctores_logos',
      allowPhoto: true,
      imageQuality: 85,
    );

    if (mediaList == null || mediaList.isEmpty) return;
    setState(() => _isUploading = true);

    try {
      final uploadedUrl = await uploadSupabaseStorageFile(
        bucketName: kImagesBucket,
        selectedFile: mediaList.first,
      );

      if (uploadedUrl.isNotEmpty) {
        for (final l in _logos) { l.isActive = false; }
        final nuevo = DoctorLogoEntry(url: uploadedUrl, uso: _logos.isEmpty ? 'Recetas e Informes Médicos' : 'Consultorio Principal', isActive: true);
        _logos.insert(0, nuevo);
        _activeLogoUrl = uploadedUrl;

        await _guardarEnPreferencias();
        widget.onLogoUpdated?.call(uploadedUrl);
        await _sincronizarLogoRemoto(uploadedUrl);

        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Logotipo subido y asignado como membrete activo.'), backgroundColor: Color(0xFF059669)));
        }
      } else {
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _asignarComoActivo(DoctorLogoEntry entry) async {
    setState(() {
      for (final l in _logos) { l.isActive = (l.url == entry.url); }
      _activeLogoUrl = entry.url;
    });

    await _guardarEnPreferencias();
    widget.onLogoUpdated?.call(entry.url);
    await _sincronizarLogoRemoto(entry.url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logotipo activado para: ${entry.uso}'), backgroundColor: const Color(0xFF0284C7)));
    }
  }

  Future<void> _eliminarLogo(DoctorLogoEntry entry) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar logotipo?'),
        content: Text('Se retirará este archivo (${entry.uso}) de tus membretes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _logos.removeWhere((l) => l.url == entry.url);
      if (entry.isActive) {
        if (_logos.isNotEmpty) {
          _logos.first.isActive = true;
          _activeLogoUrl = _logos.first.url;
        } else {
          _activeLogoUrl = null;
        }
      }
    });

    await _guardarEnPreferencias();
    widget.onLogoUpdated?.call(_activeLogoUrl);
    try {
      await deleteSupabaseFileFromPublicUrl(entry.url);
    } catch (_) {}
    await _sincronizarLogoRemoto(_activeLogoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.secondaryBackground,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.business_rounded, color: Color(0xFF0284C7), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Membrete Institucional', style: GoogleFonts.mooli(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Sube y asigna logotipos para recetas, informes o sedes', style: TextStyle(fontSize: 11.5, color: theme.secondaryText)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context, _activeLogoUrl)),
              ],
            ),
            const Divider(height: 20),
            if (_isLoading)
              const Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator()))
            else ...[
              _buildUploadArrowBox(theme),
              const SizedBox(height: 16),
              if (_logos.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tus Logotipos Asignados (${_logos.length})', style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold, color: theme.primaryText)),
                    Text('Toca uno para activar', style: TextStyle(fontSize: 11, color: theme.secondaryText)),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _logos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildLogoItemCard(_logos[index], theme),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, _activeLogoUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Listo', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArrowBox(FlutterFlowTheme theme) {
    return InkWell(
      onTap: _isUploading ? null : _seleccionarYSubirLogo,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          children: [
            if (_isUploading)
              const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5))
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 26),
              ),
            const SizedBox(height: 10),
            Text(
              _isUploading ? 'Subiendo logotipo a la nube...' : 'Toca aquí para subir logotipo',
              style: GoogleFonts.mooli(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
            ),
            const SizedBox(height: 3),
            Text('Formatos: PNG, JPG, WEBP (Fondo blanco o transparente recomendado)', style: TextStyle(fontSize: 11, color: theme.secondaryText), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoItemCard(DoctorLogoEntry item, FlutterFlowTheme theme) {
    final isActivo = item.isActive;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActivo ? const Color(0xFFE0F2FE).withValues(alpha: 0.5) : theme.primaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActivo ? const Color(0xFF0284C7) : theme.alternate, width: isActivo ? 1.5 : 1.0),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 52,
              height: 52,
              color: Colors.white,
              child: Image.network(
                item.url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, size: 24, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  value: item.uso,
                  isDense: true,
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: GoogleFonts.mooli(fontSize: 12.5, fontWeight: FontWeight.w600, color: theme.primaryText),
                  items: _opcionesUso.map((op) => DropdownMenuItem(value: op, child: Text(op, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (nuevoUso) {
                    if (nuevoUso != null) {
                      setState(() => item.uso = nuevoUso);
                      _guardarEnPreferencias();
                    }
                  },
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => _asignarComoActivo(item),
                  child: Row(
                    children: [
                      Icon(isActivo ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 14, color: isActivo ? const Color(0xFF0284C7) : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        isActivo ? 'Membrete Activo' : 'Usar para membrete',
                        style: TextStyle(fontSize: 11, fontWeight: isActivo ? FontWeight.bold : FontWeight.normal, color: isActivo ? const Color(0xFF0284C7) : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
            tooltip: 'Eliminar logotipo',
            onPressed: () => _eliminarLogo(item),
          ),
        ],
      ),
    );
  }
}
