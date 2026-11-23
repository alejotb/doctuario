import 'package:flutter/material.dart';

/// Fallback para plataformas no-web (Android / iOS / Desktop)
Widget buildEmbeddedPdfViewer({
  required String pdfUrl,
  required VoidCallback onOpenExternal,
  double height = 460,
}) {
  return Container(
    height: 300,
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFCBD5E1)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.picture_as_pdf_rounded,
            color: Colors.red,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Documento Clínico en PDF',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Abre el visor nativo del dispositivo para leer, hacer zoom o imprimir el PDF completo.',
          style: TextStyle(fontSize: 12.5, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onOpenExternal,
          icon: const Icon(Icons.visibility_rounded, size: 18),
          label: const Text(
            'Abrir y Visualizar PDF Completo',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
