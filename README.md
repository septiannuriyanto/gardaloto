w# Garda LOTO

App to Track Fuelman Activity of Performing LOTO (Lock Out, Tag Out) isolation to mining equipment before conducting refueling activity.

## Features

- **Authentication**:
  - Login with NRP and Password.
  - Forgot Password flow.
  - Role-based access (Admin, Fuelman, Vendor, Guest).
- **User Management**:
  - Add, View, Edit LOTO users.
  - Role assignment and password management.
- **LOTO Capture**:
  - Image capture with watermark overlay.
  - **Watermark Details**: Time, GPS Coordinates, NRP, Unit Code, and Logo.
  - Offline support using Hive for local storage.
- **Dashboards**:
  - **Fuelman Data**: Track achievements and history.
  - **Admin Dashboard**: Overview of system activity.
- **Account Customization**:
  - Dynamic background gradient based on user photo.
  - Profile photo management.
- **Offline Capability**:
  - Hive-based local storage for LOTO records.

## Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **Backend/Database**: Supabase
- **Local Storage**: Hive
- **State Management**: Bloc (Cubit)
- **Routing**: GoRouter
- **Other Key Packages**:
  - `package_info_plus` (Version display)
  - `palette_generator` (Dynamic UI colors)
  - `cached_network_image` (Image optimization)
  - `geolocator` (GPS fetching)

## Getting Started

### Prerequisites

- Flutter SDK (>=3.7.2)
- Supabase Project Credentials

### Installation

1.  Clone the repository.
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the app:
    ```bash
    flutter run
    ```

## Usage

### Watermark Customization
- The watermark is automatically generated upon photo capture.
- It includes the current timestamp, GPS location, user NRP, and Unit Code.
- Uses `image_utils.dart` to composite the overlay.


