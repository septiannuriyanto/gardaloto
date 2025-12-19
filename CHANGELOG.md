# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-12-19

### Added
- **Dynamic Backgrounds**: Account page now generates a harmonious gradient background based on the user's profile photo.
- **Version Display**: App version is now displayed on the Login Screen and Account Page.
- **Logo Overlay**: Watermarked images now include the corporate logo in the top-right corner.
- **Frosty Glass UI**: Enhanced "Add New NRP" dialog with a glassmorphism effect.

### Changed
- **Watermark Font Sizing**: Overlay text now scales based on image width for consistent readability across all resolutions.
- **Default Status**: Newly created users are now set to `inactive` by default.
- **User Sorting**: User lists are now sorted by ID instead of incumbent status.

### Fixed
- **Loading State**: Fixed an issue where the app would hang (endless loading) if a duplicate NRP was added.
- **Overlay Bug**: Resolved missing logo in generated overlay images.
- **Navigation**: Corrected routing paths for nested user management pages.


### --------- GO LIVE BETA ---------


## [1.0.1] - 2025-12-19

- **Fixed Storage Duplicate Issue**: Fixed an issue where the app would show error 409 (duplicate) when there was a partial upload, usually when uploading when in lack of connectivity.