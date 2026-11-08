enum ParticipantSex {
  male('Мужчина'),
  female('Женщина');

  const ParticipantSex(this.label);
  final String label;

  static ParticipantSex? fromId(Object? value) => switch (value) {
    'male' => male,
    'female' => female,
    _ => null,
  };
}
