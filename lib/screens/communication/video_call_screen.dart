import 'package:flutter/material.dart';

class VideoCallScreen extends StatelessWidget {
  const VideoCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Video Call'),
        backgroundColor: Colors.black,
      ),
      body: const Center(
        child: Icon(Icons.videocam, color: Colors.white, size: 80),
      ),
    );
  }
}
