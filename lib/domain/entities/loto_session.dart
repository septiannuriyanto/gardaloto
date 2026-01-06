import 'package:gardaloto/core/constants.dart';

class LotoSession {
  final DateTime dateTime; // the chosen date/time in device local
  final int shift; // 1 or 2
  final String fuelman;
  final String operatorName;
  final String warehouseCode;
  final String nomor; // generated YYMMDDAAAA(BBBB) code
  final String? fuelmanPhotoUrl;
  final String? operatorPhotoUrl;
  final String? appVersion;

  LotoSession({
    required this.dateTime,
    required this.shift,
    required this.fuelman,
    required this.operatorName,
    required this.warehouseCode,
    required this.nomor,
    this.fuelmanPhotoUrl,
    this.operatorPhotoUrl,
    this.appVersion,
  });

  Map<String, dynamic> toJson() {
    // Convert True UTC to Face Value (UTC+timezone)
    final faceValue = dateTime.toUtc().add(const Duration(hours: timezone));
    final iso = faceValue.toIso8601String();

    // Replace Z with +0X:00 to strictly indicate timezone
    // We assume timezone is int.
    final offsetString = '+${timezone.toString().padLeft(2, '0')}:00';

    final timestampEx =
        iso.endsWith('Z')
            ? iso.replaceFirst('Z', offsetString)
            : '${iso.split('+')[0]}$offsetString';

    return {
      'created_at': timestampEx,
      'create_shift': shift,
      'fuelman': fuelman,
      'operator': operatorName,
      'warehouse_code': warehouseCode,
      'session_code': nomor,
      'app_version':
          appVersion != null
              ? int.tryParse(appVersion!.replaceAll('.', ''))
              : null,
    };
  }

  factory LotoSession.fromJson(Map<String, dynamic> json) {
    return LotoSession(
      dateTime: DateTime.parse(json['created_at']),
      shift: json['create_shift'],
      fuelman: json['fuelman'],
      operatorName: json['operator'],
      warehouseCode: json['warehouse_code'],
      nomor: json['session_code'],
      fuelmanPhotoUrl: json['fuelman_photo_url'],
      operatorPhotoUrl: json['operator_photo_url'],
      appVersion: json['app_version']?.toString(),
    );
  }
}
