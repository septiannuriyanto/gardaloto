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

    // We will use a boolean flag for nullable string manually
    final hasThumbnail = reader.readBool();
    final thumbnailUrl = hasThumbnail ? reader.readString() : null;

    final hasVersion = reader.readBool();
    final appVersion = hasVersion ? reader.readString() : null;

    return LotoModel(
      codeNumber: codeNumber,
      photoPath: photoPath,
      timestampTaken: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
      latitude: latitude,
      longitude: longitude,
      sessionId: sessionId,
      thumbnailUrl: thumbnailUrl,
      appVersion: appVersion,
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

    if (obj.thumbnailUrl != null) {
      writer.writeBool(true);
      writer.writeString(obj.thumbnailUrl!);
    } else {
      writer.writeBool(false);
    }

    if (obj.appVersion != null) {
      writer.writeBool(true);
      writer.writeString(obj.appVersion!);
    } else {
      writer.writeBool(false);
    }
  }
}
