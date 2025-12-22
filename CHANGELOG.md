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


## [1.1.0] - 2025-12-21

- **Fixed Compression Issue**: I realized when examining supabase storage, the image is stored in its original size, so I implemented the compression procedure to cut image size of maximum 150kb. This will enhance the image loading without compromising the quality.
- **Added image size indicator**: I added a debug indicator to show the image size in the review page.

- **Thumbnail image for a better loading speed**: The upload function now server several purposes :

  - Save the original image (which has been compressed before) to the proper place based on the form data
  - Generate thumbnail image for faster loading
  - Save the url path to the "loto_records" table
