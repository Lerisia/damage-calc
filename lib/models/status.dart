import '../utils/app_strings.dart';

/// Pokemon status conditions
enum StatusCondition {
  none,
  burn,
  poison,
  badlyPoisoned,
  paralysis,
  sleep,
  freeze;

  String get localizedName => AppStrings.t('status.$name');
}
