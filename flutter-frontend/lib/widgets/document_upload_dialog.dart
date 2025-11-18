
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter_backend/services/api_client.dart';
import '../api_endpoints.dart';

// Conditional import for File - only available on non-web platforms
import 'dart:io' if (dart.library.html) 'file_io_stub.dart' show File;

class DocumentUploadDialog extends StatefulWidget {
  final String agencyId;
  const DocumentUploadDialog({Key? key, required this.agencyId}) : super(key: key);

  @override
  State<DocumentUploadDialog> createState() => _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends State<DocumentUploadDialog> {
  final ImagePicker _picker = ImagePicker();
  String? _error;
  
  // Required document types
  static const List<String> requiredDocumentTypes = [
    'business_license',
    'certificate_of_incorporation',
    'tax_id',
  ];
  
  // Track uploading state per document type
  final Map<String, bool> _uploadingStates = {};
  
  @override
  void initState() {
    super.initState();
    // Initialize uploading states
    for (var type in requiredDocumentTypes) {
      _uploadingStates[type] = false;
    }
  }

  Future<void> _pickFile(String documentType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true, // ensures bytes available on web
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      debugPrint('✅ File picked for $documentType: ${pickedFile.name}  bytes: ${pickedFile.bytes?.length ?? 0}');
      
      // Upload immediately after picking
      await _uploadDocument(documentType, pickedFile);
    } catch (e) {
      setState(() => _error = "File picker error: $e");
      debugPrint("❌ File picker exception: $e");
    }
  }

  Future<void> _takePhoto(String documentType) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (image == null) return;
      
      debugPrint('✅ Photo taken for $documentType: ${image.name}');
      
      // Upload immediately after taking photo
      await _uploadDocumentFromCamera(documentType, image);
    } catch (e) {
      setState(() => _error = "Camera error: $e");
    }
  }

  Future<void> pickAndUploadDocument(String documentType) async {
    // Show dialog to choose between camera or file picker
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'camera'),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Take Photo"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'file'),
              icon: const Icon(Icons.attach_file),
              label: const Text("Pick File"),
            ),
          ],
        ),
      ),
    );

    if (choice == 'camera') {
      await _takePhoto(documentType);
    } else if (choice == 'file') {
      await _pickFile(documentType);
    }
  }

  Future<void> _uploadDocument(String documentType, PlatformFile pickedFile) async {
    setState(() {
      _uploadingStates[documentType] = true;
      _error = null;
    });

    try {
      debugPrint('📤 Starting document upload for $documentType...');
      debugPrint('📋 Agency ID: ${widget.agencyId}');

      // Initialize API client and get token
      await ApiClient.initialize();
      final token = ApiClient.token;
      
      if (token == null || token.isEmpty) {
        throw Exception("Authentication required. Please log in first.");
      }
      
      debugPrint('🔑 JWT Token found: ${token.substring(0, 20)}...');

      // Use ApiEndpoints to get the correct upload URL
      final endpoint = ApiEndpoints.uploadAgencyDocument(widget.agencyId);
      final uri = Uri.parse(endpoint);
      
      debugPrint('🌐 Upload URL: $endpoint');

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add Authorization header with JWT token
      request.headers['Authorization'] = 'Bearer $token';

      // Add file with correct field name 'file' (matches backend)
      debugPrint('📄 Processing picked file: ${pickedFile.name}');
      
      if (kIsWeb) {
        // web path unavailable -> use bytes
        if (pickedFile.bytes == null) throw Exception("No bytes found in selected file.");
        debugPrint('📦 File bytes: ${pickedFile.bytes!.length} bytes');
        
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          pickedFile.bytes!,
          filename: pickedFile.name,
          contentType: MediaType.parse(lookupMimeType(pickedFile.name) ?? 'application/octet-stream'),
        ));
      } else {
        // mobile: check if path is available, otherwise use bytes
        if (pickedFile.path == null || pickedFile.path!.isEmpty) {
          if (pickedFile.bytes == null) throw Exception("No bytes found in selected file.");
          debugPrint('📦 File bytes: ${pickedFile.bytes!.length} bytes');
          
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            pickedFile.bytes!,
            filename: pickedFile.name,
            contentType: MediaType.parse(lookupMimeType(pickedFile.name) ?? 'application/octet-stream'),
          ));
        } else {
          // mobile file path works fine
          debugPrint('📁 File path: ${pickedFile.path}');
          final file = File(pickedFile.path!);
          final length = await file.length();
          debugPrint('📦 File size: $length bytes');
          
          final stream = http.ByteStream(file.openRead());
          request.files.add(http.MultipartFile(
            'file',
            stream,
            length,
            filename: pickedFile.name,
            contentType: MediaType.parse(lookupMimeType(pickedFile.path!) ?? 'application/octet-stream'),
          ));
        }
      }
      
      // Add form fields (using snake_case as backend expects)
      request.fields['agency_id'] = widget.agencyId;
      request.fields['document_type'] = documentType;
      request.fields['description'] = 'Agency verification document';
      
      debugPrint('📋 Form fields added:');
      debugPrint('   - agency_id: ${widget.agencyId}');
      debugPrint('   - document_type: $documentType');
      debugPrint('   - description: Agency verification document');

      // Send request
      final streamedResponse = await request.send();
      debugPrint('📥 Response received, status code: ${streamedResponse.statusCode}');
      
      final resp = await http.Response.fromStream(streamedResponse);
      debugPrint('📄 Response body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        debugPrint('✅ Document uploaded successfully!');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("✅ ${documentType.replaceAll('_', ' ')} uploaded successfully")));
          // Close dialog and return true to trigger refresh
          Navigator.of(context).pop(true);
        }
      } else {
        final errorMsg = "Upload failed: ${resp.statusCode} ${resp.body}";
        debugPrint('❌ $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("❌ Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Upload failed: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingStates[documentType] = false;
        });
      }
    }
  }

  Future<void> _uploadDocumentFromCamera(String documentType, XFile image) async {
    setState(() {
      _uploadingStates[documentType] = true;
      _error = null;
    });

    try {
      debugPrint('📤 Starting document upload for $documentType...');
      debugPrint('📋 Agency ID: ${widget.agencyId}');

      // Initialize API client and get token
      await ApiClient.initialize();
      final token = ApiClient.token;
      
      if (token == null || token.isEmpty) {
        throw Exception("Authentication required. Please log in first.");
      }
      
      debugPrint('🔑 JWT Token found: ${token.substring(0, 20)}...');

      // Use ApiEndpoints to get the correct upload URL
      final endpoint = ApiEndpoints.uploadAgencyDocument(widget.agencyId);
      final uri = Uri.parse(endpoint);
      
      debugPrint('🌐 Upload URL: $endpoint');

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add Authorization header with JWT token
      request.headers['Authorization'] = 'Bearer $token';

      // Add file from camera
      debugPrint('📷 Processing camera image: ${image.name}');
      final bytes = await image.readAsBytes();
      debugPrint('📦 Image bytes: ${bytes.length} bytes');
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: image.name,
        contentType: MediaType.parse(lookupMimeType(image.name) ?? 'image/jpeg'),
      ));
      
      // Add form fields (using snake_case as backend expects)
      request.fields['agency_id'] = widget.agencyId;
      request.fields['document_type'] = documentType;
      request.fields['description'] = 'Agency verification document';
      
      debugPrint('📋 Form fields added:');
      debugPrint('   - agency_id: ${widget.agencyId}');
      debugPrint('   - document_type: $documentType');
      debugPrint('   - description: Agency verification document');

      // Send request
      final streamedResponse = await request.send();
      debugPrint('📥 Response received, status code: ${streamedResponse.statusCode}');
      
      final resp = await http.Response.fromStream(streamedResponse);
      debugPrint('📄 Response body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        debugPrint('✅ Document uploaded successfully!');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("✅ ${documentType.replaceAll('_', ' ')} uploaded successfully")));
          // Close dialog and return true to trigger refresh
          Navigator.of(context).pop(true);
        }
      } else {
        final errorMsg = "Upload failed: ${resp.statusCode} ${resp.body}";
        debugPrint('❌ $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("❌ Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Upload failed: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingStates[documentType] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Upload Verification Document"),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: requiredDocumentTypes.map((type) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(type.replaceAll('_', ' ')),
                      trailing: ElevatedButton(
                        onPressed: (_uploadingStates[type] == true)
                            ? null
                            : () => pickAndUploadDocument(type),
                        child: (_uploadingStates[type] == true)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Upload"),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Error display
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}

