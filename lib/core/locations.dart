class AppLocations {
  const AppLocations._();

  static const voivodeships = ['podkarpackie', 'świętokrzyskie'];

  static const countiesByVoivodeship = {
    'podkarpackie': [
      'miasto Tarnobrzeg',
      'tarnobrzeski',
      'stalowowolski',
      'kolbuszowski',
      'mielecki',
    ],
    'świętokrzyskie': ['sandomierski'],
  };

  static List<String> countiesFor(String voivodeship) {
    return countiesByVoivodeship[voivodeship] ??
        countiesByVoivodeship['podkarpackie']!;
  }
}
