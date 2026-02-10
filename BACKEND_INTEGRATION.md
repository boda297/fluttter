# Backend Integration Guide

## الكود متصل بالباك اند فقط — لا يوجد Mock

تم إزالة جميع الـ mock data ووضع التطوير. الطلبات تستخدم **Backend API** فقط وفق `backend/API_ROUTES_DOCUMENTATION.md`.

### 1. تحديث Base URL

في `orientation/lib/services/dio_client.dart`:

```dart
static const String defaultBaseUrl = 'https://your-backend-url.com';

// أمثلة:
// - Android Emulator: http://10.0.2.2:3000
// - iOS Simulator: http://localhost:3000
// - جهاز حقيقي: http://YOUR_COMPUTER_IP:3000
```

أو ديناميكياً:

```dart
AuthApi().setBaseUrl('https://your-backend-url.com');
```

### 2. Endpoints المطابقة للباك اند

- **Auth:** `POST /auth/login`, `POST /auth/register`
- **Profile:** `PATCH /users/profile` (تحديث: username, email, phoneNumber, password)
- **Projects:** `GET /projects`, `GET /projects/trending`, `GET /projects/:id`, `PATCH /projects/:id/save-project`, `PATCH /projects/:id/unsave-project`
- **Episodes:** `GET /episode` (يتم الفلترة حسب projectId في التطبيق)
- **Reels:** `GET /reels`, `POST /reels` (multipart: title, description?, projectId?, file, thumbnail)
- **News:** `GET /news`
- **Files:** `GET /files/get/inventory`, `GET /files/get/pdf`, `POST /files/upload/inventory`

### 3. نهايات قد لا تكون موجودة في الباك اند

- `POST /auth/forgot-password`, `POST /auth/verify-otp`, `POST /auth/reset-password` — أضفها في الباك اند عند الحاجة
- `GET /auth/profile` — إن وُجد يُستخدم؛ وإلا يُستخدم الكاش من SharedPreferences
- `POST /admin/join-requests` و approve/reject — أضفها عند الحاجة

### 4. التوكن والأمان

- التوكن يُحفظ بعد Login/Register ويُرسل في `Authorization: Bearer <token>`
- `DioClient` يضيف التوكن تلقائياً للطلبات المحمية

### 5. ملاحظات

- تأكد من تفعيل CORS في الباك اند
- استخدم `backend/API_ROUTES_DOCUMENTATION.md` كمرجع للـ request/response
