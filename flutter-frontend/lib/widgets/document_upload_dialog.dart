
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
  XFile? _cameraImage;
  PlatformFile? _pickedFile;
  bool _uploading = false;
  String? _error;
  String? _uploadedFileName;
  
  // Document type selection
  String? _selectedDocumentType;
  final TextEditingController _otherDocumentTypeController = TextEditingController();
  
  // Document type options
  static const List<Map<String, String>> _documentTypes = [
    {'value': 'business_license', 'label': 'Business License'},
    {'value': 'certificate_of_incorporation', 'label': 'Certificate Of Incorporation'},
    {'value': 'tax_id', 'label': 'Tax ID Document'},
    {'value': 'other', 'label': 'Other Documents'},
  ];
  
  @override
  void dispose() {
    _otherDocumentTypeController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (image == null) return;
      setState(() {
        _cameraImage = image;
        _pickedFile = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = "Camera error: $e");
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true, // ensures bytes available on web
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _pickedFile = result.files.first;
        _cameraImage = null;
        _error = null;
      });

      debugPrint('✅ File picked: ${_pickedFile!.name}  bytes: ${_pickedFile!.bytes?.length ?? 0}');
    } catch (e) {
      setState(() => _error = "File picker error: $e");
      debugPrint("❌ File picker exception: $e");
    }
  }

  Future<void> _uploadDocument() async {
    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      debugPrint('📤 Starting document upload...');
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
      debugPrint('📝 Request URI: $uri');

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add Authorization header with JWT token
      request.headers['Authorization'] = 'Bearer $token';
      debugPrint('🔐 Authorization header added');

      // Validate document is selected
      if (_cameraImage == null && _pickedFile == null) {
        throw Exception("No document selected.");
      }
      
      // Validate document type is selected
      if (_selectedDocumentType == null || _selectedDocumentType!.isEmpty) {
        throw Exception("Please select a document type.");
      }
      
      if (_selectedDocumentType == 'other' && _otherDocumentTypeController.text.trim().isEmpty) {
        throw Exception("Please enter the document type for 'Other Documents'.");
      }

      // Add file with correct field name 'file' (matches backend)
      if (_cameraImage != null) {
        debugPrint('📷 Processing camera image: ${_cameraImage!.name}');
          final bytes = await _cameraImage!.readAsBytes();
        debugPrint('📦 Image bytes: ${bytes.length} bytes');
        
          request.files.add(http.MultipartFile.fromBytes(
          'file', // ✅ MATCHES BACKEND
            bytes,
            filename: _cameraImage!.name,
          contentType: MediaType.parse(lookupMimeType(_cameraImage!.name) ?? 'image/jpeg'),
        ));
        debugPrint('✅ Camera image added to request with field name: file');
      } else if (_pickedFile != null) {
        final pf = _pickedFile!;
        debugPrint('📄 Processing picked file: ${pf.name}');
        
        if (kIsWeb) {
          // web path unavailable -> use bytes
          if (pf.bytes == null) throw Exception("No bytes found in selected file.");
          debugPrint('📦 File bytes: ${pf.bytes!.length} bytes');
          
          request.files.add(http.MultipartFile.fromBytes(
            'file', // ✅ MATCHES BACKEND
            pf.bytes!,
            filename: pf.name,
            contentType: MediaType.parse(lookupMimeType(pf.name) ?? 'application/octet-stream'),
          ));
          debugPrint('✅ File bytes added to request with field name: file');
        } else {
          // mobile: check if path is available, otherwise use bytes
          if (pf.path == null || pf.path!.isEmpty) {
            if (pf.bytes == null) throw Exception("No bytes found in selected file.");
            debugPrint('📦 File bytes: ${pf.bytes!.length} bytes');
            
            request.files.add(http.MultipartFile.fromBytes(
              'file', // ✅ MATCHES BACKEND
              pf.bytes!,
              filename: pf.name,
              contentType: MediaType.parse(lookupMimeType(pf.name) ?? 'application/octet-stream'),
            ));
            debugPrint('✅ File bytes added to request with field name: file');
          } else {
            // mobile file path works fine
            debugPrint('📁 File path: ${pf.path}');
          final file = File(pf.path!);
            final length = await file.length();
            debugPrint('📦 File size: $length bytes');
            
            final stream = http.ByteStream(file.openRead());
            request.files.add(http.MultipartFile(
              'file', // ✅ MATCHES BACKEND
              stream,
              length,
              filename: pf.name,
              contentType: MediaType.parse(lookupMimeType(pf.path!) ?? 'application/octet-stream'),
            ));
            debugPrint('✅ File stream added to request with field name: file');
          }
        }
      }

      // Get document type value (already validated earlier)
      String documentTypeValue = _selectedDocumentType!;
      if (_selectedDocumentType == 'other') {
        // For "Other Documents", use the custom text input
        if (_otherDocumentTypeController.text.trim().isEmpty) {
          throw Exception("Please enter the document type for 'Other Documents'.");
        }
        documentTypeValue = _otherDocumentTypeController.text.trim();
      }
      
      // Add form fields (using snake_case as backend expects)
      request.fields['agency_id'] = widget.agencyId;
      request.fields['document_type'] = documentTypeValue; // Use selected document type
      request.fields['description'] = 'Agency verification document';
      
      debugPrint('📋 Form fields added:');
      debugPrint('   - agency_id: ${widget.agencyId}');
      debugPrint('   - document_type: $documentTypeValue');
      debugPrint('   - description: Agency verification document');

      // Log request details
      debugPrint('📤 Sending multipart request...');
      debugPrint('   Method: POST');
      debugPrint('   URL: $endpoint');
      debugPrint('   Headers: ${request.headers}');
      debugPrint('   Files count: ${request.files.length}');
      debugPrint('   Fields: ${request.fields}');

      // Send request
      final streamedResponse = await request.send();
      debugPrint('📥 Response received, status code: ${streamedResponse.statusCode}');
      
      final resp = await http.Response.fromStream(streamedResponse);
      debugPrint('📄 Response body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        debugPrint('✅ Document uploaded successfully!');
        setState(() => _uploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("✅ Document uploaded successfully")));
          Navigator.pop(context, true);
        }
      } else {
        final errorMsg = "Upload failed: ${resp.statusCode} ${resp.body}";
        debugPrint('❌ $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("❌ Upload error: $e");
      debugPrint("❌ Error type: ${e.runtimeType}");
      if (e is Exception) {
        debugPrint("❌ Exception details: ${e.toString()}");
      }
      
      setState(() {
        _uploading = false;
        _error = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Upload failed: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
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
              // Document Type Selection
              const Text(
                "Document Type *",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedDocumentType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                hint: const Text("Select document type"),
                items: _documentTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDocumentType = value;
                    if (value != 'other') {
                      _otherDocumentTypeController.clear();
                    }
                  });
                },
              ),
              // Custom document type input (shown when "Other Documents" is selected)
              if (_selectedDocumentType == 'other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otherDocumentTypeController,
                  decoration: InputDecoration(
                    labelText: "Enter document type *",
                    hintText: "e.g., Operating License, Permit, etc.",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // File selection buttons
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Take Photo"),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: const Text("Pick File"),
              ),
              const SizedBox(height: 16),
              // Selected file display
              if (_cameraImage != null || _pickedFile != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _cameraImage?.name ?? _pickedFile!.name,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: (_uploading || 
                      _selectedDocumentType == null || 
                      (_selectedDocumentType == 'other' && _otherDocumentTypeController.text.trim().isEmpty) ||
                      (_cameraImage == null && _pickedFile == null))
              ? null 
              : _uploadDocument,
          child: _uploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Upload Document"),
        ),
      ],
    );
  }
}

