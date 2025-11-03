# Document Verification API Endpoints

## Overview

This document lists all endpoints for company document verification system. Agencies upload company documents during/after registration, and admins review and approve/reject them.

---

## Mobile App Endpoints (4 Endpoints)

### 1. Upload Document
**POST** `/api/mobile/auth/upload-document`

**Authentication**: Required (JWT)

**Request**: Multipart Form Data
- `document` (file): PDF, PNG, JPG, JPEG (max 10MB)
- `document_type` (string, optional): `business_license`, `certificate`, `tax_id`, `other`
- `description` (string, optional): Additional notes

**Response:**
```json
{
  "success": true,
  "message": "Document uploaded successfully. Awaiting admin review.",
  "data": {
    "document_id": 123,
    "verification_status": "pending",
    "uploaded_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### 2. Get Verification Status
**GET** `/api/mobile/auth/verification-status`

**Authentication**: Required (JWT)

**Response:**
```json
{
  "email_verified": true,
  "document_status": "pending",
  "overall_status": "pending_verification",
  "document": {
    "id": 123,
    "document_type": "business_license",
    "file_name": "license.pdf",
    "verification_status": "pending",
    "uploaded_at": "2024-01-01T00:00:00Z"
  },
  "message": "Your document is pending admin review"
}
```

---

### 3. Get All Documents
**GET** `/api/mobile/auth/documents`

**Authentication**: Required (JWT)

**Response:**
```json
{
  "documents": [
    {
      "id": 123,
      "document_type": "business_license",
      "file_name": "license.pdf",
      "verification_status": "pending",
      "uploaded_at": "2024-01-01T00:00:00Z",
      "description": "State business license"
    }
  ]
}
```

---

## Admin Portal Endpoints (4 Endpoints)

### 4. List Verification Documents
**GET** `/api/admin/verification-documents`

**Authentication**: Required (Admin JWT)

**Query Parameters:**
- `status` (optional): `pending`, `approved`, `rejected`
- `page` (optional): Page number (default: 1)
- `limit` (optional): Results per page (default: 20)
- `agency_id` (optional): Filter by agency

**Response:**
```json
{
  "documents": [
    {
      "id": 123,
      "agency_id": 456,
      "agency_name": "ABC Agency",
      "agency_email": "agency@example.com",
      "document_type": "business_license",
      "file_name": "license.pdf",
      "verification_status": "pending",
      "uploaded_at": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 5
  }
}
```

---

### 5. Download Document
**GET** `/api/admin/verification-documents/:id/download`

**Authentication**: Required (Admin JWT)

**Response**: File stream with appropriate headers

---

### 6. Approve Document
**PUT** `/api/admin/verification-documents/:id/approve`

**Authentication**: Required (Super Admin JWT)

**Request Body:**
```json
{
  "notes": "Document verified. Business license is valid."
}
```

**Response:**
```json
{
  "success": true,
  "message": "Document approved successfully",
  "data": {
    "document_id": 123,
    "verification_status": "approved",
    "reviewed_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### 7. Reject Document
**PUT** `/api/admin/verification-documents/:id/reject`

**Authentication**: Required (Super Admin JWT)

**Request Body:**
```json
{
  "rejection_reason": "Document is unclear/illegible. Please upload a clearer image.",
  "notes": "Customer service notes"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Document rejected",
  "data": {
    "document_id": 123,
    "verification_status": "rejected",
    "rejection_reason": "Document is unclear..."
  }
}
```

---

## Database Table

**Table**: `verification_documents`

```sql
CREATE TABLE verification_documents (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER REFERENCES agencies(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size INTEGER NOT NULL,
    mime_type VARCHAR(100),
    description TEXT,
    verification_status VARCHAR(50) DEFAULT 'pending',
    reviewed_by INTEGER REFERENCES users(id),
    reviewed_at TIMESTAMP,
    rejection_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(agency_id, verification_status),
    INDEX(verification_status)
);
```

---

## Verification Flow

1. **Registration**: Agency registers with email/password
2. **Email Verification**: Agency verifies email with code
3. **Document Upload**: Agency uploads company document (POST `/api/mobile/auth/upload-document`)
4. **Admin Review**: Admin reviews document in admin portal
5. **Approval/Rejection**: Admin approves or rejects document
6. **Agency Notified**: Agency receives notification of decision
7. **Account Activation**: If approved, agency account is fully verified

---

## Status Values

- **`no_document`**: No document uploaded yet
- **`pending`**: Document uploaded, awaiting admin review
- **`approved`**: Document approved by admin
- **`rejected`**: Document rejected by admin

---

**Full implementation details**: See `BACKEND_API_DEVELOPMENT_GUIDE.md` Section 1.1 and Section 2.1

