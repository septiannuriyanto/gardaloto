class LotoSession {
  final DateTime dateTime; // the chosen date/time in device local
  final int shift; // 1 or 2
  final String fuelman;
  final String operatorName;
  final String warehouseCode;
  final String nomor; // generated YYMMDDAAAA(BBBB) code

  LotoSession({
    required this.dateTime,
    required this.shift,
    required this.fuelman,
    required this.operatorName,
    required this.warehouseCode,
    required this.nomor,
  });

  Map<String, dynamic> toJson() {
    return {
      'created_at': dateTime.toIso8601String(),
      'create_shift': shift,
      'fuelman': fuelman,
      'operator': operatorName,
      'warehouse_code': warehouseCode,
      'session_code': nomor,
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
    );
  }
}
