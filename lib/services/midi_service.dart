import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import '../models/midi_note.dart';

class MidiService extends ChangeNotifier {
  static final MidiService _instance = MidiService._internal();
  factory MidiService() => _instance;
  MidiService._internal();

  final MidiCommand _midiCommand = MidiCommand();

  List<MidiDevice> _devices = [];
  MidiDevice? _connectedDevice;
  bool _isScanning = false;

  StreamSubscription<MidiPacket>? _midiDataSubscription;
  StreamSubscription<MidiSetupChange>? _setupSubscription;

  // Stream controller to broadcast parsed live events (NoteOn, NoteOff, Pedal)
  final StreamController<LiveMidiEvent> _liveEventController =
      StreamController<LiveMidiEvent>.broadcast();

  Stream<LiveMidiEvent> get onLiveEvent => _liveEventController.stream;

  List<MidiDevice> get devices => _devices;
  MidiDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  bool get isScanning => _isScanning;

  /// Initialize listeners for MIDI devices and data
  Future<void> init() async {
    // Listen for setup changes (devices connected/disconnected)
    _setupSubscription = _midiCommand.onMidiSetupChanged?.listen((change) {
      debugPrint('[MidiService] MIDI Setup changed: ${change.name}');
      refreshDevices();
    });

    // Listen for incoming raw MIDI packets
    _midiDataSubscription = _midiCommand.onMidiPacketReceived?.listen(_handleMidiPacket);

    // Initial scan for devices
    await refreshDevices();
  }

  /// Scan for available USB and Bluetooth MIDI devices
  Future<void> refreshDevices() async {
    _isScanning = true;
    notifyListeners();

    try {
      final devList = await _midiCommand.devices;
      _devices = devList ?? [];

      // Check if previously connected device is still available
      if (_connectedDevice != null) {
        final stillPresent = _devices.any((d) => d.id == _connectedDevice!.id);
        if (!stillPresent) {
          _connectedDevice = null;
        }
      }

      // Auto-connect if only 1 device found and none currently connected
      if (_connectedDevice == null && _devices.isNotEmpty) {
        await connectToDevice(_devices.first);
      }
    } catch (e) {
      debugPrint('[MidiService] Error fetching devices: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Connect to a specific MIDI device
  Future<void> connectToDevice(MidiDevice device) async {
    try {
      if (_connectedDevice != null && _connectedDevice!.id != device.id) {
        _midiCommand.disconnectDevice(_connectedDevice!);
      }

      _midiCommand.connectToDevice(device);
      _connectedDevice = device;
      debugPrint('[MidiService] Connected to: ${device.name}');
      notifyListeners();
    } catch (e) {
      debugPrint('[MidiService] Connect error: $e');
    }
  }

  /// Disconnect from current MIDI device
  void disconnect() {
    if (_connectedDevice != null) {
      try {
        _midiCommand.disconnectDevice(_connectedDevice!);
      } catch (e) {
        debugPrint('[MidiService] Disconnect error: $e');
      }
      _connectedDevice = null;
      notifyListeners();
    }
  }

  /// Send MIDI Note On back to physical piano
  void sendNoteOn(int pitch, {int velocity = 100, int channel = 0}) {
    final status = 0x90 | (channel & 0x0F);
    final data = Uint8List.fromList([status, pitch.clamp(0, 127), velocity.clamp(0, 127)]);
    _midiCommand.sendData(data);
  }

  /// Send MIDI Note Off back to physical piano
  void sendNoteOff(int pitch, {int channel = 0}) {
    final status = 0x80 | (channel & 0x0F);
    final data = Uint8List.fromList([status, pitch.clamp(0, 127), 0]);
    _midiCommand.sendData(data);
  }

  /// Parse incoming raw MIDI bytes and dispatch typed events
  void _handleMidiPacket(MidiPacket packet) {
    final data = packet.data;
    if (data.isEmpty) return;

    int i = 0;
    while (i < data.length) {
      final status = data[i];
      if ((status & 0x80) == 0) {
        // Data byte without status, skip
        i++;
        continue;
      }

      final msgType = status & 0xF0;
      final channel = status & 0x0F;

      if (msgType == 0x90 && i + 2 < data.length) {
        // Note On
        final pitch = data[i + 1];
        final velocity = data[i + 2];
        i += 3;

        if (velocity > 0) {
          _liveEventController.add(LiveMidiEvent(
            type: MidiPacketType.noteOn,
            pitch: pitch,
            velocity: velocity,
            channel: channel,
          ));
        } else {
          // Velocity 0 is Note Off
          _liveEventController.add(LiveMidiEvent(
            type: MidiPacketType.noteOff,
            pitch: pitch,
            velocity: 0,
            channel: channel,
          ));
        }
      } else if (msgType == 0x80 && i + 2 < data.length) {
        // Note Off
        final pitch = data[i + 1];
        i += 3;
        _liveEventController.add(LiveMidiEvent(
          type: MidiPacketType.noteOff,
          pitch: pitch,
          velocity: 0,
          channel: channel,
        ));
      } else if (msgType == 0xB0 && i + 2 < data.length) {
        // Control Change (e.g. Sustain pedal = 64)
        final controller = data[i + 1];
        final val = data[i + 2];
        i += 3;
        _liveEventController.add(LiveMidiEvent(
          type: MidiPacketType.controlChange,
          controller: controller,
          value: val,
          channel: channel,
        ));
      } else {
        // Skip unhandled messages
        i++;
      }
    }
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  /// Inject virtual event (for mouse clicks / virtual keyboard)
  void injectVirtualEvent(LiveMidiEvent event) {
    if (!_isDisposed) {
      _liveEventController.add(event);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _midiDataSubscription?.cancel();
    _setupSubscription?.cancel();
    _liveEventController.close();
    super.dispose();
  }
}
