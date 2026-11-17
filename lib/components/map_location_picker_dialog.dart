import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../flutter_flow/flutter_flow_theme.dart';
import '../services/location_maps_service.dart';
import '../services/venezuela_locations.dart';

class MapLocationPickerDialog extends StatefulWidget {
  final String? direccionInicial;
  final String? ciudadInicial;
  final String? estadoInicial;
  final double? latitudInicial;
  final double? longitudInicial;

  const MapLocationPickerDialog({
    super.key,
    this.direccionInicial,
    this.ciudadInicial,
    this.estadoInicial,
    this.latitudInicial,
    this.longitudInicial,
  });

  /// Método estático conveniente para abrir el selector de ubicación como Pop-up
  static Future<LocationPickerResult?> mostrar(
    BuildContext context, {
    String? direccionInicial,
    String? ciudadInicial,
    String? estadoInicial,
    double? latitudInicial,
    double? longitudInicial,
  }) {
    return showDialog<LocationPickerResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MapLocationPickerDialog(
        direccionInicial: direccionInicial,
        ciudadInicial: ciudadInicial,
        estadoInicial: estadoInicial,
        latitudInicial: latitudInicial,
        longitudInicial: longitudInicial,
      ),
    );
  }

  @override
  State<MapLocationPickerDialog> createState() => _MapLocationPickerDialogState();
}

class _MapLocationPickerDialogState extends State<MapLocationPickerDialog> {
  late double _latitud;
  late double _longitud;
  int _zoom = 16;

  final TextEditingController _busquedaCtrl = TextEditingController();
  final TextEditingController _direccionResultadoCtrl = TextEditingController();

  List<LocationSearchResult> _sugerencias = [];
  bool _buscandoSugerencias = false;
  bool _geocodificandoInverso = false;
  bool _obteniendoGPS = false;
  Timer? _debounceTimer;

  String? _ciudadDetectada;
  String? _estadoDetectado;

  @override
  void initState() {
    super.initState();
    _inicializarUbicacion();
  }

  void _inicializarUbicacion() {
    if (widget.latitudInicial != null &&
        widget.longitudInicial != null &&
        widget.latitudInicial != 0.0 &&
        widget.longitudInicial != 0.0) {
      _latitud = widget.latitudInicial!;
      _longitud = widget.longitudInicial!;
      _ciudadDetectada = widget.ciudadInicial ?? 'Valera';
      _estadoDetectado = widget.estadoInicial ?? 'Trujillo';

      if (widget.direccionInicial != null && widget.direccionInicial!.isNotEmpty) {
        _direccionResultadoCtrl.text = widget.direccionInicial!;
      } else {
        _ejecutarGeocodificacionInversa(_latitud, _longitud);
      }
    } else {
      // Coordenadas iniciales por defecto mientras se intenta obtener GPS en segundo plano
      final coordsDefecto = LocationMapsService.getCoordenadasDefecto(
        ciudad: widget.ciudadInicial,
        estado: widget.estadoInicial,
      );
      _latitud = coordsDefecto[0];
      _longitud = coordsDefecto[1];
      _ciudadDetectada = widget.ciudadInicial ?? 'Valera';
      _estadoDetectado = widget.estadoInicial ?? 'Trujillo';

      if (widget.direccionInicial != null && widget.direccionInicial!.isNotEmpty) {
        _direccionResultadoCtrl.text = widget.direccionInicial!;
      } else {
        _ejecutarGeocodificacionInversa(_latitud, _longitud);
      }

      // Intentar auto-detectar la ubicación GPS real del dispositivo al abrir
      _detectarUbicacionActualGPS(silencioso: true);
    }
  }

  /// Obtiene la posición GPS en tiempo real y centra el mapa
  Future<void> _detectarUbicacionActualGPS({bool silencioso = false}) async {
    if (_obteniendoGPS) return;
    setState(() => _obteniendoGPS = true);

    try {
      final coords = await LocationMapsService.obtenerUbicacionActualGPS();
      if (!mounted) return;

      if (coords != null) {
        setState(() {
          _latitud = coords[0];
          _longitud = coords[1];
          _zoom = 17; // Zoom cercano para vista de calle precisa
        });

        await _ejecutarGeocodificacionInversa(_latitud, _longitud);

        if (!silencioso && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Ubicación GPS actual detectada con éxito'),
              backgroundColor: Color(0xFF00796B),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (!silencioso && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No se pudo obtener la ubicación GPS. Verifica los permisos de ubicación de tu dispositivo.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error en _detectarUbicacionActualGPS: $e');
    } finally {
      if (mounted) {
        setState(() => _obteniendoGPS = false);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _busquedaCtrl.dispose();
    _direccionResultadoCtrl.dispose();
    super.dispose();
  }

  void _onBusquedaChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 3) {
      setState(() => _sugerencias = []);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _buscandoSugerencias = true);
      final resultados = await LocationMapsService.buscarLugares(
        query,
        ciudad: _ciudadDetectada,
        estado: _estadoDetectado,
      );
      if (mounted) {
        setState(() {
          _sugerencias = resultados;
          _buscandoSugerencias = false;
        });
      }
    });
  }

  void _seleccionarSugerencia(LocationSearchResult lugar) {
    setState(() {
      _latitud = lugar.lat;
      _longitud = lugar.lon;
      _sugerencias = [];
      _busquedaCtrl.clear();
      _direccionResultadoCtrl.text = lugar.direccionCorta;
      if (lugar.city != null && lugar.city!.isNotEmpty) {
        _ciudadDetectada = lugar.city;
      }
      if (lugar.state != null && lugar.state!.isNotEmpty) {
        _estadoDetectado = lugar.state;
      }
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _ejecutarGeocodificacionInversa(double lat, double lon) async {
    setState(() => _geocodificandoInverso = true);
    final res = await LocationMapsService.reverseGeocode(lat, lon);
    if (mounted) {
      setState(() {
        _geocodificandoInverso = false;
        if (res != null) {
          _direccionResultadoCtrl.text = res.direccionCorta;
          if (res.city != null && res.city!.isNotEmpty) {
            _ciudadDetectada = res.city;
          }
          if (res.state != null && res.state!.isNotEmpty) {
            _estadoDetectado = res.state;
          }
        }
      });
    }
  }

  void _moverMapa(double deltaLat, double deltaLon) {
    setState(() {
      _latitud += deltaLat;
      _longitud += deltaLon;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _ejecutarGeocodificacionInversa(_latitud, _longitud);
    });
  }

  void _centrarEnCiudad(String ciudad, String estado) {
    final coords = LocationMapsService.getCoordenadasDefecto(ciudad: ciudad, estado: estado);
    setState(() {
      _latitud = coords[0];
      _longitud = coords[1];
      _ciudadDetectada = ciudad;
      _estadoDetectado = estado;
    });
    _ejecutarGeocodificacionInversa(_latitud, _longitud);
  }

  void _confirmarUbicacion() {
    final direccionFinal = _direccionResultadoCtrl.text.trim();
    if (direccionFinal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escribe o selecciona la dirección del lugar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final matchedEstado = VenezuelaLocations.matchEstado(_estadoDetectado) ?? _estadoDetectado;
    final matchedCiudad = VenezuelaLocations.matchCiudad(_ciudadDetectada, matchedEstado) ?? _ciudadDetectada;

    final resultado = LocationPickerResult(
      direccion: direccionFinal,
      ciudad: matchedCiudad,
      estado: matchedEstado,
      latitud: _latitud,
      longitud: _longitud,
    );

    Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    // Dimensiones compactas para pop-up modal centrado (no pantalla completa)
    final dialogWidth = isMobile ? (size.width * 0.92) : min(size.width * 0.75, 560.0);
    final dialogHeight = min(size.height * 0.84, 620.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.secondaryBackground,
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header del Pop-up con icono y botón de cierre
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Color(0xFF00796B), size: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ubicación del Consultorio',
                        style: GoogleFonts.mooli(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryText,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Buscador superior
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
              children: [
                TextField(
                  controller: _busquedaCtrl,
                  onChanged: _onBusquedaChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar calle, avenida o sector en Venezuela...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF00796B)),
                    suffixIcon: _buscandoSugerencias
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_busquedaCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _busquedaCtrl.clear();
                                  setState(() => _sugerencias = []);
                                },
                              )
                            : null),
                    filled: true,
                    fillColor: theme.primaryBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),

                // Lista de sugerencias desplegable
                if (_sugerencias.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _sugerencias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final item = _sugerencias[idx];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on, color: Colors.teal, size: 20),
                          title: Text(
                            item.direccionCorta,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            item.displayName,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _seleccionarSugerencia(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Chips de acceso rápido: Ubicación Actual GPS + Ciudades
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                _buildGpsChip(),
                const SizedBox(width: 8),
                _buildCityChip('Valera (Centro)', 'Valera', 'Trujillo'),
                const SizedBox(width: 8),
                _buildCityChip('Trujillo Capital', 'Trujillo', 'Trujillo'),
                const SizedBox(width: 8),
                _buildCityChip('Boconó', 'Bocono', 'Trujillo'),
                const SizedBox(width: 8),
                _buildCityChip('Caracas', 'Caracas', 'Distrito Capital'),
                const SizedBox(width: 8),
                _buildCityChip('Maracaibo', 'Maracaibo', 'Zulia'),
                const SizedBox(width: 8),
                _buildCityChip('Barquisimeto', 'Barquisimeto', 'Lara'),
                const SizedBox(width: 8),
                _buildCityChip('Mérida', 'Merida', 'Mérida'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Canvas Interactivo del Mapa (Slippy OpenStreetMap Tiles Viewer)
          Expanded(
            child: Stack(
              children: [
                // Mapa interactivo por capas de tiles
                _buildMapCanvas(),

                // Banner de estado GPS cuando se está detectando
                if (_obteniendoGPS)
                  Positioned(
                    top: 12,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Detectando ubicación GPS actual...',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Pin central fijo que indica la posición exacta
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            '📍 Mueve el mapa para fijar el consultorio',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(
                          Icons.location_pin,
                          size: 44,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                ),

                // Controles de Navegación (+/- zoom y botones direccionales)
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Column(
                    children: [
                      _buildMapIconButton(
                        icon: Icons.add,
                        onPressed: () {
                          if (_zoom < 19) setState(() => _zoom += 1);
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildMapIconButton(
                        icon: Icons.remove,
                        onPressed: () {
                          if (_zoom > 10) setState(() => _zoom -= 1);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildMapIconButton(
                        icon: _obteniendoGPS ? Icons.sync : Icons.my_location,
                        color: const Color(0xFF00796B),
                        tooltip: 'Centrar en mi Ubicación Actual GPS',
                        onPressed: () => _detectarUbicacionActualGPS(silencioso: false),
                      ),
                    ],
                  ),
                ),

                // Control Pad direccional en pantalla táctil/desktop
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _moverMapa(0.0015, 0),
                          child: const Icon(Icons.arrow_drop_up, size: 28, color: Colors.blueGrey),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _moverMapa(0, -0.0015),
                              child: const Icon(Icons.arrow_left, size: 28, color: Colors.blueGrey),
                            ),
                            const Icon(Icons.touch_app, size: 16, color: Colors.teal),
                            InkWell(
                              onTap: () => _moverMapa(0, 0.0015),
                              child: const Icon(Icons.arrow_right, size: 28, color: Colors.blueGrey),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _moverMapa(-0.0015, 0),
                          child: const Icon(Icons.arrow_drop_down, size: 28, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tarjeta inferior con Dirección y Botón de Confirmación
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_location_alt, color: Colors.teal, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Dirección Detectada (puedes ajustarla):',
                      style: GoogleFonts.mooli(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    if (_geocodificandoInverso) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _direccionResultadoCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Av. Bolívar con Calle 10, Sector Centro',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📍 $_ciudadDetectada, $_estadoDetectado',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'GPS: ${_latitud.toStringAsFixed(4)}, ${_longitud.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      'Usar esta Dirección y Coordenadas',
                      style: GoogleFonts.mooli(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _confirmarUbicacion,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildMapCanvas() {
    // Calculamos el Tile X / Y de OpenStreetMap para las coordenadas actuales y zoom
    final tileX = ((_longitud + 180.0) / 360.0 * (1 << _zoom)).floor();
    final latRad = _latitud * pi / 180.0;
    final tileY = ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * (1 << _zoom)).floor();

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanEnd: (_) {
            _debounceTimer?.cancel();
            _ejecutarGeocodificacionInversa(_latitud, _longitud);
          },
          onPanUpdate: (details) {
            final scaleFactor = 360.0 / (256.0 * (1 << _zoom) * 2.5);
            final deltaLon = -details.delta.dx * scaleFactor;
            final deltaLat = details.delta.dy * scaleFactor;
            setState(() {
              _latitud += deltaLat;
              _longitud += deltaLon;
            });
          },
          onTapUp: (details) {
            final centerDx = constraints.maxWidth / 2;
            final centerDy = constraints.maxHeight / 2;
            final offsetDx = details.localPosition.dx - centerDx;
            final offsetDy = details.localPosition.dy - centerDy;
            final scaleFactor = 360.0 / (256.0 * (1 << _zoom) * 2.5);
            final deltaLon = offsetDx * scaleFactor;
            final deltaLat = -offsetDy * scaleFactor;
            _moverMapa(deltaLat, deltaLon);
          },
          child: Container(
            color: const Color(0xFFE5E3DF),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
              ),
              itemCount: 9,
              itemBuilder: (ctx, index) {
                final colOffset = (index % 3) - 1;
                final rowOffset = (index ~/ 3) - 1;
                final curX = tileX + colOffset;
                final curY = tileY + rowOffset;
                final tileUrl = 'https://tile.openstreetmap.org/$_zoom/$curX/$curY.png';

                return Image.network(
                  tileUrl,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  headers: const {
                    'User-Agent': 'MediConnectApp/1.0 (healthcare_app_venezuela)',
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE8ECEF),
                    child: const Center(
                      child: Icon(Icons.map_outlined, color: Colors.grey, size: 28),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGpsChip() {
    return ActionChip(
      elevation: 1.5,
      avatar: _obteniendoGPS
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.my_location, size: 14, color: Colors.white),
      label: Text(
        _obteniendoGPS ? 'Buscando GPS...' : 'Mi Ubicación Actual',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF00796B),
      side: const BorderSide(color: Color(0xFF004D40), width: 1),
      onPressed: () => _detectarUbicacionActualGPS(silencioso: false),
    );
  }

  Widget _buildCityChip(String label, String ciudad, String estado) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      backgroundColor: Colors.teal.shade50,
      avatar: const Icon(Icons.location_city, size: 14, color: Colors.teal),
      onPressed: () => _centrarEnCiudad(ciudad, estado),
    );
  }

  Widget _buildMapIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = Colors.black87,
    String? tooltip,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
