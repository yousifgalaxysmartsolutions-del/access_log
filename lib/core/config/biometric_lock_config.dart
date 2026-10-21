/// Local UI lock only. Does not expire tokens or stop background field work.
abstract final class BiometricLockConfig {
  static const enabled = true;
  static const backgroundTimeoutMinutes = 1;
}
