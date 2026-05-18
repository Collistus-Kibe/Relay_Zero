import 'dart:convert';

/// Represents the compressed JSON structure for the 50-byte BLE payload.
class TriagePayload {
  // We use ultra-short keys for JSON serialization to stay under 50 bytes.
  // 't': Triage Level (R, Y, G)
  final String triageLevel;
  
  // 'h': Primary Hazard (short string, e.g. "flood", "fire")
  final String primaryHazard;
  
  // 'm': Medical Flag (true/false)
  final bool medicalFlag;
  
  // 'c': Headcount (integer)
  final int headcount;

  // 'lat': Latitude (double)
  final double? lat;

  // 'lng': Longitude (double)
  final double? lng;

  TriagePayload({
    required this.triageLevel,
    required this.primaryHazard,
    required this.medicalFlag,
    required this.headcount,
    this.lat,
    this.lng,
  });

  /// Serializes to a compact JSON string.
  /// Example output: `{"t":"R","h":"flood","m":true,"c":4}` (33 bytes)
  String toJsonString() {
    final Map<String, dynamic> data = {
      't': triageLevel,
      'h': primaryHazard,
      'm': medicalFlag,
      'c': headcount,
    };
    if (lat != null) data['lat'] = lat;
    if (lng != null) data['lng'] = lng;
    // jsonEncode produces minified JSON by default without spaces
    return jsonEncode(data);
  }

  /// Deserializes from a JSON string.
  factory TriagePayload.fromJsonString(String jsonString) {
    final Map<String, dynamic> map = jsonDecode(jsonString);
    return TriagePayload(
      triageLevel: map['t'] as String,
      primaryHazard: map['h'] as String,
      medicalFlag: map['m'] as bool,
      headcount: map['c'] as int,
      lat: map['lat'] as double?,
      lng: map['lng'] as double?,
    );
  }
}
