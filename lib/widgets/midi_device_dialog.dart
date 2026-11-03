import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import '../services/midi_service.dart';

class MidiDeviceDialog extends StatefulWidget {
  final MidiService midiService;

  const MidiDeviceDialog({super.key, required this.midiService});

  static Future<void> show(BuildContext context, MidiService service) {
    return showDialog(
      context: context,
      builder: (context) => MidiDeviceDialog(midiService: service),
    );
  }

  @override
  State<MidiDeviceDialog> createState() => _MidiDeviceDialogState();
}

class _MidiDeviceDialogState extends State<MidiDeviceDialog> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.midiService,
      builder: (context, _) {
        final devices = widget.midiService.devices;
        final connected = widget.midiService.connectedDevice;
        final isScanning = widget.midiService.isScanning;

        return AlertDialog(
          backgroundColor: const Color(0xFF181614),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF3A332B), width: 1),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEADBC8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.piano, color: Color(0xFFEADBC8)),
              ),
              const SizedBox(width: 12),
              const Text(
                'Koneksi MIDI Piano',
                style: TextStyle(
                  color: Color(0xFFFAF6F0),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEADBC8),
                        ),
                      )
                    : const Icon(Icons.refresh, color: Color(0xFFC8B8A6)),
                tooltip: 'Scan ulang perangkat MIDI',
                onPressed: isScanning
                    ? null
                    : () => widget.midiService.refreshDevices(),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sambungkan piano digital atau keyboard Anda menggunakan kabel USB-MIDI atau Bluetooth MIDI.',
                  style: TextStyle(color: Color(0xFFC8B8A6), fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                if (devices.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF221E1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF383129)),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.usb_off_rounded, size: 40, color: Color(0xFF6B6156)),
                          SizedBox(height: 12),
                          Text(
                            'Tidak ada perangkat MIDI terdeteksi',
                            style: TextStyle(color: Color(0xFFFAF6F0), fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Colokkan kabel USB piano ke PC, atau pastikan Bluetooth MIDI sudah terpasang.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF998C7E), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF221E1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF383129)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      separatorBuilder: (_, _) => const Divider(color: Color(0xFF383129), height: 1),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final isThisConnected = connected?.id == device.id;
                        final isBle = device.type == MidiDeviceType.ble;

                        return ListTile(
                          leading: Icon(
                            isBle ? Icons.bluetooth : Icons.usb,
                            color: isThisConnected ? const Color(0xFFFFDFB8) : const Color(0xFFC8B8A6),
                          ),
                          title: Text(
                            device.name,
                            style: const TextStyle(
                              color: Color(0xFFFAF6F0),
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${device.id} • Tipe: ${device.type.name}',
                            style: const TextStyle(color: Color(0xFF998C7E), fontSize: 11),
                          ),
                          trailing: isThisConnected
                              ? OutlinedButton.icon(
                                  icon: const Icon(Icons.check_circle, size: 16, color: Color(0xFFFFDFB8)),
                                  label: const Text('Terhubung', style: TextStyle(color: Color(0xFFFFDFB8))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFFFDFB8)),
                                  ),
                                  onPressed: () => widget.midiService.disconnect(),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEADBC8),
                                    foregroundColor: const Color(0xFF1E1A16),
                                  ),
                                  onPressed: () => widget.midiService.connectToDevice(device),
                                  child: const Text('Hubungkan', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                // Helpful hints
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEADBC8).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF383129)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFFEADBC8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tips: Anda juga bisa mencoba tuts di layar langsung dengan mengkliknya menggunakan mouse atau keyboard [A–K]!',
                          style: TextStyle(color: Color(0xFFC8B8A6), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup', style: TextStyle(color: Color(0xFFC8B8A6))),
            ),
          ],
        );
      },
    );
  }
}
