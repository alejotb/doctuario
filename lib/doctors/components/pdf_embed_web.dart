// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredPdfViews = <String>{};

/// Renderiza un visor PDF interactivo dentro de la misma aplicación web usando un iframe HTML5
/// que permite leer, hacer zoom, descargar e imprimir directamente desde el visor integrado del navegador.
Widget buildEmbeddedPdfViewer({
  required String pdfUrl,
  required VoidCallback onOpenExternal,
  double height = 460,
}) {
  final viewType = 'doctuario-pdf-viewer-${pdfUrl.hashCode}';
  if (!_registeredPdfViews.contains(viewType)) {
    _registeredPdfViews.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = pdfUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '12px'
        ..allowFullscreen = true;
      return iframe;
    });
  }

  return Container(
    height: height,
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF334155)),
    ),
    child: HtmlElementView(viewType: viewType),
  );
}
