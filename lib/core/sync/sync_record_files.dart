import 'sync_gateway.dart';
import 'sync_record.dart';

abstract interface class SyncRecordFiles {
  Future<SyncRecord> prepare(SyncGateway gateway, SyncRecord record);
  void apply(SyncRecord record);
}
