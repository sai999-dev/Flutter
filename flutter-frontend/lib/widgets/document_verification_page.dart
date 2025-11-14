import 'package:flutter/material.dart';
import 'package:flutter_backend/services/document_verification_service.dart';
import 'document_upload_dialog.dart';

/// Document Verification Page
/// Shows verification status and allows uploading documents
class DocumentVerificationPage extends StatefulWidget {
  final String agencyId;

  const DocumentVerificationPage({
    super.key,
    required this.agencyId,
  });

  @override
  State<DocumentVerificationPage> createState() =>
      _DocumentVerificationPageState();
}

class _DocumentVerificationPageState extends State<DocumentVerificationPage> {
  Map<String, dynamic>? _verificationStatus;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load verification status (now handles errors gracefully)
      final status = await DocumentVerificationService.getVerificationStatus();
      
      // Load documents list (now handles errors gracefully)
      final documents = await DocumentVerificationService.getDocuments(agencyId: widget.agencyId);

      if (mounted) {
        setState(() {
          _verificationStatus = status;
          _documents = documents;
          _isLoading = false;
          // Clear error if we got a response (even if it's default status)
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Only show error if it's a critical error
          // getVerificationStatus now returns default status instead of throwing
          _error = e.toString().contains('Authentication required') 
              ? 'Please log in to view verification status'
              : null;
          _isLoading = false;
          // Set default status if error occurred
          _verificationStatus ??= {
              'document_status': 'no_document',
              'message': 'Unable to load verification status',
            };
        });
      }
    }
  }

  Future<void> _showUploadDialog() async {
    final uploaded = await showDialog<bool>(
      context: context,
      builder: (context) => DocumentUploadDialog(
        agencyId: widget.agencyId,
      ),
    );

    if (uploaded == true) {
      // Refresh status after upload
      await _loadVerificationStatus();
    }
  }

  String _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return 'green';
      case 'pending':
        return 'orange';
      case 'rejected':
        return 'red';
      default:
        return 'grey';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending Review';
      case 'rejected':
        return 'Rejected';
      case 'no_document':
        return 'No Document Uploaded';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00888C);
    const lightTeal = Color(0xFFE0F7F7);

    return Scaffold(
      backgroundColor: tealColor,
      appBar: AppBar(
        title: const Text(
          'Business Verification',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: tealColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading verification status',
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadVerificationStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: tealColor,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status Card
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: lightTeal,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getStatusIcon(
                                            _verificationStatus?['document_status']),
                                        color: tealColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Verification Status',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: tealColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getStatusText(
                                                _verificationStatus?['document_status']),
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
                                if (_verificationStatus?['message'] != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: lightTeal,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _verificationStatus!['message'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Instructions Card
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: lightTeal,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Business Verification',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: tealColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Please upload your Certificate of Incorporation (or Formation) issued by your state\'s Secretary of State.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: tealColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: tealColor,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '(Optional) You may also upload your IRS EIN Confirmation Letter for faster verification.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Documents List
                        if (_documents.isNotEmpty) ...[
                          const Text(
                            'Uploaded Documents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._documents.map((doc) => Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.description,
                                      color: tealColor),
                                  title: Text(
                                    doc['file_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Type: ${doc['document_type'] ?? 'Unknown'}',
                                      ),
                                      Text(
                                        'Status: ${_getStatusText(doc['verification_status'])}',
                                        style: TextStyle(
                                          color: _getStatusColor(
                                                  doc['verification_status']) ==
                                              'green'
                                              ? Colors.green
                                              : _getStatusColor(
                                                      doc['verification_status']) ==
                                                  'orange'
                                                  ? Colors.orange
                                                  : Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    _getStatusIcon(doc['verification_status']),
                                    color: _getStatusColor(
                                            doc['verification_status']) ==
                                        'green'
                                        ? Colors.green
                                        : _getStatusColor(
                                                doc['verification_status']) ==
                                            'orange'
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],

                        // Upload Button
                        ElevatedButton.icon(
                          onPressed: _showUploadDialog,
                          icon: const Icon(Icons.upload_file),
                          label: const Text(
                            'Upload New Document',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: tealColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload a company document for verification. Supported formats: PDF, PNG, JPG, JPEG (Max 10MB)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
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

