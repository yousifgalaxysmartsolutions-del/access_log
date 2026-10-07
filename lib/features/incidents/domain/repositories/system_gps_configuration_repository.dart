import '../../../../core/network/result.dart';
import '../../data/models/system_gps_configuration.dart';

abstract interface class SystemGpsConfigurationRepository {
  Future<Result<SystemGpsConfiguration>> load();
}
