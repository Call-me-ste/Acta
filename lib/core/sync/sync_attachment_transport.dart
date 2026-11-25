import 'dart:io';

/// Streaming file transport for immutable, already-encrypted blobs.
abstract interface class SyncAttachmentTransport {
  Future<bool> hasAttachment(String path);
  Future<void> uploadAttachment(String path, File source);
  Future<bool> downloadAttachment(String path, File target);
}
