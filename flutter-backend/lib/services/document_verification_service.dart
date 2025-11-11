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
      print('📂 Opening file picker dialog...');
      
      FilePickerResult? result;
      
      // Try with custom file types first (more restrictive)
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
          allowMultiple: false,
          withData: false,
          withReadStream: false,
          dialogTitle: 'Select a document (PDF, PNG, JPG, JPEG)',
        );
      } catch (e) {
        print('⚠️ Custom file type picker failed, trying any file type: $e');
        // Fallback to any file type if custom fails
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
          withData: false,
          withReadStream: false,
          dialogTitle: 'Select a document file',
        );
      }

      print('📂 File picker returned: ${result != null ? "result received" : "null"}');
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        print('📄 File info - Name: ${file.name}, Path: ${file.path}, Size: ${file.size}');
        
        // Validate file extension
        final extension = path.extension(file.name).toLowerCase();
        final allowedExtensions = ['.pdf', '.png', '.jpg', '.jpeg'];
        if (!allowedExtensions.contains(extension)) {
          throw Exception('Invalid file type. Please select a PDF, PNG, JPG, or JPEG file.');
        }
        
        // Handle both path and bytes (for web/platform differences)
        if (file.path != null && file.path!.isNotEmpty) {
          // Verify file exists
          final fileExists = await File(file.path!).exists();
          if (fileExists) {
            print('✅ File selected and verified: ${file.path}');
            return file.path;
          } else {
            print('⚠️ File path exists but file not found: ${file.path}');
            throw Exception('Selected file not found. Please try selecting the file again.');
          }
        } else if (file.name.isNotEmpty) {
          // On some platforms (like web), path might be null but we have bytes
          // For now, we'll throw an error to guide the user
          print('⚠️ File selected but path is null. File name: ${file.name}');
          throw Exception('File path not available. Please try selecting the file again or use camera option.');
        } else {
          print('⚠️ File selected but no name or path available');
          throw Exception('Invalid file selection. Please try again.');
        }
      }
      
      print('ℹ️ File picker cancelled or no file selected');
      return null;
    } catch (e) {
      print('❌ File picker error: $e');
      // Re-throw to show error in UI, but wrap in a user-friendly message
      if (e.toString().contains('permission') || e.toString().contains('Permission')) {
        throw Exception('File access permission denied. Please grant file access permissions and try again.');
      } else if (e.toString().contains('Invalid file type')) {
        rethrow; // Already has a good message
      } else if (e.toString().contains('path') || e.toString().contains('Path')) {
        rethrow; // Already has a good message
      } else {
        throw Exception('Failed to select file: ${e.toString()}. Please try again or use the camera option.');
      }
    }
  }

  /// Get verification status
  /// GET /api/mobile/auth/verification-status
  static Future<Map<String, dynamic>> getVerificationStatus() async {
    print('📋 Checking verification status...');

    try {
      // Ensure API client is initialized and token is loaded
      await ApiClient.initialize();
      
      // Check if token is available
      if (!ApiClient.isAuthenticated) {
        print('⚠️ No authentication token found - returning default status');
        // Return default pending status if not authenticated
        return {
          'document_status': 'no_document',
          'message': 'Please log in to view verification status',
        };
      }

      final response = await ApiClient.get(
        '/api/mobile/auth/verification-status',
        requireAuth: true,
      );

      if (response == null) {
        print('⚠️ No response from server - returning default status');
        return {
          'document_status': 'no_document',
          'message': 'Unable to load verification status',
        };
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
        print('⚠️ Error response: $message - returning default status');
        // Return default status instead of throwing
        return {
          'document_status': 'no_document',
          'message': message,
        };
      }
    } catch (e) {
      print('❌ Get verification status error: $e');
      // Return default status instead of throwing
      return {
        'document_status': 'no_document',
        'message': 'Unable to load verification status. Please try again later.',
      };
    }
  }

  /// Get uploaded documents list
  /// GET /api/mobile/auth/documents
  static Future<List<Map<String, dynamic>>> getDocuments() async {
    print('📄 Fetching uploaded documents...');

    try {
      // Ensure API client is initialized and token is loaded
      await ApiClient.initialize();
      
      // Check if token is available
      if (!ApiClient.isAuthenticated) {
        print('⚠️ No authentication token found - returning empty list');
        return [];
      }

      final response = await ApiClient.get(
        '/api/mobile/auth/documents',
        requireAuth: true,
      );

      if (response == null || response.statusCode != 200) {
        print('⚠️ Failed to fetch documents: ${response?.statusCode} - returning empty list');
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
      print('❌ Get documents error: $e - returning empty list');
      return [];
    }
  }
}

