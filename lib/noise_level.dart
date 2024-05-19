class NoiseLevel {
  final String? timestamp;
  final double? noiseLevel;

  NoiseLevel({this.timestamp, this.noiseLevel});

  factory NoiseLevel.fromJson(Map<String, dynamic> json) {
    return NoiseLevel(
      timestamp: json['timestamp'],
      noiseLevel: double.parse(json['noiseLevel']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'noiseLevel': noiseLevel?.toStringAsFixed(2),
    };
  }
}
