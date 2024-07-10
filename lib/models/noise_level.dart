class NoiseLevel {
  final int? id;
  final String? RecordedDate;
  final double? Decibel;
  final int? Person;
  final String Station;

  NoiseLevel({
    this.id,
    this.RecordedDate,
    this.Decibel,
    this.Person,
    this.Station = 'Station 1',
  });

  factory NoiseLevel.fromJsonLocal(Map<String, dynamic> json) {
    return NoiseLevel(
      id: json['id'],
      RecordedDate: json['RecordedDate'],
      Decibel: (json['Decibel']),
      Person: json['Person'],
      Station: json['Station'] ?? 'Station 1',
    );
  }
  factory NoiseLevel.fromJsonRemote(Map<String, dynamic> json) {
    return NoiseLevel(
      id: json['Id'],
      RecordedDate: json['RecordedDate'],
      Decibel: double.parse(json['Decibel'].toString()),
      Person: json['Person']['Id'],
      Station: json['Station'] ?? 'Station 1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'RecordedDate': RecordedDate,
      'Decibel': Decibel,
      'Person': Person,
      'Station': Station,
    };
  }

  @override
  String toString() {
    return 'NoiseLevel{id: $id, RecordedDate: $RecordedDate, Decibel: $Decibel, Person: $Person, Station: $Station}';
  }
}
