/// Coalesces preparation of optional GPU assets for the app's startup path.
class RuntimeEffectLoader {
  RuntimeEffectLoader(this._load);
  final Future<void> Function() _load;
  Future<void>? _loading;
  Object? _error;
  Object? get error => _error;
  bool get failed => error != null;

  Future<void> prepare() => _loading ??= Future<void>.sync(_load).catchError((
    Object failure,
  ) {
    // GPU optics are optional. Keep startup usable with bounded native blur.
    // Latch the failure so each new control does not retry broken assets.
    _error = failure;
  });
}
