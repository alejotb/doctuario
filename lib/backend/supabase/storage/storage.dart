import 'package:flutter/foundation.dart';
import '/flutter_flow/upload_data.dart';
import '../supabase.dart';

const String kImagesBucket = 'perfiles';
const String kDefaultStorageBucket = 'perfiles';

/// Verifica si el bucket de almacenamiento existe en Supabase y lo crea si es necesario
Future<void> ensureStorageBucketExists(String bucketName) async {
  try {
    final buckets = await SupaFlow.client.storage.listBuckets();
    final exists = buckets.any((b) => b.name == bucketName || b.id == bucketName);
    if (!exists) {
      await SupaFlow.client.storage.createBucket(
        bucketName,
        const BucketOptions(public: true),
      );
    }
  } catch (e) {
    // Si no tiene permisos de admin para crear bucket vía API, continuará normalmente
  }
}

Future<List<String>> uploadSupabaseStorageFiles({
  String bucketName = kImagesBucket,
  required List<SelectedFile> selectedFiles,
}) =>
    Future.wait(
      selectedFiles.map(
        (media) => uploadSupabaseStorageFile(
          bucketName: bucketName,
          selectedFile: media,
        ),
      ),
    );

Future<String> uploadSupabaseStorageFile({
  String bucketName = kImagesBucket,
  required SelectedFile selectedFile,
}) async {
  String? contentType;
  final pathLower = selectedFile.storagePath.toLowerCase();
  if (pathLower.endsWith('.jpg') || pathLower.endsWith('.jpeg')) {
    contentType = 'image/jpeg';
  } else if (pathLower.endsWith('.png')) {
    contentType = 'image/png';
  } else if (pathLower.endsWith('.webp')) {
    contentType = 'image/webp';
  } else if (pathLower.endsWith('.gif')) {
    contentType = 'image/gif';
  } else if (pathLower.endsWith('.pdf')) {
    contentType = 'application/pdf';
  }

  try {
    final storageBucket = SupaFlow.client.storage.from(bucketName);
    await storageBucket.uploadBinary(
      selectedFile.storagePath,
      selectedFile.bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return storageBucket.getPublicUrl(selectedFile.storagePath);
  } catch (e) {
    // Si falla porque el bucket no existe, intentar con el alternativo ('perfiles' <-> 'images')
    final altBucket = bucketName == 'perfiles' ? 'images' : 'perfiles';
    try {
      final fallbackStorage = SupaFlow.client.storage.from(altBucket);
      await fallbackStorage.uploadBinary(
        selectedFile.storagePath,
        selectedFile.bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      return fallbackStorage.getPublicUrl(selectedFile.storagePath);
    } catch (_) {}
    rethrow;
  }
}

Future<void> deleteSupabaseFileFromPublicUrl(String publicUrl) async {
  try {
    if (publicUrl.trim().isEmpty) return;

    // 1. Intentar con pathFromPublicUrl
    final storagePath = SupaFlow.client.storage.pathFromPublicUrl(publicUrl);
    if (storagePath != null && storagePath.contains('/')) {
      final bucketName = storagePath.split('/').first;
      final filePath = storagePath.split('/').skip(1).join('/');
      if (bucketName.isNotEmpty && filePath.isNotEmpty) {
        await SupaFlow.client.storage.from(bucketName).remove([filePath]);
        return;
      }
    }

    // 2. Fallback con Uri parsing directo
    final uri = Uri.tryParse(publicUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments;
      final publicIndex = segments.indexOf('public');
      if (publicIndex != -1 && publicIndex + 1 < segments.length) {
        final bucketName = segments[publicIndex + 1];
        final filePath = segments.sublist(publicIndex + 2).join('/');
        if (bucketName.isNotEmpty && filePath.isNotEmpty) {
          await SupaFlow.client.storage.from(bucketName).remove([filePath]);
          return;
        }
      }
    }
  } catch (e) {
    // Si la eliminación remota falla (ej. sin red o permisos), loguear sin romper el flujo
    debugPrint('Nota: No se pudo eliminar archivo previo de Supabase Storage: $e');
  }
}

extension _SupabaseBucketExtensions on SupabaseStorageClient {
  String? pathFromPublicUrl(String publicUrl) {
    final publicUrlPrefix = '$url/object/public/';
    final urlParts = publicUrl.split(publicUrlPrefix);
    if (urlParts.length != 2) {
      return null;
    }
    final fullStoragePath = urlParts.last;
    final storagePathParts = fullStoragePath.split('/');
    if (storagePathParts.length <= 1) {
      return null;
    }
    return fullStoragePath;
  }
}
