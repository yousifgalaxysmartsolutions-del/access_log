import 'package:flutter/widgets.dart';

/// Holds the language currently selected inside the app.
///
/// The CAP data layer needs to pick between `resultmessageen` and
/// `resultmessagear`, but repositories and blocs must not depend on a
/// `BuildContext`. `AccessLogAppState` keeps this holder in sync with the
/// `MaterialApp.locale`, giving the data layer a single source of truth.
class CapLocaleHolder {
  CapLocaleHolder({Locale locale = const Locale('ar')}) : _locale = locale;

  static final CapLocaleHolder instance = CapLocaleHolder();

  Locale _locale;

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  void update(Locale locale) => _locale = locale;
}
