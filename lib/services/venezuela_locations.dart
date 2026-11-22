class VenezuelaLocation {
  final String estado;
  final List<String> ciudades;

  const VenezuelaLocation({
    required this.estado,
    required this.ciudades,
  });
}

class VenezuelaLocations {
  static const List<VenezuelaLocation> list = [
    VenezuelaLocation(
      estado: 'Distrito Capital',
      ciudades: ['Caracas', 'El Recreo', 'Sucre', 'La Pastora', 'El Valle', 'Antímano'],
    ),
    VenezuelaLocation(
      estado: 'Miranda',
      ciudades: [
        'Los Teques',
        'Chacao',
        'Baruta',
        'El Hatillo',
        'Petare',
        'Guarenas',
        'Guatire',
        'San Antonio de los Altos',
        'Charallave',
        'Cúa',
        'Higuerote',
        'Santa Teresa del Tuy',
        'Ocumare del Tuy',
        'Río Chico',
      ],
    ),
    VenezuelaLocation(
      estado: 'Carabobo',
      ciudades: [
        'Valencia',
        'Naguanagua',
        'San Diego',
        'Guacara',
        'Puerto Cabello',
        'Los Guayos',
        'Tocuyito',
        'Mariara',
        'Morón',
      ],
    ),
    VenezuelaLocation(
      estado: 'Zulia',
      ciudades: [
        'Maracaibo',
        'San Francisco',
        'Cabimas',
        'Ciudad Ojeda',
        'Machiques',
        'Santa Bárbara del Zulia',
        'Villa del Rosario',
        'La Concepción',
        'Los Puertos de Altagracia',
      ],
    ),
    VenezuelaLocation(
      estado: 'Lara',
      ciudades: [
        'Barquisimeto',
        'Cabudare',
        'Carora',
        'El Tocuyo',
        'Quíbor',
        'Duaca',
        'Sanare',
        'Siquisique',
      ],
    ),
    VenezuelaLocation(
      estado: 'Aragua',
      ciudades: [
        'Maracay',
        'Turmero',
        'La Victoria',
        'Cagua',
        'El Limón',
        'Villa de Cura',
        'Palo Negro',
        'Santa Cruz',
        'San Mateo',
      ],
    ),
    VenezuelaLocation(
      estado: 'Anzoátegui',
      ciudades: [
        'Barcelona',
        'Puerto La Cruz',
        'Lechería',
        'Guanta',
        'El Tigre',
        'Anaco',
        'Cantaura',
        'Pariaguán',
        'Clarines',
      ],
    ),
    VenezuelaLocation(
      estado: 'Bolívar',
      ciudades: [
        'Ciudad Guayana / Puerto Ordaz',
        'San Félix',
        'Ciudad Bolívar',
        'Upata',
        'Caicara del Orinoco',
        'Tumeremo',
        'Santa Elena de Uairén',
        'El Callao',
      ],
    ),
    VenezuelaLocation(
      estado: 'Táchira',
      ciudades: [
        'San Cristóbal',
        'Táriba',
        'Rubio',
        'San Antonio del Táchira',
        'La Grita',
        'Coloncito',
        'La Fría',
        'Palmira',
        'Capacho',
      ],
    ),
    VenezuelaLocation(
      estado: 'Mérida',
      ciudades: [
        'Mérida',
        'El Vigía',
        'Ejido',
        'Tovar',
        'Nueva Bolivia',
        'Mucuchíes',
        'Lagunillas',
        'Bailadores',
      ],
    ),
    VenezuelaLocation(
      estado: 'Falcón',
      ciudades: [
        'Coro',
        'Punto Fijo',
        'Dabajuro',
        'Tucacas',
        'Chichiriviche',
        'Churuguara',
        'La Vela de Coro',
        'Punta Cardón',
      ],
    ),
    VenezuelaLocation(
      estado: 'Monagas',
      ciudades: [
        'Maturín',
        'Punta de Mata',
        'Caripe',
        'Caripito',
        'Temblador',
        'Caicara de Maturín',
      ],
    ),
    VenezuelaLocation(
      estado: 'Nueva Esparta',
      ciudades: [
        'Porlamar',
        'Pampatar',
        'La Asunción',
        'Juan Griego',
        'El Valle del Espíritu Santo',
        'Playa El Agua',
      ],
    ),
    VenezuelaLocation(
      estado: 'Portuguesa',
      ciudades: [
        'Acarigua',
        'Araure',
        'Guanare',
        'Turén',
        'Biscucuy',
        'Ospino',
        'Villa Bruzual',
      ],
    ),
    VenezuelaLocation(
      estado: 'Sucre',
      ciudades: [
        'Cumaná',
        'Carúpano',
        'Güiria',
        'Cariaco',
        'Casanay',
        'Marigüitar',
        'Río Caribe',
      ],
    ),
    VenezuelaLocation(
      estado: 'Trujillo',
      ciudades: [
        'Valera',
        'Trujillo',
        'Boconó',
        'Betijoque',
        'Carache',
        'Sabana de Mendoza',
        'Pampán',
      ],
    ),
    VenezuelaLocation(
      estado: 'La Guaira',
      ciudades: [
        'La Guaira',
        'Catia La Mar',
        'Maiquetía',
        'Caraballeda',
        'Macuto',
        'Naiguatá',
      ],
    ),
    VenezuelaLocation(
      estado: 'Yaracuy',
      ciudades: [
        'San Felipe',
        'Yaritagua',
        'Chivacoa',
        'Nirgua',
        'Aroa',
        'Cocorote',
      ],
    ),
    VenezuelaLocation(
      estado: 'Guárico',
      ciudades: [
        'San Juan de los Morros',
        'Calabozo',
        'Valle de la Pascua',
        'Zaraza',
        'Altagracia de Orituco',
        'Tucupido',
      ],
    ),
    VenezuelaLocation(
      estado: 'Barinas',
      ciudades: [
        'Barinas',
        'Barinitas',
        'Socopó',
        'Santa Bárbara',
        'Pedraza',
        'Sabaneta',
      ],
    ),
    VenezuelaLocation(
      estado: 'Cojedes',
      ciudades: [
        'San Carlos',
        'Tinaquillo',
        'Tinaco',
        'El Baúl',
        'El Pao',
      ],
    ),
    VenezuelaLocation(
      estado: 'Apure',
      ciudades: [
        'San Fernando de Apure',
        'Guasdualito',
        'Achaguas',
        'Biruaca',
        'Elorza',
      ],
    ),
    VenezuelaLocation(
      estado: 'Amazonas',
      ciudades: [
        'Puerto Ayacucho',
        'San Fernando de Atabapo',
        'Maroa',
        'San Carlos de Río Negro',
      ],
    ),
    VenezuelaLocation(
      estado: 'Delta Amacuro',
      ciudades: [
        'Tucupita',
        'Pedernales',
        'Curiapo',
        'Sierra Imataca',
      ],
    ),
  ];

  /// Obtiene una lista plana formateada de "Ciudad, Estado"
  static List<String> getAllFormattedLocations() {
    final List<String> result = [];
    for (final loc in list) {
      for (final ciudad in loc.ciudades) {
        result.add('$ciudad, ${loc.estado}');
      }
    }
    return result;
  }

  /// Normaliza una cadena removiendo acentos/diacríticos y convirtiendo a minúsculas
  static String normalize(String text) {
    var str = text.toLowerCase().trim();
    str = str.replaceAll(RegExp(r'[áàäâã]'), 'a');
    str = str.replaceAll(RegExp(r'[éèëê]'), 'e');
    str = str.replaceAll(RegExp(r'[íìïî]'), 'i');
    str = str.replaceAll(RegExp(r'[óòöôõ]'), 'o');
    str = str.replaceAll(RegExp(r'[úùüû]'), 'u');
    str = str.replaceAll(RegExp(r'[ñ]'), 'n');
    str = str.replaceAll(RegExp(r'[ç]'), 'c');
    return str;
  }

  /// Verifica si [source] contiene [query] ignorando mayúsculas y acentos
  static bool containsIgnoreAccents(String? source, String query) {
    if (source == null || source.isEmpty) return false;
    final normQuery = normalize(query);
    if (normQuery.isEmpty) return true;
    return normalize(source).contains(normQuery);
  }

  /// Encuentra el estado canónico correspondiente a un texto crudo (ej: "Trujillo State", "Estado Trujillo", "Distrito Capital")
  static String? matchEstado(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var clean = normalize(raw)
        .replaceAll('state', '')
        .replaceAll('estado', '')
        .replaceAll('region', '')
        .replaceAll('provincia', '')
        .replaceAll('departamento', '')
        .replaceAll('distrito', '')
        .replaceAll('capital', '')
        .trim();

    // Caso especial para Distrito Capital
    if (normalize(raw).contains('distrito') || normalize(raw).contains('caracas') || normalize(raw).contains('capital')) {
      return 'Distrito Capital';
    }

    // 1. Coincidencia exacta o contenida
    for (final loc in list) {
      final normEst = normalize(loc.estado);
      if (normEst == clean || normEst.contains(clean) || (clean.isNotEmpty && clean.contains(normEst))) {
        return loc.estado;
      }
    }
    return null;
  }

  /// Encuentra la ciudad canónica correspondiente dentro de un estado o en toda Venezuela
  static String? matchCiudad(String? rawCiudad, String? rawEstado) {
    if (rawCiudad == null || rawCiudad.trim().isEmpty) return null;
    final estado = matchEstado(rawEstado);
    final ciudades = estado != null ? getCiudadesPorEstado(estado) : <String>[];
    var clean = normalize(rawCiudad)
        .replaceAll('municipio', '')
        .replaceAll('parroquia', '')
        .replaceAll('ciudad', '')
        .replaceAll('sector', '')
        .trim();

    // 1. Buscar en ciudades del estado correspondiente
    for (final c in ciudades) {
      final normC = normalize(c);
      if (normC == clean || normC.contains(clean) || (clean.isNotEmpty && clean.contains(normC))) {
        return c;
      }
    }

    // 2. Buscar en todas las ciudades de Venezuela
    for (final loc in list) {
      for (final c in loc.ciudades) {
        final normC = normalize(c);
        if (normC == clean || normC.contains(clean) || (clean.isNotEmpty && clean.contains(normC))) {
          return c;
        }
      }
    }
    return null;
  }

  /// Obtiene la lista de todos los estados de Venezuela
  static List<String> getEstados() {
    return list.map((loc) => loc.estado).toList();
  }

  /// Obtiene la lista de ciudades pertenecientes a un estado específico
  static List<String> getCiudadesPorEstado(String estado) {
    if (estado.trim().isEmpty) return [];
    final match = list.firstWhere(
      (loc) => normalize(loc.estado) == normalize(estado.trim()),
      orElse: () => const VenezuelaLocation(estado: '', ciudades: []),
    );
    return match.ciudades;
  }

  /// Devuelve el nombre del estado al que pertenece una ciudad (o texto de ubicación "Ciudad, Estado")
  static String? getEstadoDeCiudad(String? rawLocation) {
    if (rawLocation == null || rawLocation.trim().isEmpty) return null;
    final parts = rawLocation.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length > 1) {
      final bySecond = matchEstado(parts.last);
      if (bySecond != null) return bySecond;
    }
    final cityNorm = normalize(parts.first);
    for (final loc in list) {
      for (final c in loc.ciudades) {
        final normC = normalize(c);
        if (normC == cityNorm || (cityNorm.isNotEmpty && (normC.contains(cityNorm) || cityNorm.contains(normC)))) {
          return loc.estado;
        }
      }
    }
    return matchEstado(rawLocation);
  }

  /// Filtra estados por texto
  static List<String> searchEstados(String query) {
    final all = getEstados();
    final q = normalize(query.trim());
    if (q.isEmpty) return all;
    return all.where((est) => normalize(est).contains(q)).toList();
  }

  /// Filtra ciudades de un estado por texto
  static List<String> searchCiudades(String estado, String query) {
    final all = getCiudadesPorEstado(estado);
    final q = normalize(query.trim());
    if (q.isEmpty) return all;
    return all.where((ciu) => normalize(ciu).contains(q)).toList();
  }

  /// Filtra ubicaciones sin importar mayúsculas, minúsculas ni acentos
  static List<String> searchLocations(String query) {
    final all = getAllFormattedLocations();
    final q = normalize(query.trim());
    if (q.isEmpty) return all;
    return all.where((loc) => normalize(loc).contains(q)).toList();
  }
}
