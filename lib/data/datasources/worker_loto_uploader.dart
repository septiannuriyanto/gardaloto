import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/data/datasources/loto_uploader.dart';
import 'package:gardaloto/core/r2_constants.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerLotoUploader implements LotoUploader {
  final SupabaseClient _supabaseClient;

  WorkerLotoUploader(this._supabaseClient);

  @override
  Future<String> upload({
    required File file,
    required String path,
    required LotoSession session,
    required LotoEntity record,
    required bool isThumbnail,
  }) async {
    final fileBytes = await file.readAsBytes();
    // Encode image to Base64 to send within JSON body as required by worker's req.json()
    final base64Image = base64Encode(fileBytes);

    // Construct metadata based on session and record
    // The worker expects: year, month, day, shift, wh, unitName
    final body = {
      'year': session.dateTime.year.toString().padLeft(4, '0'),
      'month': session.dateTime.month.toString().padLeft(2, '0'),
      'day': session.dateTime.day.toString().padLeft(2, '0'),
      'shift': session.shift.toString(),
      'wh': session.warehouseCode,
      'unitName':
          isThumbnail ? '${record.codeNumber}-thumbnail' : record.codeNumber,
      // Pass the Base64 image data.
      // NOTE: The user needs to update their worker to read this field and save it as file content.
      // If the worker blindly saves `req.body` directly to R2, the file in R2 will be this JSON string.
      'image_data': base64Image,
    };

    final token = _supabaseClient.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No active session. Cannot upload to Worker.');
    }

    final response = await http.post(
      Uri.parse(R2Constants.workerUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'content-type': 'application/json', // Sending JSON
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Worker upload failed: ${response.statusCode} - ${response.body}',
      );
    }

    final jsonResponse = jsonDecode(response.body);
    return jsonResponse['url'] as String;
  }
}
