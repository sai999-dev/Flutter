# 📋 Agency Documents Table Field Verification

**Table Name:** `agency_documents` (NOT `verification_documents`)

## ✅ Fields Currently Being Sent from Flutter App

Based on `document_upload_dialog.dart`, the app is sending:

| Field Name | Value | Type | Status |
|------------|-------|------|--------|
| `file` | File (multipart) | File/Binary | ✅ Correct field name |
| `agency_id` | `widget.agencyId` | String | ✅ Correct |
| `document_type` | `'verification'` | String | ⚠️ Check if backend accepts this value |
| `description` | `'Agency verification document'` | String | ✅ Optional field |

## 📊 Expected `agency_documents` Table Schema

The `agency_documents` table should have these columns:

| Column Name | Type | Required | Source | Notes |
|-------------|------|----------|--------|-------|
| `id` | SERIAL/INTEGER | ✅ | Auto-generated | Primary key |
| `agency_id` | INTEGER/VARCHAR | ✅ | From request | Foreign key to `agencies` table |
| `document_type` | VARCHAR | ✅ | From request | Should be: `business_license`, `certificate`, `tax_id`, `other`, or `verification` |
| `file_path` | VARCHAR/TEXT | ✅ | Backend saves | Path/URL where file is stored |
| `file_name` | VARCHAR | ⚠️ | From filename | Original filename |
| `file_size` | INTEGER | ⚠️ | From file | File size in bytes |
| `mime_type` | VARCHAR | ⚠️ | From Content-Type | e.g., `image/jpeg`, `application/pdf` |
| `description` | TEXT | ❌ | From request | Optional description |
| `status` | VARCHAR | ✅ | Backend default | Usually: `pending`, `approved`, `rejected` (default: `pending`) |
| `uploaded_at` | TIMESTAMP | ✅ | Auto-generated | When document was uploaded |
| `created_at` | TIMESTAMP | ✅ | Auto-generated | Record creation time |
| `updated_at` | TIMESTAMP | ✅ | Auto-generated | Last update time |

## 🔍 Field Mapping Analysis

### ✅ Correctly Mapped Fields:

1. **`agency_id`** ✅
   - **Sent as:** `request.fields['agency_id'] = widget.agencyId`
   - **Database expects:** `agency_id` column
   - **Status:** ✅ Matches perfectly

2. **`file` (file upload)** ✅
   - **Sent as:** `request.files.add(http.MultipartFile(..., 'file', ...))`
   - **Backend processes:** File upload, saves to storage, stores path in `file_path`
   - **Status:** ✅ Correct field name - uses `'file'` to match backend

3. **`description`** ✅
   - **Sent as:** `request.fields['description'] = 'Agency verification document'`
   - **Database expects:** `description` column (optional)
   - **Status:** ✅ Correct

### ⚠️ Potential Issues:

1. **`document_type` value** ⚠️
   - **Currently sending:** `'verification'`
   - **Expected values (from service):** `'business_license'`, `'certificate'`, `'tax_id'`, `'other'`
   - **Issue:** `'verification'` might not be a valid value in your database enum/constraint
   - **Recommendation:** Check if backend accepts `'verification'` or use one of the specific types

2. **Missing fields that backend might auto-populate:**
   - `file_name` - Backend should extract from uploaded file
   - `file_size` - Backend should calculate from file
   - `mime_type` - Backend should extract from Content-Type header
   - `status` - Backend should default to `'pending'`
   - `uploaded_at`, `created_at`, `updated_at` - Backend should auto-generate

## 🔧 Recommended Actions

### 1. Verify `document_type` Value

Check your backend code or database schema to confirm if `'verification'` is an accepted value. If not, you may need to:

**Option A:** Use a more specific type:
```dart
request.fields['document_type'] = 'business_license'; // or 'certificate', 'tax_id', 'other'
```

**Option B:** Check if backend accepts `'verification'` as a valid document type.

### 2. Check Database Schema

Run this SQL query to see your actual table structure:

```sql
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'agency_documents'
ORDER BY ordinal_position;
```

### 3. Verify Backend Processing

Check your backend upload handler to ensure it:
- ✅ Accepts `'file'` as the file field name (matches backend expectation)
- ✅ Accepts `'verification'` as a valid `document_type` value
- ✅ Extracts `file_name` from the uploaded file
- ✅ Calculates `file_size` from the file
- ✅ Extracts `mime_type` from Content-Type
- ✅ Sets default `status` to `'pending'`
- ✅ Auto-generates timestamps (`uploaded_at`, `created_at`, `updated_at`)

## 📝 Current Request Format

```dart
// Multipart Request
POST /api/v1/agencies/{agencyId}/documents
Headers:
  Authorization: Bearer <JWT_TOKEN>
  Content-Type: multipart/form-data

Form Data:
  file: <file binary>
  agency_id: <string>
  document_type: "verification"
  description: "Agency verification document"
```

## ✅ Verification Checklist

- [x] File field name is `'file'` (matches backend)
- [x] `agency_id` is sent as snake_case
- [x] `document_type` is sent as snake_case
- [x] JWT token is included in Authorization header
- [x] Endpoint is correct: `/api/v1/agencies/{agencyId}/documents`
- [ ] Verify `document_type` value `'verification'` is accepted by backend
- [ ] Verify backend extracts file metadata (name, size, mime_type)
- [ ] Verify backend sets default status to `'pending'`
- [ ] Verify backend auto-generates timestamps

## 🐛 If Documents Still Don't Appear in Database

1. **Check backend logs** for any errors during file processing
2. **Verify file storage** - ensure backend can write files to storage location
3. **Check database constraints** - ensure no foreign key or constraint violations
4. **Verify transaction commits** - ensure backend commits the database transaction
5. **Check response** - verify backend returns success response even if database insert fails

