import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Di browser berkas langsung masuk ke folder unduhan; tidak ada aplikasi pembuka yang dipanggil.
const bool savedFilesOpenInApp = false;

/// Memicu unduhan [bytes] sebagai [fileName] di browser dan mengembalikan nama berkasnya.
Future<String> saveDownloadedFile(Uint8List bytes, String fileName) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return fileName;
}
