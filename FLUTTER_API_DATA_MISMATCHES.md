# Flutter ↔ API: Data Alignment (Aligned)

Flutter models and APIs are aligned with the backend. `fromJson` uses **only**:

- Fields that exist in the backend payload
- Values derived from backend fields (e.g. `category` from `status`, `hasVideo` from `heroVideoUrl`, `developerName`/`developerLogo` from populated `developerId`)
- **Fixed defaults** for fields the UI needs but the API does not provide (e.g. `subtitle: ''`, `gradientColors: [...]`, `likes: 0`, `isReminded: false`)

Nothing is read from `json['...']` for keys that do not exist in the backend.

---

## 1. Project (ProjectModel)

| Flutter field | Source | Notes |
|---------------|--------|--------|
| `id`, `title`, `location`, `script`, `whatsappNumber`, `createdAt` | API | |
| `image` | API | `json['image']` or `heroVideoUrl` |
| `area` | API | `json['area']` or `json['location']` |
| `locationUrl` | API | `json['locationUrl']` or `json['mapsLocation']` |
| `developer`, `developerId` | API | From `developer` (ObjectId or populated) |
| `status` | API | Used to derive `category`, `isUpcoming` |
| `heroVideoUrl` / `advertisementVideoUrl` | API | Used for `advertisementVideoUrl`, `hasVideo` |
| `logo` | API | `json['logo']` or `json['logoUrl']` when present |
| `subtitle`, `label`, `gradientColors`, `description`, `rank`, `isFeatured`, `isSaved`, `tags` | **Default** | `''`, `null`, `const [...]`, `0`, `false`, `[]` — not in API |
| `inventoryUrl` | **Default `''`** | URL comes from `GET /files/get/inventory`; project_details uses `getInventoryUrl(projectId)` |
| `category`, `isUpcoming`, `hasVideo` | **Derived** | From `status` and `heroVideoUrl` |

---

## 2. Episode (EpisodeModel)

| Flutter field | Source | Notes |
|---------------|--------|--------|
| `id`, `projectId`, `title`, `thumbnail`, `videoUrl`/`episodeUrl`, `duration`, `createdAt` | API | |
| `episodeNumber` | API / Derived | From `episodeOrder` or `episodeNumber` |
| `description` | **Default `''`** | Not in API |

---

## 3. Reel / Clip (ClipModel)

| Flutter field | Source | Notes |
|---------------|--------|--------|
| `id`, `projectId`, `title`, `videoUrl`, `thumbnail`, `createdAt` | API | |
| `developerName`, `developerLogo` | **Derived** | From populated `developerId` (`name`, `logoUrl`) |
| `description`, `likes`, `isLiked`, `hasWhatsApp` | **Default** | `''`, `0`, `false`, `true` — not in API |

---

## 4. News (NewsModel)

| Flutter field | Source | Notes |
|---------------|--------|--------|
| `id`, `projectId`, `title`, `thumbnail`/`image`, `createdAt`/`date` | API | |
| `projectName` | **Derived** | From `projectId.title` when `projectId` is populated |
| `projectSubtitle` | API | `json['developer']` (string) |
| `subtitle`, `description`, `gradientColors`, `isReminded` | **Default** | `''`, `const [...]`, `false` — not in API |

---

## 5. PDF / File (PdfFileModel)

| Flutter field | Source | Notes |
|---------------|--------|--------|
| `id`, `title`, `pdfUrl`, `project`, `createdAt`, `updatedAt` | API | `project` → `projectId`; `pdfUrl` → `fileUrl` |
| `fileName` | **Derived** | From `title` or last segment of `s3Key` |
| `description`, `fileSize` | **Default** | `null`, `0` — not in API |

**Response:** `GET /files/get/pdf` returns `{ message, pdfs }`. Flutter uses `data['pdfs']`.

---

## 6. Inventory (getInventoryUrl)

| Item | Source | Notes |
|------|--------|--------|
| List | `data['inventories']` | Not `data` as array |
| `projectId` | `project` or `project._id` | Resolved via `_resolveId(m['project'])` |
| URL | `inventoryUrl` | Not `fileUrl` |

---

## 7. Developer (DeveloperModel)

| Flutter field | Source | Notes |
|---------------|--------|--------|
| `id`, `name`, `projects` (for count) | API | |
| `projectsCount` | API / Derived | `projects.length` when populated, or `projectsCount` |
| `logo` | API | `json['logo']` or `json['logoUrl']` when present (else `''`) |
| `description`, `areas` | **Default** | `''`, `[]` — not in API |

---

## 8. Area (AreaModel)

No `/areas` in backend. `getAreas()` returns `[]`. `fromJson` only runs if the API adds an areas endpoint; it reads `name`, `image`, `projectsCount`, `country`, `createdAt`.

---

## 9. Auth / User

- `GET /auth/profile`: not in backend; Flutter uses cache (SharedPreferences) when the API is absent.
- `forgot-password`, `verify-otp`, `reset-password`: not in backend; Flutter calls them when implemented.

---

## Summary of fromJson / API Behavior

1. **getInventoryUrl:** uses `data['inventories']`; resolves `project`/`project._id` for `projectId`; uses `inventoryUrl` (fallback `fileUrl`). project_details uses `getInventoryUrl(projectId)` for the Open-inventory action.
2. **getPdfFiles:** uses `data['pdfs']`; `PdfFileModel.fromJson` supports `pdfUrl`, `project`→`projectId`, `fileName` from `title` or `s3Key`; `description` and `fileSize` default to `null` and `0`.
3. **ProjectModel.fromJson:** `locationUrl` from `json['mapsLocation']` when `locationUrl` is absent; non-API fields use defaults.
4. **ClipModel.fromJson:** `developerName` and `developerLogo` from populated `developerId`; `description`, `likes`, `isLiked`, `hasWhatsApp` use defaults.
