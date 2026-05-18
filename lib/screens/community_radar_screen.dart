import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../models/triage_payload.dart';

class CommunityRadarScreen extends StatefulWidget {
  final Stream<TriagePayload> interceptedPayloads;

  const CommunityRadarScreen({super.key, required this.interceptedPayloads});

  @override
  State<CommunityRadarScreen> createState() => _CommunityRadarScreenState();
}

class _CommunityRadarScreenState extends State<CommunityRadarScreen> {
  final List<InterceptedSOS> _activeAlerts = [];
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _fetchMyPosition();
    widget.interceptedPayloads.listen(_handleNewPayload);
  }

  Future<void> _fetchMyPosition() async {
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        _myPosition = Position(
          longitude: 36.965, latitude: -1.144, // Slightly offset from victim mock
          timestamp: DateTime.now(), accuracy: 1, 
          altitude: 0, heading: 0, speed: 0, speedAccuracy: 0,
          altitudeAccuracy: 0, headingAccuracy: 0
        );
      } else {
        _myPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }
      if (mounted) setState(() {});
    } catch (e) {
      print("GPS Error: \$e");
    }
  }

  void _handleNewPayload(TriagePayload payload) {
    if (payload.lat == null || payload.lng == null) return;
    
    // Check if we already have this exact payload (dedup in UI if necessary)
    // We assume the BLE service already deduplicated, but we can do it here just in case.
    setState(() {
      _activeAlerts.insert(0, InterceptedSOS(payload: payload, timestamp: DateTime.now()));
    });
  }

  String _calculateDistance(double targetLat, double targetLng) {
    if (_myPosition == null) return "Unknown distance";
    double distanceInMeters = Geolocator.distanceBetween(
      _myPosition!.latitude, _myPosition!.longitude, 
      targetLat, targetLng
    );
    if (distanceInMeters < 1000) {
      return "${distanceInMeters.toStringAsFixed(0)}m";
    } else {
      return "${(distanceInMeters / 1000).toStringAsFixed(1)}km";
    }
  }

  String _calculateBearing(double targetLat, double targetLng) {
    if (_myPosition == null) return "";
    double bearing = Geolocator.bearingBetween(
      _myPosition!.latitude, _myPosition!.longitude, 
      targetLat, targetLng
    );
    
    // Convert bearing (-180 to 180) to 0-360
    if (bearing < 0) bearing += 360;
    
    if (bearing >= 337.5 || bearing < 22.5) return "North";
    if (bearing >= 22.5 && bearing < 67.5) return "North-East";
    if (bearing >= 67.5 && bearing < 112.5) return "East";
    if (bearing >= 112.5 && bearing < 157.5) return "South-East";
    if (bearing >= 157.5 && bearing < 202.5) return "South";
    if (bearing >= 202.5 && bearing < 247.5) return "South-West";
    if (bearing >= 247.5 && bearing < 292.5) return "West";
    if (bearing >= 292.5 && bearing < 337.5) return "North-West";
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1E2C), Color(0xFF0B0B0F)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "COMMUNITY RADAR",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "Listening for BLE Mesh SOS signals...",
                  style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: _activeAlerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.radar, size: 80, color: Colors.white.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            Text("No signals detected.", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _activeAlerts.length,
                        itemBuilder: (context, index) {
                          final alert = _activeAlerts[index];
                          final p = alert.payload;
                          final distanceStr = _calculateDistance(p.lat!, p.lng!);
                          final bearingStr = _calculateBearing(p.lat!, p.lng!);
                          
                          Color threatColor = p.triageLevel == 'R' ? Colors.redAccent 
                              : p.triageLevel == 'Y' ? Colors.orangeAccent 
                              : Colors.greenAccent;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: threatColor.withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: threatColor.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning, color: threatColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "${p.triageLevel == 'R' ? 'CRITICAL' : p.triageLevel == 'Y' ? 'URGENT' : 'MINOR'} - ${p.headcount} People - ${p.primaryHazard.toUpperCase()}",
                                        style: TextStyle(color: threatColor, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.blueAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$distanceStr $bearingStr",
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    if (p.medicalFlag)
                                      const Row(
                                        children: [
                                          Icon(Icons.local_hospital, color: Colors.redAccent, size: 16),
                                          SizedBox(width: 4),
                                          Text("MEDICAL", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InterceptedSOS {
  final TriagePayload payload;
  final DateTime timestamp;

  InterceptedSOS({required this.payload, required this.timestamp});
}
