/// ================================================
///  API ENDPOINTS CONFIGURATION
///  Updated to connect with super-admin backend
///  instead of mobile/auth route
/// ================================================

class ApiEndpoints {
  // Base URL of backend
  static const String baseUrl = 'http://127.0.0.1:3001';

  // Agency document upload (connects to backend route)
  static String uploadAgencyDocument(String agencyId) =>
      '$baseUrl/api/v1/agencies/$agencyId/documents';

  // Fetch uploaded documents for agency
  static String fetchAgencyDocuments(String agencyId) =>
      '$baseUrl/api/v1/agencies/$agencyId/documents';

  // (Optional) Serve document preview for Super Admin (if needed later)
  static String serveDocumentFile(String filename) =>
      '$baseUrl/api/v1/agencies/files/$filename';
}

