/// Enumerations shared across the data model.
///
/// Each enum has a stable [storageValue] used as the on-disk representation so
/// that renaming a Dart symbol never silently corrupts existing rows.

enum GoalType {
  lose('lose'),
  maintain('maintain'),
  gain('gain'),
  recomp('recomp');

  const GoalType(this.storageValue);
  final String storageValue;

  static GoalType fromStorage(String v) =>
      GoalType.values.firstWhere((e) => e.storageValue == v,
          orElse: () => GoalType.maintain);

  String get label => switch (this) {
        GoalType.lose => 'Lose weight',
        GoalType.maintain => 'Maintain',
        GoalType.gain => 'Gain muscle',
        GoalType.recomp => 'Recomposition',
      };
}

enum ActivityLevel {
  sedentary('sedentary', 1.2, 'Sedentary'),
  light('light', 1.375, 'Lightly active'),
  moderate('moderate', 1.55, 'Moderately active'),
  active('active', 1.725, 'Very active'),
  athlete('athlete', 1.9, 'Athlete');

  const ActivityLevel(this.storageValue, this.multiplier, this.label);
  final String storageValue;
  final double multiplier;
  final String label;

  static ActivityLevel fromStorage(String v) =>
      ActivityLevel.values.firstWhere((e) => e.storageValue == v,
          orElse: () => ActivityLevel.moderate);
}

enum Sex {
  male('male'),
  female('female');

  const Sex(this.storageValue);
  final String storageValue;

  static Sex fromStorage(String v) =>
      Sex.values.firstWhere((e) => e.storageValue == v, orElse: () => Sex.male);
}

enum Units {
  metric('metric'),
  imperial('imperial');

  const Units(this.storageValue);
  final String storageValue;

  static Units fromStorage(String v) =>
      Units.values.firstWhere((e) => e.storageValue == v,
          orElse: () => Units.metric);
}

enum MealSlot {
  breakfast('breakfast', 'Breakfast'),
  lunch('lunch', 'Lunch'),
  dinner('dinner', 'Dinner'),
  snack('snack', 'Snacks');

  const MealSlot(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static MealSlot fromStorage(String v) =>
      MealSlot.values.firstWhere((e) => e.storageValue == v,
          orElse: () => MealSlot.snack);
}

enum FoodSource {
  verified('verified'),
  usda('usda'),
  off('off'), // Open Food Facts
  custom('custom');

  const FoodSource(this.storageValue);
  final String storageValue;

  static FoodSource fromStorage(String v) =>
      FoodSource.values.firstWhere((e) => e.storageValue == v,
          orElse: () => FoodSource.custom);

  bool get isEstimated => this == off || this == usda;
}

enum EntrySource {
  search('search'),
  recent('recent'),
  scan('scan'),
  recipe('recipe'),
  template('template'),
  manual('manual');

  const EntrySource(this.storageValue);
  final String storageValue;

  static EntrySource fromStorage(String v) =>
      EntrySource.values.firstWhere((e) => e.storageValue == v,
          orElse: () => EntrySource.manual);
}

enum Pose {
  front('front'),
  side('side'),
  back('back');

  const Pose(this.storageValue);
  final String storageValue;

  static Pose fromStorage(String v) =>
      Pose.values.firstWhere((e) => e.storageValue == v, orElse: () => Pose.front);

  String get label => switch (this) {
        Pose.front => 'Front',
        Pose.side => 'Side',
        Pose.back => 'Back',
      };
}

enum VaultItemType {
  capsule('capsule'),
  weeklyReview('weekly_review'),
  photo('photo'),
  weightMilestone('weight_milestone'),
  measurementMilestone('measurement_milestone'),
  reflection('reflection');

  const VaultItemType(this.storageValue);
  final String storageValue;

  static VaultItemType fromStorage(String v) =>
      VaultItemType.values.firstWhere((e) => e.storageValue == v,
          orElse: () => VaultItemType.reflection);
}
