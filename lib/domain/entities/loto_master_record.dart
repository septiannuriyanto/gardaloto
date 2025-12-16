class LotoMasterRecord {
  final String fuelman;
  final String operatorName;
  final String warehouseCode;

  LotoMasterRecord({
    required this.fuelman,
    required this.operatorName,
    required this.warehouseCode,
  });

  Map<String, dynamic> toJson() => {
    'fuelman': fuelman,
    'operatorName': operatorName,
    'warehouseCode': warehouseCode,
  };

  static LotoMasterRecord fromJson(Map<String, dynamic> json) =>
      LotoMasterRecord(
        fuelman: (json['fuelman'] ?? '') as String,
        operatorName: (json['operatorName'] ?? '') as String,
        warehouseCode: (json['warehouseCode'] ?? 'FT01') as String,
      );
}
