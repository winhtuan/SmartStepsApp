import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartsteps/main.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late _FakeVideoPlayerPlatform fakeVideoPlatform;

  setUp(() {
    fakeVideoPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideoPlatform;
  });

  testWidgets('safe lesson flow reaches reward panel', (tester) async {
    await tester.pumpWidget(const SmartStepsApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('ĐĂNG NHẬP'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Bắt đầu bài học'), findsOneWidget);

    await tester.tap(find.text('Bắt đầu bài học'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text(lessonOne.videoIntro.skipLabel), findsOneWidget);
    expect(fakeVideoPlatform.playCalls, 1);

    await tester.tap(find.text(lessonOne.videoIntro.skipLabel));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text(lessonOne.inspectQuestion), findsOneWidget);

    await tester.tap(find.text(lessonOne.choices.last.label));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text(lessonOne.videoCorrect.skipLabel));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text(lessonOne.correctTitle), findsOneWidget);

    await tester.tap(find.text('Nhận sao'));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text(lessonOne.rewardTitle), findsOneWidget);
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 1;
  int playCalls = 0;
  final Map<int, StreamController<VideoEvent>> _eventControllers = {};
  final Map<int, Duration> _positions = {};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextPlayerId++;
    final controller = StreamController<VideoEvent>.broadcast();
    _eventControllers[playerId] = controller;
    _positions[playerId] = Duration.zero;

    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    scheduleMicrotask(() {
      _eventControllers[playerId]?.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 3),
          size: const Size(16, 9),
        ),
      );
    });

    return _eventControllers[playerId]!.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    await _eventControllers.remove(playerId)?.close();
    _positions.remove(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    playCalls += 1;
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return ColoredBox(
      key: ValueKey('fake-video-${options.playerId}'),
      color: Colors.black,
    );
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
