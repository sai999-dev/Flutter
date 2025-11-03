import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'api_client.dart';

/// Document Verification Service
/// Handles company document upload and verification status checking
class DocumentVerificationService {
  /// Upload company verification document
  /// POST /api/mobile/auth/upload-document
  /// Supports: PDF, PNG, JPG, JPEG (max 10MB)
  static Future<Map<String, dynamic>> uploadDocument({
    required String agencyId,
    required String filePath,
    String? documentType, // business_license, certificate, tax_id, other
    String? description,
  }) async {
    print('📄 Uploading verification document for agency: $agencyId');

    try {
      // Get file
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }

      // Check file size (max 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('File size exceeds 10MB limit');
      }

      // Get file extension and validate
      final extension = path.extension(filePath).toLowerCase();
      final allowedExtensions = ['.pdf', '.png', '.jpg', '.jpeg'];
      if (!allowedExtensions.contains(extension)) {
        throw Exception('Invalid file type. Allowed: PDF, PNG, JPG, JPEG');
      }

      // Initialize API client
      await ApiClient.initialize();
      
      // Get JWT token
      final token = ApiClient.token;
      if (token == null) {
        throw Exception('Authentication required');
      }

      // Discover active base URL by making a test request
      // We'll use the first available base URL from the list
      final baseUrls = ApiClient.baseUrlsList;
      
      String? baseUrl;
      for (final url in baseUrls) {
        try {
          final healthCheck = await http.get(
            Uri.parse('$url/api/health'),
          ).timeout(const Duration(seconds: 2));
          if (healthCheck.statusCode == 200) {
            baseUrl = url;
            break;
          }
        } catch (e) {
          continue;
        }
      }
      
      if (baseUrl == null) {
        throw Exception('Backend API not available');
      }

      // Create multipart request
      final uri = Uri.parse('$baseUrl/api/mobile/auth/upload-document');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add file
      final fileName = path.basename(filePath);
      request.files.add(
        await http.MultipartFile.fromPath(
          'document',
          filePath,
          filename: fileName,
        ),
      );

      // Add form fields
      request.fields['agency_id'] = agencyId;
      if (documentType != null) {
        request.fields['document_type'] = documentType;
      }
      if (description != null) {
        request.fields['description'] = description;
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Document uploaded successfully');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        final message = (errorData['message'] ?? 
            errorData['error'] ?? 
            'Document upload failed').toString();
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Document upload error: $e');
      rethrow;
    }
  }

  /// Pick a document file (PDF or Image)
  /// Returns file path if selected, null if cancelled
  static Future<String?> pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path;
      }
      return null;
    } catch (e) {
      print('❌ File picker error: $e');
      return null;
    }
  }

  /// Get verification status
  /// GET /api/mobile/auth/verification-status
  static Future<Map<String, dynamic>> getVerificationStatus() async {
    print('📋 Checking verification status...');

    try {
      final response = await ApiClient.get(
        '/api/mobile/auth/verification-status',
        requireAuth: true,
      );

      if (response == null) {
        throw Exception('No response from server');
      }

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        print('✅ Verification status retrieved');
        return decoded;
      } else {
        final errorData = json.decode(response.body);
        final message = (errorData['message'] ?? 
            errorData['error'] ?? 
            'Failed to get verification status').toString();
        throw Exception(message);
      }
    } catch (e) {
      print('❌ Get verification status error: $e');
      rethrow;
    }
  }

  /// Get uploaded documents list
  /// GET /api/mobile/auth/documents
  static Future<List<Map<String, dynamic>>> getDocuments() async {
    print('📄 Fetching uploaded documents...');

    try {
      final response = await ApiClient.get(
        '/api/mobile/auth/documents',
        requireAuth: true,
      );

      if (response == null || response.statusCode != 200) {
        print('❌ Failed to fetch documents: ${response?.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      List<Map<String, dynamic>> documents = [];

      if (data['documents'] is List) {
        documents = List<Map<String, dynamic>>.from(data['documents']);
      } else if (data['data'] is List) {
        documents = List<Map<String, dynamic>>.from(data['data']);
      } else if (data is List) {
        documents = List<Map<String, dynamic>>.from(data);
      }

      print('✅ Fetched ${documents.length} documents');
      return documents;
    } catch (e) {
      print('❌ Get documents error: $e');
      return [];
    }
  }
}

