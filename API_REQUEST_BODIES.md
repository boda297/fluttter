# API Request Bodies — Orientation App

This document lists all **request bodies** required to connect the **orientation** Flutter app with the backend API.

---

## Table of Contents

1. [Auth](#1-auth)
2. [Admin — Join Requests](#2-admin--join-requests)
3. [Projects](#3-projects)
4. [Reels / Clips](#4-reels--clips)
5. [Backend-Only Endpoints](#5-backend-only-endpoints)
6. [Authentication Header](#6-authentication-header)
7. [Mismatches to Resolve](#7-mismatches-to-resolve)

---

## 1. Auth

| Endpoint | Method | Request Body |
|----------|--------|--------------|
| `/auth/login` | POST | `{ "email": string, "password": string }` |
| `/auth/register` | POST | `{ "username": string, "email": string, "phoneNumber": string, "password": string }` |
| `/auth/forgot-password` | POST | `{ "email": string }` |
| `/auth/verify-otp` | POST | `{ "email": string, "otp": string }` |
| `/auth/reset-password` | POST | `{ "email": string, "newPassword": string }` |
| `PATCH /users/profile` | PATCH | `{ "username": string, "email": string, "phoneNumber": string }` — للبروفايل؛ الـ app يرسل `username` = `firstName + lastName` |
| `PATCH /users/profile` | PATCH | `{ "password": string }` — لتغيير كلمة المرور |

**Notes:**
- Profile: الـ app يبعث `firstName`+`lastName` كـ `username` إلى `PATCH /users/profile`.
- `email`, `password`, `newPassword`, `phoneNumber`: كما في `backend/API_ROUTES_DOCUMENTATION.md`.
- `GET /auth/profile` و `forgot-password`, `verify-otp`, `reset-password` قد لا تكون في الباك اند بعد.

---

## 2. Admin — Join Requests

| Endpoint | Method | Request Body |
|----------|--------|--------------|
| `POST /admin/join-requests` | POST | `{ "companyName": string, "headOffice": string, "projectName": string, "orientationsCount": number, "notes"?: string }` |
| `POST /admin/join-requests/:id/approve` | POST | None (ID in URL) |
| `POST /admin/join-requests/:id/reject` | POST | None (ID in URL) |

**Notes:**
- `orientationsCount`: integer.
- `notes`: optional string.

---

## 3. Projects

| Endpoint | Method | Request Body |
|----------|--------|--------------|
| `GET /projects` | GET | None. Query: `developerId?`, `location?`, `status?`, `title?`, `slug?`, `limit?`, `page?`, `sortBy?` |
| `GET /projects/:id` | GET | None |
| `GET /projects/trending` | GET | None. Query: `limit?` |
| `PATCH /projects/:id/increment-view` | PATCH | None |
| `PATCH /projects/:id/save-project` | PATCH | None (user from JWT) |
| `PATCH /projects/:id/unsave-project` | PATCH | None (user from JWT) |

**Notes:**
- Project ID in URL; user identity from `Authorization: Bearer <token>`.

---

## 4. Reels / Clips

الـ app يستخدم **`POST /reels`** (multipart/form-data) كما في الباك اند:

| Field | Type | Required |
|-------|------|----------|
| `title` | string | Yes |
| `description` | string | No |
| `projectId` | string (ObjectId) | No |
| `file` | Video file | Yes |
| `thumbnail` | Image file | Yes (مطلوب في الباك اند؛ إن لم يُرسل قد يرجع 400) |

---

## 5. Backend-Only Endpoints

These are used by the backend (e.g. admin panel) or future features. Request bodies for connecting external clients:

### 5.1 Users

| Endpoint | Method | Content-Type | Request Body |
|----------|--------|--------------|--------------|
| `POST /users` | POST | JSON | `{ "username": string, "email": string, "phoneNumber": string, "password": string }` |
| `PATCH /users/:id` | PATCH | JSON | `{ "username"?: string, "email"?: string, "phoneNumber"?: string, "password"?: string }` |

---

### 5.2 Projects (multipart/form-data)

| Endpoint | Method | Request Body | Files |
|----------|--------|--------------|-------|
| `POST /projects` | POST | `title`, `developer`, `location`, `status?`, `script`, `episodes?`, `reels?`, `inventory?`, `pdfUrl?`, `whatsappNumber?` | `logo`, `heroVideo` |
| `PATCH /projects/:id` | PATCH | Same fields, all optional | — |

**Status values:** `PLANNING` \| `CONSTRUCTION` \| `COMPLETED` \| `DELIVERED`

---

### 5.3 Developer (multipart/form-data)

| Endpoint | Method | Request Body | Files |
|----------|--------|--------------|-------|
| `POST /developer` | POST | `name`, `email?`, `phone?`, `socialMediaLink?`, `location` | `logo` (optional) |
| `PATCH /developer/:id` | PATCH | `name?`, `email?`, `phone?`, `socialMediaLink?`, `location?` | — |
| `PATCH /developer/:id/project` | PATCH | `{ "script": string }` | — |

---

### 5.4 Episode (multipart/form-data)

| Endpoint | Method | Request Body | Files |
|----------|--------|--------------|-------|
| `POST /episode` | POST | `projectId`, `title`, `thumbnail?`, `episodeOrder`, `duration` | `file` (video, required) |
| `PATCH /episode/:id` | PATCH | `title?`, `thumbnail?`, `episodeUrl?`, `episodeOrder?`, `duration?` | — |

---

### 5.5 Reels (multipart/form-data)

| Endpoint | Method | Request Body | Files |
|----------|--------|--------------|-------|
| `POST /reels` | POST | `title`, `description?`, `projectId?` | `file` (video), `thumbnail` |
| `PATCH /reels/:id` | PATCH | `title?`, `description?`, `videoUrl?`, `thumbnail?`, `projectId?` | — |

---

### 5.6 News (multipart/form-data)

| Endpoint | Method | Request Body | Files |
|----------|--------|--------------|-------|
| `POST /news` | POST | `title`, `projectId`, `developer` | `image` (required) |
| `PATCH /news/:id` | PATCH | `title?`, `projectId?`, `developer?` | `image` (optional) |

---

### 5.7 Files (multipart/form-data)

| Endpoint | Method | Request Body | Files |
|----------|--------|--------------|-------|
| `POST /files/upload/inventory` | POST | `projectId`, `description?` | `inventory` (required) |
| `POST /files/upload/pdf` | POST | `projectId`, `title` | `PDF` (required) |

---

### 5.8 Upload (multipart/form-data)

| Endpoint | Method | Request Body | Files |
|----------|--------|--------------|-------|
| `POST /upload` | POST | `folder?` (`episodes` \| `reels` \| `images` \| `PDF`) | `file` (required) |
| `POST /upload/episode` | POST | — | `file` (video) |
| `POST /upload/reel` | POST | — | `file` (video) |
| `POST /upload/image` | POST | — | `file` (image) |
| `POST /upload/pdf` | POST | — | `file` (PDF) |

---

## 6. Authentication Header

For protected routes, send:

```
Authorization: Bearer <jwt_token>
```

Token is obtained from:
- `POST /auth/login`
- `POST /auth/register`

---

## 7. ملاحظات ومطابقة Flutter ↔ Backend

- **Profile:** الـ app يرسل `PATCH /users/profile` مع `username` (من firstName+lastName), `email`, `phoneNumber`؛ وتغيير كلمة المرور بـ `{ "password": "..." }`. ✅
- **Reels:** الـ app يرسل `POST /reels` (multipart): `title`, `description` (يتجاهلها الباك اند), `projectId?`, `file`, `thumbnail?`. الباك اند: `thumbnail` اختياري؛ `projectId` **مطلوب** في الـ DTO — إن لم يُرسل يَرجع 400.
- **Inventory:** `POST /files/upload/inventory`: الباك اند يتوقع `projectId`, `title`, وملف `inventory`. الـ app يرسل `title` (افتراضي `'Inventory'` إن لزم). ✅
- **Join requests, forgot/verify/reset:** أضف هذه الـ routes في الباك اند عند الحاجة.

---

## 8. Example: Login

```json
POST /auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "MyPass123!"
}
```

---

## 9. Example: Register

```json
POST /auth/register
Content-Type: application/json

{
  "username": "johndoe",
  "email": "john@example.com",
  "phoneNumber": "+966501234567",
  "password": "MyPass123!"
}
```

---

## 10. Example: Join Request

```json
POST /admin/join-requests
Content-Type: application/json
Authorization: Bearer <token>

{
  "companyName": "Acme Corp",
  "headOffice": "Riyadh",
  "projectName": "Tower A",
  "orientationsCount": 5,
  "notes": "Optional notes"
}
```

---

## 11. Example: Update Profile

```json
PATCH /users/profile
Content-Type: application/json
Authorization: Bearer <token>

{
  "username": "John Doe",
  "email": "john@example.com",
  "phoneNumber": "+966501234567"
}
```

---

*Generated from `orientation/lib/services/api/*.dart` and `backend/API_ROUTES_DOCUMENTATION.md`.*
