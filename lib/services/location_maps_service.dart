import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'venezuela_locations.dart';

class LocationPickerResult {
  final String direccion;
  final String? ciudad;
  final String? estado;
  final double latitud;
  final double longitud;
  final String? nombreLugar;

  LocationPickerResult({
    required this.direccion,
    this.ciudad,
    this.estado,
    required this.latitud,
    required this.longitud,
    this.nombreLugar,
  });
}

class LocationSearchResult {
  final String displayName;
  final String? road;
  final String? suburb;
  final String? city;
  final String? state;
  final double lat;
  final double lon;

  LocationSearchResult({
    required this.displayName,
    this.road,
    this.suburb,
    this.city,
    this.state,
    required this.lat,
    required this.lon,
  });

  String get direccionCorta {
    final partes = <String>[];
    if (road != null && road!.isNotEmpty) partes.add(road!);
    if (suburb != null && suburb!.isNotEmpty && suburb != road) partes.add(suburb!);
    if (partes.isEmpty) {
      final tokens = displayName.split(',');
      if (tokens.isNotEmpty) return tokens.take(2).join(',').trim();
      return displayName;
    }
    return partes.join(', ');
  }
}

class LocationMapsService {
  /// Coordenadas por defecto de ciudades clave en Venezuela
  static const Map<String, List<double>> coordenadasCiudades = {
    'valera': [9.3178, -70.6036],
    'trujillo': [9.3667, -70.4333],
    'bocono': [9.2483, -70.2589],
    'caracas': [10.4806, -66.9036],
    'maracaibo': [10.6544, -71.6425],
    'barquisimeto': [10.0678, -69.3474],
    'valencia': [10.1620, -68.0077],
    'maracay': [10.2469, -67.5958],
    'merida': [8.5983, -71.1450],
    'san cristobal': [7.7669, -72.2250],
    'puerto la cruz': [10.2138, -64.6328],
    'maturin': [9.7457, -63.1832],
    'ciudad guayana': [8.3077, -62.7126],
  };

  static List<double> getCoordenadasDefecto({String? ciudad, String? estado}) {
    if (ciudad != null) {
      final key = ciudad.trim().toLowerCase();
      for (final entry in coordenadasCiudades.entries) {
        if (key.contains(entry.key) || entry.key.contains(key)) {
          return entry.value;
        }
      }
    }
    if (estado != null) {
      final key = estado.trim().toLowerCase();
      if (key.contains('trujillo')) return [9.3178, -70.6036];
      if (key.contains('distrito') || key.contains('miranda')) return [10.4806, -66.9036];
      if (key.contains('zulia')) return [10.6544, -71.6425];
      if (key.contains('lara')) return [10.0678, -69.3474];
      if (key.contains('merida')) return [8.5983, -71.1450];
      if (key.contains('tachira')) return [7.7669, -72.2250];
      if (key.contains('carabobo')) return [10.1620, -68.0077];
      if (key.contains('aragua')) return [10.2469, -67.5958];
    }
    // Por defecto Valera, Trujillo
    return [9.3178, -70.6036];
  }

  /// Obtiene la ubicación real del dispositivo (GPS en móvil/web y fallback IP en escritorio)
  static Future<List<double>?> obtenerUbicacionActualGPS() async {
    // 1. Intentar con Geolocator (Móvil y Web con soporte HTML5 Geolocation)
    try {
      bool serviceEnabled = true;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (e) {
        debugPrint('isLocationServiceEnabled no soportado en esta plataforma: $e');
      }

      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position? position;
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 7),
              ),
            );
          } catch (e) {
            debugPrint('getCurrentPosition dio timeout/error, intentando getLastKnownPosition: $e');
            position = await Geolocator.getLastKnownPosition();
          }

          if (position != null && position.latitude != 0.0 && position.longitude != 0.0) {
            return [position.latitude, position.longitude];
          }
        }
      }
    } catch (e) {
      debugPrint('Geolocator no disponible en esta plataforma: $e');
    }

    // 2. Fallback de geolocalización por red/IP (Ideal para Web y Escritorio sin GPS)
    return await _obtenerUbicacionPorIP();
  }

  /// Geolocalización por IP como respaldo para Web y Escritorio
  static Future<List<double>?> _obtenerUbicacionPorIP() async {
    try {
      final url = Uri.parse('http://ip-api.com/json');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['lat'] != null && data['lon'] != null) {
          final lat = double.tryParse(data['lat'].toString());
          final lon = double.tryParse(data['lon'].toString());
          if (lat != null && lon != null) {
            debugPrint('Ubicación aproximada detectada por IP: $lat, $lon');
            return [lat, lon];
          }
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo ubicación por IP: $e');
    }
    return null;
  }

  /// Busca direcciones y puntos de interés usando OpenStreetMap Nominatim
  static Future<List<LocationSearchResult>> buscarLugares(
    String query, {
    String? ciudad,
    String? estado,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final queryLimpia = query.trim();
      final queryFinal = (ciudad != null && !queryLimpia.toLowerCase().contains(ciudad.toLowerCase()))
          ? '$queryLimpia, $ciudad, Venezuela'
          : '$queryLimpia, Venezuela';

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(queryFinal)}&addressdetails=1&countrycodes=ve&limit=8',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'MediConnectApp/1.0 (healthcare_app_venezuela)',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) {
          final address = item['address'] as Map<String, dynamic>? ?? {};
          final road = address['road'] ?? address['pedestrian'] ?? address['footway'] ?? address['neighbourhood'] ?? address['suburb'];
          final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['residential'];
          final rawCity = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'];
          final rawState = address['state'];

          final matchedState = VenezuelaLocations.matchEstado(rawState?.toString()) ?? rawState?.toString();
          final matchedCity = VenezuelaLocations.matchCiudad(rawCity?.toString(), matchedState) ?? rawCity?.toString();

          return LocationSearchResult(
            displayName: item['display_name'] ?? '',
            road: road?.toString(),
            suburb: suburb?.toString(),
            city: matchedCity,
            state: matchedState,
            lat: double.tryParse(item['lat'].toString()) ?? 0.0,
            lon: double.tryParse(item['lon'].toString()) ?? 0.0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error buscando lugares en Nominatim: $e');
    }
    return [];
  }

  /// Geocodificación inversa para obtener la dirección exacta de unas coordenadas
  static Future<LocationSearchResult?> reverseGeocode(
    double lat,
    double lon,
  ) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&addressdetails=1',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'MediConnectApp/1.0 (healthcare_app_venezuela)',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final item = jsonDecode(response.body);
        final address = item['address'] as Map<String, dynamic>? ?? {};
        final road = address['road'] ?? address['pedestrian'] ?? address['footway'];
        final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['residential'];
        final rawCity = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'];
        final rawState = address['state'];

        final matchedState = VenezuelaLocations.matchEstado(rawState?.toString()) ?? rawState?.toString();
        final matchedCity = VenezuelaLocations.matchCiudad(rawCity?.toString(), matchedState) ?? rawCity?.toString();

        return LocationSearchResult(
          displayName: item['display_name'] ?? '',
          road: road?.toString(),
          suburb: suburb?.toString(),
          city: matchedCity,
          state: matchedState,
          lat: lat,
          lon: lon,
        );
      }
    } catch (e) {
      debugPrint('Error en geocodificación inversa: $e');
    }
    return null;
  }

  /// Genera la URL de Google Maps para visualización y navegación externa
  static String getGoogleMapsUrl({
    double? latitud,
    double? longitud,
    String? direccion,
    String? ciudad,
    String? estado,
    String? nombreLugar,
  }) {
    if (latitud != null && longitud != null && latitud != 0.0 && longitud != 0.0) {
      return 'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud';
    }

    final partes = <String>[];
    if (nombreLugar != null && nombreLugar.trim().isNotEmpty) partes.add(nombreLugar.trim());
    if (direccion != null && direccion.trim().isNotEmpty) partes.add(direccion.trim());
    if (ciudad != null && ciudad.trim().isNotEmpty) partes.add(ciudad.trim());
    if (estado != null && estado.trim().isNotEmpty) partes.add(estado.trim());
    partes.add('Venezuela');

    final query = Uri.encodeComponent(partes.join(', '));
    return 'https://www.google.com/maps/search/?api=1&query=$query';
  }

  /// Abre la ubicación en Google Maps (App o Navegador)
  static Future<bool> abrirGoogleMaps({
    double? latitud,
    double? longitud,
    String? direccion,
    String? ciudad,
    String? estado,
    String? nombreLugar,
  }) => abrirEnGoogleMaps(
    latitud: latitud,
    longitud: longitud,
    direccion: direccion,
    ciudad: ciudad,
    estado: estado,
    nombreLugar: nombreLugar,
  );

  /// Abre la ubicación en Google Maps
  static Future<bool> abrirEnGoogleMaps({
    double? latitud,
    double? longitud,
    String? direccion,
    String? ciudad,
    String? estado,
    String? nombreLugar,
  }) async {
    final urlStr = getGoogleMapsUrl(
      latitud: latitud,
      longitud: longitud,
      direccion: direccion,
      ciudad: ciudad,
      estado: estado,
      nombreLugar: nombreLugar,
    );

    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error abriendo Google Maps: $e');
    }
    return false;
  }
}
