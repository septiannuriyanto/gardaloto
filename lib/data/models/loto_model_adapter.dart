import 'package:hive/hive.dart';
import 'package:gardaloto/data/models/loto_model.dart';

class LotoModelAdapter extends TypeAdapter<LotoModel> {
  @override
  final int typeId = 0;

  @override
  LotoModel read(BinaryReader reader) {
    final codeNumber = reader.readString();
    final photoPath = reader.readString();
    final timestampMillis = reader.readInt();
    final latitude = reader.readDouble();
    final longitude = reader.readDouble();
    final sessionId = reader.readString();

    return LotoModel(
      codeNumber: codeNumber,
      photoPath: photoPath,
      timestampTaken: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
      latitude: latitude,
      longitude: longitude,
      sessionId: sessionId,
    );
  }

  @override
  void write(BinaryWriter writer, LotoModel obj) {
    writer.writeString(obj.codeNumber);
    writer.writeString(obj.photoPath);
    writer.writeInt(obj.timestampTaken.millisecondsSinceEpoch);
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);
    writer.writeString(obj.sessionId);
  }
}
