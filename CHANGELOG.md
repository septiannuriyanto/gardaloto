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

- **Fixed Compression Issue**: I realized when examining supabase storage, the image is stored in its original size, so I implemented the compression procedure to cut image size of maximum 150kb. This will enhance the image loading and brings around 95% efficiency to the device storage, loading speed and data usage.

- **Added image size indicator**: I added a debug indicator to show the image size in the review page.

- **Thumbnail image for a better loading speed**: The upload function now server several purposes :

  - Save the original image (which has been compressed before) to the proper place based on the form data
  - Generate thumbnail image for faster loading
  - Save the url path to the "loto_records" table

  This will lead to an even higher efficiency. How about 99.7% efficiency sounds?


  ## [1.2.1] - 2025-12-26

  - **Fixed Photo Save to Cache Issue**: Fixed an issue where saved photos will not be saved to cache anymore, so they will not be deleted when the app is closed or the cache is cleared manually by user. They will be saved to the app folder using path_provider package.

  - **Login Screen UX Improvement** : Added a clear button at the right edge of the User and Password Text input, and added a password visibility toggle. And the inputted NRP and password will not be erased upon a failed login.

  - **Session Input UX Improvement** : Added a logic where the "Operator" Text Input will be replaced with Fuelman value if the selected warehouse is a Fuel Static Storage, not a Fuel Truck.

  - **Re-arranged Route for LOTO Draft** : LOTO Draft route now brought to the front for better accessibility and straightforward user flow : Dashboard -> LOTO Draft Page (Center of activity, a lot of viewing, eliminate 100% of the data usage ) -> LOTO History Page (For occasional viewing, reduce around 90% activities which consume data usage) -> LOTO Review Page (For even less viewing)

  - **Eliminates ghost Draft** : Introduced an isolated LOTO state in cubit to prevent the ghost draft appears in LOTO Draft after viewing the LOTO History page.

  - **Published Shorebird Release** : Release v1.2.1 demands the dev to release the newer apk, since it incorporates new features which involved new packages. So delivering update via patch is not possible. 

  ## [1.3.0] - 2025-12-28

  - **MAJOR IMAGE STORAGE MIGRATION**  : As of now I found out that Supabase meticulously measure our Egress usage, since our app is a image-heavy app, this won't bring us advantage in the long run. So we use cloudflare worker and R2 storage to store our images. It is far more advantageous than Supabase

  - **Lottie Dialog Fixes**  : The fixes in  LotoCubit and LotoPage to handle the upload state, so the Lottie will be hidden when user uploads the report

   - **Hardcoded App Version** : Since I'm prefer shorebird patches whenever possible, I would hardcode the app version string in constants to prevent repeated apk update to user.