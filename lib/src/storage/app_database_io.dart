import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openAppDatabase() async {
  final directory = await getApplicationDocumentsDirectory();
  final databasePath = '${directory.path}/volley_ace.db';
  return databaseFactoryIo.openDatabase(databasePath);
}
