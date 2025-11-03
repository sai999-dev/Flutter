import 'package:flutter/material.dart';
import 'package:flutter_backend/services/document_verification_service.dart';
import 'package:path/path.dart' as path;

/// Document Upload Dialog
/// Shown after registration to upload company verification document
class DocumentUploadDialog extends StatefulWidget {
  final String agencyId;
  final VoidCallback onSkip;
  final VoidCallback onUpload;

  const DocumentUploadDialog({
    super.key,
    required this.agencyId,
    required this.onSkip,
    required this.onUpload,
  });

  @override
  State<DocumentUploadDialog> createState() => _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends State<DocumentUploadDialog> {
  String? _selectedFilePath;
  String? _selectedFileName;
  String _selectedDocumentType = 'business_license';
  final _descriptionController = TextEditingController();
  bool _isUploading = false;
  String? _uploadError;

  final List<Map<String, String>> _documentTypes = [
    {'value': 'business_license', 'label': 'Business License'},
    {'value': 'certificate', 'label': 'Certificate of Incorporation'},
    {'value': 'tax_id', 'label': 'Tax ID Document'},
    {'value': 'other', 'label': 'Other Document'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final filePath = await DocumentVerificationService.pickDocument();
      if (filePath != null && mounted) {
        setState(() {
          _selectedFilePath = filePath;
          _selectedFileName = path.basename(filePath);
          _uploadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = 'Failed to pick document: $e';
        });
      }
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedFilePath == null) {
      setState(() {
        _uploadError = 'Please select a document first';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      await DocumentVerificationService.uploadDocument(
        agencyId: widget.agencyId,
        filePath: _selectedFilePath!,
        documentType: _selectedDocumentType,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Document uploaded successfully! Awaiting admin review.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        widget.onUpload();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = 'Upload failed: ${e.toString()}';
          _isUploading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00888C);
    const lightTeal = Color(0xFFE0F7F7);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: tealColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Company Verification',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: tealColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload company document for verification',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Document Type Selection
              const Text(
                'Document Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tealColor,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedDocumentType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: lightTeal,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: lightTeal),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: lightTeal),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: tealColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: _documentTypes.map((type) {
                  return DropdownMenuItem(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedDocumentType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // File Picker
              const Text(
                'Select Document',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tealColor,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isUploading ? null : _pickDocument,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: lightTeal,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedFilePath != null
                          ? tealColor
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedFilePath != null
                            ? Icons.check_circle
                            : Icons.attach_file,
                        color: _selectedFilePath != null
                            ? Colors.green
                            : tealColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFileName ?? 'Tap to select PDF or Image',
                          style: TextStyle(
                            color: _selectedFilePath != null
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: _selectedFilePath != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_selectedFilePath != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: _isUploading
                              ? null
                              : () {
                                  setState(() {
                                    _selectedFilePath = null;
                                    _selectedFileName = null;
                                  });
                                },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Supported formats: PDF, PNG, JPG, JPEG (Max 10MB)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),

              // Description (Optional)
              const Text(
                'Description (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tealColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any notes about this document...',
                  filled: true,
                  fillColor: lightTeal,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: lightTeal),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: lightTeal),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: tealColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Error Message
              if (_uploadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _uploadError!,
                          style: TextStyle(color: Colors.red[700], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_uploadError != null) const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isUploading ? null : widget.onSkip,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip for Now',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isUploading || _selectedFilePath == null
                          ? null
                          : _uploadDocument,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Upload Document',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Note: You can upload documents later from your profile settings.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

