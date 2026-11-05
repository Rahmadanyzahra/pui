import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Di HP berkas disimpan di folder dokumen aplikasi lalu dibuka dengan aplikasi pembaca PDF.
const bool savedFilesOpenInApp = true;

/// Menyimpan [bytes] sebagai [fileName] dan mengembalikan lokasi berkasnya.
Future<String> saveDownloadedFile(Uint8List bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
