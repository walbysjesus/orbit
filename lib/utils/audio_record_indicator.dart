import 'package:flutter/material.dart';

class AudioRecordIndicator extends StatelessWidget {
  final bool isRecording;
  final String? audioPath;
  final Duration elapsed;

  const AudioRecordIndicator({
    required this.isRecording,
    this.audioPath,
    this.elapsed = Duration.zero,
    super.key,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

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
                  color: Colors.redAccent.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Grabando ${_formatDuration(elapsed)}',
            style: const TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else if (audioPath != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_arrow, color: Colors.green),
          const SizedBox(width: 8),
          const Text('Nota de voz enviada',
              style: TextStyle(color: Colors.green)),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
