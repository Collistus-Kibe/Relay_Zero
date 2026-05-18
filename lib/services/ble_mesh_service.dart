import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../models/triage_payload.dart';

class BleMeshService {
  static const String SERVICE_UUID = "0000180F-0000-1000-8000-00805f9b34fb";
  static const int MANUFACTURER_ID = 0xFFFF; // Custom ID for the Hackathon Mesh

  final FlutterReactiveBle _bleScanner = FlutterReactiveBle();
  final FlutterBlePeripheral _bleBroadcaster = FlutterBlePeripheral();
  
  StreamSubscription? _scanSubscription;
  
  // Message Deduplication Cache
  final Set<String> _seenMessages = {};
  
  bool _isBroadcasting = false;

  final StreamController<TriagePayload> _payloadStreamController = StreamController.broadcast();
  Stream<TriagePayload> get interceptedPayloads => _payloadStreamController.stream;

  /// 1. The Broadcaster: Blindly pulse the JSON payload as Manufacturer Data
  Future<void> startBroadcasting(String jsonPayload) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print("BLE Mock Mode: Broadcasting payload on desktop -> \$jsonPayload");
      return;
    }

    if (_isBroadcasting) {
      await _bleBroadcaster.stop();
    }

    // Embed JSON directly into Manufacturer Data
    final List<int> payloadBytes = utf8.encode(jsonPayload);
    
    final AdvertiseData advertiseData = AdvertiseData(
      serviceUuid: SERVICE_UUID,
      manufacturerId: MANUFACTURER_ID,
      manufacturerData: Uint8List.fromList(payloadBytes),
    );

    try {
      await _bleBroadcaster.start(advertiseData: advertiseData);
      _isBroadcasting = true;
      print("BLE_TX: Broadcasting SOS payload -> \$jsonPayload");
      
      // Add to our seen cache so we don't bounce our own message
      _seenMessages.add(jsonPayload);
    } catch (e) {
      print("BLE_TX Error: Failed to start broadcasting: \$e");
    }
  }

  /// 2. The Scanner: Listen for payloads from other phones
  void startScanning() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print("BLE Mock Mode: Scanning for payloads on desktop.");
      return;
    }

    _scanSubscription?.cancel();
    print("BLE_RX: Starting connectionless scan...");
    
    // We scan specifically for our Service UUID using low power to save battery
    _scanSubscription = _bleScanner.scanForDevices(
      withServices: [Uuid.parse(SERVICE_UUID)],
      scanMode: ScanMode.lowPower, 
    ).listen((device) {
      
      // Extract Manufacturer Data (Connectionless Payload)
      final Uint8List data = device.manufacturerData; 
      
      if (data.isNotEmpty) {
        try {
          final String jsonPayload = utf8.decode(data);
          
          // 3. Message Deduplication: Avoid infinite loops!
          if (!_seenMessages.contains(jsonPayload)) {
            print("BLE_RX: Heard new SOS Payload -> \$jsonPayload");
            _seenMessages.add(jsonPayload);
            
            // Rebroadcast immediately to continue the mesh network
            startBroadcasting(jsonPayload);
            
            // Notify the UI Stream
            try {
              final payload = TriagePayload.fromJsonString(jsonPayload);
              _payloadStreamController.add(payload);
            } catch(e) {
              print("Failed to decode payload for UI stream.");
            }
          }
        } catch (e) {
          // Payload was not valid UTF-8, ignore it.
        }
      }
    }, onError: (error) {
      print("BLE_RX Error: \$error");
    });
  }

  void dispose() {
    _scanSubscription?.cancel();
    if (_isBroadcasting) {
      _bleBroadcaster.stop();
    }
    _payloadStreamController.close();
  }
}
