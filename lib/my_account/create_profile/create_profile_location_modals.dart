import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/i18n_service.dart';
import '/services/venezuela_locations.dart';

/// Selector interactivo de Ubicación (Estado y Ciudad) para el formulario de perfil.
class CreateProfileLocationSelector extends StatelessWidget {
  const CreateProfileLocationSelector({
    super.key,
    required this.estadoOrigen,
    required this.ciudadActual,
    required this.ciudadOrigenCompleta,
    required this.onEstadoSelected,
    required this.onCiudadSelected,
  });

  final String? estadoOrigen;
  final String? ciudadActual;
  final String? ciudadOrigenCompleta;
  final ValueChanged<String> onEstadoSelected;
  final void Function(String ciudad, String formatted) onCiudadSelected;

  void _mostrarModalSeleccionarEstado(BuildContext context) {
    final i18n = I18nService.instance;
    String filtro = '';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = FlutterFlowTheme.of(context);
            final screenWidth = MediaQuery.of(context).size.width;
            final isDesktop = screenWidth >= 900.0;
            final modalWidth = isDesktop ? screenWidth * 0.40 : screenWidth * 0.88;
            final estados = VenezuelaLocations.searchEstados(filtro);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Container(
                width: modalWidth.clamp(320.0, 480.0),
                constraints: const BoxConstraints(maxHeight: 520.0),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18.0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 16.0, 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.map_outlined, color: theme.primary, size: 22.0),
                              const SizedBox(width: 8.0),
                              Text(
                                i18n.isSpanish ? 'Selecciona tu Estado' : 'Select State',
                                style: theme.titleMedium.override(
                                  font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                  fontSize: 17.0,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20.0),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1.0),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: TextField(
                        onChanged: (val) => setModalState(() => filtro = val),
                        decoration: InputDecoration(
                          hintText: i18n.isSpanish ? 'Buscar estado...' : 'Search state...',
                          hintStyle: theme.labelSmall.override(font: GoogleFonts.mooli()),
                          prefixIcon: Icon(Icons.search_rounded, color: theme.secondaryText, size: 20.0),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                          filled: true,
                          fillColor: theme.primaryBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(color: theme.alternate, width: 1.0),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: estados.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                i18n.isSpanish ? 'No se encontraron estados' : 'No states found',
                                style: theme.bodySmall.override(font: GoogleFonts.mooli()),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                              itemCount: estados.length,
                              separatorBuilder: (_, __) => const Divider(height: 1.0),
                              itemBuilder: (context, index) {
                                final est = estados[index];
                                final isSelected = estadoOrigen == est;
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                                  leading: Icon(
                                    Icons.place_outlined,
                                    size: 18.0,
                                    color: isSelected ? theme.primary : theme.secondaryText,
                                  ),
                                  title: Text(
                                    est,
                                    style: theme.bodyMedium.override(
                                      font: GoogleFonts.mooli(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      color: isSelected ? theme.primary : theme.primaryText,
                                      fontSize: 14.0,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle_rounded, color: theme.primary, size: 20.0)
                                      : null,
                                  onTap: () {
                                    onEstadoSelected(est);
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarModalSeleccionarCiudad(BuildContext context) {
    final i18n = I18nService.instance;
    if (estadoOrigen == null || estadoOrigen!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.isSpanish ? 'Por favor, selecciona primero un estado.' : 'Please select a state first.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    String filtro = '';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = FlutterFlowTheme.of(context);
            final screenWidth = MediaQuery.of(context).size.width;
            final isDesktop = screenWidth >= 900.0;
            final modalWidth = isDesktop ? screenWidth * 0.40 : screenWidth * 0.88;
            final ciudades = VenezuelaLocations.searchCiudades(estadoOrigen!, filtro);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Container(
                width: modalWidth.clamp(320.0, 480.0),
                constraints: const BoxConstraints(maxHeight: 520.0),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18.0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 16.0, 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.location_city_outlined, color: theme.primary, size: 22.0),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    '${i18n.isSpanish ? "Ciudades en" : "Cities in"} $estadoOrigen',
                                    style: theme.titleMedium.override(
                                      font: GoogleFonts.mooli(fontWeight: FontWeight.bold),
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20.0),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1.0),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: TextField(
                        onChanged: (val) => setModalState(() => filtro = val),
                        decoration: InputDecoration(
                          hintText: i18n.isSpanish ? 'Buscar ciudad...' : 'Search city...',
                          hintStyle: theme.labelSmall.override(font: GoogleFonts.mooli()),
                          prefixIcon: Icon(Icons.search_rounded, color: theme.secondaryText, size: 20.0),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                          filled: true,
                          fillColor: theme.primaryBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(color: theme.alternate, width: 1.0),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: ciudades.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                i18n.isSpanish
                                    ? 'No se encontraron ciudades para este estado'
                                    : 'No cities found for this state',
                                style: theme.bodySmall.override(font: GoogleFonts.mooli()),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                              itemCount: ciudades.length,
                              separatorBuilder: (_, __) => const Divider(height: 1.0),
                              itemBuilder: (context, index) {
                                final ciu = ciudades[index];
                                final formatted = '$ciu, $estadoOrigen';
                                final isSelected = ciudadOrigenCompleta == formatted || ciudadActual == ciu;
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                                  leading: Icon(
                                    Icons.location_city_outlined,
                                    size: 18.0,
                                    color: isSelected ? theme.primary : theme.secondaryText,
                                  ),
                                  title: Text(
                                    ciu,
                                    style: theme.bodyMedium.override(
                                      font: GoogleFonts.mooli(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      color: isSelected ? theme.primary : theme.primaryText,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle_rounded, color: theme.primary, size: 20.0)
                                      : null,
                                  onTap: () {
                                    onCiudadSelected(ciu, formatted);
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18nService.instance;
    final theme = FlutterFlowTheme.of(context);
    final hasEstado = estadoOrigen != null && estadoOrigen!.trim().isNotEmpty;
    final hasCiudad = ciudadActual != null && ciudadActual!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _mostrarModalSeleccionarEstado(context),
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  height: 50.0,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  decoration: BoxDecoration(
                    color: theme.primaryBackground,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: hasEstado ? theme.primary.withValues(alpha: 0.6) : const Color(0x6257636C),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, color: hasEstado ? theme.primary : theme.secondaryText, size: 20.0),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          hasEstado ? estadoOrigen! : (i18n.isSpanish ? 'Estado' : 'State'),
                          style: theme.bodyMedium.override(
                            font: GoogleFonts.mooli(fontWeight: hasEstado ? FontWeight.w600 : FontWeight.normal),
                            color: hasEstado ? theme.primaryText : theme.secondaryText,
                            fontSize: 14.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down_rounded, color: theme.secondaryText, size: 24.0),
                    ],
                  ),
                ),
              ),
            ),
            if (hasEstado) ...[
              const SizedBox(width: 12.0),
              Expanded(
                child: InkWell(
                  onTap: () => _mostrarModalSeleccionarCiudad(context),
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    height: 50.0,
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    decoration: BoxDecoration(
                      color: theme.primaryBackground,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: hasCiudad ? theme.primary.withValues(alpha: 0.6) : const Color(0x6257636C),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_city_outlined,
                          color: hasCiudad ? theme.primary : theme.secondaryText,
                          size: 20.0,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            hasCiudad ? ciudadActual! : (i18n.isSpanish ? 'Ciudad' : 'City'),
                            style: theme.bodyMedium.override(
                              font: GoogleFonts.mooli(fontWeight: hasCiudad ? FontWeight.w600 : FontWeight.normal),
                              color: hasCiudad ? theme.primaryText : theme.secondaryText,
                              fontSize: 14.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down_rounded, color: theme.secondaryText, size: 24.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (ciudadOrigenCompleta != null && ciudadOrigenCompleta!.isNotEmpty) ...[
          const SizedBox(height: 6.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: theme.primary, size: 14.0),
                const SizedBox(width: 4.0),
                Expanded(
                  child: Text(
                    '${i18n.isSpanish ? "Ubicación:" : "Location:"} $ciudadOrigenCompleta',
                    style: theme.bodySmall.override(
                      font: GoogleFonts.mooli(fontWeight: FontWeight.w600),
                      color: theme.primary,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
