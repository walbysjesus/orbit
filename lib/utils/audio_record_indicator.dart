import 'package:flutter/material.dart';

class AudioRecordIndicator extends StatelessWidget {
  final bool isRecording;
  final String? audioPath;
  const AudioRecordIndicator({required this.isRecording, this.audioPath, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isRecording) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text('Grabando audio...', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ],
      );
    } else if (audioPath != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_arrow, color: Colors.green),
          const SizedBox(width: 8),
          const Text('Nota de voz enviada', style: TextStyle(color: Colors.green)),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
