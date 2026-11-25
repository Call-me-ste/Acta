/// FNV-1a a 64 bit, scritto a mano per non reintrodurre la dipendenza `crypto`.
///
/// Serve a **rilevare corruzione** di uno shard, non a proteggere un segreto:
/// se un byte cambia, il checksum non torna e lo shard viene rifiutato.
library;

/// Offset basis 0xcbf29ce484222325 come intero con segno a 64 bit: il valore
/// senza segno supera 2^63, che in Dart non entra in un letterale `int`.
const int _offsetBasis = -3750763034362895579;

/// Primo FNV a 64 bit: 0x100000001b3.
const int _prime = 0x100000001b3;

/// Hash dei byte, reso come stringa esadecimale senza segno (16 cifre).
///
/// Le due metà si mascherano a 32 bit prima di convertirle: su un `int` a 64 bit
/// `toUnsigned(64)` restituisce il valore **col segno**, e la stringa uscirebbe
/// con un meno davanti (17 cifre) per metà degli hash.
String fnv1a64Hex(List<int> bytes) => _toHex(_append(_offsetBasis, bytes));

Future<String> fnv1a64Stream(Stream<List<int>> input) async {
  var hash = _offsetBasis;
  await for (final chunk in input) {
    hash = _append(hash, chunk);
  }
  return _toHex(hash);
}

int _append(int hash, List<int> bytes) {
  for (final byte in bytes) {
    hash ^= byte;
    // L'aritmetica a 64 bit di Dart avvolge da sola: è esattamente ciò che
    // serve a un hash.
    hash = hash * _prime;
  }
  return hash;
}

String _toHex(int hash) {
  final high = (hash >> 32) & 0xFFFFFFFF;
  final low = hash & 0xFFFFFFFF;
  return high.toRadixString(16).padLeft(8, '0') +
      low.toRadixString(16).padLeft(8, '0');
}
