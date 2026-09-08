import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/frame_quality.dart';
import '../theme/ayna_colors.dart';
import '../theme/ayna_motion.dart';
import '../theme/ayna_tokens.dart';
import '../theme/ayna_typography.dart';
import '../widgets/face_guide.dart';
import '../widgets/press_scale.dart';

/// Take the selfie.
///
/// The most consequential screen in the product: everything downstream reads
/// whatever this hands over. A dark or side-lit frame does not fail loudly —
/// it returns plausible, worse numbers for the same skin, which surface later
/// as "your skin got worse" on a trend line that is really measuring the room.
/// So the guidance here is not polish; it is the only defence against a whole
/// class of wrong answers.
///
/// It is also the screen that spends money. Every accepted photo is a paid
/// vendor call and one of the user's weekly allowance, which is why the review
/// step exists rather than submitting straight from the shutter.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.onCaptured,
    required this.onCancel,
  });

  /// Called with the captured file once the user confirms it.
  final void Function(XFile photo) onCaptured;

  final VoidCallback onCancel;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Stage { starting, ready, denied, unavailable, captured }

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  _Stage _stage = _Stage.starting;
  CaptureHint _hint = CaptureHint.ready;
  XFile? _shot;
  String? _failure;

  /// Analysis runs on one frame in [_analyseEvery]. The preview arrives at
  /// 30fps and nobody can read a hint that changes thirty times a second — it
  /// would also burn the frame budget for a number that barely moves.
  static const _analyseEvery = 10;
  int _frame = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// The camera must be released when the app goes to the background.
  ///
  /// Android will take it away regardless; handling it here is the difference
  /// between a clean restart and a black preview with no error when the user
  /// returns from answering a message.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c.dispose();
      if (mounted) setState(() => _stage = _Stage.starting);
    } else if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        // A device with no front camera can still scan with the rear one held
        // at arm's length. Refusing outright would be a worse answer than an
        // awkward one.
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        // High rather than max: the vendor downsamples anyway, and max on a
        // modern phone produces a multi-megabyte JPEG that costs the user
        // upload time on a connection this product cannot assume is good.
        ResolutionPreset.high,
        enableAudio: false,
        // yuv420 on Android delivers YUV_420_888, whose first plane is luma --
        // exactly what the quality check reads. Without pinning the format the
        // plugin may hand over a packed format with no separate Y plane.
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.startImageStream(_onFrame);

      setState(() {
        _controller = controller;
        _stage = _Stage.ready;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage =
            e.code == 'CameraAccessDenied' ||
                e.code == 'CameraAccessDeniedWithoutPrompt'
            ? _Stage.denied
            : _Stage.unavailable;
        _failure = e.description;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.unavailable;
        _failure = '$e';
      });
    }
  }

  void _onFrame(CameraImage image) {
    if (_busy || _stage != _Stage.ready) return;
    if (++_frame % _analyseEvery != 0) return;

    _busy = true;
    try {
      final y = image.planes.first;
      final mean = FrameQuality.meanLuma(
        y.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: y.bytesPerRow,
      );
      final sides = FrameQuality.halves(
        y.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: y.bytesPerRow,
      );
      final hint = FrameQuality.hint(
        mean: mean,
        left: sides.left,
        right: sides.right,
      );
      if (hint != _hint && mounted) setState(() => _hint = hint);
    } catch (e) {
      // A malformed frame is not worth interrupting the viewfinder for. The
      // next one is 33ms away.
      debugPrint('frame analysis: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _shutter() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return;

    try {
      // The stream must stop first: taking a picture while frames are being
      // delivered fails on a good number of Android devices, and the failure
      // is a platform exception rather than anything this code can catch
      // meaningfully after the fact.
      await c.stopImageStream();
      final file = await c.takePicture();
      if (!mounted) return;
      setState(() {
        _shot = file;
        _stage = _Stage.captured;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _failure = e.description);
      if (c.value.isInitialized) await c.startImageStream(_onFrame);
    }
  }

  Future<void> _retake() async {
    final c = _controller;
    setState(() {
      _shot = null;
      _stage = _Stage.ready;
      _failure = null;
    });
    if (c != null && c.value.isInitialized && !c.value.isStreamingImages) {
      await c.startImageStream(_onFrame);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AynaColors.captureGround,
    body: switch (_stage) {
      _Stage.starting => const _Waiting(),
      _Stage.denied => _Blocked(
        title: 'Ayna needs your camera',
        body:
            'The scan is a selfie, so there is nothing to analyse without it. '
            'You can turn the camera on for Ayna in your phone settings, and '
            'nothing is saved until you tap Use this photo.',
        onBack: widget.onCancel,
      ),
      _Stage.unavailable => _Blocked(
        title: 'The camera would not open',
        body: _failure == null
            ? 'Something stopped the camera from starting. Closing other apps '
                  'that use it usually clears this.'
            : 'Something stopped the camera from starting: $_failure',
        onBack: widget.onCancel,
      ),
      _Stage.ready => _viewfinder(context),
      _Stage.captured => _review(context),
    },
  );

  Widget _viewfinder(BuildContext context) {
    final t = context.ayna;
    final c = _controller!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover rather than contain: letterboxing a viewfinder makes the phone
        // look like it is showing a video, not looking at you.
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.previewSize?.height ?? 1080,
            height: c.value.previewSize?.width ?? 1920,
            child: CameraPreview(c),
          ),
        ),

        FaceGuide(good: _hint.isGood),

        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close_rounded),
                  color: AynaColors.onClay,
                  iconSize: 28,
                  tooltip: 'Cancel',
                  padding: EdgeInsets.all(t.space3),
                ),
              ),
              const Spacer(),
              _HintPill(hint: _hint),
              SizedBox(height: t.space5),
              _Shutter(onPressed: _shutter, good: _hint.isGood),
              SizedBox(height: t.space6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _review(BuildContext context) {
    final t = context.ayna;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The mirrored preview is flipped back for review. People recognise
        // their mirror image, but the analysis sees the unmirrored one, and
        // showing the frame that will actually be sent is the honest choice.
        Image.file(File(_shot!.path), fit: BoxFit.cover),
        Container(color: AynaColors.captureGround.withValues(alpha: 0.35)),

        SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space6),
                child: Text(
                  'Good light, no makeup, hair off your forehead.',
                  textAlign: TextAlign.center,
                  style: AynaType.bodyMedium.copyWith(
                    color: AynaColors.onClayMuted,
                  ),
                ),
              ),
              SizedBox(height: t.space4),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space6),
                child: Row(
                  children: [
                    Expanded(
                      child: PressScale(
                        child: OutlinedButton(
                          onPressed: _retake,
                          style: OutlinedButton.styleFrom(
                            // backgroundColor MUST be overridden here. The app
                            // theme fills every OutlinedButton with a near-white
                            // surface for light screens; on this dark one that
                            // put near-white text on a near-white button and
                            // the label vanished. Overriding only the
                            // foreground, as this did, changes nothing.
                            backgroundColor: Colors.transparent,
                            foregroundColor: AynaColors.onClay,
                            side: const BorderSide(
                              color: AynaColors.captureGuide,
                              width: 1.5,
                            ),
                            minimumSize: Size.fromHeight(t.minTouch),
                          ),
                          child: const Text('Retake'),
                        ),
                      ),
                    ),
                    SizedBox(width: t.space3),
                    Expanded(
                      child: PressScale(
                        child: FilledButton(
                          onPressed: () => widget.onCaptured(_shot!),
                          style: FilledButton.styleFrom(
                            backgroundColor: AynaColors.onClay,
                            foregroundColor: AynaColors.captureGround,
                            minimumSize: Size.fromHeight(t.minTouch),
                          ),
                          child: const Text('Use this photo'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: t.space6),
            ],
          ),
        ),
      ],
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({required this.hint});

  final CaptureHint hint;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return AnimatedSwitcher(
      duration: AynaMotion.of(context, AynaMotion.quick),
      child: Container(
        // Keyed by the hint so the switcher cross-fades between messages
        // rather than mutating one label, which would read as a glitch.
        key: ValueKey(hint),
        padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space2),
        decoration: BoxDecoration(
          color: AynaColors.captureGround.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: hint.isGood ? AynaColors.captureOk : AynaColors.captureGuide,
            width: 1.5,
          ),
        ),
        child: Text(
          hint.message,
          style: AynaType.bodyMedium.copyWith(
            color: hint.isGood ? AynaColors.captureOk : AynaColors.captureGuide,
          ),
        ),
      ),
    );
  }
}

/// The shutter.
///
/// Enabled even when the lighting hint is unhappy. The thresholds are
/// provisional and a false "too dark" must never be able to stop someone
/// taking a photo of their own face — the ring and the pill steer, they do not
/// gate. When conditions are poor the button simply stops drawing attention to
/// itself.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.onPressed, required this.good});

  final VoidCallback onPressed;
  final bool good;

  @override
  Widget build(BuildContext context) => PressScale(
    scale: 0.92,
    child: Semantics(
      button: true,
      label: 'Take photo',
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: good ? 1 : 0),
          duration: AynaMotion.of(context, AynaMotion.base),
          builder: (context, t, _) => Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Color.lerp(
                  AynaColors.captureGuide.withValues(alpha: 0.55),
                  AynaColors.captureOk,
                  t,
                )!,
                width: 3,
              ),
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    AynaColors.onClay.withValues(alpha: 0.75),
                    AynaColors.onClay,
                    t,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: AynaColors.captureGuide),
  );
}

/// Camera unavailable, for whatever reason.
///
/// Never a bare error code. The person reading this wanted to use the product
/// and cannot, and the only useful screen is one that says why and what to do.
class _Blocked extends StatelessWidget {
  const _Blocked({
    required this.title,
    required this.body,
    required this.onBack,
  });

  final String title;
  final String body;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.ayna;

    return Padding(
      padding: EdgeInsets.all(t.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 40,
            color: AynaColors.captureGuide,
          ),
          SizedBox(height: t.space4),
          Text(
            title,
            style: AynaType.displaySmall.copyWith(color: AynaColors.onClay),
          ),
          SizedBox(height: t.space3),
          Text(
            body,
            style: AynaType.bodyLarge.copyWith(color: AynaColors.onClayMuted),
          ),
          SizedBox(height: t.space6),
          PressScale(
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: AynaColors.onClay,
                side: const BorderSide(color: AynaColors.captureGuide),
                minimumSize: Size.fromHeight(t.minTouch),
              ),
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }
}
