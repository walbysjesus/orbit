import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool fromMe;
  final String? userName;
  final String? userAvatar;
  final String? status;
  final String? attachmentUrl;
  final String? reaction;
  final bool isHighlighted;
  final VoidCallback? onLongPress;
  final String? timeLabel;
  final String? messageType;

  const ChatBubble({
    super.key,
    required this.text,
    required this.fromMe,
    this.userName,
    this.userAvatar,
    this.status,
    this.attachmentUrl,
    this.reaction,
    this.timeLabel,
    this.messageType,
    this.isHighlighted = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              color: isHighlighted
                  ? Colors.blue.withValues(alpha: 0.08)
                  : Colors.transparent,
              child: Align(
                alignment:
                    fromMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.70,
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 2),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? (fromMe ? Colors.blue[200] : Colors.grey[300])
                              : (fromMe ? Colors.blue[100] : Colors.grey[200]),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(fromMe ? 16 : 4),
                            bottomRight: Radius.circular(fromMe ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: fromMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (userName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(userName!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ),
                            if (attachmentUrl != null &&
                                attachmentUrl!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _isImage(attachmentUrl!)
                                  ? GestureDetector(
                                      onTap: () => _openAttachmentUrl(
                                          context, attachmentUrl!),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: attachmentUrl!,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const SizedBox(
                                            width: 120,
                                            height: 120,
                                            child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2)),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(Icons.broken_image,
                                                  size: 40, color: Colors.grey),
                                        ),
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: () => _openAttachmentUrl(
                                          context, attachmentUrl!),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                              messageType == 'audio'
                                                  ? Icons.multitrack_audio
                                                  : Icons.insert_drive_file,
                                              size: 24,
                                              color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              messageType == 'audio'
                                                  ? 'Nota de voz'
                                                  : 'Archivo adjunto',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.blue,
                                                  decoration:
                                                      TextDecoration.underline),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ],
                            if (text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(text,
                                    style: const TextStyle(fontSize: 15)),
                              ),
                            if (timeLabel != null ||
                                (status != null && status!.isNotEmpty))
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (timeLabel != null)
                                      Text(
                                        timeLabel!,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey),
                                      ),
                                    if (timeLabel != null &&
                                        status != null &&
                                        status!.isNotEmpty)
                                      const SizedBox(width: 4),
                                    if (status != null && status!.isNotEmpty)
                                      Text(
                                        status!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: status == 'seen'
                                              ? Colors.green[700]
                                              : status == 'delivered'
                                                  ? Colors.blue[700]
                                                  : status == 'sending'
                                                      ? Colors.blueGrey[600]
                                                      : status == 'queued'
                                                          ? Colors.orange[700]
                                                          : status == 'failed'
                                                              ? Colors.red[700]
                                                              : Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (reaction != null && reaction!.isNotEmpty)
                      Positioned(
                        bottom: -8,
                        right: fromMe ? 8 : null,
                        left: fromMe ? null : 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: Text(reaction!,
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isImage(String url) {
    final imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
    return imageExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }

  void _openAttachmentUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo adjunto.')),
      );
    }
  }
}
