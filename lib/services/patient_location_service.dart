import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../backend/supabase/supabase.dart';
import '../flutter_flow/flutter_flow_theme.dart';
import 'i18n_service.dart';
import 'venezuela_locations.dart';

/// Servicio centralizado para la gestión y sincronización de la ubicación del paciente.
/// Mantiene un ValueNotifier global para que tanto la barra superior (TopBar / NavBar)
/// como la pantalla de inicio y el catálogo de médicos se actualicen reactivamente
/// sin necesidad de duplicar lógica o estado local.
class PatientLocationService {
  PatientLocationService._internal();

  /// Instancia única del servicio (Singleton)
  static final PatientLocationService instance = PatientLocationService._internal();

  /// Ubicación por defecto cuando el usuario no ha especificado otra
  static const String ubicacionPredeterminada = 'Caracas, Distrito Capital';

  /// Notificador reactivo de la ubicación seleccionada
  final ValueNotifier<String> currentLocationNotifier = ValueNotifier<String>(ubicacionPredeterminada);

  /// Obtiene la ubicación actual en formato 'Ciudad, Estado'
  String get currentLocation => currentLocationNotifier.value;

  /// Extrae únicamente el nombre de la ciudad (ej: 'Caracas' de 'Caracas, Distrito Capital')
  String get currentCityOnly {
    final parts = currentLocationNotifier.value.split(',');
    return parts.isNotEmpty ? parts.first.trim() : currentLocationNotifier.value;
  }

  /// Extrae únicamente el nombre del estado
  String get currentStateOnly {
    final parts = currentLocationNotifier.value.split(',');
    return parts.length > 1 ? parts.last.trim() : '';
  }

  bool _initialized = false;

  /// Inicializa la ubicación del paciente desde Supabase o mantiene la predeterminada
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final uid = SupaFlow.client.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      try {
        final rows = await UsuariosTable().querySingleRow(
          queryFn: (q) => q.eq('id', uid),
        );
        if (rows.isNotEmpty) {
          final ciudad = rows.first.ciudadOrigen;
          if (ciudad != null && ciudad.trim().isNotEmpty) {
            currentLocationNotifier.value = ciudad.trim();
          }
        }
      } catch (e) {
        debugPrint('PatientLocationService: Error cargando ubicación del usuario: $e');
      }
    }
  }

  /// Actualiza la ubicación global y la persiste en el perfil de usuario si está autenticado
  Future<void> setLocation(String newLocation) async {
    final trimmed = newLocation.trim();
    if (trimmed.isEmpty || trimmed == currentLocationNotifier.value) return;

    currentLocationNotifier.value = trimmed;

    final uid = SupaFlow.client.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      try {
        await UsuariosTable().update(
          data: {'ciudad_origen': trimmed},
          matchingRows: (q) => q.eq('id', uid),
        );
      } catch (e) {
        debugPrint('PatientLocationService: Error guardando ubicación en perfil: $e');
      }
    }
  }

  /// Despliega el modal interactivo con buscador para seleccionar ciudad/estado en Venezuela
  Future<void> mostrarSelectorUbicacion(BuildContext context) async {
    final i18n = I18nService.instance;
    String filtro = '';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final isDesktop = screenWidth >= 768;

            final modalWidth = isDesktop
                ? (screenWidth * 0.38).clamp(380.0, 520.0)
                : (screenWidth * 0.90).clamp(290.0, 400.0);
            final modalHeight = (screenHeight * 0.65).clamp(380.0, 560.0);

            final resultados = VenezuelaLocations.searchLocations(filtro);

            return Dialog(
              backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              elevation: 8.0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Container(
                width: modalWidth,
                height: modalHeight,
                padding: const EdgeInsets.symmetric(vertical: 18.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cabecera con título e icono
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Container(
                            width: 36.0,
                            height: 36.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF0284C7),
                              size: 20.0,
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  i18n.isSpanish ? 'Ubicación de Atención' : 'Healthcare Location',
                                  style: GoogleFonts.mooli(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.5,
                                    color: FlutterFlowTheme.of(context).primaryText,
                                  ),
                                ),
                                Text(
                                  i18n.isSpanish
                                      ? 'Selecciona tu ciudad para ver doctores cercanos'
                                      : 'Select your city to view nearby doctors',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: FlutterFlowTheme.of(context).secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(dialogCtx),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close_rounded,
                                color: FlutterFlowTheme.of(context).secondaryText,
                                size: 22.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14.0),
                    // Campo de búsqueda con icono y borrado
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: Container(
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12.0),
                            const Icon(
                              Icons.search_rounded,
                              size: 19.0,
                              color: Color(0xFF0284C7),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: TextField(
                                autofocus: false,
                                onChanged: (val) {
                                  setModalState(() {
                                    filtro = val;
                                  });
                                },
                                style: GoogleFonts.mooli(fontSize: 13.5),
                                decoration: InputDecoration(
                                  hintText: i18n.isSpanish
                                      ? 'Buscar ciudad o estado...'
                                      : 'Search city or state...',
                                  hintStyle: TextStyle(
                                    fontSize: 13.0,
                                    color: FlutterFlowTheme.of(context).secondaryText,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                                ),
                              ),
                            ),
                            if (filtro.isNotEmpty)
                              InkWell(
                                onTap: () => setModalState(() => filtro = ''),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.clear_rounded,
                                    size: 16.0,
                                    color: FlutterFlowTheme.of(context).secondaryText,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    const Divider(height: 1.0),
                    // Lista scrollable de resultados
                    Expanded(
                      child: resultados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_off_outlined,
                                    size: 42.0,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    i18n.isSpanish ? 'No se encontraron ciudades' : 'No locations found',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13.0,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              itemCount: resultados.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1.0,
                                indent: 46.0,
                                endIndent: 16.0,
                                color: FlutterFlowTheme.of(context).alternate.withValues(alpha: 0.4),
                              ),
                              itemBuilder: (ctx, index) {
                                final loc = resultados[index];
                                final isSelected = loc == currentLocationNotifier.value;

                                return InkWell(
                                  onTap: () {
                                    setLocation(loc);
                                    Navigator.pop(dialogCtx);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.location_on_rounded : Icons.location_on_outlined,
                                          size: 19.0,
                                          color: isSelected
                                              ? const Color(0xFF0284C7)
                                              : FlutterFlowTheme.of(context).secondaryText,
                                        ),
                                        const SizedBox(width: 12.0),
                                        Expanded(
                                          child: Text(
                                            loc,
                                            style: GoogleFonts.mooli(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              fontSize: 13.5,
                                              color: isSelected
                                                  ? const Color(0xFF0284C7)
                                                  : FlutterFlowTheme.of(context).primaryText,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 18.0,
                                            color: Color(0xFF0284C7),
                                          ),
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
          },
        );
      },
    );
  }
}
