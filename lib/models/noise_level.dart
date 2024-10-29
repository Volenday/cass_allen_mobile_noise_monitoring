class NoiseLevel {
  final int? id;
  final String recordedDate;
  final double decibel;
  final int station;
  final String audioPath;

  NoiseLevel({
    this.id,
    this.recordedDate = '',
    this.decibel = 0.0,
    this.station = 1,
    this.audioPath = '',
  });

  factory NoiseLevel.fromJsonLocal(Map<String, dynamic> json) {
    return NoiseLevel(
      id: json['id'],
      recordedDate: json['recordedDate'],
      decibel: (json['decibel']),
      station: json['station'] ?? 1,
    );
  }
  factory NoiseLevel.fromJsonRemote(Map<String, dynamic> json) {
    return NoiseLevel(
      id: json['Id'],
      recordedDate: json['recordedDate'],
      decibel: double.parse(json['decibel'].toString()),
      station: json['station'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recordedDate': recordedDate,
      'decibel': decibel,
      'station': station,
    };
  }

  @override
  String toString() {
    return 'NoiseLevel{id: $id, RecordedDate: $recordedDate, Decibel: $decibel, Station: $station}';
  }
}
