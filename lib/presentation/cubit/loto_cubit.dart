import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/domain/repositories/loto_repository.dart';
import 'package:gardaloto/presentation/cubit/loto_state.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/usecases/send_loto_report.dart';
import 'package:gardaloto/core/image_utils.dart';
import 'package:gardaloto/core/time_helper.dart';
import 'package:gardaloto/core/constants.dart';

class LotoCubit extends Cubit<LotoState> {
  final LotoRepository repo;

  LotoSession? _currentSession;
  bool _isReviewMode = false;

  // Internal storage for capture form selected code (not part of state)
  String? _captureSelectedCode;

  LotoCubit(this.repo) : super(LotoInitial());

  // Getters and setters for selected code
  String? get captureSelectedCode => _captureSelectedCode;
  void setCaptureSelectedCode(String? code) {
    _captureSelectedCode = code;
  }

  void clearCaptureSelectedCode() {
    _captureSelectedCode = null;
  }

  Future<void> loadLocalRecords({bool force = false}) async {
    _isReviewMode = false;

    // Skip all state emission if we're in capture mode to prevent state override
    if (!force && state is LotoCapturing) {
      print('🔄 Skipping loadLocalRecords - capture in progress');
      return;
    }

    // Only emit LotoLoading if we're not already in LotoCapturing state
    if (state is! LotoCapturing || force) {
      emit(LotoLoading());
    }

    print('🕒 Starting loadLocalRecords with 10s timeout...');

    try {
      await Future<void>(() async {
        _currentSession = await repo.getActiveSession();
        final records =
            _currentSession != null
                ? await repo.getLocalSessionRecords(_currentSession!.nomor)
                : <LotoEntity>[];

        print('✅ Local records loaded: ${records.length}');

        // Double-check we're not in capture mode before emitting loaded state
        if (state is! LotoCapturing) {
          emit(
            LotoLoaded(
              records,
              session: _currentSession,
              isPendingOperation: false,
            ),
          );
        } else {
          print('🔄 Skipping LotoLoaded emission - capture still in progress');
        }
      }).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      print('⏰ TimeoutException in loadLocalRecords!');
      emit(
        LotoError(
          "Connection Timeout. Please check your internet or try again.",
        ),
      );
    } catch (e) {
      print('❌ Error in loadLocalRecords: $e');
      // If loading fails, try to at least load the session if possible
      if (state is! LotoCapturing) {
        try {
          _currentSession = await repo.getActiveSession();
          emit(
            LotoLoaded([], session: _currentSession, isPendingOperation: false),
          );
        } catch (_) {
          emit(LotoError("Failed to load data: $e"));
        }
      } else {
        print('🔄 Skipping error emission - capture still in progress');
      }
    }
  }

  Future<void> loadActiveSession() async {
    await loadLocalRecords();
  }

  Future<void> loadReviewSession(LotoSession session) async {
    _isReviewMode = true;
    _currentSession = session;

    // Skip all state emission if we're in capture mode
    if (state is LotoCapturing) {
      print('🔄 Skipping loadReviewSession - capture in progress');
      return;
    }

    print('🕒 Starting loadReviewSession with 10s timeout...');
    emit(LotoLoading());

    try {
      await Future<void>(() async {
        print('📡 Fetching remote records...');
        final remoteRecords = await repo.fetchSessionRecords(session.nomor);
        print('✅ Remote records fetched: ${remoteRecords.length}');

        final localRecords = await repo.getLocalSessionRecords(session.nomor);

        final allRecords = [...remoteRecords, ...localRecords];
        // Sort by timestamp
        allRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        emit(
          LotoLoaded(allRecords, session: session, isPendingOperation: false),
        );
      }).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      print('⏰ TimeoutException caught in Cubit!');
      emit(
        LotoError(
          "Connection Timeout. Please check your internet or try again.",
        ),
      );
    } catch (e) {
      print('❌ Error caught in loadReviewSession: $e');
      emit(LotoError("Error: $e"));
    }
  }

  Future<void> startCapture({
    required String photoPath,
    double lat = 0,
    double lng = 0,
  }) async {
    print('📸 startCapture called with photoPath: $photoPath');
    print('📍 Location: $lat, $lng');
    print('🔄 Current state before capture: ${state.runtimeType}');

    // Clear selected code for new capture
    clearCaptureSelectedCode();

    // Preserve current session and records from any state
    LotoSession? currentSession;
    List<LotoEntity> currentRecords = [];

    if (state is LotoLoaded) {
      final loadedState = state as LotoLoaded;
      currentSession = loadedState.session;
      currentRecords = loadedState.records;
      print(
        '📄 Preserved from LotoLoaded: session=${currentSession?.nomor}, records=${currentRecords.length}',
      );
    } else if (state is LotoCapturing) {
      final capturingState = state as LotoCapturing;
      currentSession = capturingState.session;
      currentRecords = capturingState.records;
      print(
        '📄 Preserved from LotoCapturing: session=${currentSession?.nomor}, records=${currentRecords.length}',
      );
    } else if (state is LotoUploading) {
      final uploadingState = state as LotoUploading;
      currentSession = uploadingState.session;
      currentRecords = uploadingState.records;
      print(
        '📄 Preserved from LotoUploading: session=${currentSession?.nomor}, records=${currentRecords.length}',
      );
    } else if (state is LotoUploadSuccess) {
      final successState = state as LotoUploadSuccess;
      currentSession = successState.session;
      currentRecords = successState.records;
      print(
        '📄 Preserved from LotoUploadSuccess: session=${currentSession?.nomor}, records=${currentRecords.length}',
      );
    } else if (state is LotoUploadError) {
      final errorState = state as LotoUploadError;
      currentSession = errorState.session;
      currentRecords = errorState.records;
      print(
        '📄 Preserved from LotoUploadError: session=${currentSession?.nomor}, records=${currentRecords.length}',
      );
    } else {
      print('📄 No state context preserved (${state.runtimeType})');
    }

    final newState = LotoCapturing(
      photoPath: photoPath,
      lat: lat,
      lng: lng,
      timestamp: TimeHelper.now(),
      session: currentSession,
      records: currentRecords,
      isLocationLoading: lat == 0 && lng == 0, // Assume loading if 0,0
      hasAttemptedGpsFetch: false, // Reset on new capture
    );

    print('🎯 Emitting LotoCapturing state...');
    emit(newState);
    print('✅ LotoCapturing state emitted successfully');
  }

  void updateLocation(double lat, double lng) {
    print('📍 updateLocation: $lat,$lng');
    if (state is LotoCapturing) {
      final currentState = state as LotoCapturing;
      emit(
        LotoCapturing(
          photoPath: currentState.photoPath,
          lat: lat,
          lng: lng,
          timestamp: currentState.timestamp,
          session: currentState.session,
          records: currentState.records,
          isLocationLoading: false,
          locationError: null,
          hasAttemptedGpsFetch: true,
        ),
      );
    }
  }

  void updateLocationStatus({bool isLoading = false, String? error}) {
    if (state is LotoCapturing) {
      final currentState = state as LotoCapturing;
      emit(
        LotoCapturing(
          photoPath: currentState.photoPath,
          lat: currentState.lat,
          lng: currentState.lng,
          timestamp: currentState.timestamp,
          session: currentState.session,
          records: currentState.records,
          isLocationLoading: isLoading,
          locationError: error,
          hasAttemptedGpsFetch:
              isLoading ? true : currentState.hasAttemptedGpsFetch,
        ),
      );
    }
  }

  void cancelCapture() {
    print('↩️ cancelCapture called');
    if (state is LotoCapturing) {
      final currentState = state as LotoCapturing;

      // Clean up the temp/persistent file since we are cancelling
      final file = File(currentState.photoPath);
      file.exists().then((exists) {
        if (exists) {
          file
              .delete()
              .then(
                (_) => print(
                  '🗑️ Cancelled capture: Deleted ${currentState.photoPath}',
                ),
              )
              .catchError(
                (e) => print('⚠️ Failed to delete file on cancel: $e'),
              );
        }
      });

      // Restore previous session and records
      emit(
        LotoLoaded(
          currentState.records,
          session: currentState.session,
          isPendingOperation: false,
        ),
      );
      print('✅ State restored to LotoLoaded');
    }
  }

  // Track records currently being processed (background watermarking)
  final Set<String> _processingIds = {};

  bool isProcessing(String timestampId) {
    return _processingIds.contains(timestampId);
  }

  Future<void> submit(
    LotoEntity entity, {
    required String nrp,
    required String gps,
    required DateTime timestamp,
  }) async {
    // Show loading state first? No, we want instant feedback.
    // Actually, we might be in Capture state.

    try {
      print('🚀 Fast Submit: Saving raw data for ${entity.codeNumber}');

      // 1. Save data with RAW photo path immediately
      // Validate file existence
      final file = File(entity.photoPath);
      if (!file.existsSync()) {
        throw Exception('Photo file not found: ${entity.photoPath}');
      }

      await repo.saveLocal(entity);

      // Ensure we have session
      if (_currentSession == null && entity.sessionId.isNotEmpty) {
        _currentSession = await repo.getActiveSession();
      }

      print('✅ Raw data saved. Triggering background processing...');

      // 2. Mark as processing
      final id = entity.timestamp.toIso8601String();
      _processingIds.add(id);

      // 3. Emit Loaded state immediately so UI pops and shows list (with raw/skeleton)
      // We need to reload the list to include the new item
      final newState = await _reload();
      emit(newState);

      // 4. Start background processing (Fire-and-Forget)
      // We don't await this here, allowing the UI to proceed
      _processImageInBackground(entity, nrp, gps, timestamp);
    } catch (e) {
      print("❌ Submit failed: $e");
      emit(LotoError("Failed to save record: $e"));
    }
  }

  Future<void> _processImageInBackground(
    LotoEntity rawEntity,
    String nrp,
    String gps,
    DateTime timestamp,
  ) async {
    final id = rawEntity.timestamp.toIso8601String();
    print('⚙️ Background: Processing image for $id ...');

    try {
      // 1. Resize & Watermark
      // We import image_utils.dart to use addWatermarkToImage
      // Note: We need to import 'package:gardaloto/core/image_utils.dart';
      final finalPath = await addWatermarkToImage(
        inputPath: rawEntity.photoPath,
        unitCode: rawEntity.codeNumber,
        nrp: nrp,
        gps: gps,
        timestamp: timestamp,
        targetWidth: 1280, // Resize to 1280px width
      );

      print('✅ Background: Watermark added: $finalPath');

      // 2. Update DB with new path
      final updatedEntity = LotoEntity(
        codeNumber: rawEntity.codeNumber,
        photoPath: finalPath, // Updated path
        timestamp: rawEntity.timestamp,
        latitude: rawEntity.latitude,
        longitude: rawEntity.longitude,
        sessionId: rawEntity.sessionId,
        appVersion: rawEntity.appVersion ?? appVersion,
      );

      // We can use saveLocal again, it should overwrite based on timestamp/primary key?
      // Repository `saveLocal` usually effectively upserts or we might need `updateLocal`.
      // Assuming `saveLocal` handles updates if key matches (timestamp usually key for local SQLite/Hive).
      // Checking `saveLocal` implementation would be good, but assuming upsert for now.
      await repo.saveLocal(updatedEntity);

      print('✅ Background: DB updated with watermarked image.');

      // 3. Cleanup Raw File
      // Since we have a new compressed file, delete the large raw one
      // Make sure we are not deleting the same file (in case overwrite happened, though suffix prevents it)
      if (rawEntity.photoPath != finalPath) {
        final rawFile = File(rawEntity.photoPath);
        if (await rawFile.exists()) {
          await rawFile.delete();
          print(
            '🗑️ Background: Deleted raw original file: ${rawEntity.photoPath}',
          );
        }
      }

      // 4. Cleanup Id
      _processingIds.remove(id);

      // 4. Emit updated state (thumbnail will change from Skeleton to Image)
      // Only emit if the current state allows (e.g. we are still in Loaded state viewing the list)
      if (state is LotoLoaded) {
        final newState = await _reload();
        emit(newState);
      }
    } catch (e) {
      print('❌ Background Processing Failed: $e');
      _processingIds.remove(id);
      // We don't necessarily emit error to UI as the user might be doing something else.
      // The Raw image is still preserved in DB, so it's not a total loss.
      // Maybe we can flag it as "failed" in future.
      if (state is LotoLoaded) {
        emit(await _reload()); // Refresh just to remove skeleton state
      }
    }
  }

  Future<void> delete(LotoEntity entity) async {
    // Optimistically remove the record from the currently displayed state
    if (state is LotoLoaded) {
      final current = (state as LotoLoaded).records;
      final updated =
          current.where((r) => r.timestamp != entity.timestamp).toList();
      // preserve session if present
      final session = (state as LotoLoaded).session;
      // Mark as pending so UI can avoid showing the empty dialog prematurely
      emit(LotoLoaded(updated, session: session, isPendingOperation: true));
    } else {
      emit(LotoLoading());
    }

    try {
      await repo.deleteLocal(entity);
      // Reload from repository to ensure consistency
      emit(await _reload());
    } catch (e) {
      print("Delete failed: $e");
      // Revert to authoritative data on error (or keep optimistic if reload fails?)
      // If reload fails, we should probably revert to the previous state (which we don't have easily unless we stored it)
      // Or we can just try to reload again or emit error.

      // If _reload threw, we are here.
      // We should try to restore the previous state if possible, or just emit error.
      // Since we don't have previous state easily accessible here (unless we copy it),
      // let's just emit an error state but try to keep the data visible?

      // Actually, if _reload fails, we don't know the true state.
      // But we shouldn't show empty list.

      // Let's emit LotoError for now so user knows something went wrong.
      emit(LotoError("Failed to delete/reload: $e"));

      // Or better, try to reload again safely?
      // No, if it failed once, it might fail again.
    }
  }

  Future<LotoState> _reload() async {
    try {
      return await Future<LotoState>(() async {
        if (_isReviewMode && _currentSession != null) {
          // Use cache if available/appropriate or fetch again
          // For consistency with timeout, we fetch again or careful with cache
          // Let's re-fetch to ensure sync, or use cache?
          // Previous logic used cache. Let's stick to safe logic but wrapped in timeout.

          final remoteRecords = await repo.fetchSessionRecords(
            _currentSession!.nomor,
          );

          final localRecords = await repo.getLocalSessionRecords(
            _currentSession!.nomor,
          );
          final allRecords = [...remoteRecords, ...localRecords];
          allRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          return LotoLoaded(
            allRecords,
            session: _currentSession,
            isPendingOperation: false,
          );
        } else {
          final session = await repo.getActiveSession();
          _currentSession = session;
          final records =
              session != null
                  ? await repo.getLocalSessionRecords(session.nomor)
                  : <LotoEntity>[];
          return LotoLoaded(
            records,
            session: session,
            isPendingOperation: false,
          );
        }
      }).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      return LotoError(
        "Connection Timeout. Please check your internet or try again.",
      );
    } catch (e) {
      print("Error in _reload: $e");
      // Return empty list/error state representation?
      // Since return type is LotoState, we can return LotoError.
      // But _reload is used to silently update often.
      // However, if it times out, we should probably know.
      return LotoError(e.toString());
    }
  }

  /// Set session/header information (e.g., when the list is empty and the user
  /// fills in the initial details). This is kept in memory as part of the
  /// displayed state so the UI can show/consume it.
  Future<void> setSession(LotoSession session) async {
    await repo.saveActiveSession(session);
    _currentSession = session;

    if (state is LotoLoaded) {
      final current = (state as LotoLoaded).records;
      final pending = (state as LotoLoaded).isPendingOperation;
      emit(LotoLoaded(current, session: session, isPendingOperation: pending));
    } else {
      // If we're not in LotoLoaded, reload and attach the session
      final loadedState = await _reload();

      if (loadedState is LotoLoaded) {
        emit(
          LotoLoaded(
            loadedState.records,
            session: session,
            isPendingOperation: loadedState.isPendingOperation,
          ),
        );
      } else {
        // If _reload returns an error or initial state, we might want to emit that instead
        emit(loadedState);
      }
    }
  }

  Future<void> clearSession() async {
    if (_currentSession != null) {
      await repo.deleteLocalSessionRecords(_currentSession!.nomor);
    }
    await repo.clearActiveSession();
    _currentSession = null;
    emit(LotoLoaded([], session: null, isPendingOperation: false));
  }

  Future<void> uploadData() async {
    if (state is! LotoLoaded) return;

    final currentState = state as LotoLoaded;
    final session = currentState.session;
    final records = currentState.records;

    if (session == null || records.isEmpty) {
      emit(LotoError('No data to upload'));
      return;
    }

    // Emit uploading state
    emit(
      LotoUploading(
        uploadedCount: 0,
        totalCount: records.length,
        session: session,
        records: records,
      ),
    );

    try {
      final sendLotoReport = SendLotoReport(repo);
      final result = await sendLotoReport.call(
        session,
        records,
        onProgress: (count, total) {
          emit(
            LotoUploading(
              uploadedCount: count,
              totalCount: total,
              session: session,
              records: records,
            ),
          );
        },
      );

      if (result.isSuccess) {
        // Clear local data after successful upload
        await clearSession();
        emit(LotoUploadSuccess(result.message));
      } else {
        emit(
          LotoUploadError(result.message, session: session, records: records),
        );
      }
    } catch (e) {
      emit(
        LotoUploadError(
          'Upload failed: $e',
          session: session,
          records: records,
        ),
      );
    } finally {
      // Reload local data to get back to normal state
      await loadLocalRecords();
    }
  }

  Future<void> uploadPendingRecords() async {
    if (state is! LotoLoaded) return;

    final currentState = state as LotoLoaded;
    final session = currentState.session;
    final allRecords = currentState.records;

    if (session == null) return;

    // Filter for pending records (local paths)
    final pendingRecords =
        allRecords.where((r) => !r.photoPath.startsWith('http')).toList();

    if (pendingRecords.isEmpty) {
      emit(LotoError('No pending records to upload'));
      return;
    }

    // Emit uploading state
    emit(
      LotoUploading(
        uploadedCount: 0,
        totalCount: pendingRecords.length,
        session: session,
        records: allRecords,
      ),
    );

    try {
      await repo.appendSessionRecords(
        session,
        pendingRecords,
        onProgress: (count, total) {
          emit(
            LotoUploading(
              uploadedCount: count,
              totalCount: total,
              session: session,
              records: allRecords,
            ),
          );
        },
      );

      // Delete local records after successful upload
      await repo.deleteLocalSessionRecords(session.nomor);

      emit(LotoUploadSuccess('Upload successful'));

      // Reload session to refresh data
      if (_isReviewMode) {
        await loadReviewSession(session);
      } else {
        await loadLocalRecords();
      }
      // But if we emit LotoUploadSuccess, we need to make sure it has the UPDATED records.
      // However, loadReviewSession is async and emits LotoLoaded.
      // So the sequence is: Uploading -> LotoLoaded (from reload).
      // The UI listener can listen for LotoLoaded and if it was previously uploading, show success?
      // Or we can just show success message from the UI side when the future completes?
      // But the user wants "UI diupdate dengan responsive saat success... badge pending berubah menjadi uploaded".
      // Reloading will fetch the new data (where records are now remote), so badges will turn green.

      // The issue is the "blank" page.
      // By passing data to LotoUploading, the UI can still render.

      // Let's emit LotoUploadSuccess briefly or just let the reload handle it?
      // If I emit LotoUploadSuccess, I need the NEW records.
      // But I just called loadReviewSession which emits LotoLoaded.
      // So LotoUploadSuccess might be overwritten immediately or overwrite LotoLoaded.

      // Actually, I should probably NOT emit LotoUploadSuccess here if I'm reloading.
      // OR, I can emit LotoUploadSuccess with the OLD records (but marked as uploaded?)
      // No, reloading is safer.

      // Wait, the previous code emitted LotoUploadSuccess.
      // emit(LotoUploadSuccess('Records appended successfully'));

      // If I keep this, I should pass the session/records.
      // But these records are the OLD ones (still local).
      // So the badges won't update until reload.

      // Strategy:
      // 1. Upload.
      // 2. Delete local.
      // 3. Reload (emits LotoLoaded with new data).
      // 4. Show success message (via listener checking for transition or just a separate event).

      // If I remove LotoUploadSuccess emission, how does the UI know to show "Success"?
      // I can return a bool or use a specific "Action" stream, but Cubit uses State.

      // Let's keep LotoUploadSuccess but make sure we have the updated data.
      // But I can't get updated data without reloading.

      // Let's just rely on LotoLoaded.
      // But the UI needs to close the dialog.
      // If state goes LotoUploading -> LotoLoaded, the listener can close the dialog.

      // Let's modify the code to:
      // 1. Uploading (with data)
      // 2. Reload (LotoLoaded)
      // 3. Emit a "Success" side effect? No.

      // Let's stick to:
      // Uploading -> Reload (LotoLoaded).
      // The UI listener can close dialog when state is LotoLoaded.
      // But how to show snackbar?

      // Maybe I can emit LotoUploadSuccess *before* reload? No, then data is stale.
      // After reload? LotoLoaded is final.

      // Let's use a simple approach:
      // The `uploadPendingRecords` method is Future<void>.
      // The UI can await it? No, UI calls it via `context.read`.

      // I will emit LotoUploadSuccess *instead* of reloading manually,
      // BUT I will fetch the data first and put it in LotoUploadSuccess.

      // Refactored flow:
      // 1. Upload.
      // 2. Delete local.
      // 3. Fetch new records (without emitting LotoLoaded yet).
      // 4. Emit LotoUploadSuccess(message, session, newRecords).
      // 5. (Optional) Emit LotoLoaded(newRecords).

      final remoteRecords = await repo.fetchSessionRecords(session.nomor);

      final localRecords = await repo.getLocalSessionRecords(
        session.nomor,
      ); // Should be empty of the uploaded ones
      final newAllRecords = [...remoteRecords, ...localRecords];
      newAllRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      emit(
        LotoUploadSuccess(
          'Records appended successfully',
          session: session,
          records: newAllRecords,
        ),
      );

      // Then emit LotoLoaded to settle state
      emit(
        LotoLoaded(newAllRecords, session: session, isPendingOperation: false),
      );
    } catch (e) {
      emit(
        LotoUploadError(
          'Upload failed: $e',
          session: session,
          records: allRecords,
        ),
      );
      // Reload to restore state
      if (_isReviewMode) {
        await loadReviewSession(session);
      } else {
        await loadLocalRecords();
      }
    }
  }
}
