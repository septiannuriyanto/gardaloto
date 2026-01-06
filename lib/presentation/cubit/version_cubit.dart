import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/repositories/version_repository.dart';

import 'package:gardaloto/presentation/cubit/version_state.dart';
import 'package:gardaloto/core/constants.dart';

class VersionCubit extends Cubit<VersionState> {
  final VersionRepository repo;

  VersionCubit(this.repo) : super(VersionInitial());

  Future<void> checkVersion() async {
    emit(VersionLoading());
    try {
      // final packageInfo = await PackageInfo.fromPlatform();
      // final currentVersion = packageInfo.version;

      final currentVersion = appVersion; // From constants.dart

      final remoteData = await repo.getLatestVersion();

      if (remoteData == null) {
        // No remote data (or error caught in repo), assume latest
        emit(VersionLatest());
        return;
      }

      final String remoteRaw =
          remoteData['version'].toString(); // "142" or "1.4.2"
      final bool forceUpdate = remoteData['force_update'] ?? false;
      final String? storeUrl = remoteData['store_url'];

      final int localVer =
          int.tryParse(currentVersion.replaceAll('.', '')) ??
          0; // "1.4.2" -> 142
      final int remoteVer =
          int.tryParse(remoteRaw.replaceAll('.', '')) ?? 0; // "142" -> 142

      if (remoteVer > localVer) {
        emit(
          VersionOutdated(
            currentVersion: currentVersion,
            latestVersion:
                remoteRaw, // Show remote raw string (e.g. 142? or format it?)
            isForceUpdate: forceUpdate,
            storeUrl: storeUrl,
          ),
        );
      } else {
        emit(VersionLatest());
      }
    } catch (e) {
      emit(VersionError("Failed to check version: $e"));
    }
  }

  // Helper removed as we do direct int comparison now
  // bool _isUpdateAvailable...
}
