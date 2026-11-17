import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../flutter_flow/flutter_flow_theme.dart';

/// Barra de filtros y ordenamiento para el listado de pacientes del médico.
///
/// Permite:
/// 1. Ordenar por: Alfabético A-Z, Alfabético Z-A, Cédula de Identidad, Última Cita.
/// 2. Filtrar por rango de fechas de última cita (con botón de selección y limpieza).
/// 3. Filtrar por categorías rápidas: Todos, Preferenciales, Foráneos.
class PatientFilterBar extends StatelessWidget {
  /// Filtro de categoría actual ('todos', 'preferenciales', 'foraneos')
  final String filtroActivo;

  /// Callback al cambiar la categoría seleccionada
  final ValueChanged<String> onFiltroActivoChanged;

  /// Clave de ordenamiento actual ('alfabetico_asc', 'alfabetico_desc', 'cedula', 'ultima_cita')
  final String ordenSeleccionado;

  /// Callback al cambiar el criterio de ordenamiento
  final ValueChanged<String> onOrdenChanged;

  /// Rango de fechas seleccionado para filtrar por fecha de última cita
  final DateTimeRange? filtroRangoFechas;

  /// Callback para abrir el selector de rango de fechas
  final VoidCallback onSelectRangoFechas;

  /// Callback para limpiar el filtro de fecha activo
  final VoidCallback onClearRangoFechas;

  /// Cantidad total de pacientes registrados
  final int totalPacientes;

  const PatientFilterBar({
    super.key,
    required this.filtroActivo,
    required this.onFiltroActivoChanged,
    required this.ordenSeleccionado,
    required this.onOrdenChanged,
    required this.filtroRangoFechas,
    required this.onSelectRangoFechas,
    required this.onClearRangoFechas,
    required this.totalPacientes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Container(
      color: theme.secondaryBackground,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSortMenu(context, theme),
            _buildDateFilterChip(context, theme),
            const SizedBox(width: 8),
            _buildCategoryChip(
              context: context,
              theme: theme,
              label: 'Todos ($totalPacientes)',
              valor: 'todos',
            ),
            const SizedBox(width: 6),
            _buildCategoryChip(
              context: context,
              theme: theme,
              label: '⭐ Preferenciales',
              valor: 'preferenciales',
            ),
            const SizedBox(width: 6),
            _buildCategoryChip(
              context: context,
              theme: theme,
              label: '🚗 Foráneos',
              valor: 'foraneos',
            ),
          ],
        ),
      ),
    );
  }

  /// Menú emergente de selección de criterio de orden
  Widget _buildSortMenu(BuildContext context, FlutterFlowTheme theme) {
    final Map<String, String> labels = {
      'alfabetico_asc': 'Nombre (A-Z)',
      'alfabetico_desc': 'Nombre (Z-A)',
      'cedula': 'N° Cédula',
      'ultima_cita': 'Última Cita',
    };

    return PopupMenuButton<String>(
      initialValue: ordenSeleccionado,
      tooltip: 'Ordenar pacientes',
      onSelected: onOrdenChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'alfabetico_asc',
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18),
              SizedBox(width: 8),
              Text('Nombre (A-Z)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'alfabetico_desc',
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18),
              SizedBox(width: 8),
              Text('Nombre (Z-A)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'cedula',
          child: Row(
            children: [
              Icon(Icons.badge_outlined, size: 18),
              SizedBox(width: 8),
              Text('Número de Cédula'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'ultima_cita',
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 18),
              SizedBox(width: 8),
              Text('Última Cita (Reciente)'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.primaryBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.alternate),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 16, color: theme.primary),
            const SizedBox(width: 4),
            Text(
              labels[ordenSeleccionado] ?? 'Ordenar',
              style: GoogleFonts.mooli(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.secondaryText),
          ],
        ),
      ),
    );
  }

  /// Chip interactivo para activar o limpiar el filtro de fecha
  Widget _buildDateFilterChip(BuildContext context, FlutterFlowTheme theme) {
    final hasDateFilter = filtroRangoFechas != null;
    final labelText = hasDateFilter
        ? '${DateFormat('dd/MM').format(filtroRangoFechas!.start)} - ${DateFormat('dd/MM').format(filtroRangoFechas!.end)}'
        : 'Fecha cita';

    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: onSelectRangoFechas,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: hasDateFilter
                ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                : theme.primaryBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasDateFilter ? const Color(0xFF0284C7) : theme.alternate,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 15,
                color: hasDateFilter
                    ? const Color(0xFF0284C7)
                    : theme.secondaryText,
              ),
              const SizedBox(width: 4),
              Text(
                labelText,
                style: GoogleFonts.mooli(
                  fontSize: 12,
                  fontWeight: hasDateFilter ? FontWeight.bold : FontWeight.w500,
                  color: hasDateFilter
                      ? const Color(0xFF0284C7)
                      : theme.primaryText,
                ),
              ),
              if (hasDateFilter) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClearRangoFechas,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Chip para selección de categoría (Todos, Preferenciales, Foráneos)
  Widget _buildCategoryChip({
    required BuildContext context,
    required FlutterFlowTheme theme,
    required String label,
    required String valor,
  }) {
    final activo = filtroActivo == valor;
    return ChoiceChip(
      label: Text(label),
      selected: activo,
      selectedColor: theme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: activo ? FontWeight.bold : FontWeight.normal,
        color: activo ? theme.primary : theme.primaryText,
      ),
      onSelected: (selected) {
        if (selected) onFiltroActivoChanged(valor);
      },
    );
  }
}
