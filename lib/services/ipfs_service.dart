import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:crypto/crypto.dart';
import '../constants/app_constants.dart';

/// IPFS Service for off-chain document storage (Thesis Section 3.4.4 & 3.7)
///
/// "Documents are stored off-chain on IPFS, which generates a unique
/// content identifier (CID). Only the CID and cryptographic hash
/// are stored on-chain."
///
/// Supports two modes:
///  1. **Pinata mode** — real IPFS uploads via Pinata pinning service
///  2. **Demo mode** — generates deterministic mock CIDs for offline testing
class IPFSService {
  late final Dio _dio;
  final String _gateway;
  final String _apiUrl;
  final bool _isDemoMode;

  IPFSService({
    String? gateway,
    String? apiUrl,
    String? pinataJwt,
  })  : _gateway = gateway ?? AppConstants.ipfsGateway,
        _apiUrl = apiUrl ?? AppConstants.ipfsApiUrl,
        _isDemoMode = (pinataJwt ?? AppConstants.pinataJwt).isEmpty {
    _dio = Dio();

    // Configure Pinata auth if we have a JWT
    final jwt = pinataJwt ?? AppConstants.pinataJwt;
    if (!_isDemoMode && jwt.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $jwt';
    }
  }

  /// Whether the service is running in demo/offline mode
  bool get isDemoMode => _isDemoMode;

  // ─── Upload ───────────────────────────────────────────────────

  /// Upload a file to IPFS and return its CID
  Future<String> uploadFile(File file) async {
    if (_isDemoMode) {
      return _generateDemoCid(await file.readAsBytes());
    }

    try {
      final fileName = file.path.split(RegExp(r'[/\\]')).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: MediaType('application', 'octet-stream'),
        ),
        'pinataMetadata': jsonEncode({
          'name': fileName,
          'keyvalues': {
            'app': AppConstants.appName,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        }),
      });

      final response = await _dio.post(
        '$_apiUrl/pinning/pinFileToIPFS',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (response.data != null && response.data['IpfsHash'] != null) {
        return response.data['IpfsHash'] as String;
      } else {
        throw Exception('Pinata response missing IpfsHash');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception(
          'IPFS authentication failed. Please check your Pinata JWT token '
          'in app_constants.dart. Get a free key at https://app.pinata.cloud',
        );
      }
      throw Exception('IPFS upload error: ${e.message}');
    } catch (e) {
      throw Exception('IPFS upload error: $e');
    }
  }

  /// Upload raw bytes to IPFS
  Future<String> uploadBytes(Uint8List bytes, String fileName) async {
    if (_isDemoMode) {
      return _generateDemoCid(bytes);
    }

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType('application', 'octet-stream'),
        ),
        'pinataMetadata': jsonEncode({
          'name': fileName,
        }),
      });

      final response = await _dio.post(
        '$_apiUrl/pinning/pinFileToIPFS',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (response.data != null && response.data['IpfsHash'] != null) {
        return response.data['IpfsHash'] as String;
      } else {
        throw Exception('Pinata response missing IpfsHash');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception(
          'IPFS authentication failed. Check your Pinata JWT token.',
        );
      }
      throw Exception('IPFS upload error: ${e.message}');
    } catch (e) {
      throw Exception('IPFS upload error: $e');
    }
  }

  // ─── Retrieve ─────────────────────────────────────────────────

  /// Retrieve a file from IPFS by its CID
  Future<Uint8List> retrieveFile(String cid) async {
    if (_isDemoMode) {
      // In demo mode, return a small placeholder
      return Uint8List.fromList(utf8.encode('DEMO_FILE_CONTENT:$cid'));
    }

    try {
      final response = await _dio.get<Uint8List>(
        '$_gateway$cid',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        return response.data!;
      } else {
        throw Exception('Failed to retrieve file from IPFS');
      }
    } catch (e) {
      throw Exception('IPFS retrieval error: $e');
    }
  }

  /// Get the public gateway URL for a CID
  String getFileUrl(String cid) {
    return '$_gateway$cid';
  }

  // ─── Pinning ──────────────────────────────────────────────────

  /// Pin a CID to keep it available
  Future<bool> pinFile(String cid) async {
    if (_isDemoMode) return true;

    try {
      final response = await _dio.post(
        '$_apiUrl/pinning/pinByHash',
        data: {'hashToPin': cid},
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to pin file: $e');
    }
  }

  /// Unpin a CID
  Future<bool> unpinFile(String cid) async {
    if (_isDemoMode) return true;

    try {
      final response = await _dio.delete(
        '$_apiUrl/pinning/unpin/$cid',
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to unpin file: $e');
    }
  }

  // ─── Demo Mode Helpers ────────────────────────────────────────

  /// Generate a deterministic mock CID from file bytes
  /// Produces a realistic-looking CIDv1-style string
  String _generateDemoCid(List<int> bytes) {
    final hash = sha256.convert(bytes).toString();
    // Simulate a CIDv1 prefix (Qm... is CIDv0, bafy... is CIDv1)
    return 'QmDemo${hash.substring(0, 38)}';
  }
}
