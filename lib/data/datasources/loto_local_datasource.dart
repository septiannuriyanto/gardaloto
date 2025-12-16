import 'package:gardaloto/data/models/loto_model.dart';

abstract class LotoLocalDatasource {
  Future<List<LotoModel>> getAll();
  Future<void> insert(LotoModel model);
}
