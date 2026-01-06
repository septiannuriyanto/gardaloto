# Changelog

All notable changes to this project will be documented in this file.
## [1.4.3] - 2026-01-07

### Fixed
- **CRITICAL / Upload Stability**: Solved "Connection Abort" errors by compressing images (Max 1024px, 80% Quality) and increasing upload timeout to 60s.
- **CRITICAL / Data Integrity**: Fixed schema mismatch where `app_version` was incorrectly sent to `loto_records`.
- **CRITICAL / Crash Fix**: Resolved `type 'int' is not a subtype of type 'String'` crash in session parsing.
- **Date Logic**: Smart date display in Session Dialog (shows "Yesterday" for Shift 2 < 06:00) while preserving correct Session Code generation.
- **UI Cleaning**: Hidden time display in Draft Page; refined Version Banner on Dashboard.


## [1.3.2] - 2025-12-29

### Fixed
- **Timezone Enforcement**: Enforced `Asia/Makassar` (UTC+8) for all time-related operations (Dashboard Refresh, Session Creation, File Timestamps) to ensure consistency regardless of device timezone.
- **Session Logic**: Fixed Shift 2 session date calculation logic for sessions created between 00:00 - 06:00 WITA.

## [1.3.1] - 2025-12-29

### Added
- **About Page**: New page with "About", "Contact", and "Changelog" tabs.
  - **Changelog**: Features a manual markdown renderer to display updates without native dependencies (Patch Safe).
  - **Contact**: Improved UI with developer profiles (Scalar Coding, Septian N.) and inquiry email.
- **Robust Upload Logic**: Implemented "DB-First" check for uploads.
  - Checks if session/records exist in Supabase before uploading images.
  - Skips redundant uploads (Bandwidth efficiency).
  - Uses `Upsert` and `Atomic Replace` for session/records to prevent duplicate key errors.

### Changed
- **Sidebar**: Added "About" button below Account.
- **App Version**: Bumping to 1.3.1.

## [1.3.0] - 2025-12-28

### Changed
- **MAJOR IMAGE STORAGE MIGRATION**: Migrated from Supabase Storage to Cloudflare Worker + R2 Storage.
  - **Reason**: Supabase Egress costs were too high for an image-heavy app. R2 offers zero egress fees.
- **App Version Strategy**: Hardcoded app version string in `constants.dart` to facilitate frequent Shorebird patches without requiring users to download new APKs for version bumps.

### Fixed
- **Lottie Dialog**: Fixed `LotoCubit` and `LotoPage` to properly hide the Lottie animation dialog when the user initiates an upload.

## [1.2.1] - 2025-12-26

### Added
- **Shorebird Integration**: Published initial Shorebird release to enable future over-the-air patches.

### Changed
- **Login Screen UX**:
  - Added "Clear" button to text inputs.
  - Added Password Visibility toggle.
  - Persist NRP/Password text on failed login attempts.
- **Session Input Logic**: "Operator" field is now auto-filled with "Fuelman" value if the selected warehouse is a Fuel Static Storage (not a Fuel Truck).
- **Navigation Flow**: Re-arranged route priority for better UX:
  1. **Dashboard**
  2. **LOTO Draft** (Center of activity, local data only).
  3. **LOTO History** (Occasional viewing).
  4. **LOTO Review** (Rare viewing).

### Fixed
- **Photo Persistence**: Fixed issue where photos were deleted when app closed. Now using `path_provider` to save to the Application Document Directory.
- **Ghost Drafts**: Introduced isolated LOTO state in Cubit to prevent "ghost" drafts from appearing in the Draft page after viewing History.

## [1.1.0] - 2025-12-21

### Added
- **Image Size Indicator**: Debug indicator in Review Page to monitor compression results.

### Changed
- **Upload Workflow**:
  - Save compressed original image.
  - Generate and upload optimized thumbnail.
  - Save URL paths to `loto_records`.
  - **Efficiency**: Targeted 99.7% storage/bandwidth efficiency.

### Fixed
- **Image Compression**: Fixed Supabase storage usage by implementing client-side compression (Max 150KB) before upload to save storage and data usage.

## [1.0.1] - 2025-12-19

### Fixed
- **Storage Duplicate Error (409)**: Resolved issue where partial/failed uploads caused duplicate file errors on retry.

## [1.0.0] - 2025-12-19

### Added
- **Dynamic Backgrounds**: Account page generates gradients based on profile photo.
- **Version Display**: App version on Login and Account screens.
- **Logo Overlay**: Watermarked images with corporate logo.
- **Frosty Glass UI**: Glassmorphism effect on "Add New NRP".

### Changed
- **Watermark Sizing**: Dynamic scaling for overlay text.
- **Default Status**: New users set to `inactive`.
- **User Sorting**: Sorted by ID.

### Fixed
- **Loading Hang**: Fixed endless loading on duplicate NRP add.
- **Overlay Bug**: Fixed missing logo in generated images.
- **Navigation**: Corrected nested routing paths.

### --------- GO LIVE BETA ---------