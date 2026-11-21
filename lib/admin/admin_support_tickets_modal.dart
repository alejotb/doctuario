import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../backend/supabase/supabase.dart';

/// Modal administrativo para revisar y resolver tickets de soporte enviados por doctores.
/// Muestra reportes organizados por fecha y estado (Abiertos / Resueltos).
class AdminSupportTicketsModal extends StatefulWidget {
  const AdminSupportTicketsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const AdminSupportTicketsModal(),
    );
  }

  @override
  State<AdminSupportTicketsModal> createState() =>
      _AdminSupportTicketsModalState();
}

class _AdminSupportTicketsModalState extends State<AdminSupportTicketsModal> {
  bool _isLoading = true;
  String _filtroEstado = 'abiertos'; // 'abiertos', 'resueltos', 'todos'
  List<SoporteTicketsRow> _tickets = [];

  @override
  void initState() {
    super.initState();
    _cargarTickets();
  }

  Future<void> _cargarTickets() async {
    setState(() => _isLoading = true);
    try {
      _tickets = await SoporteTicketsTable().queryRows(
        queryFn: (q) => q.order('created_at', ascending: false),
      );
    } catch (e) {
      debugPrint('Error cargando tickets de soporte: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SoporteTicketsRow> get _ticketsFiltrados {
    return _tickets.where((t) {
      final st = (t.estado ?? 'abierto').toLowerCase();
      if (_filtroEstado == 'abiertos') {
        return st == 'abierto' || st == 'en_revision';
      }
      if (_filtroEstado == 'resueltos') {
        return st == 'resuelto' || st == 'cerrado';
      }
      return true;
    }).toList();
  }

  Future<void> _resolverTicket(SoporteTicketsRow ticket) async {
    final respCtrl = TextEditingController(text: ticket.respuestaAdmin ?? '');
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resolver Ticket',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asunto: ${ticket.asunto}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: respCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Nota o respuesta de solución (opcional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Marcar Resuelto'),
          ),
        ],
      ),
    );
    final respuesta = respCtrl.text.trim();
    respCtrl.dispose();

    if (confirmar != true) return;
    try {
      await SoporteTicketsTable().update(
        data: {
          'estado': 'resuelto',
          if (respuesta.isNotEmpty) 'respuesta_admin': respuesta,
        },
        matchingRows: (q) => q.eq('id', ticket.id),
      );
      if (ticket.idDoctor != null && ticket.idDoctor!.isNotEmpty) {
        try {
          await SupaFlow.client.from('notificaciones_citas').insert({
            'id_usuario': ticket.idDoctor,
            'tipo': 'soporte_resuelto',
            'titulo': '✅ Ticket de Soporte Resuelto',
            'mensaje': respuesta.isNotEmpty
                ? 'Tu reporte "${ticket.asunto}" fue resuelto: $respuesta'
                : 'Tu reporte "${ticket.asunto}" ha sido atendido y marcado como resuelto.',
            'leido': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {}
      }
      await _cargarTickets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error actualizando ticket: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _ticketsFiltrados;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent_rounded,
                    color: Color(0xFF0284C7), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tickets y Reportes de Soporte',
                    style: GoogleFonts.mooli(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _cargarTickets,
                  tooltip: 'Actualizar',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Abiertos'),
                  selected: _filtroEstado == 'abiertos',
                  onSelected: (v) {
                    if (v) setState(() => _filtroEstado = 'abiertos');
                  },
                ),
                ChoiceChip(
                  label: const Text('Resueltos'),
                  selected: _filtroEstado == 'resueltos',
                  onSelected: (v) {
                    if (v) setState(() => _filtroEstado = 'resueltos');
                  },
                ),
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filtroEstado == 'todos',
                  onSelected: (v) {
                    if (v) setState(() => _filtroEstado = 'todos');
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtrados.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay tickets en esta categoría.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtrados.length,
                          itemBuilder: (ctx, i) {
                            final t = filtrados[i];
                            final fechaStr = DateFormat('dd/MM/yyyy HH:mm')
                                .format(t.createdAt.toLocal());
                            final esResuelto = (t.estado ?? 'abierto') == 'resuelto' ||
                                (t.estado ?? '') == 'cerrado';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t.asunto,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: esResuelto
                                                ? const Color(0xFFD1FAE5)
                                                : const Color(0xFFFEF3C7),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            (t.estado ?? 'abierto')
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: esResuelto
                                                  ? const Color(0xFF065F46)
                                                  : const Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dr(a). ${t.doctorNombre ?? "Médico"} • $fechaStr • Prioridad: ${(t.prioridad ?? "media").toUpperCase()}',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(t.mensaje,
                                        style: const TextStyle(fontSize: 12.5)),
                                    if (t.respuestaAdmin?.isNotEmpty ??
                                        false) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Respuesta: ${t.respuestaAdmin}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF166534)),
                                        ),
                                      ),
                                    ],
                                    if (!esResuelto) ...[
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF0F766E),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                          onPressed: () => _resolverTicket(t),
                                          icon: const Icon(
                                              Icons.check_circle_outline,
                                              size: 16),
                                          label: const Text('Resolver',
                                              style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
