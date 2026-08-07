import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../core/localization/app_locale_controller.dart';
import '../../core/network/api_client.dart';
import 'media_file_opener.dart';

class ConversationImage extends StatefulWidget {
  const ConversationImage({
    super.key,
    required this.api,
    required this.mediaUrl,
  });

  final ApiClient api;
  final String mediaUrl;

  @override
  State<ConversationImage> createState() => _ConversationImageState();
}

class _ConversationImageState extends State<ConversationImage> {
  late Future<AuthenticatedMediaRequest> source;

  @override
  void initState() {
    super.initState();
    source = widget.api.mediaRequest(widget.mediaUrl);
  }

  @override
  void didUpdateWidget(covariant ConversationImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api || oldWidget.mediaUrl != widget.mediaUrl) {
      source = widget.api.mediaRequest(widget.mediaUrl);
    }
  }

  void _retry() => setState(() {
        source = widget.api.mediaRequest(widget.mediaUrl);
      });

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<AuthenticatedMediaRequest>(
        future: source,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MediaError(
              icon: Icons.broken_image_outlined,
              label: tr('تعذر عرض الصورة'),
              onRetry: _retry,
            );
          }
          if (!snapshot.hasData) {
            return const _MediaLoading(width: 260, height: 210);
          }
          final request = snapshot.data!;
          return Semantics(
            button: true,
            label: tr('فتح الصورة'),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _FullScreenImage(source: request),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  request.url,
                  headers: request.headers,
                  width: 270,
                  height: 220,
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const _MediaLoading(width: 270, height: 220),
                  errorBuilder: (_, __, ___) => _MediaError(
                    icon: Icons.broken_image_outlined,
                    label: tr('تعذر عرض الصورة'),
                    onRetry: _retry,
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.source});
  final AuthenticatedMediaRequest source;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(tr('الصورة')),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: .8,
            maxScale: 5,
            child: Image.network(
              source.url,
              headers: source.headers,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _MediaError(
                icon: Icons.broken_image_outlined,
                label: tr('تعذر عرض الصورة'),
                foreground: Colors.white,
              ),
            ),
          ),
        ),
      );
}

class ConversationVideo extends StatelessWidget {
  const ConversationVideo({
    super.key,
    required this.api,
    required this.mediaUrl,
  });

  final ApiClient api;
  final String mediaUrl;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 270,
        child: Material(
          color: Colors.black.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _FullScreenVideo(
                  api: api,
                  mediaUrl: mediaUrl,
                ),
              ),
            ),
            child: SizedBox(
              height: 190,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black87),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 64,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('\u062A\u0634\u063A\u064A\u0644 \u0627\u0644\u0641\u064A\u062F\u064A\u0648'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _FullScreenVideo extends StatefulWidget {
  const _FullScreenVideo({
    required this.api,
    required this.mediaUrl,
  });

  final ApiClient api;
  final String mediaUrl;

  @override
  State<_FullScreenVideo> createState() => _FullScreenVideoState();
}

class _FullScreenVideoState extends State<_FullScreenVideo> {
  VideoPlayerController? controller;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final old = controller;
    controller = null;
    if (old != null) {
      await old.dispose();
    }

    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    VideoPlayerController? next;
    try {
      final request = await widget.api.mediaRequest(widget.mediaUrl);
      next = VideoPlayerController.networkUrl(
        Uri.parse(request.url),
        httpHeaders: request.headers,
      );
      await next.initialize();
      await next.setLooping(false);

      if (!mounted) {
        await next.dispose();
        return;
      }

      controller = next;
      await next.play();
    } catch (_) {
      if (next != null) {
        await next.dispose();
      }
      if (mounted) {
        error = tr(
            '\u062A\u0639\u0630\u0631 \u062A\u0634\u063A\u064A\u0644 \u0627\u0644\u0641\u064A\u062F\u064A\u0648');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr('\u0641\u064A\u062F\u064A\u0648')),
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null || player == null
                ? Center(
                    child: _MediaError(
                      icon: Icons.video_file_outlined,
                      label: error ??
                          tr('\u062A\u0639\u0630\u0631 \u062A\u0634\u063A\u064A\u0644 \u0627\u0644\u0641\u064A\u062F\u064A\u0648'),
                      foreground: Colors.white,
                      onRetry: _initialize,
                    ),
                  )
                : Center(
                    child: GestureDetector(
                      onTap: () async {
                        if (player.value.isPlaying) {
                          await player.pause();
                        } else {
                          await player.play();
                        }
                        if (mounted) setState(() {});
                      },
                      child: AspectRatio(
                        aspectRatio: player.value.aspectRatio <= 0
                            ? 16 / 9
                            : player.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(player),
                            if (!player.value.isPlaying)
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 72,
                              ),
                            PositionedDirectional(
                              start: 14,
                              end: 14,
                              bottom: 12,
                              child: VideoProgressIndicator(
                                player,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Color(0xFF25D366),
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}

class ConversationAudio extends StatefulWidget {
  const ConversationAudio({
    super.key,
    required this.api,
    required this.mediaUrl,
    required this.foreground,
  });

  final ApiClient api;
  final String mediaUrl;
  final Color foreground;

  @override
  State<ConversationAudio> createState() => _ConversationAudioState();
}

class _ConversationAudioState extends State<ConversationAudio> {
  final AudioPlayer player = AudioPlayer(useProxyForRequestHeaders: false);
  StreamSubscription<PlayerState>? stateSubscription;
  bool loading = false;
  bool loaded = false;
  String? error;

  @override
  void initState() {
    super.initState();
    stateSubscription = player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(player.seek(Duration.zero));
        unawaited(player.pause());
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _AudioPlaybackCoordinator.release(player);
    stateSubscription?.cancel();
    player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (loading) return;
    try {
      if (!loaded) {
        setState(() {
          loading = true;
          error = null;
        });
        final source = await widget.api.mediaRequest(widget.mediaUrl);
        if (source.headers.isEmpty) {
          await player.setUrl(source.url);
        } else {
          await player.setUrl(source.url, headers: source.headers);
        }
        loaded = true;
      }
      if (player.playing) {
        await player.pause();
      } else {
        await _AudioPlaybackCoordinator.activate(player);
        unawaited(player.play());
      }
    } catch (_) {
      error = tr('تعذر تشغيل الرسالة الصوتية');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = player.duration ?? Duration.zero;
    return SizedBox(
      width: 270,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _toggle,
                tooltip: player.playing ? tr('إيقاف مؤقت') : tr('تشغيل'),
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(player.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
              ),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: player.positionStream,
                  initialData: Duration.zero,
                  builder: (_, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final maximum = duration.inMilliseconds <= 0
                        ? 1.0
                        : duration.inMilliseconds.toDouble();
                    return Slider(
                      value: position.inMilliseconds
                          .clamp(0, maximum.toInt())
                          .toDouble(),
                      max: maximum,
                      onChanged: loaded
                          ? (value) => player.seek(
                                Duration(milliseconds: value.round()),
                              )
                          : null,
                    );
                  },
                ),
              ),
              Text(
                _durationLabel(duration),
                style: TextStyle(
                  color: widget.foreground.withValues(alpha: .78),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }
}

class ConversationDocument extends StatefulWidget {
  const ConversationDocument({
    super.key,
    required this.api,
    required this.mediaUrl,
    required this.fileName,
    required this.foreground,
  });

  final ApiClient api;
  final String mediaUrl;
  final String fileName;
  final Color foreground;

  @override
  State<ConversationDocument> createState() => _ConversationDocumentState();
}

class _ConversationDocumentState extends State<ConversationDocument> {
  bool busy = false;
  String? error;

  Future<void> _open() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final request = await widget.api.mediaRequest(widget.mediaUrl);
      final opened = await openMediaFile(
        url: request.url,
        headers: request.headers,
        fileName: widget.fileName,
      );
      if (!opened) error = tr('تعذر فتح الملف على هذا الجهاز');
    } catch (_) {
      error = tr('تعذر تنزيل الملف');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 270,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: widget.foreground.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _open,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.foreground.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.insert_drive_file_rounded,
                            color: widget.foreground),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.download_rounded,
                              color: widget.foreground),
                    ],
                  ),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      );
}

class _AudioPlaybackCoordinator {
  static AudioPlayer? _active;

  static Future<void> activate(AudioPlayer next) async {
    final current = _active;
    if (current != null && current != next) await current.pause();
    _active = next;
  }

  static void release(AudioPlayer player) {
    if (_active == player) _active = null;
  }
}

class _MediaLoading extends StatelessWidget {
  const _MediaLoading({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class _MediaError extends StatelessWidget {
  const _MediaError({
    required this.icon,
    required this.label,
    this.foreground,
    this.onRetry,
  });

  final IconData icon;
  final String label;
  final Color? foreground;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        height: 150,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground)),
            if (onRetry != null) ...[
              const SizedBox(height: 6),
              TextButton(onPressed: onRetry, child: Text(tr('إعادة المحاولة'))),
            ],
          ],
        ),
      );
}

String _durationLabel(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
