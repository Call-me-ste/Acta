import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

({Uint8List photo, Uint8List thumbnail}) prepareAttachmentImage(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoder = image.findDecoderForData(bytes);
  final details = decoder?.startDecode(bytes);
  if (details == null ||
      details.width <= 0 ||
      details.height <= 0 ||
      details.width * details.height > 20000000 ||
      details.numFrames != 1) {
    throw const FormatException('Immagine non supportata o troppo grande');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw const FormatException('Immagine danneggiata');
  final oriented = image.bakeOrientation(decoded);
  image.Image scaled(int limit) {
    // Creare un'immagine dai pixel rimuove EXIF, GPS e commenti d'origine.
    final reduce = oriented.width > limit || oriented.height > limit;
    final resized = !reduce
        ? oriented
        : image.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? limit : null,
            height: oriented.height > oriented.width ? limit : null,
            interpolation: image.Interpolation.average,
          );
    final order =
        resized.hasAlpha ? image.ChannelOrder.rgba : image.ChannelOrder.rgb;
    return image.Image.fromBytes(
      width: resized.width,
      height: resized.height,
      bytes: resized.getBytes(order: order).buffer,
      order: order,
    );
  }

  Uint8List encode(image.Image pixels, int quality) => pixels.hasAlpha
      ? image.encodePng(pixels)
      : image.encodeJpg(pixels, quality: quality);
  return (photo: encode(scaled(2000), 84), thumbnail: encode(scaled(320), 78));
}
