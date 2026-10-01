import '../../../../core/network/result.dart';
import '../../../../mock/mock_data.dart';
import '../../../../models/models.dart';
import '../../domain/repositories/incident_repository.dart';

/// Prototype "today" incidents, used while the app runs in mock-auth mode.
class DemoIncidentRepository implements IncidentRepository {
  @override
  Future<Result<List<CapIncident>>> getIncidentsForDay({
    required DateTime day,
  }) async => Success(prototypeDay);

  /// Fixed prototype day, kept independent of the wall clock so the demo and the
  /// existing widget tests stay stable.
  static List<CapIncident> get prototypeDay => MockData.capIncidents
      .where((item) => item.dateTime.day == _prototypeDay)
      .where((item) => item.dateTime.month == _prototypeMonth)
      .toList();

  static int get prototypeDayCount => prototypeDay.length;

  static const int _prototypeDay = 10;
  static const int _prototypeMonth = 8;
}
