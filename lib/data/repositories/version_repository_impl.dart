import 'package:flutter/foundation.dart';
import 'package:gardaloto/domain/repositories/version_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VersionRepositoryImpl implements VersionRepository {
  final SupabaseClient supabase;

  VersionRepositoryImpl(this.supabase);

  @override
  Future<Map<String, dynamic>?> getLatestVersion() async {
    try {
      // Query 'loto_sessions' for the latest app_version
      final response =
          await supabase
              .from('loto_sessions')
              .select('app_version')
              .not('app_version', 'is', null) // Filter out nulls
              .order('app_version', ascending: false) // Highest version
              .limit(1)
              .maybeSingle();

      if (response == null) {
        return null; // Silent failure
      }

      // Construct a compatible map
      // Note: loto_sessions doesn't hold 'force_update' or 'store_url' or platform specifics
      // We will just return the version. The Cubit must handle missing keys gracefully.
      return {
        'version': response['app_version'],
        'force_update': false, // Default to false
        'store_url': null, // Default to null
      };
    } catch (e) {
      debugPrint('⚠️ Helper: Failed to fetch app version: $e');
      return null;
    }
  }
}
