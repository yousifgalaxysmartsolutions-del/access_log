import 'dart:async';
import '../../../core/network/result.dart';
import '../../../core/session/session_manager.dart';
import '../domain/usecases/get_incident_lookup_use_case.dart';
import 'models/incident_lookup_models.dart';

/// Session-only snapshot. Each refresh calls the backend, even with warm cache.
class IncidentLookupStore {
  IncidentLookupStore(this._load, this._session) {
    _generation = _session.generation;
    _subscription = _session.changes.listen((_) {
      _checkSession();
      if (!_session.isAuthenticated) clear();
    });
  }
  final GetIncidentLookupUseCase _load;
  final SessionManager _session;
  late final StreamSubscription<SessionStatus> _subscription;
  late int _generation;
  int _revision = 0, _nextRequest = 0, _acceptedRequest = 0;
  bool _disposed = false;
  IncidentLookupData? _current;

  IncidentLookupData? get current {
    _checkSession();
    return _current;
  }

  void _checkSession() {
    if (_generation != _session.generation) {
      clear();
      _generation = _session.generation;
    }
  }

  Future<Result<IncidentLookupData>> refresh() async {
    _checkSession();
    final generation = _session.generation;
    final revision = _revision;
    final request = ++_nextRequest;
    final result = await _load();
    // A late response never crosses logout, login, explicit clear or disposal.
    // Among overlapping successes, the newest-started successful call wins.
    if (!_disposed &&
        generation == _session.generation &&
        revision == _revision &&
        _session.isAuthenticated &&
        request > _acceptedRequest &&
        result is Success<IncidentLookupData>) {
      _current = result.data;
      _acceptedRequest = request;
    }
    return result;
  }

  void clear() {
    _revision++;
    _current = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    clear();
    await _subscription.cancel();
  }
}
