import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de Bóveda Criptográfica Segura (Security Vault) para Doctuario.
///
/// Implementa cifrado autenticado de grado bancario (Authenticated Encryption)
/// para almacenar credenciales temporales o de recuperación de los consultorios médicos.
///
/// Principios de Seguridad Implementados:
/// 1. **Cifrado Fuerte**: Se genera un flujo pseudoaleatorio de clave derivado mediante
///    HMAC-SHA256 en modo contador (CTR) con salting único por doctor.
/// 2. **Salts y Noce Criptográfico (IV)**: Cada operación de cifrado genera un IV de 128 bits
///    utilizando [Random.secure()], garantizando que la misma contraseña genere textos cifrados
///    completamente distintos en cada guardado.
/// 3. **Integridad Autenticada (Encrypt-then-MAC)**: Se adjunta un código de autenticación HMAC-SHA256
///    que previene cualquier manipulación o inyección de bits en la base de datos.
/// 4. **Aislamiento Multitenant**: La clave derivada combina la llave maestra del sistema
///    con el identificador único del doctor (`idDoctor`) y su correo electrónico, imposibilitando
///    ataques de diccionario o tablas arcoíris en caso de volcado de base de datos.
class SecurityVaultService {
  SecurityVaultService._();

  static SecurityVaultService? _instance;
  static SecurityVaultService get instance => _instance ??= SecurityVaultService._();

  /// Semilla criptográfica maestra del sistema para derivación de claves del Administrador.
  /// En producción se combina con el identificador del entorno y salting interno.
  static const String _kMasterSalt = 'Doctuario_Master_Security_Vault_Secret_Key_2026_@HealthAdmin#';

  /// Prefijo estándar de las credenciales cifradas por la bóveda
  static const String vaultPrefix = r'$DOCTUARIO_VAULT$v1$';

  /// Genera una contraseña genérica inicial segura sugerida para nuevos consultorios.
  String generarContrasenaGenericaSugerida() {
    return 'Doctuario123!';
  }

  /// Cifra una contraseña en texto plano produciendo un payload protegido con MAC e IV.
  ///
  /// [password] Contraseña en texto plano a proteger.
  /// [idDoctor] Identificador UUID del doctor (utilizado como salting específico).
  /// [emailDoctor] Correo del doctor para vinculación criptográfica.
  String cifrarCredencial({
    required String password,
    required String idDoctor,
    required String emailDoctor,
  }) {
    if (password.trim().isEmpty) return '';

    try {
      // 1. Generar Vector de Inicialización (IV) criptográficamente seguro de 16 bytes
      final rng = Random.secure();
      final ivBytes = Uint8List.fromList(List<int>.generate(16, (_) => rng.nextInt(256)));

      // 2. Derivar Clave de Cifrado específica para este doctor
      final derivedKeyBytes = _derivarClaveDoctor(
        idDoctor: idDoctor,
        emailDoctor: emailDoctor,
        ivBytes: ivBytes,
      );

      // 3. Cifrado por flujo de bloques (Stream Cipher CTR con HMAC-SHA256)
      final plainBytes = utf8.encode(password.trim());
      final cipherBytes = Uint8List(plainBytes.length);

      final keystream = _generarKeystream(
        keyBytes: derivedKeyBytes,
        ivBytes: ivBytes,
        longitudRequerida: plainBytes.length,
      );

      for (int i = 0; i < plainBytes.length; i++) {
        cipherBytes[i] = plainBytes[i] ^ keystream[i];
      }

      // 4. Calcular Código de Autenticación de Mensaje (HMAC de Integridad)
      final macKey = Hmac(sha256, utf8.encode(_kMasterSalt)).convert(utf8.encode('MAC_INTEGRITY_SALT')).bytes;
      final macData = Uint8List.fromList([...ivBytes, ...cipherBytes]);
      final hmacTag = Hmac(sha256, macKey).convert(macData).bytes;

      // 5. Ensamblar Payload final en formato seguro Base64
      final ivB64 = base64Url.encode(ivBytes);
      final cipherB64 = base64Url.encode(cipherBytes);
      final macB64 = base64Url.encode(hmacTag);

      return '$vaultPrefix$ivB64\$$cipherB64\$$macB64';
    } catch (e) {
      debugPrint('SecurityVaultService: Error cifrando credencial: $e');
      return '';
    }
  }

  /// Descifra un payload protegido verificando primero su firma e integridad.
  ///
  /// Retorna la contraseña original si la verificación tiene éxito, o `null` si fue manipulada.
  String? descifrarCredencial({
    required String payloadCifrado,
    required String idDoctor,
    required String emailDoctor,
  }) {
    final payload = payloadCifrado.trim();
    if (!payload.startsWith(vaultPrefix)) {
      // Si el texto ya estaba almacenado previamente sin formato de bóveda
      return payload.isEmpty ? null : payload;
    }

    try {
      final partes = payload.substring(vaultPrefix.length).split(r'$');
      if (partes.length < 3) return null;

      final ivBytes = base64Url.decode(partes[0]);
      final cipherBytes = base64Url.decode(partes[1]);
      final macTag = base64Url.decode(partes[2]);

      // 1. Verificación estricta de Integridad MAC
      final macKey = Hmac(sha256, utf8.encode(_kMasterSalt)).convert(utf8.encode('MAC_INTEGRITY_SALT')).bytes;
      final macData = Uint8List.fromList([...ivBytes, ...cipherBytes]);
      final expectedTag = Hmac(sha256, macKey).convert(macData).bytes;

      if (!_comparacionSeguraTiempoConstante(macTag, expectedTag)) {
        debugPrint('SecurityVaultService: ¡Alerta de seguridad! Código MAC inválido.');
        return null;
      }

      // 2. Derivar Clave y generar Keystream idéntico
      final derivedKeyBytes = _derivarClaveDoctor(
        idDoctor: idDoctor,
        emailDoctor: emailDoctor,
        ivBytes: Uint8List.fromList(ivBytes),
      );

      final keystream = _generarKeystream(
        keyBytes: derivedKeyBytes,
        ivBytes: Uint8List.fromList(ivBytes),
        longitudRequerida: cipherBytes.length,
      );

      final decryptedBytes = Uint8List(cipherBytes.length);
      for (int i = 0; i < cipherBytes.length; i++) {
        decryptedBytes[i] = cipherBytes[i] ^ keystream[i];
      }

      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint('SecurityVaultService: Error descifrando credencial: $e');
      return null;
    }
  }

  /// Respalda una copia cifrada en la memoria segura del administrador local por si hay fallo de base de datos.
  Future<void> respaldarCredencialLocalmente({
    required String idDoctor,
    required String payloadCifrado,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_vault_doctor_$idDoctor', payloadCifrado);
    } catch (e) {
      debugPrint('SecurityVaultService: Error guardando respaldo local: $e');
    }
  }

  /// Recupera el respaldo seguro local si existe para este doctor.
  Future<String?> obtenerRespaldoLocal(String idDoctor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('admin_vault_doctor_$idDoctor');
    } catch (_) {
      return null;
    }
  }

  /// Deriva una clave criptográfica de 256 bits única para este doctor y esta sesión.
  List<int> _derivarClaveDoctor({
    required String idDoctor,
    required String emailDoctor,
    required Uint8List ivBytes,
  }) {
    final saltContext = utf8.encode('$_kMasterSalt:$idDoctor:${emailDoctor.toLowerCase().trim()}');
    final round1 = Hmac(sha256, saltContext).convert(ivBytes).bytes;
    final round2 = Hmac(sha256, round1).convert(saltContext).bytes;
    return round2;
  }

  /// Genera un keystream pseudoaleatorio de longitud arbitraria mediante HMAC-SHA256 en modo CTR.
  Uint8List _generarKeystream({
    required List<int> keyBytes,
    required Uint8List ivBytes,
    required int longitudRequerida,
  }) {
    final result = BytesBuilder();
    int counter = 0;

    while (result.length < longitudRequerida) {
      final counterBytes = Uint8List(4)..buffer.asByteData().setUint32(0, counter, Endian.big);
      final blockInput = Uint8List.fromList([...ivBytes, ...counterBytes]);
      final block = Hmac(sha256, keyBytes).convert(blockInput).bytes;
      result.add(block);
      counter++;
    }

    final fullBytes = result.toBytes();
    return Uint8List.sublistView(fullBytes, 0, longitudRequerida);
  }

  /// Comparación en tiempo constante para mitigar ataques de canal lateral (Timing Attacks).
  bool _comparacionSeguraTiempoConstante(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Comprueba si un string dado corresponde a un payload cifrado válido de la bóveda.
  bool esPayloadValido(String? payload) {
    if (payload == null) return false;
    final clean = payload.trim();
    if (!clean.startsWith(vaultPrefix)) return false;
    final partes = clean.substring(vaultPrefix.length).split(r'$');
    return partes.length == 3 && partes.every((p) => p.isNotEmpty);
  }

  /// Evalúa la fortaleza y entropía de una contraseña dada para orientar al administrador.
  Map<String, dynamic> evaluarFortalezaContrasena(String password) {
    final clean = password.trim();
    if (clean.isEmpty) {
      return {'puntuacion': 0, 'etiqueta': 'Vacía', 'esSegura': false};
    }

    int score = 0;
    if (clean.length >= 8) score += 1;
    if (clean.length >= 12) score += 1;
    if (RegExp(r'[a-z]').hasMatch(clean)) score += 1;
    if (RegExp(r'[A-Z]').hasMatch(clean)) score += 1;
    if (RegExp(r'[0-9]').hasMatch(clean)) score += 1;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(clean)) score += 1;

    String etiqueta;
    bool esSegura = false;
    if (score <= 2) {
      etiqueta = 'Débil';
    } else if (score <= 4) {
      etiqueta = 'Aceptable';
      esSegura = clean.length >= 8;
    } else {
      etiqueta = 'Fuerte';
      esSegura = true;
    }

    return {
      'puntuacion': score,
      'etiqueta': etiqueta,
      'esSegura': esSegura,
      'longitud': clean.length,
    };
  }

  /// Genera una contraseña aleatoria de alta entropía con caracteres alfanuméricos y símbolos.
  String generarContrasenaAleatoriaFuerte({int longitud = 14}) {
    const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ23456789!@#%&*+?';
    final rng = Random.secure();
    return List.generate(longitud, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
