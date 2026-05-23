import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';

import 'login_screen.dart';

Future<void> runSmartStepsApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(_outsidePortraitOrientations);
  await _configureGlobalAudio();
  runApp(const SmartStepsApp());
}

Future<void> _configureGlobalAudio() async {
  try {
    await AudioPlayer.global.setAudioContext(_voiceAudioContext);
  } catch (error, stackTrace) {
    debugPrint('SmartSteps voice global audio context failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class SmartStepsApp extends StatelessWidget {
  const SmartStepsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartSteps',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: GameColors.cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GameColors.safe,
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: GameColors.ink,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
          titleLarge: TextStyle(
            color: GameColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
          bodyMedium: TextStyle(
            color: GameColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
      home: LoginScreen(
        onLogin: (context) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const _SmartStepsLandingPage(),
            ),
          );
        },
      ),
    );
  }
}

class _SmartStepsLandingPage extends StatefulWidget {
  const _SmartStepsLandingPage();

  @override
  State<_SmartStepsLandingPage> createState() => _SmartStepsLandingPageState();
}

class _SmartStepsLandingPageState extends State<_SmartStepsLandingPage> {
  @override
  void initState() {
    super.initState();
    unawaited(_enterLandingViewingMode());
  }

  Future<void> _enterLandingViewingMode() async {
    try {
      await SystemChrome.setPreferredOrientations(_outsidePortraitOrientations);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // Some desktop/test hosts do not expose system chrome controls.
    }
  }

  Future<void> _openLesson() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LessonGameScreen(lesson: lessonOne),
      ),
    );

    if (mounted) {
      unawaited(_enterLandingViewingMode());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE4F7FF), GameColors.cream],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Image.asset(LessonAssets.mascot, width: 54),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _DockLabel('SmartSteps'),
                          Text(
                            'Bài học an toàn cho bé',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(LessonAssets.livingRoom, fit: BoxFit.cover),
                        const _WarmSceneOverlay(),
                        Positioned(
                          left: 18,
                          right: 18,
                          top: 18,
                          child: _GlassPanel(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _DockLabel('Bài 1'),
                                const SizedBox(height: 6),
                                Text(
                                  lessonOne.title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lessonOne.mission,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: 0,
                          child: Image.asset(
                            LessonAssets.kid,
                            width: 210,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PillButton(
                  label: 'Bắt đầu bài học',
                  icon: Icons.play_arrow_rounded,
                  color: GameColors.banana,
                  onPressed: () {
                    unawaited(_openLesson());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum LessonPhase {
  introVideo,
  opening,
  inspectObject,
  correctVideo,
  wrongVideo,
  correct,
  wrong,
  rewardBurst,
  reward,
  parent,
}

enum ChoiceTone { safe, danger }

class GameColors {
  const GameColors._();

  static const cream = Color(0xFFFFF7DF);
  static const sky = Color(0xFFBFE9FF);
  static const mint = Color(0xFFB9F6D3);
  static const banana = Color(0xFFFFE66D);
  static const coral = Color(0xFFFF8A7A);
  static const safe = Color(0xFF58CC8B);
  static const danger = Color(0xFFFFB347);
  static const ink = Color(0xFF25324B);
  static const muted = Color(0xFF697386);
  static const paper = Color(0xFFFFFFFF);
}

class LessonAssets {
  const LessonAssets._();

  static const livingRoom = 'assets/images/living_room.jpg';
  static const kid = 'assets/images/kid.png';
  static const childHappy = 'assets/images/child-happy.png';
  static const childChoking = 'assets/images/child-choking.png';
  static const mother = 'assets/images/mother.png';
  static const ball = 'assets/images/ball.png';
  static const mascot = 'assets/images/mascot.png';
  static const rewardStar = 'assets/images/reward-star.png';
}

class SafetyLesson {
  const SafetyLesson({
    required this.id,
    required this.title,
    required this.topic,
    required this.ageRange,
    required this.sceneTitle,
    required this.mission,
    required this.openingHint,
    required this.inspectQuestion,
    required this.questionVoice,
    required this.videoIntro,
    required this.videoCorrect,
    required this.videoWrong,
    required this.wrongTitle,
    required this.wrongExplanation,
    required this.correctTitle,
    required this.correctExplanation,
    required this.rewardTitle,
    required this.learningGoals,
    required this.choices,
    required this.parentNotes,
  });

  final String id;
  final String title;
  final String topic;
  final String ageRange;
  final String sceneTitle;
  final String mission;
  final String openingHint;
  final String inspectQuestion;
  final LessonVoice questionVoice;
  final LessonVideoCopy videoIntro;
  final LessonVideoCopy videoCorrect;
  final LessonVideoCopy videoWrong;
  final String wrongTitle;
  final String wrongExplanation;
  final String correctTitle;
  final String correctExplanation;
  final String rewardTitle;
  final List<String> learningGoals;
  final List<LessonChoice> choices;
  final ParentNotes parentNotes;
}

class LessonVideoCopy {
  const LessonVideoCopy({
    required this.asset,
    required this.title,
    required this.caption,
    required this.actionLabel,
    required this.skipLabel,
  });

  final String asset;
  final String title;
  final String caption;
  final String actionLabel;
  final String skipLabel;
}

class LessonVoice {
  const LessonVoice({required this.asset, required this.text});

  final String asset;
  final String text;
}

class LessonChoice {
  const LessonChoice({
    required this.id,
    required this.label,
    required this.helper,
    required this.accessibilityLabel,
    required this.imageAsset,
    required this.voice,
    required this.tone,
  });

  final String id;
  final String label;
  final String helper;
  final String accessibilityLabel;
  final String imageAsset;
  final LessonVoice voice;
  final ChoiceTone tone;
}

class ParentNotes {
  const ParentNotes({
    required this.skill,
    required this.practice,
    required this.risk,
  });

  final String skill;
  final String practice;
  final String risk;
}

const correctChoiceId = 'ask-adult';
const _voicePlaybackRate = 0.82;
const _voicePlaybackTimeout = Duration(seconds: 12);
const _voiceStartTimeout = Duration(milliseconds: 1800);
const _voiceSequenceGap = Duration(milliseconds: 360);
const _questionFallbackDuration = Duration(milliseconds: 3600);
const _choiceFallbackDuration = Duration(milliseconds: 2300);
const _outsidePortraitOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
];
final _voiceAudioContext = AudioContext(
  android: const AudioContextAndroid(
    contentType: AndroidContentType.speech,
    usageType: AndroidUsageType.media,
    audioFocus: AndroidAudioFocus.gain,
  ),
);

const lessonOne = SafetyLesson(
  id: 'lesson-1-shiny-round-object',
  title: 'Bài 1: Vật tròn lấp lánh',
  topic: 'An toàn dị vật',
  ageRange: '4-9 tuổi',
  sceneTitle: 'Phòng khách an toàn',
  mission: 'Giúp bé chọn cách xử lý khi thấy vật nhỏ lạ trên sàn.',
  videoIntro: LessonVideoCopy(
    asset: 'assets/videos/lesson1-intro.mp4',
    title: 'Cùng xem tình huống đầu tiên',
    caption:
        'Sau đoạn intro, bé sẽ chọn cách xử lý an toàn ngay trên flash card.',
    actionLabel: 'Bắt đầu intro',
    skipLabel: 'Bỏ qua intro',
  ),
  videoCorrect: LessonVideoCopy(
    asset: 'assets/videos/lesson1-correct.mp4',
    title: 'Cách xử lý an toàn',
    caption: 'Clip này cho bé thấy lựa chọn đúng khi nhặt được vật nhỏ lạ.',
    actionLabel: 'Xem video đúng',
    skipLabel: 'Bỏ qua clip',
  ),
  videoWrong: LessonVideoCopy(
    asset: 'assets/videos/lesson1-wrong.mp4',
    title: 'Dừng lại và sửa lựa chọn',
    caption: 'Clip này nhắc bé vì sao không nên cho vật nhỏ lạ vào miệng.',
    actionLabel: 'Xem video sai',
    skipLabel: 'Bỏ qua clip',
  ),
  openingHint: 'Bấm vào vật lấp lánh',
  inspectQuestion: 'Con sẽ làm gì khi thấy vật nhỏ lạ trên sàn?',
  questionVoice: LessonVoice(
    asset: 'assets/voices/lesson1/question.mp3',
    text: 'Đó không phải là kẹo đâu bé ơi. Con chọn cách an toàn nhé.',
  ),
  wrongTitle: 'Khoan đã bé ơi!',
  wrongExplanation:
      'Vật nhỏ lạ có thể làm mình bị hóc. Mình không đưa vào miệng nhé.',
  correctTitle: 'Con làm đúng rồi!',
  correctExplanation: 'Mang vật lạ đến cho bố mẹ là cách an toàn nhất.',
  rewardTitle: 'Một ngôi sao an toàn cho bé!',
  learningGoals: [
    'Không bỏ vật nhỏ lạ vào miệng.',
    'Biết đưa vật lạ cho người lớn.',
    'Phân biệt đồ ăn được và đồ vật nguy hiểm.',
  ],
  choices: [
    LessonChoice(
      id: 'put-mouth',
      label: 'Cho vào miệng',
      helper: 'Không an toàn',
      accessibilityLabel: 'Cho vật nhỏ vào miệng. Không an toàn.',
      imageAsset: LessonAssets.childChoking,
      voice: LessonVoice(
        asset: 'assets/voices/lesson1/choice-put-mouth-loud.mp3',
        text: 'Cho vật nhỏ vào miệng. Không an toàn.',
      ),
      tone: ChoiceTone.danger,
    ),
    LessonChoice(
      id: correctChoiceId,
      label: 'Đưa cho bố mẹ',
      helper: 'An toàn',
      accessibilityLabel: 'Đưa vật nhỏ cho bố mẹ. Đây là cách an toàn.',
      imageAsset: LessonAssets.mother,
      voice: LessonVoice(
        asset: 'assets/voices/lesson1/choice-ask-adult.mp3',
        text: 'Đưa vật nhỏ cho bố mẹ. Đây là cách an toàn.',
      ),
      tone: ChoiceTone.safe,
    ),
  ],
  parentNotes: ParentNotes(
    skill: 'Bé tập nhận ra vật nhỏ có thể gây nguy hiểm nếu đưa vào miệng.',
    practice:
        'Cùng bé đi quanh nhà, chỉ vào các vật nhỏ và nói: thấy vật lạ thì gọi người lớn.',
    risk:
        'Đồng xu, viên bi, nút áo, pin nhỏ và hạt cứng có thể gây hóc hoặc nghẹt thở.',
  ),
);

class LessonGameScreen extends StatefulWidget {
  const LessonGameScreen({super.key, required this.lesson});

  final SafetyLesson lesson;

  @override
  State<LessonGameScreen> createState() => _LessonGameScreenState();
}

class _LessonGameScreenState extends State<LessonGameScreen> {
  LessonPhase _phase = LessonPhase.introVideo;
  String? _selectedChoiceId;
  bool _parentReadingMode = false;
  Timer? _rewardTimer;

  LessonChoice? get _selectedChoice {
    for (final choice in widget.lesson.choices) {
      if (choice.id == _selectedChoiceId) {
        return choice;
      }
    }
    return null;
  }

  bool get _hasReward {
    return _phase == LessonPhase.reward || _phase == LessonPhase.parent;
  }

  bool get _isVideoPhase {
    return _phase == LessonPhase.introVideo ||
        _phase == LessonPhase.correctVideo ||
        _phase == LessonPhase.wrongVideo;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_enterLessonViewingMode());
  }

  @override
  void dispose() {
    _rewardTimer?.cancel();
    unawaited(_restoreSystemViewingMode());
    super.dispose();
  }

  Future<void> _enterLessonViewingMode() async {
    try {
      await SystemChrome.setPreferredOrientations(_outsidePortraitOrientations);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // Orientation and fullscreen APIs are unavailable on some test/desktop hosts.
    }
  }

  Future<void> _restoreSystemViewingMode() async {
    try {
      await SystemChrome.setPreferredOrientations(_outsidePortraitOrientations);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // Keep dispose best-effort so platform limitations do not break teardown.
    }
  }

  void _restartLesson() {
    _rewardTimer?.cancel();
    setState(() {
      _selectedChoiceId = null;
      _phase = LessonPhase.introVideo;
    });
  }

  void _toggleReadingMode() {
    setState(() {
      _parentReadingMode = !_parentReadingMode;
    });
  }

  void _completeVideo() {
    setState(() {
      switch (_phase) {
        case LessonPhase.introVideo:
          _phase = LessonPhase.inspectObject;
        case LessonPhase.correctVideo:
          _phase = LessonPhase.correct;
        case LessonPhase.wrongVideo:
          _phase = LessonPhase.wrong;
        case LessonPhase.opening:
        case LessonPhase.inspectObject:
        case LessonPhase.correct:
        case LessonPhase.wrong:
        case LessonPhase.rewardBurst:
        case LessonPhase.reward:
        case LessonPhase.parent:
          break;
      }
    });
  }

  void _inspectObject() {
    if (_phase != LessonPhase.opening) {
      return;
    }
    setState(() {
      _phase = LessonPhase.inspectObject;
    });
  }

  void _selectChoice(String choiceId) {
    setState(() {
      _selectedChoiceId = choiceId;
      _phase = choiceId == correctChoiceId
          ? LessonPhase.correctVideo
          : LessonPhase.wrongVideo;
    });
  }

  void _retryChoice() {
    setState(() {
      _selectedChoiceId = null;
      _phase = LessonPhase.inspectObject;
    });
  }

  void _showReward() {
    _rewardTimer?.cancel();
    setState(() {
      _phase = LessonPhase.rewardBurst;
    });

    _rewardTimer = Timer(const Duration(milliseconds: 950), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = LessonPhase.reward;
      });
    });
  }

  void _showParentPanel() {
    setState(() {
      _phase = LessonPhase.parent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    if (_isVideoPhase) {
      return Scaffold(backgroundColor: Colors.black, body: _buildStage(lesson));
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF1B5), GameColors.cream, Color(0xFFE4F7FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GameHeader(
                  lesson: lesson,
                  hasReward: _hasReward,
                  isParentReadingMode: _parentReadingMode,
                  onToggleReadingMode: _toggleReadingMode,
                  onRestart: _restartLesson,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: _buildStage(lesson)),
                      if (_phase == LessonPhase.inspectObject)
                        _QuestionOverlay(
                          lesson: lesson,
                          selectedChoice: _selectedChoice,
                          onSelectChoice: _selectChoice,
                        ),
                      if (_phase == LessonPhase.rewardBurst)
                        const _RewardBurstOverlay(),
                      if (_phase == LessonPhase.reward)
                        _RewardPanel(
                          title: lesson.rewardTitle,
                          onContinue: _showParentPanel,
                        ),
                      if (_phase == LessonPhase.parent)
                        _ParentNotesPanel(notes: lesson.parentNotes),
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

  Widget _buildStage(SafetyLesson lesson) {
    switch (_phase) {
      case LessonPhase.introVideo:
        return _StoryClipStage(
          key: const ValueKey('intro-video'),
          copy: lesson.videoIntro,
          variant: LessonPhase.introVideo,
          onFinished: _completeVideo,
        );
      case LessonPhase.correctVideo:
        return _StoryClipStage(
          key: const ValueKey('correct-video'),
          copy: lesson.videoCorrect,
          variant: LessonPhase.correctVideo,
          onFinished: _completeVideo,
        );
      case LessonPhase.wrongVideo:
        return _StoryClipStage(
          key: const ValueKey('wrong-video'),
          copy: lesson.videoWrong,
          variant: LessonPhase.wrongVideo,
          onFinished: _completeVideo,
        );
      case LessonPhase.opening:
      case LessonPhase.inspectObject:
      case LessonPhase.correct:
      case LessonPhase.wrong:
      case LessonPhase.rewardBurst:
      case LessonPhase.reward:
      case LessonPhase.parent:
        return _SceneStage(
          lesson: lesson,
          phase: _phase,
          onInspectObject: _inspectObject,
          onRetryChoice: _retryChoice,
          onShowReward: _showReward,
        );
    }
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({
    required this.lesson,
    required this.hasReward,
    required this.isParentReadingMode,
    required this.onToggleReadingMode,
    required this.onRestart,
  });

  final SafetyLesson lesson;
  final bool hasReward;
  final bool isParentReadingMode;
  final VoidCallback onToggleReadingMode;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF476070),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lesson.title,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CircleIconButton(
                  label: 'Chơi lại màn',
                  icon: Icons.restart_alt_rounded,
                  onPressed: onRestart,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: isParentReadingMode ? 'Phụ huynh đọc' : 'Bé tự nghe',
                    icon: isParentReadingMode
                        ? Icons.family_restroom_rounded
                        : Icons.volume_up_rounded,
                    onPressed: onToggleReadingMode,
                  ),
                ),
                const SizedBox(width: 10),
                _SafetyDots(isActive: hasReward),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StoryClipStage extends StatefulWidget {
  const _StoryClipStage({
    super.key,
    required this.copy,
    required this.variant,
    required this.onFinished,
  });

  final LessonVideoCopy copy;
  final LessonPhase variant;
  final VoidCallback onFinished;

  @override
  State<_StoryClipStage> createState() => _StoryClipStageState();
}

class _StoryClipStageState extends State<_StoryClipStage> {
  late final VideoPlayerController _videoController;
  bool _hasStartedPlayback = false;
  bool _hasFinishedVideo = false;

  bool get _isWrong => widget.variant == LessonPhase.wrongVideo;
  bool get _isReady => _videoController.value.isInitialized;
  bool get _isPlaying => _videoController.value.isPlaying;

  double get _progress {
    if (!_isReady || _videoController.value.duration.inMilliseconds == 0) {
      return 0;
    }

    final position = _videoController.value.position.inMilliseconds;
    final duration = _videoController.value.duration.inMilliseconds;
    return (position / duration).clamp(0.0, 1.0).toDouble();
  }

  @override
  void initState() {
    super.initState();

    _videoController =
        VideoPlayerController.asset(
            widget.copy.asset,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          )
          ..addListener(_handleVideoTick)
          ..setLooping(false);
    _videoController.initialize().then((_) async {
      if (!mounted) {
        return;
      }

      setState(() {});
      await _autoplayClip();

      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _videoController.removeListener(_handleVideoTick);
    _videoController.dispose();
    super.dispose();
  }

  void _handleVideoTick() {
    if (!mounted) {
      return;
    }

    final value = _videoController.value;
    if (value.isInitialized && !_hasStartedPlayback) {
      unawaited(_autoplayClip());
    }

    final isAtEnd =
        value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 160);

    var shouldFinish = false;
    setState(() {
      shouldFinish = !_hasFinishedVideo && isAtEnd;
      if (shouldFinish) {
        _hasFinishedVideo = true;
      }
    });

    if (shouldFinish) {
      widget.onFinished();
    }
  }

  Future<void> _startClipFromBeginning() async {
    if (!_isReady) {
      return;
    }

    _hasFinishedVideo = false;
    await _videoController.seekTo(Duration.zero);

    try {
      await _videoController.setVolume(1.0);
    } catch (_) {
      // Keep playback usable on platforms that do not expose volume control.
    }

    try {
      await _videoController.setPlaybackSpeed(1.0);
    } catch (_) {
      // Keep the clip usable even if a platform cannot apply playback speed.
    }

    try {
      await _videoController.play();
    } catch (_) {
      // Autoplay can be blocked on some hosts; the clip remains visible.
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _autoplayClip() async {
    if (_hasStartedPlayback || !_isReady) {
      return;
    }

    _hasStartedPlayback = true;
    await _startClipFromBeginning();
  }

  Future<void> _skipClip() async {
    if (_isReady && _videoController.value.isPlaying) {
      await _videoController.pause();
    }
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isWrong ? GameColors.danger : GameColors.safe;
    final aspectRatio = _isReady ? _videoController.value.aspectRatio : 16 / 9;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ColoredBox(
                color: Colors.black,
                child: _isReady
                    ? VideoPlayer(_videoController)
                    : const Center(child: _VideoLoadingBadge()),
              ),
            ),
          ),
          _FullscreenClipControls(
            copy: widget.copy,
            isReady: _isReady,
            isPlaying: _isPlaying,
            progress: _progress,
            accent: accent,
            onSkip: _skipClip,
          ),
        ],
      ),
    );
  }
}

class _FullscreenClipControls extends StatelessWidget {
  const _FullscreenClipControls({
    required this.copy,
    required this.isReady,
    required this.isPlaying,
    required this.progress,
    required this.accent,
    required this.onSkip,
  });

  final LessonVideoCopy copy;
  final bool isReady;
  final bool isPlaying;
  final double progress;
  final Color accent;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final statusLabel = isPlaying
        ? 'Đang chiếu'
        : isReady
        ? 'Sẵn sàng'
        : 'Đang chuẩn bị';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    unawaited(onSkip());
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.52),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: Text(copy.skipLabel),
                ),
              ],
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoLoadingBadge extends StatelessWidget {
  const _VideoLoadingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Đang chuẩn bị video...',
        style: TextStyle(
          color: GameColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SceneStage extends StatelessWidget {
  const _SceneStage({
    required this.lesson,
    required this.phase,
    required this.onInspectObject,
    required this.onRetryChoice,
    required this.onShowReward,
  });

  final SafetyLesson lesson;
  final LessonPhase phase;
  final VoidCallback onInspectObject;
  final VoidCallback onRetryChoice;
  final VoidCallback onShowReward;

  bool get _isObjectActive => phase == LessonPhase.opening;
  bool get _isWrong => phase == LessonPhase.wrong;
  bool get _isCorrect => phase == LessonPhase.correct;
  bool get _showMother {
    return phase == LessonPhase.correct ||
        phase == LessonPhase.rewardBurst ||
        phase == LessonPhase.reward ||
        phase == LessonPhase.parent;
  }

  String get _characterAsset {
    switch (phase) {
      case LessonPhase.wrong:
      case LessonPhase.wrongVideo:
        return LessonAssets.childChoking;
      case LessonPhase.correct:
      case LessonPhase.correctVideo:
      case LessonPhase.rewardBurst:
      case LessonPhase.reward:
      case LessonPhase.parent:
        return LessonAssets.childHappy;
      case LessonPhase.introVideo:
      case LessonPhase.opening:
      case LessonPhase.inspectObject:
        return LessonAssets.kid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StageFrame(
      semanticLabel: lesson.sceneTitle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final compact = width < 430;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset(
                  LessonAssets.livingRoom,
                  fit: BoxFit.cover,
                  alignment: compact ? Alignment.center : Alignment.centerRight,
                ),
              ),
              const Positioned.fill(child: _WarmSceneOverlay()),
              Positioned(
                left: compact ? 20 : width * 0.12,
                bottom: compact ? 26 : 58,
                child: _HazardSpot(
                  isActive: _isObjectActive,
                  hint: lesson.openingHint,
                  onTap: onInspectObject,
                ),
              ),
              Positioned(
                right: compact ? -10 : width * 0.06,
                bottom: compact ? 2 : 18,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.08, 0.04),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    _characterAsset,
                    key: ValueKey(_characterAsset),
                    width: compact ? width * 0.48 : width * 0.36,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (_showMother)
                Positioned(
                  right: compact ? width * 0.32 : width * 0.33,
                  bottom: compact ? 10 : 28,
                  child: _FloatingImage(
                    asset: LessonAssets.mother,
                    width: compact ? width * 0.27 : width * 0.22,
                    delay: const Duration(milliseconds: 220),
                  ),
                ),
              if (_isWrong)
                _ResultPanel(
                  tone: ChoiceTone.danger,
                  label: 'Cùng thử lại',
                  title: lesson.wrongTitle,
                  body: lesson.wrongExplanation,
                  actionLabel: 'Chọn lại',
                  icon: Icons.refresh_rounded,
                  onAction: onRetryChoice,
                ),
              if (_isCorrect)
                _ResultPanel(
                  tone: ChoiceTone.safe,
                  label: 'Rất tốt',
                  title: lesson.correctTitle,
                  body: lesson.correctExplanation,
                  actionLabel: 'Nhận sao',
                  icon: Icons.star_rounded,
                  onAction: onShowReward,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HazardSpot extends StatefulWidget {
  const _HazardSpot({
    required this.isActive,
    required this.hint,
    required this.onTap,
  });

  final bool isActive;
  final String hint;
  final VoidCallback onTap;

  @override
  State<_HazardSpot> createState() => _HazardSpotState();
}

class _HazardSpotState extends State<_HazardSpot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.isActive,
      label: widget.hint,
      child: GestureDetector(
        key: const ValueKey('hazard-spot'),
        onTap: widget.isActive ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pulse = 1 + math.sin(_controller.value * math.pi * 2) * 0.06;
            final lift = math.sin(_controller.value * math.pi * 2) * -5;

            return Transform.translate(
              offset: Offset(0, widget.isActive ? lift : 0),
              child: Transform.scale(
                scale: widget.isActive ? pulse : 1,
                child: child,
              ),
            );
          },
          child: SizedBox(
            width: 118,
            height: 132,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                if (widget.isActive)
                  Positioned(
                    bottom: 82,
                    child: _HintBubble(label: widget.hint),
                  ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GameColors.banana.withValues(alpha: 0.26),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.72),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GameColors.banana.withValues(alpha: 0.32),
                          blurRadius: widget.isActive ? 28 : 12,
                          spreadRadius: widget.isActive ? 8 : 0,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  child: Image.asset(
                    LessonAssets.ball,
                    width: 65,
                    fit: BoxFit.contain,
                  ),
                ),
                const Positioned(
                  right: 18,
                  bottom: 54,
                  child: _Sparkle(size: 11),
                ),
                const Positioned(
                  left: 18,
                  bottom: 22,
                  child: _Sparkle(size: 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintBubble extends StatelessWidget {
  const _HintBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2425324B),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: GameColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

class _QuestionOverlay extends StatefulWidget {
  const _QuestionOverlay({
    required this.lesson,
    required this.selectedChoice,
    required this.onSelectChoice,
  });

  final SafetyLesson lesson;
  final LessonChoice? selectedChoice;
  final ValueChanged<String> onSelectChoice;

  @override
  State<_QuestionOverlay> createState() => _QuestionOverlayState();
}

class _QuestionOverlayState extends State<_QuestionOverlay> {
  late final AudioPlayer _voicePlayer;
  String? _activeNarrationId = 'question';
  bool _hasPlayedOpeningNarration = false;
  int _openingSequenceId = 0;
  int _voiceRequestId = 0;

  List<({String id, String asset, String text})> get _narrationQueue {
    return [
      (
        id: 'question',
        asset: widget.lesson.questionVoice.asset,
        text: widget.lesson.questionVoice.text,
      ),
      ...widget.lesson.choices.map(
        (choice) =>
            (id: choice.id, asset: choice.voice.asset, text: choice.voice.text),
      ),
    ];
  }

  Duration _fallbackDurationFor(String id) {
    return id == 'question'
        ? _questionFallbackDuration
        : _choiceFallbackDuration;
  }

  @override
  void initState() {
    super.initState();
    _voicePlayer = AudioPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_playOpeningNarrationOnce());
    });
  }

  @override
  void dispose() {
    _voiceRequestId++;
    unawaited(_stopAndDisposeVoicePlayer());
    super.dispose();
  }

  Future<void> _stopAndDisposeVoicePlayer() async {
    try {
      await _voicePlayer.stop();
    } catch (_) {
      // Audio plugin calls can fail on test/desktop hosts.
    }

    try {
      await _voicePlayer.dispose();
    } catch (_) {
      // Keep teardown best-effort on hosts without audio support.
    }
  }

  Future<void> _stopVoicePlayer() async {
    try {
      await _voicePlayer.stop();
    } catch (error, stackTrace) {
      debugPrint('SmartSteps voice stop failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _prepareVoicePlayer() async {
    try {
      await _voicePlayer.setAudioContext(_voiceAudioContext);
    } catch (error, stackTrace) {
      debugPrint('SmartSteps voice audio context failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _voicePlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _voicePlayer.setReleaseMode(ReleaseMode.stop);
      await _voicePlayer.setVolume(1.0);
    } catch (error, stackTrace) {
      debugPrint('SmartSteps voice player setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _setVoicePlaybackRate() async {
    try {
      await _voicePlayer.setPlaybackRate(_voicePlaybackRate);
    } catch (error, stackTrace) {
      debugPrint('SmartSteps voice playback rate failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _precacheNarrationAssets() async {
    for (final item in _narrationQueue) {
      if (!mounted) {
        return;
      }

      final assetPath = item.asset.replaceFirst('assets/', '');
      try {
        await rootBundle.load(item.asset);
        await _voicePlayer.audioCache.loadPath(assetPath);
        debugPrint('SmartSteps voice preloaded: $assetPath');
      } catch (error, stackTrace) {
        debugPrint('SmartSteps voice preload failed for $assetPath: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _playOpeningNarrationOnce() async {
    if (_hasPlayedOpeningNarration) {
      return;
    }

    _hasPlayedOpeningNarration = true;
    final sequenceId = ++_openingSequenceId;

    await _precacheNarrationAssets();

    for (final item in _narrationQueue) {
      if (!mounted || sequenceId != _openingSequenceId) {
        return;
      }

      final didStart = await _playNarrationAsset(
        item.id,
        item.asset,
        text: item.text,
        clearWhenFinished: false,
      );
      if (!mounted || sequenceId != _openingSequenceId) {
        return;
      }

      if (!didStart) {
        await Future<void>.delayed(_fallbackDurationFor(item.id));
      }

      if (!mounted || sequenceId != _openingSequenceId) {
        return;
      }
      await Future<void>.delayed(_voiceSequenceGap);
    }

    if (mounted && sequenceId == _openingSequenceId) {
      setState(() {
        _activeNarrationId = null;
      });
    }
  }

  Future<void> _playNarration(String id, String asset, String text) async {
    _openingSequenceId++;
    await _playNarrationAsset(id, asset, text: text, clearWhenFinished: true);
  }

  void _focusNarration(String id, String asset) {
    unawaited(_playNarration(id, asset, _narrationTextFor(id)));
  }

  String _narrationTextFor(String id) {
    if (id == 'question') {
      return widget.lesson.questionVoice.text;
    }

    for (final choice in widget.lesson.choices) {
      if (choice.id == id) {
        return choice.voice.text;
      }
    }

    return widget.lesson.questionVoice.text;
  }

  Future<bool> _playNarrationAsset(
    String id,
    String asset, {
    required String text,
    required bool clearWhenFinished,
  }) async {
    final requestId = ++_voiceRequestId;
    final assetPath = asset.replaceFirst('assets/', '');

    setState(() {
      _activeNarrationId = id;
    });

    try {
      await _stopVoicePlayer();
      if (!mounted || requestId != _voiceRequestId) {
        return false;
      }

      await rootBundle.load(asset);
      if (!mounted || requestId != _voiceRequestId) {
        return false;
      }
      await _prepareVoicePlayer();
      if (!mounted || requestId != _voiceRequestId) {
        return false;
      }
      await _voicePlayer.setSourceAsset(assetPath, mimeType: 'audio/mpeg');
      if (!mounted || requestId != _voiceRequestId) {
        return false;
      }
      final startedFuture = _voicePlayer.onPlayerStateChanged
          .where((state) => state == PlayerState.playing)
          .first
          .timeout(_voiceStartTimeout, onTimeout: () => _voicePlayer.state);
      final completeFuture = _voicePlayer.onPlayerComplete.first.timeout(
        _voicePlaybackTimeout,
        onTimeout: () {},
      );
      await _voicePlayer.resume();
      final startState = await startedFuture;
      final didStart =
          startState == PlayerState.playing ||
          _voicePlayer.state == PlayerState.playing;
      if (!didStart) {
        debugPrint('SmartSteps voice did not enter playing state: $assetPath');
        return false;
      }
      await _setVoicePlaybackRate();
      debugPrint('SmartSteps voice playing: $assetPath');
      final minimumHold = _fallbackDurationFor(id);
      final stopwatch = Stopwatch()..start();
      await completeFuture;
      stopwatch.stop();
      if (stopwatch.elapsed < minimumHold &&
          mounted &&
          requestId == _voiceRequestId) {
        await Future<void>.delayed(minimumHold - stopwatch.elapsed);
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('SmartSteps voice playback failed for $assetPath: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (requestId == _voiceRequestId) {
        await _stopVoicePlayer();
      }
      return false;
    } finally {
      if (mounted && requestId == _voiceRequestId) {
        setState(() {
          if (clearWhenFinished) {
            _activeNarrationId = null;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;

          return AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: EdgeInsets.all(isLandscape ? 10 : 14),
              decoration: BoxDecoration(
                color: const Color(0xFF161C2C).withValues(alpha: 0.52),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isLandscape ? 30 : 34),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: _QuestionPanel(
                      lesson: widget.lesson,
                      selectedChoice: widget.selectedChoice,
                      activeNarrationId: _activeNarrationId,
                      isLandscape: isLandscape,
                      onVoiceFocus: _focusNarration,
                      onSelectChoice: widget.onSelectChoice,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.lesson,
    required this.selectedChoice,
    required this.activeNarrationId,
    required this.isLandscape,
    required this.onVoiceFocus,
    required this.onSelectChoice,
  });

  final SafetyLesson lesson;
  final LessonChoice? selectedChoice;
  final String? activeNarrationId;
  final bool isLandscape;
  final void Function(String id, String asset) onVoiceFocus;
  final ValueChanged<String> onSelectChoice;

  @override
  Widget build(BuildContext context) {
    final panelRadius = isLandscape ? 30.0 : 34.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactCards = isLandscape || constraints.maxWidth < 430;
        final choices = lesson.choices.map((choice) {
          return _ChoiceCard(
            choice: choice,
            isSelected: selectedChoice?.id == choice.id,
            isNarrating: activeNarrationId == choice.id,
            isCompact: compactCards,
            onVoiceFocus: () => onVoiceFocus(choice.id, choice.voice.asset),
            onSelect: () => onSelectChoice(choice.id),
          );
        }).toList();

        final prompt = _QuestionPrompt(
          lesson: lesson,
          isActive: activeNarrationId == 'question',
          isCompact: compactCards,
          onVoiceFocus: () =>
              onVoiceFocus('question', lesson.questionVoice.asset),
        );

        final body = isLandscape
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: math.min(310.0, constraints.maxWidth * 0.34),
                    child: prompt,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: choices.first),
                        const SizedBox(width: 14),
                        Expanded(child: choices.last),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  prompt,
                  const SizedBox(height: 14),
                  choices.first,
                  const SizedBox(height: 14),
                  choices.last,
                ],
              );

        return Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: isLandscape ? 360 : 640),
          padding: EdgeInsets.fromLTRB(
            isLandscape ? 14 : 18,
            isLandscape ? 14 : 18,
            isLandscape ? 14 : 18,
            isLandscape ? 14 : 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(panelRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.84),
              width: 5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D0F1828),
                blurRadius: 50,
                offset: Offset(0, 24),
              ),
            ],
          ),
          child: SingleChildScrollView(child: body),
        );
      },
    );
  }
}

class _QuestionPrompt extends StatelessWidget {
  const _QuestionPrompt({
    required this.lesson,
    required this.isActive,
    required this.isCompact,
    required this.onVoiceFocus,
  });

  final SafetyLesson lesson;
  final bool isActive;
  final bool isCompact;
  final VoidCallback onVoiceFocus;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isActive ? 1.02 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(LessonAssets.mascot, width: isCompact ? 54 : 74),
          SizedBox(width: isCompact ? 9 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _DockLabel('Nghe rồi chọn'),
                const SizedBox(height: 4),
                Text(
                  lesson.inspectQuestion,
                  style: isCompact
                      ? const TextStyle(
                          color: GameColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        )
                      : Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _VoiceButton(
            label: 'Nghe câu hỏi',
            isActive: isActive,
            onPressed: onVoiceFocus,
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.isSelected,
    required this.isNarrating,
    required this.isCompact,
    required this.onVoiceFocus,
    required this.onSelect,
  });

  final LessonChoice choice;
  final bool isSelected;
  final bool isNarrating;
  final bool isCompact;
  final VoidCallback onVoiceFocus;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isDanger = choice.tone == ChoiceTone.danger;
    final accent = isDanger ? GameColors.danger : GameColors.safe;
    final helperBackground = accent.withValues(alpha: isDanger ? 0.34 : 0.42);
    final imageAreaHeight = isCompact ? 112.0 : 150.0;
    final imageHeight = isCompact ? 104.0 : 140.0;
    final minCardHeight = isCompact ? 192.0 : 238.0;

    return Semantics(
      button: true,
      selected: isSelected,
      label: choice.accessibilityLabel,
      child: AnimatedScale(
        scale: isNarrating ? 1.035 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: activeCardOpacity(isNarrating),
          duration: const Duration(milliseconds: 180),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSelect,
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                constraints: BoxConstraints(minHeight: minCardHeight),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isNarrating
                        ? GameColors.banana
                        : isSelected
                        ? accent
                        : Colors.white.withValues(alpha: 0.76),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(
                        alpha: isNarrating ? 0.22 : 0.12,
                      ),
                      blurRadius: isNarrating ? 30 : 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: imageAreaHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.78),
                                accent.withValues(
                                  alpha: isDanger ? 0.15 : 0.20,
                                ),
                              ],
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Positioned(
                                bottom: 11,
                                child: Container(
                                  width: 150,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: GameColors.ink.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                child: AnimatedSlide(
                                  offset: isNarrating
                                      ? const Offset(0, -0.06)
                                      : Offset.zero,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutBack,
                                  child: Image.asset(
                                    choice.imageAsset,
                                    height: imageHeight,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
                          child: Column(
                            children: [
                              Text(
                                choice.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: GameColors.ink,
                                  fontSize: isCompact ? 18 : 21,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: helperBackground,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  choice.helper,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDanger
                                        ? const Color(0xFF543104)
                                        : const Color(0xFF214532),
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _VoiceButton(
                        label: 'Nghe lựa chọn ${choice.label}',
                        isActive: isNarrating,
                        onPressed: onVoiceFocus,
                      ),
                    ),
                    if (isNarrating)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: GameColors.banana.withValues(
                                    alpha: 0.7,
                                  ),
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double activeCardOpacity(bool isNarrating) => isNarrating ? 1 : 0.98;
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.tone,
    required this.label,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.icon,
    required this.onAction,
  });

  final ChoiceTone tone;
  final String label;
  final String title;
  final String body;
  final String actionLabel;
  final IconData icon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final accent = tone == ChoiceTone.safe
        ? GameColors.safe
        : GameColors.danger;

    return Positioned(
      left: 18,
      right: 18,
      top: 20,
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        child: _GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockLabel(label),
              const SizedBox(height: 6),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              _PillButton(
                label: actionLabel,
                icon: icon,
                color: accent,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardBurstOverlay extends StatefulWidget {
  const _RewardBurstOverlay();

  @override
  State<_RewardBurstOverlay> createState() => _RewardBurstOverlayState();
}

class _RewardBurstOverlayState extends State<_RewardBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale =
                0.2 + Curves.easeOutBack.transform(_controller.value) * 1.9;
            final opacity = _controller.value < 0.8
                ? 1.0
                : (1 - ((_controller.value - 0.8) / 0.2))
                      .clamp(0.0, 1.0)
                      .toDouble();
            final rotation = -0.22 + _controller.value * 0.58;

            return Container(
              color: GameColors.cream.withValues(alpha: 0.10),
              alignment: Alignment.center,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(scale: scale, child: child),
                ),
              ),
            );
          },
          child: Image.asset(LessonAssets.rewardStar, width: 150),
        ),
      ),
    );
  }
}

class _RewardPanel extends StatelessWidget {
  const _RewardPanel({required this.title, required this.onContinue});

  final String title;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: _GlassPanel(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Image.asset(LessonAssets.rewardStar, width: 86),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _DockLabel('Phần thưởng'),
                  const SizedBox(height: 5),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _PillButton(
                    label: 'Xem cùng ba mẹ',
                    icon: Icons.groups_rounded,
                    color: GameColors.safe,
                    onPressed: onContinue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentNotesPanel extends StatelessWidget {
  const _ParentNotesPanel({required this.notes});

  final ParentNotes notes;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: _GlassPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DockLabel('Góc phụ huynh'),
            const SizedBox(height: 10),
            _ParentNoteRow(
              icon: Icons.psychology_alt_rounded,
              title: 'Kỹ năng',
              body: notes.skill,
            ),
            const SizedBox(height: 9),
            _ParentNoteRow(
              icon: Icons.location_searching_rounded,
              title: 'Luyện tập',
              body: notes.practice,
            ),
            const SizedBox(height: 9),
            _ParentNoteRow(
              icon: Icons.health_and_safety_rounded,
              title: 'Cần chú ý',
              body: notes.risk,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentNoteRow extends StatelessWidget {
  const _ParentNoteRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: GameColors.mint.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: GameColors.ink, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    color: GameColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StageFrame extends StatelessWidget {
  const _StageFrame({required this.child, this.semanticLabel});

  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final frame = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GameColors.sky,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.74),
          width: 7,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2425324B),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );

    if (semanticLabel == null) {
      return frame;
    }

    return Semantics(label: semanticLabel, child: frame);
  }
}

class _WarmSceneOverlay extends StatelessWidget {
  const _WarmSceneOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            GameColors.cream.withValues(alpha: 0.60),
            Colors.white.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.54, 0.7),
            radius: 0.55,
            colors: [
              GameColors.banana.withValues(alpha: 0.34),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.76),
              width: 4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2425324B),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = color ?? Colors.white.withValues(alpha: 0.78);

    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: background,
        foregroundColor: GameColors.ink,
        disabledBackgroundColor: background.withValues(alpha: 0.58),
        disabledForegroundColor: GameColors.ink.withValues(alpha: 0.48),
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.82),
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          fixedSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white.withValues(alpha: 0.82),
          foregroundColor: GameColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.82),
              width: 3,
            ),
          ),
        ),
        child: Icon(icon, size: 24),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: AnimatedScale(
        scale: isActive ? 1.08 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(50, 50),
            fixedSize: const Size(50, 50),
            padding: EdgeInsets.zero,
            backgroundColor: isActive
                ? GameColors.banana
                : GameColors.banana.withValues(alpha: 0.92),
            foregroundColor: GameColors.ink,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.88),
                width: 4,
              ),
            ),
          ),
          child: const Icon(Icons.volume_up_rounded, size: 25),
        ),
      ),
    );
  }
}

class _SafetyDots extends StatelessWidget {
  const _SafetyDots({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.80),
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F25324B),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SafetyDot(
            color: const Color(0xFFFF6B6B),
            isActive: isActive,
            delay: 0,
          ),
          const SizedBox(width: 8),
          _SafetyDot(color: GameColors.safe, isActive: isActive, delay: 100),
          const SizedBox(width: 8),
          _SafetyDot(color: GameColors.banana, isActive: isActive, delay: 200),
        ],
      ),
    );
  }
}

class _SafetyDot extends StatefulWidget {
  const _SafetyDot({
    required this.color,
    required this.isActive,
    required this.delay,
  });

  final Color color;
  final bool isActive;
  final int delay;

  @override
  State<_SafetyDot> createState() => _SafetyDotState();
}

class _SafetyDotState extends State<_SafetyDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = widget.isActive ? -3 * _controller.value : 0.0;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x2425324B),
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockLabel extends StatelessWidget {
  const _DockLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF476070),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.7,
        height: 1,
      ),
    );
  }
}

class _Sparkle extends StatefulWidget {
  const _Sparkle({required this.size});

  final double size;

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.7 + _controller.value * 0.55,
          child: Opacity(
            opacity: 0.42 + _controller.value * 0.55,
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7A8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFF7A8).withValues(alpha: 0.30),
              blurRadius: 9,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingImage extends StatefulWidget {
  const _FloatingImage({
    required this.asset,
    required this.width,
    required this.delay,
  });

  final String asset;
  final double width;
  final Duration delay;

  @override
  State<_FloatingImage> createState() => _FloatingImageState();
}

class _FloatingImageState extends State<_FloatingImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = math.sin(_controller.value * math.pi) * -5;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Image.asset(
        widget.asset,
        width: widget.width,
        fit: BoxFit.contain,
      ),
    );
  }
}
