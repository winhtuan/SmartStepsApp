import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartsteps/main.dart';
import 'package:smartsteps/models/situation.dart';
import 'package:smartsteps/services/situation_service.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late _FakeVideoPlayerPlatform fakeVideoPlatform;

  setUp(() {
    fakeVideoPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideoPlatform;
  });

  testWidgets('safe lesson flow uses backend API data', (tester) async {
    final situationService = _FakeSituationService();

    await tester.pumpWidget(
      SmartStepsApp(
        situationService: situationService,
        showPremiumOfferAfterLogin: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('login-submit-button')));
    await tester.pumpAndSettle();

    expect(situationService.detailCalls, 0);
    expect(find.byKey(const ValueKey('island-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('island-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('island-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('situation-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('situation-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('situation-1')));
    await tester.pumpAndSettle();

    expect(situationService.detailCalls, 1);
    expect(find.text(_fakeSummary.title), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('start-lesson-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Bỏ qua intro'), findsOneWidget);
    expect(fakeVideoPlatform.playCalls, 0);

    await tester.tap(find.text('Bỏ qua intro'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text(_fakeFlashcard.question), findsOneWidget);

    await tester.tap(find.text(_fakeFlashcard.optionB));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('Bỏ qua clip'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Con làm đúng rồi!'), findsOneWidget);

    await tester.tap(find.text('Nhận sao'));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Kid knows API safety! +1 Safety Star'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('premium offer close button appears after delay', (tester) async {
    final situationService = _FakeSituationService();

    await tester.pumpWidget(SmartStepsApp(situationService: situationService));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('SMARTSTEPS\nPREMIUM'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('premium-offer-close-button')),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('premium-offer-close-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('premium-offer-close-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('island-1')), findsOneWidget);
  });
}

final _fakeSummary = SituationSummary(
  situationId: 1,
  islandId: 1,
  islandName: 'API Island',
  title: 'API Lesson',
  intro: 'Loaded from backend API',
  orderIndex: 1,
  status: 'Published',
);

final _fakeIsland = IslandSummary(
  islandId: 1,
  name: 'API Island',
  orderIndex: 1,
  status: 'Active',
  situationCount: 2,
);

final _otherIsland = IslandSummary(
  islandId: 2,
  name: 'Another Island',
  orderIndex: 2,
  status: 'Active',
  situationCount: 1,
);

final _secondSummary = SituationSummary(
  situationId: 2,
  islandId: 1,
  islandName: 'API Island',
  title: 'Second API Lesson',
  intro: 'Same island lesson',
  orderIndex: 2,
  status: 'Published',
);

final _otherIslandSummary = SituationSummary(
  situationId: 3,
  islandId: 2,
  islandName: 'Another Island',
  title: 'Other Island Lesson',
  intro: 'Another island lesson',
  orderIndex: 1,
  status: 'Published',
);

final _fakeFlashcard = Flashcard(
  flashcardId: 1,
  question: 'What should the kid do?',
  optionA: 'Unsafe choice',
  optionB: 'Ask an adult',
  correctAnswer: 'B',
  correctFeedback: 'Correct from API',
  wrongFeedback: 'Wrong from API',
);

final _fakeDetail = SituationDetail(
  situationId: _fakeSummary.situationId,
  islandId: _fakeSummary.islandId,
  islandName: _fakeSummary.islandName,
  title: _fakeSummary.title,
  intro: _fakeSummary.intro,
  orderIndex: _fakeSummary.orderIndex,
  status: _fakeSummary.status,
  steps: const [
    SituationStep(
      stepId: 1,
      stepType: 'Intro',
      orderIndex: 1,
      content: 'Intro content from API.',
    ),
    SituationStep(
      stepId: 2,
      stepType: 'Flashcard',
      orderIndex: 2,
      content: 'Flashcard content from API.',
    ),
    SituationStep(
      stepId: 3,
      stepType: 'Story',
      orderIndex: 3,
      content: 'Wrong content from API.',
    ),
    SituationStep(
      stepId: 4,
      stepType: 'Result',
      orderIndex: 4,
      content:
          'Good outcome from API. Reward: Kid knows API safety! +1 Safety Star.',
    ),
  ],
  flashcard: _fakeFlashcard,
  skills: const [
    SituationSkill(
      skillId: 1,
      name: 'API Skill',
      description: 'API skill description',
    ),
  ],
  parentReview: const ParentReviewQuestion(
    questionId: 1,
    skillId: 1,
    questionText: 'Practice from API',
    suggestedActivity: 'Risk from API',
  ),
);

class _FakeSituationService extends SituationService {
  _FakeSituationService() : super(baseUrl: 'http://api.test');

  int detailCalls = 0;

  @override
  Future<List<IslandSummary>> getIslands() async => [_fakeIsland, _otherIsland];

  @override
  Future<List<SituationSummary>> getIslandSituations(int islandId) async {
    return switch (islandId) {
      1 => [_fakeSummary, _secondSummary],
      2 => [_otherIslandSummary],
      _ => const [],
    };
  }

  @override
  Future<SituationDetail> getSituationDetail(int situationId) async {
    detailCalls += 1;
    return _fakeDetail;
  }
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
