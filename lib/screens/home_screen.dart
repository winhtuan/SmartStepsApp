import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:smartsteps/models/child_profile.dart';
import 'package:smartsteps/models/situation.dart';
import 'package:smartsteps/services/situation_service.dart';
import 'package:video_player/video_player.dart';

import '../services/supabase_config.dart';
import '../services/app_audio_controller.dart';
import '../services/local_profile_storage.dart';
import '../theme/duo_theme.dart';
import '../utils/constants.dart';
import '../utils/platform_environment.dart';
import '../widgets/duo_components.dart';
import '../widgets/smartsteps_press_effect.dart';
import 'app_feedback_dialog.dart';
import 'learn_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'quick_review_screen.dart';
import 'register_screen.dart';

Future<void> runSmartStepsApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(_outsidePortraitOrientations);
  await initializeSupabaseIfConfigured();
  await _configureGlobalAudio();
  runApp(SmartStepsApp(enableAudio: true));
}

Future<void> _configureGlobalAudio() async {
  try {
    await AudioPlayer.global.setAudioContext(_voiceAudioContext);
  } catch (error, stackTrace) {
    debugPrint('SmartSteps voice global audio context failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class SmartStepsApp extends StatefulWidget {
  SmartStepsApp({
    super.key,
    SituationService? situationService,
    LocalProfileStorage? profileStorage,
    this.showPremiumOfferAfterLogin = false,
    this.showInitialSurveyAfterLogin = true,
    this.enableAudio = false,
  }) : situationService = situationService ?? SituationService(),
       profileStorage = profileStorage ?? const LocalProfileStorage();

  final SituationService situationService;
  final LocalProfileStorage profileStorage;
  final bool showPremiumOfferAfterLogin;
  final bool showInitialSurveyAfterLogin;
  final bool enableAudio;

  @override
  State<SmartStepsApp> createState() => _SmartStepsAppState();
}

class _SmartStepsAppState extends State<SmartStepsApp> {
  final SmartStepsAudioController _audioController =
      SmartStepsAudioController();
  bool _hasCompletedInitialSurvey = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.enableAudio) {
        unawaited(_audioController.startBackgroundMusic());
      }
    });
  }

  @override
  void dispose() {
    _audioController.dispose();
    super.dispose();
  }

  void _openCatalog(NavigatorState navigator) {
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SmartStepsCatalogPage(
          situationService: widget.situationService,
          profileStorage: widget.profileStorage,
          showPremiumOffer: widget.showPremiumOfferAfterLogin,
        ),
      ),
    );
  }

  void _handleLogin(BuildContext context) {
    if (widget.enableAudio) {
      unawaited(_audioController.ensureBackgroundMusicPlaying());
    }
    unawaited(_handleLoginAsync(Navigator.of(context)));
  }

  void _handleRegistrationCompleted(BuildContext context) {
    if (widget.enableAudio) {
      unawaited(_audioController.ensureBackgroundMusicPlaying());
    }
    _openCatalog(Navigator.of(context));
  }

  Future<void> _handleLoginAsync(NavigatorState navigator) async {
    final hasProfile = await widget.profileStorage.hasProfile();
    if (!mounted) {
      return;
    }

    final shouldShowOnboarding =
        widget.showInitialSurveyAfterLogin &&
        !_hasCompletedInitialSurvey &&
        !hasProfile;
    if (!shouldShowOnboarding) {
      _openCatalog(navigator);
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (registrationContext) => RegisterScreen(
          profileStorage: widget.profileStorage,
          onRegistrationCompleted: (context) {
            _hasCompletedInitialSurvey = true;
            _openCatalog(Navigator.of(registrationContext));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartSteps',
      theme: DuoTheme.light,
      home: LoginScreen(
        profileStorage: widget.profileStorage,
        onLogin: _handleLogin,
        onRegistrationCompleted: _handleRegistrationCompleted,
      ),
    );

    if (!widget.enableAudio) {
      return app;
    }

    return SmartStepsAudioScope(controller: _audioController, child: app);
  }
}

class SmartStepsCatalogPage extends StatefulWidget {
  const SmartStepsCatalogPage({
    super.key,
    required this.situationService,
    required this.profileStorage,
    this.showPremiumOffer = false,
  });

  final SituationService situationService;
  final LocalProfileStorage profileStorage;
  final bool showPremiumOffer;

  @override
  State<SmartStepsCatalogPage> createState() => _SmartStepsCatalogPageState();
}

class _SmartStepsCatalogPageState extends State<SmartStepsCatalogPage>
    with WidgetsBindingObserver {
  List<_IslandCatalogEntry> _islands = _fallbackIslandEntries;
  List<SituationSummary> _situations = const [];
  int? _selectedIslandId;
  int _selectedTabIndex = 0;
  SafetyLesson? _activeLesson;
  bool _isLoadingCatalog = false;
  bool _isLoadingIslandSituations = false;
  int? _loadingSituationId;
  String? _catalogError;
  ChildProfile? _profile;
  bool _isFeedbackPromptOpen = false;

  SituationService get _situationService => widget.situationService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enterCatalogViewingMode());
    unawaited(_loadProfile());
    unawaited(_loadCatalog());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          SmartStepsAudioScope.maybeOf(context)?.ensureBackgroundMusicPlaying(),
        );
        unawaited(_showStartupPrompts());
      }
    });
  }

  Future<void> _showStartupPrompts() async {
    if (widget.showPremiumOffer) {
      await _showPremiumOfferIfNeeded();
    }

    await _maybeShowFeedbackAfterFirstExit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.profileStorage.markFirstExitObserved());
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeShowFeedbackAfterFirstExit());
    }
  }

  Future<void> _maybeShowFeedbackAfterFirstExit() async {
    if (_isFeedbackPromptOpen) {
      return;
    }

    final shouldPrompt = await widget.profileStorage
        .shouldPromptFeedbackAfterFirstExit();
    if (!mounted || !shouldPrompt) {
      return;
    }

    _isFeedbackPromptOpen = true;
    await widget.profileStorage.markFirstExitFeedbackPromptShown();
    if (!mounted) {
      _isFeedbackPromptOpen = false;
      return;
    }

    final submitted = await showAppFeedbackDialog(
      context,
      profileStorage: widget.profileStorage,
      source: 'after_first_exit',
    );

    _isFeedbackPromptOpen = false;
    if (!mounted || submitted != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã lưu đánh giá. Cảm ơn phản hồi của bạn.'),
      ),
    );
  }

  Future<void> _loadProfile() async {
    final profile = await widget.profileStorage.readProfile();
    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
    });
  }

  Future<void> _showPremiumOfferIfNeeded() async {
    final profile = _profile ?? await widget.profileStorage.readProfile();
    if (!mounted || (profile?.isPremium ?? false)) {
      return;
    }

    await _showPremiumOffer();
  }

  Future<void> _showPremiumOffer() async {
    // 1. Hiển thị popup toán học bảo vệ trước
    final isParent = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Bắt buộc phải nhập hoặc bấm hủy
      builder: (_) => const _ParentalGateDialog(),
    );

    // 2. Nếu trả lời sai hoặc bấm Hủy thì dừng lại, không hiện form nhập mã
    if (isParent != true) {
      return;
    }

    if (!mounted) return;

    // 3. Nếu đúng, tiếp tục hiển thị popup Premium Offer ban đầu
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PremiumOfferDialog(
        profileStorage: widget.profileStorage,
        onPremiumActivated: (profile) {
          setState(() {
            _profile = profile;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã nâng cấp lên Premium.')),
          );
        },
      ),
    );
  }

  void _showPremiumRequired(SituationSummary summary) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${summary.title} cần Premium. Nhập mã PREMIUM để mở khóa.',
        ),
      ),
    );
    unawaited(_showPremiumOffer());
  }

  Future<void> _enterCatalogViewingMode() async {
    try {
      await SystemChrome.setPreferredOrientations(_outsidePortraitOrientations);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // Some desktop/test hosts do not expose system chrome controls.
    }
  }

  Future<void> _loadCatalog() async {
    if (!_situationService.isEnabled) {
      setState(() {
        _islands = _fallbackIslandEntries;
        _situations = const [];
        _selectedIslandId = null;
        _activeLesson = null;
        _isLoadingCatalog = false;
        _isLoadingIslandSituations = false;
        _catalogError = null;
      });
      return;
    }

    setState(() {
      _isLoadingCatalog = true;
      _isLoadingIslandSituations = false;
      _catalogError = null;
      _activeLesson = null;
      _loadingSituationId = null;
    });

    try {
      final islands = await _situationService.getIslands();
      if (!mounted) {
        return;
      }

      setState(() {
        _islands = islands.isEmpty
            ? _fallbackIslandEntries
            : islands
                  .map(_IslandCatalogEntry.fromSummary)
                  .toList(growable: false);
        _situations = const [];
        _selectedIslandId = null;
        _activeLesson = null;
        _isLoadingCatalog = false;
        _catalogError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('SmartSteps situation catalog failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      setState(() {
        _islands = _fallbackIslandEntries;
        _situations = const [];
        _selectedIslandId = null;
        _activeLesson = null;
        _isLoadingCatalog = false;
        _isLoadingIslandSituations = false;
        _catalogError = null;
      });
    }
  }

  void _selectIsland(_IslandCatalogEntry island) {
    setState(() {
      _selectedIslandId = island.islandId;
      _situations = const [];
      _activeLesson = null;
      _loadingSituationId = null;
      _catalogError = null;
      _isLoadingIslandSituations = true;
    });
    unawaited(_loadIslandSituations(island));
  }

  Future<void> _loadIslandSituations(_IslandCatalogEntry island) async {
    try {
      final situations = await _situationService.getIslandSituations(
        island.islandId,
      );
      if (!mounted || _selectedIslandId != island.islandId) {
        return;
      }

      setState(() {
        _situations = situations;
        _isLoadingIslandSituations = false;
        _catalogError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('SmartSteps island situations failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || _selectedIslandId != island.islandId) {
        return;
      }

      setState(() {
        _situations = const [];
        _activeLesson = null;
        _isLoadingIslandSituations = false;
        _catalogError = 'Không tải được tình huống của đảo';
      });
    }
  }

  void _showIslands() {
    setState(() {
      _selectedIslandId = null;
      _situations = const [];
      _activeLesson = null;
      _loadingSituationId = null;
      _catalogError = null;
      _isLoadingIslandSituations = false;
    });
  }

  Future<void> _selectSituation(SituationSummary summary) async {
    if (_loadingSituationId == summary.situationId) {
      return;
    }

    if (!_isSituationUnlocked(summary, _profile?.isPremium ?? false)) {
      _showPremiumRequired(summary);
      return;
    }

    setState(() {
      _loadingSituationId = summary.situationId;
      _catalogError = null;
    });

    try {
      final detail = await _situationService.getSituationDetail(
        summary.situationId,
      );
      final lesson = _lessonFromSituation(detail);
      if (!mounted) {
        return;
      }

      setState(() {
        _activeLesson = lesson;
      });
    } catch (error, stackTrace) {
      debugPrint('SmartSteps situation detail failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      setState(() {
        _catalogError = 'Không tải được bài học';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSituationId = null;
        });
      }
    }
  }

  Future<void> _openLesson() async {
    final lesson = _activeLesson;
    if (lesson == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonGameScreen(
          lesson: lesson,
          profileStorage: widget.profileStorage,
          onLessonCompleted: (profile) {
            if (mounted) {
              setState(() {
                _profile = profile;
              });
            }
          },
        ),
      ),
    );

    if (mounted) {
      unawaited(_enterCatalogViewingMode());
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIsland = _selectedIslandId == null
        ? null
        : _islandById(_islands, _selectedIslandId!);
    final selectedSituations = selectedIsland == null
        ? const <SituationSummary>[]
        : _situations;
    final canStartLesson =
        _activeLesson != null &&
        !_isLoadingCatalog &&
        !_isLoadingIslandSituations &&
        _loadingSituationId == null;

    return Scaffold(
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          selectedIsland == null
              ? _IslandHomeMapTab(
                  profile: _profile,
                  audioController: SmartStepsAudioScope.maybeOf(context),
                  islands: _islands,
                  isLoading: _isLoadingCatalog && _islands.isEmpty,
                  error: _catalogError,
                  onSelected: _selectIsland,
                )
              : _IslandLessonMapTab(
                  island: selectedIsland,
                  situations: selectedSituations,
                  isLoadingSituations: _isLoadingIslandSituations,
                  isPremium: _profile?.isPremium ?? false,
                  activeLessonId: _activeLesson?.id,
                  loadingSituationId: _loadingSituationId,
                  hasActiveLesson: _activeLesson != null,
                  canStartLesson: canStartLesson,
                  onBack: _showIslands,
                  onLocked: _showPremiumRequired,
                  onSelected: (summary) {
                    unawaited(_selectSituation(summary));
                  },
                  onStartLesson: () {
                    unawaited(_openLesson());
                  },
                ),
          ParentReportPage(
            situationService: _situationService,
            profileStorage: widget.profileStorage,
            isActive: _selectedTabIndex == 1,
          ),
          const _PracticeTabPage(),
          ProfileScreen(profileStorage: widget.profileStorage),
        ],
      ),
      bottomNavigationBar: _SmartStepsBottomNavigation(
        currentIndex: _selectedTabIndex,
        onSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
      ),
    );
  }
}

class _PracticeTabPage extends StatelessWidget {
  const _PracticeTabPage();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: DuoColors.background),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            DuoCard(
              color: DuoColors.primaryYellow,
              borderColor: DuoColors.darkYellow,
              child: Row(
                children: [
                  Image.asset(LessonAssets.mascotSinging, width: 82),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Luyện tập',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ôn lại các kỹ năng an toàn đã học.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DuoAchievementCard(
              icon: Icons.replay_rounded,
              title: 'Ôn bài nhanh',
              subtitle: '5 câu hỏi ngắn để ghi nhớ lâu hơn',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuickReviewScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const DuoAchievementCard(
              icon: Icons.shield_rounded,
              title: 'Tình huống an toàn',
              subtitle: 'Chọn cách xử lý đúng trong đời sống',
            ),
            const SizedBox(height: 12),
            const DuoAchievementCard(
              icon: Icons.lock_rounded,
              title: 'Thử thách nâng cao',
              subtitle: 'Mở khóa khi hoàn thành thêm bài học',
              isUnlocked: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumOfferDialog extends StatefulWidget {
  const _PremiumOfferDialog({
    required this.profileStorage,
    required this.onPremiumActivated,
  });

  final LocalProfileStorage profileStorage;
  final ValueChanged<ChildProfile> onPremiumActivated;

  @override
  State<_PremiumOfferDialog> createState() => _PremiumOfferDialogState();
}

class _PremiumOfferDialogState extends State<_PremiumOfferDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _canDismiss = false;
  bool _isSubmitting = false;
  String? _errorText;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _canDismiss = true;
      });
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activatePremium() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final profile = await widget.profileStorage.activatePremium(
        _codeController.text,
      );
      if (!mounted) {
        return;
      }

      widget.onPremiumActivated(profile);
      Navigator.of(context).pop();
    } on PremiumActivationException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = error.message;
        _isSubmitting = false;
      });
    } catch (error, stackTrace) {
      debugPrint('SmartSteps premium activation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = 'Chưa nâng cấp được Premium. Vui lòng thử lại.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(size.width - 32, 436),
          maxHeight: size.height - 44,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Material(
            color: Colors.white,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(height: 14, color: DuoColors.primaryYellow),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SMARTSTEPS\nPREMIUM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8BC34A),
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF1B8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.rocket_launch_rounded,
                              color: Color(0xFFFF8F00),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mở khóa toàn bộ hành trình học tập',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _PremiumBenefitRow('AI gợi ý bài học mỗi ngày'),
                      const _PremiumBenefitRow('Không giới hạn màn chơi'),
                      const _PremiumBenefitRow(
                        'Huy hiệu và phần thưởng đặc biệt',
                      ),
                      const _PremiumBenefitRow('Theo dõi tiến bộ của bé'),
                      const _PremiumBenefitRow('Chế độ luyện tập nâng cao'),
                      const SizedBox(height: 20),
                      TextField(
                        key: const ValueKey('premium-code-field'),
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Nhập mã PREMIUM',
                          errorText: _errorText,
                          filled: true,
                          fillColor: const Color(0xFFFFF4C2),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: DuoColors.border,
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: DuoColors.darkYellow,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFBA1A1A),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SmartStepsPressEffect(
                        enabled: !_isSubmitting,
                        child: FilledButton.icon(
                          key: const ValueKey('premium-code-submit-button'),
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  unawaited(_activatePremium());
                                },
                          icon: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFFF7A1A),
                            size: 24,
                          ),
                          label: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text('Kích hoạt Premium'),
                          style: FilledButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFFFFE99C),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 56),
                            textStyle: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 18,
                  right: 14,
                  child: _canDismiss
                      ? Tooltip(
                          message: 'Đóng',
                          child: IconButton.filled(
                            key: const ValueKey('premium-offer-close-button'),
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF5F5F5),
                              foregroundColor: DuoColors.textPrimary,
                            ),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumBenefitRow extends StatelessWidget {
  const _PremiumBenefitRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, color: Color(0xFF2CB34A), size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: DuoColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartStepsBottomNavigation extends StatelessWidget {
  const _SmartStepsBottomNavigation({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DuoColors.card,
      elevation: 18,
      shadowColor: const Color(0x296B5B00),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _SmartStepsBottomNavigationItem(
                key: const ValueKey('home-tab-button'),
                icon: Icons.home_rounded,
                label: 'Trang chủ',
                isSelected: currentIndex == 0,
                onTap: () => onSelected(0),
              ),
              _SmartStepsBottomNavigationItem(
                key: const ValueKey('learn-tab-button'),
                icon: Icons.map_rounded,
                label: 'Tiến bộ',
                isSelected: currentIndex == 1,
                onTap: () => onSelected(1),
              ),
              _SmartStepsBottomNavigationItem(
                key: const ValueKey('practice-tab-button'),
                icon: Icons.bolt_rounded,
                label: 'Luyện tập',
                isSelected: currentIndex == 2,
                onTap: () => onSelected(2),
              ),
              _SmartStepsBottomNavigationItem(
                key: const ValueKey('profile-tab-button'),
                icon: Icons.face_rounded,
                label: 'Bé',
                isSelected: currentIndex == 3,
                onTap: () => onSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmartStepsBottomNavigationItem extends StatelessWidget {
  const _SmartStepsBottomNavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: label,
        child: SmartStepsPressEffect(
          child: InkResponse(
            onTap: onTap,
            containedInkWell: true,
            highlightShape: BoxShape.rectangle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? DuoColors.softYellow : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? DuoColors.darkYellow
                        : DuoColors.textSecondary,
                    size: 25,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? DuoColors.textPrimary
                          : DuoColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
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

class _IslandHomeMapTab extends StatelessWidget {
  const _IslandHomeMapTab({
    required this.profile,
    required this.audioController,
    required this.islands,
    required this.isLoading,
    required this.error,
    required this.onSelected,
  });

  final ChildProfile? profile;
  final SmartStepsAudioController? audioController;
  final List<_IslandCatalogEntry> islands;
  final bool isLoading;
  final String? error;
  final ValueChanged<_IslandCatalogEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DuoColors.primaryYellow,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _IslandHomeHeader(
              profile: profile,
              audioController: audioController,
            ),
          ),
          Expanded(
            child: _IslandMapStage(
              islands: islands,
              isLoading: isLoading,
              error: error,
              onSelected: onSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class _IslandHomeHeader extends StatelessWidget {
  const _IslandHomeHeader({
    required this.profile,
    required this.audioController,
  });

  final ChildProfile? profile;
  final SmartStepsAudioController? audioController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;
        final showAudioControls =
            audioController != null && constraints.maxWidth >= 430;
        final logoSize = isCompact ? 58.0 : 72.0;
        final avatarSize = isCompact ? 56.0 : 66.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 16 : 24,
            isCompact ? 8 : 12,
            isCompact ? 16 : 24,
            isCompact ? 10 : 14,
          ),
          child: SizedBox(
            height: isCompact ? 64 : 78,
            child: Row(
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(LessonAssets.logo, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    AppConstants.appName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 25 : 31,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                if (showAudioControls) ...[
                  _AudioToggleCluster(controller: audioController!),
                  const SizedBox(width: 12),
                ],
                Tooltip(
                  message: _catalogChildName(profile),
                  child: _KidProfileAvatar(size: avatarSize),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IslandMapStage extends StatelessWidget {
  const _IslandMapStage({
    required this.islands,
    required this.isLoading,
    required this.error,
    required this.onSelected,
  });

  final List<_IslandCatalogEntry> islands;
  final bool isLoading;
  final String? error;
  final ValueChanged<_IslandCatalogEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final transform = _IslandMapTransform.cover(
          source: _islandMapSourceSize,
          viewport: viewport,
        );
        final orderedIslands = [...islands]
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        final visibleIslandCount = math.min(
          orderedIslands.length,
          _islandMapSlots.length,
        );

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                LessonAssets.islandBackground,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              for (var index = 0; index < visibleIslandCount; index++)
                _IslandMapHitArea(
                  key: ValueKey('island-${orderedIslands[index].islandId}'),
                  rect: transform.centeredRect(
                    _islandMapSlots[index].hitCenter,
                    _islandMapSlots[index].hitSize,
                  ),
                  title: _islandMapTitle(orderedIslands[index], index),
                  onTap: () => onSelected(orderedIslands[index]),
                ),
              for (var index = 0; index < visibleIslandCount; index++)
                _IslandMapLabelPositioner(
                  viewport: viewport,
                  transform: transform,
                  slot: _islandMapSlots[index],
                  title: _islandMapTitle(orderedIslands[index], index),
                  onTap: () => onSelected(orderedIslands[index]),
                ),
              if (isLoading)
                const _IslandMapStatusOverlay(
                  icon: Icons.sync_rounded,
                  title: 'Đang tải dữ liệu',
                  body: 'SmartSteps đang mở bản đồ đảo.',
                )
              else if (error != null)
                _IslandMapStatusOverlay(
                  icon: Icons.cloud_off_rounded,
                  title: 'Không tải được dữ liệu',
                  body: error!,
                )
              else if (orderedIslands.isEmpty)
                const _IslandMapStatusOverlay(
                  icon: Icons.map_outlined,
                  title: 'Chưa có đảo',
                  body: 'Chưa có bài học đã xuất bản.',
                ),
            ],
          ),
        );
      },
    );
  }
}

class _IslandMapLabelPositioner extends StatelessWidget {
  const _IslandMapLabelPositioner({
    required this.viewport,
    required this.transform,
    required this.slot,
    required this.title,
    required this.onTap,
  });

  final Size viewport;
  final _IslandMapTransform transform;
  final _IslandMapSlot slot;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final anchor = transform.point(slot.labelAnchor);
    final fontSize = (viewport.width * 0.047).clamp(22.0, 38.0).toDouble();
    final minWidth = math.min(172.0, viewport.width - 24);
    final maxLeft = math.max(12.0, viewport.width - minWidth - 12);
    final left = anchor.dx.clamp(12.0, maxLeft).toDouble();
    final availableWidth = math.max(112.0, viewport.width - left - 12);
    final preferredWidth = math.min(
      slot.maxLabelWidth,
      viewport.width * slot.labelWidthFactor,
    );
    final labelWidth = math.min(preferredWidth, availableWidth);
    final top = anchor.dy.clamp(8.0, viewport.height - 72).toDouble();

    return Positioned(
      left: left,
      top: top,
      width: labelWidth,
      child: _IslandMapLabel(
        title: title,
        icon: slot.icon,
        fontSize: fontSize,
        onTap: onTap,
      ),
    );
  }
}

class _IslandMapLabel extends StatelessWidget {
  const _IslandMapLabel({
    required this.title,
    required this.icon,
    required this.fontSize,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shadow = Shadow(
      color: const Color(0xFF006A8D).withValues(alpha: 0.46),
      blurRadius: 10,
      offset: const Offset(0, 2),
    );

    return Semantics(
      button: true,
      label: title,
      child: SmartStepsPressEffect(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            splashColor: Colors.white.withValues(alpha: 0.16),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                        height: 1.05,
                        shadows: [shadow],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    color: Colors.white,
                    size: fontSize * 0.86,
                    shadows: [shadow],
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

class _IslandMapHitArea extends StatelessWidget {
  const _IslandMapHitArea({
    super.key,
    required this.rect,
    required this.title,
    required this.onTap,
  });

  final Rect rect;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: true,
        label: 'Mở $title',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(48),
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            onTap: onTap,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _IslandMapStatusOverlay extends StatelessWidget {
  const _IslandMapStatusOverlay({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: GameColors.ink, size: 40),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IslandMapTransform {
  const _IslandMapTransform({required this.scale, required this.offset});

  factory _IslandMapTransform.cover({
    required Size source,
    required Size viewport,
  }) {
    final scale = math.max(
      viewport.width / source.width,
      viewport.height / source.height,
    );
    final renderedSize = Size(source.width * scale, source.height * scale);

    return _IslandMapTransform(
      scale: scale,
      offset: Offset(
        (viewport.width - renderedSize.width) / 2,
        (viewport.height - renderedSize.height) / 2,
      ),
    );
  }

  final double scale;
  final Offset offset;

  Offset point(Offset sourcePoint) {
    return Offset(
      offset.dx + sourcePoint.dx * scale,
      offset.dy + sourcePoint.dy * scale,
    );
  }

  Rect centeredRect(Offset sourceCenter, Size sourceSize) {
    final center = point(sourceCenter);
    return Rect.fromCenter(
      center: center,
      width: sourceSize.width * scale,
      height: sourceSize.height * scale,
    );
  }
}

class _IslandMapSlot {
  const _IslandMapSlot({
    required this.hitCenter,
    required this.hitSize,
    required this.labelAnchor,
    required this.maxLabelWidth,
    required this.labelWidthFactor,
    required this.icon,
  });

  final Offset hitCenter;
  final Size hitSize;
  final Offset labelAnchor;
  final double maxLabelWidth;
  final double labelWidthFactor;
  final IconData icon;
}

const _islandMapSourceSize = Size(1000, 1715);

const _islandMapSlots = [
  _IslandMapSlot(
    hitCenter: Offset(720, 480),
    hitSize: Size(430, 340),
    labelAnchor: Offset(122, 308),
    maxLabelWidth: 420,
    labelWidthFactor: 0.56,
    icon: Icons.card_giftcard_rounded,
  ),
  _IslandMapSlot(
    hitCenter: Offset(360, 900),
    hitSize: Size(520, 420),
    labelAnchor: Offset(548, 820),
    maxLabelWidth: 420,
    labelWidthFactor: 0.50,
    icon: Icons.star_rounded,
  ),
  _IslandMapSlot(
    hitCenter: Offset(735, 1390),
    hitSize: Size(520, 420),
    labelAnchor: Offset(140, 1264),
    maxLabelWidth: 470,
    labelWidthFactor: 0.64,
    icon: Icons.beach_access_rounded,
  ),
];

String _islandMapTitle(_IslandCatalogEntry island, int slotIndex) {
  return switch (slotIndex) {
    0 => 'Đảo Kho Báu',
    1 => 'Đảo Tri Thức',
    2 => 'Đảo Phiêu Lưu',
    _ => island.name,
  };
}

class _IslandLessonMapTab extends StatelessWidget {
  const _IslandLessonMapTab({
    required this.island,
    required this.situations,
    required this.isLoadingSituations,
    required this.isPremium,
    required this.activeLessonId,
    required this.loadingSituationId,
    required this.hasActiveLesson,
    required this.canStartLesson,
    required this.onBack,
    required this.onLocked,
    required this.onSelected,
    required this.onStartLesson,
  });

  final _IslandCatalogEntry island;
  final List<SituationSummary> situations;
  final bool isLoadingSituations;
  final bool isPremium;
  final String? activeLessonId;
  final int? loadingSituationId;
  final bool hasActiveLesson;
  final bool canStartLesson;
  final VoidCallback onBack;
  final ValueChanged<SituationSummary> onLocked;
  final ValueChanged<SituationSummary> onSelected;
  final VoidCallback onStartLesson;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DuoColors.primaryYellow,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _IslandLessonHeader(island: island, onBack: onBack),
          ),
          Expanded(
            child: _IslandLessonMapStage(
              island: island,
              situations: situations,
              isLoadingSituations: isLoadingSituations,
              isPremium: isPremium,
              activeLessonId: activeLessonId,
              loadingSituationId: loadingSituationId,
              hasActiveLesson: hasActiveLesson,
              canStartLesson: canStartLesson,
              onLocked: onLocked,
              onSelected: onSelected,
              onStartLesson: onStartLesson,
            ),
          ),
        ],
      ),
    );
  }
}

class _IslandLessonHeader extends StatelessWidget {
  const _IslandLessonHeader({required this.island, required this.onBack});

  final _IslandCatalogEntry island;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 14 : 20,
            isCompact ? 8 : 12,
            isCompact ? 14 : 20,
            isCompact ? 10 : 14,
          ),
          child: SizedBox(
            height: isCompact ? 56 : 64,
            child: Row(
              children: [
                _CircleIconButton(
                  label: 'Quay lại bản đồ đảo',
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _islandLessonTitle(island),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 24 : 30,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        color: DuoColors.darkYellow,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${island.lessonCount} bài',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GameColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IslandLessonMapStage extends StatelessWidget {
  const _IslandLessonMapStage({
    required this.island,
    required this.situations,
    required this.isLoadingSituations,
    required this.isPremium,
    required this.activeLessonId,
    required this.loadingSituationId,
    required this.hasActiveLesson,
    required this.canStartLesson,
    required this.onLocked,
    required this.onSelected,
    required this.onStartLesson,
  });

  final _IslandCatalogEntry island;
  final List<SituationSummary> situations;
  final bool isLoadingSituations;
  final bool isPremium;
  final String? activeLessonId;
  final int? loadingSituationId;
  final bool hasActiveLesson;
  final bool canStartLesson;
  final ValueChanged<SituationSummary> onLocked;
  final ValueChanged<SituationSummary> onSelected;
  final VoidCallback onStartLesson;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _islandLessonBackgroundAsset(island.islandId),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF003848).withValues(alpha: 0.12),
                  Colors.transparent,
                  const Color(0xFF003848).withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
          if (isLoadingSituations && situations.isEmpty)
            const _IslandMapStatusOverlay(
              icon: Icons.sync_rounded,
              title: 'Đang tải',
              body: 'Đang mở bản đồ bài học.',
            )
          else if (situations.isEmpty)
            const _IslandMapStatusOverlay(
              icon: Icons.auto_stories_outlined,
              title: 'Chưa có bài học',
              body: 'Đảo này chưa có bài học đã xuất bản.',
            )
          else
            _IslandLessonPathOverlay(
              islandId: island.islandId,
              situations: situations,
              isPremium: isPremium,
              activeLessonId: activeLessonId,
              loadingSituationId: loadingSituationId,
              onLocked: onLocked,
              onSelected: onSelected,
            ),
          if (hasActiveLesson)
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: SafeArea(
                top: false,
                child: _PillButton(
                  key: const ValueKey('start-lesson-button'),
                  label: 'Bắt đầu bài học',
                  icon: Icons.play_arrow_rounded,
                  color: GameColors.banana,
                  onPressed: canStartLesson ? onStartLesson : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IslandLessonPathOverlay extends StatelessWidget {
  const _IslandLessonPathOverlay({
    required this.islandId,
    required this.situations,
    required this.isPremium,
    required this.activeLessonId,
    required this.loadingSituationId,
    required this.onLocked,
    required this.onSelected,
  });

  final int islandId;
  final List<SituationSummary> situations;
  final bool isPremium;
  final String? activeLessonId;
  final int? loadingSituationId;
  final ValueChanged<SituationSummary> onLocked;
  final ValueChanged<SituationSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pathPoints = _lessonPathPoints(
          islandId: islandId,
          count: situations.length,
        );
        final stageSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _IslandLessonPathPainter(points: pathPoints),
              ),
            ),
            for (var index = 0; index < situations.length; index++)
              _IslandLessonPathNodePositioner(
                stageSize: stageSize,
                point: pathPoints[index],
                child: _IslandLessonPathNode(
                  situation: situations[index],
                  isSelected:
                      activeLessonId ==
                      'situation-${situations[index].situationId}',
                  isLoading:
                      loadingSituationId == situations[index].situationId,
                  isUnlocked: _isSituationUnlocked(
                    situations[index],
                    isPremium,
                  ),
                  onTap: () =>
                      _isSituationUnlocked(situations[index], isPremium)
                      ? onSelected(situations[index])
                      : onLocked(situations[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _IslandLessonPathNodePositioner extends StatelessWidget {
  const _IslandLessonPathNodePositioner({
    required this.stageSize,
    required this.point,
    required this.child,
  });

  final Size stageSize;
  final Offset point;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const nodeWidth = 176.0;
    const nodeHeight = 150.0;
    final left = (stageSize.width * point.dx - nodeWidth / 2)
        .clamp(8.0, math.max(8.0, stageSize.width - nodeWidth - 8))
        .toDouble();
    final top = (stageSize.height * point.dy - 48)
        .clamp(8.0, math.max(8.0, stageSize.height - nodeHeight - 8))
        .toDouble();

    return Positioned(left: left, top: top, width: nodeWidth, child: child);
  }
}

class _IslandLessonPathNode extends StatelessWidget {
  const _IslandLessonPathNode({
    required this.situation,
    required this.isSelected,
    required this.isLoading,
    required this.isUnlocked,
    required this.onTap,
  });

  final SituationSummary situation;
  final bool isSelected;
  final bool isLoading;
  final bool isUnlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? GameColors.safe
        : isUnlocked
        ? DuoColors.primaryYellow
        : const Color(0xFFD7DCE2);
    final foreground = isUnlocked ? GameColors.ink : const Color(0xFF87909D);
    final lessonIcon = _situationIcon(situation);
    final nodeSize = isSelected ? 84.0 : 74.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('situation-${situation.situationId}'),
            onTap: isLoading ? null : onTap,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: nodeSize,
              height: nodeSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.96),
                  width: 7,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isSelected ? 0.55 : 0.34),
                    blurRadius: isSelected ? 26 : 16,
                    offset: const Offset(0, 8),
                  ),
                  const BoxShadow(
                    color: Color(0x3825324B),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(23),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Icon(
                      isSelected
                          ? Icons.play_arrow_rounded
                          : isUnlocked
                          ? lessonIcon
                          : Icons.lock_rounded,
                      color: foreground,
                      size: isSelected ? 40 : 33,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          constraints: const BoxConstraints(maxWidth: 144),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? GameColors.safe
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2625324B),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            isSelected
                ? 'START'
                : isUnlocked
                ? 'Bài ${situation.orderIndex}'
                : 'PREMIUM',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : GameColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          situation.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1.12,
            shadows: [
              Shadow(
                color: Color(0xB325324B),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IslandLessonPathPainter extends CustomPainter {
  const _IslandLessonPathPainter({required this.points});

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

    final path = Path()
      ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (var index = 1; index < points.length; index++) {
      path.lineTo(
        points[index].dx * size.width,
        points[index].dy * size.height,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0A6B74).withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = DuoColors.primaryYellow.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _IslandLessonPathPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

String _islandLessonTitle(_IslandCatalogEntry island) {
  return switch (island.islandId) {
    1 => 'Đảo Kho Báu',
    2 => 'Đảo Tri Thức',
    3 => 'Đảo Phiêu Lưu',
    _ => island.name,
  };
}

String _islandLessonBackgroundAsset(int islandId) {
  return switch (islandId) {
    1 => LessonAssets.island1Background,
    2 => LessonAssets.island2Background,
    3 => LessonAssets.island3Background,
    _ => LessonAssets.island1Background,
  };
}

List<Offset> _lessonPathPoints({required int islandId, required int count}) {
  final anchors = switch (islandId) {
    1 => const [Offset(0.50, 0.82), Offset(0.27, 0.58), Offset(0.70, 0.34)],
    2 => const [Offset(0.47, 0.82), Offset(0.35, 0.57), Offset(0.58, 0.32)],
    3 => const [Offset(0.58, 0.82), Offset(0.48, 0.58), Offset(0.33, 0.33)],
    _ => const [Offset(0.50, 0.82), Offset(0.34, 0.58), Offset(0.66, 0.34)],
  };

  if (count <= anchors.length) {
    return anchors.take(count).toList(growable: false);
  }

  return List<Offset>.generate(count, (index) {
    final t = count == 1 ? 0.0 : index / (count - 1);
    final y = 0.82 - t * 0.52;
    final x = 0.5 + math.sin(t * math.pi * 2.2) * 0.24;
    return Offset(x.clamp(0.18, 0.82).toDouble(), y);
  }, growable: false);
}

// ignore: unused_element
class _CatalogTopBar extends StatelessWidget {
  const _CatalogTopBar({
    required this.profile,
    required this.plan,
    required this.onUpgradePressed,
    // ignore: unused_element_parameter
    this.audioController,
  });

  final ChildProfile? profile;
  final String plan;
  final VoidCallback? onUpgradePressed;
  final SmartStepsAudioController? audioController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;
        final childName = _catalogChildName(profile);
        final completedLessons = profile?.completedLessonCount ?? 0;
        final totalPoints = profile?.totalSkillPoints ?? 0;
        final level = (totalPoints ~/ 3) + 1;
        final profileLine = profile == null
            ? 'Chưa có hồ sơ bé'
            : '${profile!.displayAge} - ${profile!.primaryGoal}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _HeaderMetricChip(
                    icon: Icons.check_circle_rounded,
                    label: '$completedLessons/9 bài',
                    color: const Color(0xFFFFEFE0),
                    iconColor: const Color(0xFFE86D1F),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeaderMetricChip(
                    icon: Icons.star_rounded,
                    label: '$totalPoints điểm',
                    color: const Color(0xFFE9F8D5),
                    iconColor: DuoColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeaderPlanChip(
                    plan: plan,
                    onPressed: onUpgradePressed,
                  ),
                ),
              ],
            ),
            if (audioController != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _AudioToggleCluster(controller: audioController!),
              ),
            ],
            const SizedBox(height: 12),
            DuoCard(
              color: DuoColors.primaryYellow,
              borderColor: DuoColors.darkYellow.withValues(alpha: 0.24),
              padding: EdgeInsets.fromLTRB(
                isCompact ? 14 : 18,
                isCompact ? 14 : 16,
                isCompact ? 12 : 16,
                isCompact ? 14 : 16,
              ),
              child: Row(
                children: [
                  _KidProfileAvatar(size: isCompact ? 58 : 68),
                  SizedBox(width: isCompact ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          childName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DuoColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$profileLine\nCấp $level - Học an toàn mỗi ngày',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: DuoColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        DuoProgressBar(
                          value: (completedLessons / 9).clamp(0, 1).toDouble(),
                        ),
                      ],
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 12),
                    Image.asset(LessonAssets.mascotHappyWave, width: 74),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AudioToggleCluster extends StatelessWidget {
  const _AudioToggleCluster({required this.controller});

  final SmartStepsAudioController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AudioToggleButton(
              tooltip: controller.isMusicEnabled
                  ? 'Táº¯t nháº¡c ná»n'
                  : 'Báº­t nháº¡c ná»n',
              icon: controller.isMusicEnabled
                  ? Icons.music_note_rounded
                  : Icons.music_off_rounded,
              isEnabled: controller.isMusicEnabled,
              playPressSound: controller.isSfxEnabled,
              onPressed: controller.toggleMusic,
            ),
            const SizedBox(width: 8),
            _AudioToggleButton(
              tooltip: controller.isSfxEnabled
                  ? 'Táº¯t Ã¢m thanh nÃºt'
                  : 'Báº­t Ã¢m thanh nÃºt',
              icon: controller.isSfxEnabled
                  ? Icons.ads_click_rounded
                  : Icons.volume_off_rounded,
              isEnabled: controller.isSfxEnabled,
              playPressSound: controller.isSfxEnabled,
              onPressed: controller.toggleSfx,
            ),
          ],
        );
      },
    );
  }
}

class _AudioToggleButton extends StatelessWidget {
  const _AudioToggleButton({
    required this.tooltip,
    required this.icon,
    required this.isEnabled,
    required this.playPressSound,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool isEnabled;
  final bool playPressSound;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = isEnabled ? Colors.white : const Color(0xFFFFF4D6);
    final foreground = isEnabled
        ? DuoColors.textPrimary
        : DuoColors.textSecondary;

    return Tooltip(
      message: tooltip,
      child: SmartStepsPressEffect(
        playSound: playPressSound,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            fixedSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            elevation: 0,
            backgroundColor: background,
            foregroundColor: foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: isEnabled ? DuoColors.primaryYellow : DuoColors.border,
                width: 2,
              ),
            ),
          ),
          child: Icon(icon, size: 23),
        ),
      ),
    );
  }
}

String _catalogChildName(ChildProfile? profile) {
  final name = profile?.childName.trim();
  if (name == null || name.isEmpty) {
    return 'Bé SmartSteps';
  }

  return name;
}

// ignore: unused_element
class _CatalogTopBarOld extends StatelessWidget {
  const _CatalogTopBarOld();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;

        return DuoCard(
          color: DuoColors.primaryYellow,
          borderColor: DuoColors.darkYellow.withValues(alpha: 0.24),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 18,
            vertical: isCompact ? 14 : 16,
          ),
          child: Row(
            children: [
              _KidProfileAvatar(size: isCompact ? 58 : 68),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bé SmartSteps',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: GameColors.ink,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      'Bài học an toàn cho bé',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 1, height: 0.1),
                    ),
                    const SizedBox(height: 9),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        _HeaderMetricChip(
                          icon: Icons.local_fire_department_rounded,
                          label: '0/9 bài',
                          color: Color(0xFFFFEFE0),
                          iconColor: Color(0xFFE86D1F),
                        ),
                        _HeaderMetricChip(
                          icon: Icons.star_rounded,
                          label: '0 điểm',
                          color: Color(0xFFE9F8D5),
                          iconColor: Color(0xFF6BAF2A),
                        ),
                        _HeaderMetricChip(
                          icon: Icons.military_tech_rounded,
                          label: 'Cấp 4',
                          color: Color(0xFFFFFFFF),
                          iconColor: DuoColors.darkYellow,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const _HeaderPlanChip(plan: 'Miễn phí'),
            ],
          ),
        );
      },
    );
  }
}

class _KidProfileAvatar extends StatelessWidget {
  const _KidProfileAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: const Color(0xFFBFE9FF),
          child: Image.asset(
            LessonAssets.kid,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
          ),
        ),
      ),
    );
  }
}

class _HeaderMetricChip extends StatelessWidget {
  const _HeaderMetricChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: GameColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPlanChip extends StatelessWidget {
  const _HeaderPlanChip({required this.plan, this.onPressed});

  final String plan;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Gói hiện tại',
      child: SmartStepsPressEffect(
        enabled: onPressed != null,
        child: Material(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: DuoColors.darkYellow,
                    size: 20,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    plan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GameColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1,
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

class _IslandCatalogEntry {
  const _IslandCatalogEntry({
    required this.islandId,
    required this.name,
    required this.orderIndex,
    required this.lessonCount,
    this.imageUrl,
  });

  factory _IslandCatalogEntry.fromSummary(IslandSummary summary) {
    return _IslandCatalogEntry(
      islandId: summary.islandId,
      name: summary.name,
      orderIndex: summary.orderIndex,
      lessonCount: summary.situationCount,
      imageUrl: summary.imageUrl,
    );
  }

  final int islandId;
  final String name;
  final int orderIndex;
  final int lessonCount;
  final String? imageUrl;
}

_IslandCatalogEntry? _islandById(
  List<_IslandCatalogEntry> islands,
  int islandId,
) {
  for (final island in islands) {
    if (island.islandId == islandId) {
      return island;
    }
  }

  return null;
}

bool _requiresPremium(SituationSummary situation) {
  return (situation.islandId == 2 || situation.islandId == 3) &&
      situation.orderIndex >= 2;
}

bool _isSituationUnlocked(SituationSummary situation, bool isPremium) {
  return isPremium || !_requiresPremium(situation);
}

// ignore: unused_element
class _CatalogContentFrame extends StatelessWidget {
  const _CatalogContentFrame({
    required this.isLoading,
    required this.error,
    required this.child,
  });

  final bool isLoading;
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DuoColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: DuoColors.border, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F6B5B00),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFDF4), DuoColors.background],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: isLoading
                  ? const _CatalogMessage(
                      icon: Icons.sync_rounded,
                      title: 'Đang tải dữ liệu',
                      body: 'SmartSteps đang kết nối backend.',
                    )
                  : error != null
                  ? _CatalogMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Không tải được dữ liệu',
                      body: error!,
                    )
                  : child,
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _IslandCatalogViewNew extends StatelessWidget {
  const _IslandCatalogViewNew({
    required this.islands,
    required this.onSelected,
  });

  final List<_IslandCatalogEntry> islands;
  final ValueChanged<_IslandCatalogEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    if (islands.isEmpty) {
      return const _CatalogMessage(
        icon: Icons.map_outlined,
        title: 'Chưa có đảo',
        body: 'Chưa có bài học đã xuất bản.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _IslandJourneyHero(islandCount: islands.length),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chọn đảo hôm nay',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: DuoColors.softYellow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${islands.length} đảo',
                    style: const TextStyle(
                      color: DuoColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isWide)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemCount: islands.length,
                itemBuilder: (context, index) {
                  final island = islands[index];
                  return _IslandTile(
                    island: island,
                    onTap: () => onSelected(island),
                  );
                },
              )
            else
              for (final island in islands)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _IslandTile(
                    island: island,
                    onTap: () => onSelected(island),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _IslandJourneyHero extends StatelessWidget {
  const _IslandJourneyHero({required this.islandCount});

  final int islandCount;

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      color: const Color(0xFFFFF4B8),
      borderColor: DuoColors.primaryYellow,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DockLabel('Nhiệm vụ hôm nay'),
                const SizedBox(height: 8),
                Text(
                  'Bản đồ an toàn của bé',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Mở từng đảo, hoàn thành ô bài học và nhận sao.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                DuoProgressBar(value: (islandCount / 6).clamp(0.18, 1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 78,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 70,
                    height: 42,
                    decoration: BoxDecoration(
                      color: DuoColors.primaryYellow,
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
                Image.asset(LessonAssets.mascotHappyWave, width: 76),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _IslandCatalogView extends StatelessWidget {
  const _IslandCatalogView({required this.islands, required this.onSelected});

  final List<_IslandCatalogEntry> islands;
  final ValueChanged<_IslandCatalogEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    if (islands.isEmpty) {
      return const _CatalogMessage(
        icon: Icons.map_outlined,
        title: 'Chưa có đảo',
        body: 'Backend chưa trả về tình huống đã xuất bản.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _IslandJourneyHero(islandCount: islands.length),
            const SizedBox(height: 18),
            _CatalogHeader(
              label: 'Đảo học tập',
              title: 'Chọn đảo',
              subtitle: '${islands.length} đảo',
            ),
            const SizedBox(height: 14),
            if (isWide)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.96,
                ),
                itemCount: islands.length,
                itemBuilder: (context, index) {
                  final island = islands[index];
                  return _IslandTile(
                    island: island,
                    onTap: () => onSelected(island),
                  );
                },
              )
            else
              ...islands.map(
                (island) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _IslandTile(
                    island: island,
                    onTap: () => onSelected(island),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ignore: unused_element
class _IslandSituationViewNew extends StatelessWidget {
  const _IslandSituationViewNew({
    required this.island,
    required this.situations,
    required this.isLoadingSituations,
    required this.isPremium,
    required this.activeLessonId,
    required this.loadingSituationId,
    required this.onBack,
    required this.onLocked,
    required this.onSelected,
  });

  final _IslandCatalogEntry island;
  final List<SituationSummary> situations;
  final bool isLoadingSituations;
  final bool isPremium;
  final String? activeLessonId;
  final int? loadingSituationId;
  final VoidCallback onBack;
  final ValueChanged<SituationSummary> onLocked;
  final ValueChanged<SituationSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    final progress = island.lessonCount == 0
        ? 0.0
        : (situations.length / island.lessonCount).clamp(0.12, 1.0).toDouble();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            _CircleIconButton(
              label: 'Quay lại',
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DuoCard(
                color: DuoColors.primaryYellow,
                borderColor: DuoColors.darkYellow.withValues(alpha: 0.22),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: _CatalogPictureImage(
                          asset: _islandImageAsset(island.islandId),
                          imageUrl: island.imageUrl,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            island.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${island.lessonCount} bài học',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          DuoProgressBar(value: progress),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isLoadingSituations && situations.isEmpty)
          const _CatalogMessage(
            icon: Icons.sync_rounded,
            title: 'Đang tải',
            body: 'Đang mở bản đồ bài học.',
          )
        else if (situations.isEmpty)
          const _CatalogMessage(
            icon: Icons.auto_stories_outlined,
            title: 'Chưa có bài học',
            body: 'Đảo này chưa có bài học đã xuất bản.',
          )
        else
          _LessonPathView(
            situations: situations,
            isPremium: isPremium,
            activeLessonId: activeLessonId,
            loadingSituationId: loadingSituationId,
            onLocked: onLocked,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

// ignore: unused_element
class _IslandSituationView extends StatelessWidget {
  const _IslandSituationView({
    required this.island,
    required this.situations,
    required this.isLoadingSituations,
    required this.activeLessonId,
    required this.loadingSituationId,
    required this.onBack,
    required this.onSelected,
  });

  final _IslandCatalogEntry island;
  final List<SituationSummary> situations;
  final bool isLoadingSituations;
  final String? activeLessonId;
  final int? loadingSituationId;
  final VoidCallback onBack;
  final ValueChanged<SituationSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            _CircleIconButton(
              label: 'Quay lại danh sách đảo',
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CatalogHeader(
                label: 'Tình huống',
                title: island.name,
                subtitle: '${island.lessonCount} bài',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (isLoadingSituations && situations.isEmpty)
          const _CatalogMessage(
            icon: Icons.sync_rounded,
            title: 'Đang tải',
            body: 'Đang mở các tình huống trong đảo.',
          )
        else if (situations.isEmpty)
          const _CatalogMessage(
            icon: Icons.auto_stories_outlined,
            title: 'Chưa có tình huống',
            body: 'Đảo này chưa có bài học đã xuất bản.',
          )
        else
          _LessonPathView(
            situations: situations,
            isPremium: false,
            activeLessonId: activeLessonId,
            loadingSituationId: loadingSituationId,
            onLocked: onSelected,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.label,
    required this.title,
    required this.subtitle,
  });

  final String label;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DockLabel(label),
        const SizedBox(height: 5),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _LessonPathView extends StatelessWidget {
  const _LessonPathView({
    required this.situations,
    required this.isPremium,
    required this.activeLessonId,
    required this.loadingSituationId,
    required this.onLocked,
    required this.onSelected,
  });

  final List<SituationSummary> situations;
  final bool isPremium;
  final String? activeLessonId;
  final int? loadingSituationId;
  final ValueChanged<SituationSummary> onLocked;
  final ValueChanged<SituationSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 430),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.88),
          width: 3,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LessonPathPainter(situations.length)),
          ),
          Column(
            children: [
              for (var index = 0; index < situations.length; index++) ...[
                Builder(
                  builder: (context) {
                    final situation = situations[index];
                    final isUnlocked = _isSituationUnlocked(
                      situation,
                      isPremium,
                    );

                    return _LessonPathNode(
                      situation: situation,
                      index: index,
                      isSelected:
                          activeLessonId ==
                          'situation-${situation.situationId}',
                      isLoading: loadingSituationId == situation.situationId,
                      isUnlocked: isUnlocked,
                      onTap: () => isUnlocked
                          ? onSelected(situation)
                          : onLocked(situation),
                    );
                  },
                ),
                if (index != situations.length - 1) const SizedBox(height: 22),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonPathNode extends StatelessWidget {
  const _LessonPathNode({
    required this.situation,
    required this.index,
    required this.isSelected,
    required this.isLoading,
    required this.isUnlocked,
    required this.onTap,
  });

  final SituationSummary situation;
  final int index;
  final bool isSelected;
  final bool isLoading;
  final bool isUnlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (index % 4) {
      0 => Alignment.center,
      1 => const Alignment(0.62, 0),
      2 => const Alignment(-0.58, 0),
      _ => const Alignment(0.28, 0),
    };
    final color = isSelected
        ? GameColors.safe
        : isUnlocked
        ? const Color(0xFFFFC928)
        : const Color(0xFFD7DCE2);
    final foreground = isUnlocked ? GameColors.ink : const Color(0xFF87909D);
    final lessonIcon = _situationIcon(situation);

    return Align(
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('situation-${situation.situationId}'),
              onTap: isLoading ? null : onTap,
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: isSelected ? 86 : 76,
                height: isSelected ? 86 : 76,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.94),
                    width: 7,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: isSelected ? 0.46 : 0.26),
                      blurRadius: isSelected ? 20 : 12,
                      offset: const Offset(0, 8),
                    ),
                    const BoxShadow(
                      color: Color(0x2625324B),
                      blurRadius: 8,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Icon(
                        isSelected
                            ? Icons.play_arrow_rounded
                            : isUnlocked
                            ? lessonIcon
                            : Icons.lock_rounded,
                        color: foreground,
                        size: isSelected ? 40 : 34,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? GameColors.safe
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isSelected
                  ? 'START'
                  : isUnlocked
                  ? 'Bài ${situation.orderIndex}'
                  : 'PREMIUM',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : GameColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 160,
            child: Text(
              situation.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GameColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonPathPainter extends CustomPainter {
  const _LessonPathPainter(this.nodeCount);

  final int nodeCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodeCount < 2) {
      return;
    }

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.68)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final step = size.height / nodeCount;

    path.moveTo(size.width * 0.5, step * 0.42);
    for (var index = 1; index < nodeCount; index++) {
      final y = step * (index + 0.3);
      final x = switch (index % 4) {
        1 => size.width * 0.78,
        2 => size.width * 0.23,
        3 => size.width * 0.62,
        _ => size.width * 0.5,
      };
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LessonPathPainter oldDelegate) {
    return oldDelegate.nodeCount != nodeCount;
  }
}

class _IslandTile extends StatelessWidget {
  const _IslandTile({required this.island, required this.onTap});

  final _IslandCatalogEntry island;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _islandAccent(island.islandId);

    return SmartStepsPressEffect(
      child: Material(
        color: DuoColors.card,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          key: ValueKey('island-${island.islandId}'),
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 168),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.82),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 92,
                  child: _CatalogPicture(
                    asset: _islandImageAsset(island.islandId),
                    imageUrl: island.imageUrl,
                    accent: accent,
                    icon: Icons.terrain_rounded,
                    padding: const EdgeInsets.all(18),
                  ),
                ),
                const SizedBox(height: 12),
                DuoProgressBar(
                  value: (island.lessonCount / 3).clamp(0.18, 1.0),
                  height: 12,
                  color: DuoColors.success,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        island.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${island.lessonCount}',
                        style: const TextStyle(
                          color: GameColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: accent, size: 30),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogPicture extends StatelessWidget {
  const _CatalogPicture({
    required this.asset,
    this.imageUrl,
    required this.accent,
    required this.icon,
    required this.padding,
  });

  final String asset;
  final String? imageUrl;
  final Color accent;
  final IconData icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: padding,
              child: _CatalogPictureImage(asset: asset, imageUrl: imageUrl),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogPictureImage extends StatelessWidget {
  const _CatalogPictureImage({required this.asset, required this.imageUrl});

  final String asset;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final localImageAsset = imageUrl?.trim();
    if (localImageAsset != null && localImageAsset.startsWith('assets/')) {
      return Image.asset(
        localImageAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Image.asset(asset, fit: BoxFit.contain),
      );
    }

    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl!);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Image.asset(asset, fit: BoxFit.contain),
      );
    }

    return Image.asset(asset, fit: BoxFit.contain);
  }
}

// ignore: unused_element
class _SituationTile extends StatelessWidget {
  const _SituationTile({
    required this.situation,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  final SituationSummary situation;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isSelected
        ? GameColors.safe
        : _islandAccent(situation.islandId);

    return SmartStepsPressEffect(
      enabled: !isLoading,
      child: Material(
        color: isSelected
            ? GameColors.mint.withValues(alpha: 0.74)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          key: ValueKey('situation-${situation.situationId}'),
          borderRadius: BorderRadius.circular(24),
          onTap: isLoading ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 126),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? GameColors.safe.withValues(alpha: 0.62)
                    : Colors.white.withValues(alpha: 0.82),
                width: 3,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: _CatalogPicture(
                    asset: _situationImageAsset(situation),
                    accent: accent,
                    icon: Icons.play_arrow_rounded,
                    padding: const EdgeInsets.all(13),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        situation.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isLoading
                              ? 'Đang tải'
                              : 'Bài ${situation.orderIndex}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: GameColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isLoading
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.chevron_right_rounded,
                        color: isSelected ? GameColors.safe : GameColors.ink,
                        size: 32,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _islandImageAsset(int islandId) {
  return switch (islandId) {
    1 => LessonAssets.safetyIsland,
    _ => LessonAssets.islandIcon,
  };
}

String _situationImageAsset(SituationSummary situation) {
  const assets = [
    LessonAssets.ball,
    LessonAssets.kid,
    LessonAssets.childHappy,
    LessonAssets.mother,
    LessonAssets.childChoking,
    LessonAssets.rewardStar,
  ];

  return assets[(situation.orderIndex - 1).abs() % assets.length];
}

IconData _situationIcon(SituationSummary situation) {
  final text = '${situation.title} ${situation.intro ?? ''}'.toLowerCase();
  if (text.contains('đường') || text.contains('giao thông')) {
    return Icons.traffic_rounded;
  }
  if (text.contains('siêu thị') || text.contains('bị lạc')) {
    return Icons.storefront_rounded;
  }
  if (text.contains('người lạ') || text.contains('cảnh giác')) {
    return Icons.person_off_rounded;
  }
  if (text.contains('bạn bè') || text.contains('thách đố')) {
    return Icons.groups_rounded;
  }
  if (text.contains('ví') || text.contains('nhặt được')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (text.contains('vật') || text.contains('miệng')) {
    return Icons.radio_button_checked_rounded;
  }
  if (text.contains('điện') || text.contains('ổ cắm')) {
    return Icons.bolt_rounded;
  }
  if (text.contains('nước nóng') || text.contains('bỏng')) {
    return Icons.local_fire_department_rounded;
  }
  if (text.contains('nước') || text.contains('hồ')) {
    return Icons.water_drop_rounded;
  }

  return Icons.shield_rounded;
}

// ignore: unused_element
class _SelectedLessonPreview extends StatelessWidget {
  const _SelectedLessonPreview({required this.lesson});

  final SafetyLesson lesson;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Image.asset(LessonAssets.mascotConfident, width: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _DockLabel('Đã chọn'),
                const SizedBox(height: 5),
                Text(
                  lesson.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  lesson.mission,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: GameColors.ink, size: 40),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Color _islandAccent(int islandId) {
  const colors = [
    GameColors.safe,
    Color(0xFF35A7FF),
    GameColors.coral,
    Color(0xFF8F7CFF),
  ];

  return colors[(islandId - 1).abs() % colors.length];
}

const _fallbackIslandEntries = [
  _IslandCatalogEntry(
    islandId: 1,
    name: 'Đảo an toàn cá nhân',
    orderIndex: 1,
    lessonCount: 3,
  ),
  _IslandCatalogEntry(
    islandId: 2,
    name: 'Đảo an toàn xã hội',
    orderIndex: 2,
    lessonCount: 3,
  ),
  _IslandCatalogEntry(
    islandId: 3,
    name: 'Đảo an toàn môi trường',
    orderIndex: 3,
    lessonCount: 3,
  ),
];

class SmartStepsLegacyLandingPage extends StatefulWidget {
  const SmartStepsLegacyLandingPage({
    super.key,
    required this.situationService,
  });

  final SituationService situationService;

  @override
  State<SmartStepsLegacyLandingPage> createState() =>
      _SmartStepsLandingPageState();
}

class _SmartStepsLandingPageState extends State<SmartStepsLegacyLandingPage> {
  List<SituationSummary> _situations = const [];
  SafetyLesson? _activeLesson;
  bool _isLoadingSituations = false;
  int? _loadingSituationId;
  String? _catalogError;

  SituationService get _situationService => widget.situationService;

  @override
  void initState() {
    super.initState();
    unawaited(_enterLandingViewingMode());
    unawaited(_loadSituations());
  }

  Future<void> _enterLandingViewingMode() async {
    try {
      await SystemChrome.setPreferredOrientations(_outsidePortraitOrientations);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // Some desktop/test hosts do not expose system chrome controls.
    }
  }

  Future<void> _loadSituations() async {
    if (!_situationService.isEnabled) {
      setState(() {
        _catalogError =
            'Missing SMARTSTEPS_API_BASE_URL. Run with --dart-define=SMARTSTEPS_API_BASE_URL=http://10.0.2.2:5078';
      });
      return;
    }

    setState(() {
      _isLoadingSituations = true;
      _catalogError = null;
    });

    try {
      final situations = await _situationService.getSituations();
      if (situations.isEmpty) {
        if (mounted) {
          setState(() {
            _situations = const [];
            _activeLesson = null;
            _catalogError = 'Backend returned no published lessons.';
            _isLoadingSituations = false;
          });
        }
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _situations = situations;
        _activeLesson = null;
        _isLoadingSituations = false;
      });
    } catch (error, stackTrace) {
      debugPrint('SmartSteps situation catalog failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _catalogError = 'Không tải được dữ liệu backend';
          _activeLesson = null;
          _isLoadingSituations = false;
        });
      }
    }
  }

  Future<SafetyLesson> _loadLesson(SituationSummary summary) async {
    final detail = await _situationService.getSituationDetail(
      summary.situationId,
    );
    return _lessonFromSituation(detail);
  }

  Future<void> _selectSituation(SituationSummary summary) async {
    if (_loadingSituationId == summary.situationId) {
      return;
    }

    setState(() {
      _loadingSituationId = summary.situationId;
      _catalogError = null;
    });

    try {
      final lesson = await _loadLesson(summary);
      if (!mounted) {
        return;
      }

      setState(() {
        _activeLesson = lesson;
      });
    } catch (error, stackTrace) {
      debugPrint('SmartSteps situation detail failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _catalogError = 'Không tải được bài học';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingSituationId = null;
        });
      }
    }
  }

  Future<void> _openLesson() async {
    final lesson = _activeLesson;
    if (lesson == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LessonGameScreen(lesson: lesson)),
    );

    if (mounted) {
      unawaited(_enterLandingViewingMode());
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _activeLesson;
    final canStartLesson = lesson != null && !_isLoadingSituations;

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
                    Image.asset(LessonAssets.mascotHappyWave, width: 54),
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
                                  lesson?.title ?? 'Dang tai bai hoc',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lesson?.mission ??
                                      _catalogError ??
                                      'Dang ket noi toi backend SmartSteps.',
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
                const SizedBox(height: 12),
                _LessonCatalogStrip(
                  situations: _situations,
                  activeLessonId: lesson?.id,
                  isLoading: _isLoadingSituations,
                  loadingSituationId: _loadingSituationId,
                  error: _catalogError,
                  onSelected: (summary) {
                    unawaited(_selectSituation(summary));
                  },
                ),
                const SizedBox(height: 16),
                _PillButton(
                  label: 'Bắt đầu bài học',
                  icon: Icons.play_arrow_rounded,
                  color: GameColors.banana,
                  onPressed: canStartLesson
                      ? () {
                          unawaited(_openLesson());
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonCatalogStrip extends StatelessWidget {
  const _LessonCatalogStrip({
    required this.situations,
    required this.activeLessonId,
    required this.isLoading,
    required this.loadingSituationId,
    required this.error,
    required this.onSelected,
  });

  final List<SituationSummary> situations;
  final String? activeLessonId;
  final bool isLoading;
  final int? loadingSituationId;
  final String? error;
  final ValueChanged<SituationSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    if (situations.isEmpty) {
      return SizedBox(
        height: 42,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _DockLabel(
            error ??
                (isLoading ? 'Đang tải backend' : 'Chưa có bài học từ API'),
          ),
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: situations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final situation = situations[index];
          final lessonId = 'situation-${situation.situationId}';
          final isSelected = activeLessonId == lessonId;
          final isBusy = loadingSituationId == situation.situationId;

          return ChoiceChip(
            selected: isSelected,
            label: Text(
              isBusy ? '...' : situation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onSelected: (_) => onSelected(situation),
            labelStyle: const TextStyle(
              color: GameColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.72),
            selectedColor: GameColors.banana,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.78)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
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

const _rewardBurstDuration = Duration(milliseconds: 1250);

enum ChoiceTone { safe, danger }

class GameColors {
  const GameColors._();

  static const cream = DuoColors.background;
  static const sky = Color(0xFFBFE9FF);
  static const mint = Color(0xFFB9F6D3);
  static const banana = DuoColors.primaryYellow;
  static const coral = Color(0xFFFF8A7A);
  static const safe = DuoColors.success;
  static const danger = Color(0xFFFFB347);
  static const ink = DuoColors.textPrimary;
  static const muted = DuoColors.textSecondary;
  static const paper = DuoColors.card;
}

class LessonAssets {
  const LessonAssets._();

  static const logo = 'assets/images/logo/logo smartstep-01.png';
  static const islandBackground = 'assets/images/inslandBackground.png';
  static const island1Background = 'assets/images/Insland1_Background.png';
  static const island2Background = 'assets/images/Insland2_Background.png';
  static const island3Background = 'assets/images/Insland3_Background.png';
  static const livingRoom = 'assets/images/living_room.jpg';
  static const islandIcon = 'assets/images/Island_Icon.png';
  static const safetyIsland = 'assets/images/island/safety-island.png';
  static const kid = 'assets/images/kid.png';
  static const childHappy = 'assets/images/child-happy.png';
  static const childChoking = 'assets/images/child-choking.png';
  static const mother = 'assets/images/mother.png';
  static const ball = 'assets/images/ball.png';
  static const mascot = 'assets/images/mascot/mascot-cat-happy.png';
  static const mascotHappyWave =
      'assets/images/mascot/mascot-cat-happy-wave.png';
  static const mascotSpeaking = 'assets/images/mascot/mascot-cat-speaking.png';
  static const mascotSinging = 'assets/images/mascot/mascot-cat-singing.png';
  static const mascotConfident =
      'assets/images/mascot/mascot-cat-confident.png';
  static const mascotSulking = 'assets/images/mascot/mascot-cat-sulking.png';
  static const rewardStar = 'assets/images/reward-star.png';
}

class SafetyLesson {
  const SafetyLesson({
    required this.id,
    required this.situationId,
    required this.islandId,
    required this.islandName,
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
  final int situationId;
  final int islandId;
  final String islandName;
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
    this.asset,
    this.stepId,
    required this.title,
    required this.caption,
    required this.actionLabel,
    required this.skipLabel,
  });

  final String? asset;
  final int? stepId;
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
    required this.isCorrect,
  });

  final String id;
  final String label;
  final String helper;
  final String accessibilityLabel;
  final String imageAsset;
  final LessonVoice voice;
  final ChoiceTone tone;
  final bool isCorrect;
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

SafetyLesson _lessonFromSituation(SituationDetail situation) {
  final introStep = _stepByType(situation, 'Intro');
  final flashcardStep = _stepByType(situation, 'Flashcard');
  final wrongStep = _stepByType(situation, 'Story');
  final correctStep = _stepByType(situation, 'Result');
  final flashcard = situation.flashcard;
  final question =
      flashcard?.question ??
      flashcardStep?.content ??
      situation.intro ??
      situation.title;
  final correctAnswer = flashcard?.correctAnswer.toUpperCase() ?? 'B';
  final skill = situation.skills.isNotEmpty ? situation.skills.first : null;
  final parentReview = situation.parentReview;

  return SafetyLesson(
    id: 'situation-${situation.situationId}',
    situationId: situation.situationId,
    islandId: situation.islandId,
    islandName: situation.islandName,
    title: situation.title,
    topic: skill?.name ?? situation.islandName,
    ageRange: '4-9 tuổi',
    sceneTitle: situation.islandName,
    mission:
        situation.intro ?? _shortCopy(introStep?.content) ?? situation.title,
    openingHint: 'Bấm vào tình huống',
    inspectQuestion: question,
    questionVoice: LessonVoice(
      asset: flashcard?.questionVoiceUrl ?? '',
      text: question,
    ),
    videoIntro: _videoCopyFromStep(
      step: introStep,
      title: 'Cùng xem tình huống',
      caption: introStep?.content ?? situation.intro ?? situation.title,
      actionLabel: 'Bắt đầu intro',
      skipLabel: 'Bỏ qua intro',
    ),
    videoCorrect: _videoCopyFromStep(
      step: correctStep,
      title: 'Cách xử lý an toàn',
      caption: correctStep?.content ?? flashcard?.correctFeedback ?? '',
      actionLabel: 'Xem kết quả đúng',
      skipLabel: 'Bỏ qua clip',
    ),
    videoWrong: _videoCopyFromStep(
      step: wrongStep,
      title: 'Dừng lại và sửa lựa chọn',
      caption: wrongStep?.content ?? flashcard?.wrongFeedback ?? '',
      actionLabel: 'Xem kết quả sai',
      skipLabel: 'Bỏ qua clip',
    ),
    wrongTitle: 'Chưa an toàn!',
    wrongExplanation:
        _kidWarningCopy(flashcard?.wrongFeedback ?? wrongStep?.content) ??
        'Dừng lại. Chọn cách an toàn hơn.',
    correctTitle: 'Con làm đúng rồi!',
    correctExplanation:
        flashcard?.correctFeedback ?? _shortCopy(correctStep?.content) ?? '',
    rewardTitle:
        _rewardTitle(correctStep?.content) ?? 'Một ngôi sao an toàn cho bé!',
    learningGoals: _learningGoalsFor(situation),
    choices: [
      _choiceFromFlashcard(
        id: correctAnswer == 'A' ? correctChoiceId : 'option-a',
        label: flashcard?.optionA ?? 'Lựa chọn A',
        voiceUrl: flashcard?.optionAVoiceUrl,
        imageAsset: flashcard?.optionAImageUrl,
        isCorrect: correctAnswer == 'A',
      ),
      _choiceFromFlashcard(
        id: correctAnswer == 'B' ? correctChoiceId : 'option-b',
        label: flashcard?.optionB ?? 'Lựa chọn B',
        voiceUrl: flashcard?.optionBVoiceUrl,
        imageAsset: flashcard?.optionBImageUrl,
        isCorrect: correctAnswer == 'B',
      ),
    ],
    parentNotes: ParentNotes(
      skill: skill?.description ?? situation.intro ?? situation.title,
      practice:
          parentReview?.questionText ??
          'Cùng bé nhắc lại lựa chọn an toàn trong tình huống này.',
      risk:
          parentReview?.suggestedActivity ??
          'Quan sát phản ứng của bé và luyện tập lại khi bé còn phân vân.',
    ),
  );
}

SituationStep? _stepByType(SituationDetail situation, String stepType) {
  for (final step in situation.steps) {
    if (step.stepType.toLowerCase() == stepType.toLowerCase()) {
      return step;
    }
  }

  return null;
}

LessonVideoCopy _videoCopyFromStep({
  required SituationStep? step,
  required String title,
  required String caption,
  required String actionLabel,
  required String skipLabel,
}) {
  return LessonVideoCopy(
    stepId: step?.stepId,
    asset: step?.mediaUrl,
    title: title,
    caption: caption,
    actionLabel: actionLabel,
    skipLabel: skipLabel,
  );
}

LessonChoice _choiceFromFlashcard({
  required String id,
  required String label,
  required String? voiceUrl,
  required String? imageAsset,
  required bool isCorrect,
}) {
  return LessonChoice(
    id: id,
    label: label,
    helper: isCorrect ? 'An toàn' : 'Không an toàn',
    accessibilityLabel: '$label. ${isCorrect ? 'An toàn.' : 'Không an toàn.'}',
    imageAsset:
        imageAsset ??
        (isCorrect ? LessonAssets.mother : LessonAssets.childChoking),
    voice: LessonVoice(asset: voiceUrl ?? '', text: label),
    tone: isCorrect ? ChoiceTone.safe : ChoiceTone.danger,
    isCorrect: isCorrect,
  );
}

List<String> _learningGoalsFor(SituationDetail situation) {
  final goals = situation.skills
      .map((skill) => skill.description ?? skill.name)
      .where((goal) => goal.trim().isNotEmpty)
      .toList(growable: false);

  if (goals.isNotEmpty) {
    return goals;
  }

  return [situation.intro ?? situation.title];
}

String? _shortCopy(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  return text.length <= 220 ? text : '${text.substring(0, 217)}...';
}

String? _kidWarningCopy(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
  final sentenceEnd = normalized.indexOf(RegExp(r'[.!?。]'));
  final firstSentence = sentenceEnd > 0
      ? normalized.substring(0, sentenceEnd + 1)
      : normalized;
  if (firstSentence.length <= 86) {
    return firstSentence;
  }

  final short = firstSentence.substring(0, 83).trimRight();
  return '$short...';
}

String? _rewardTitle(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  final rewardIndex = text.toLowerCase().indexOf('reward:');
  if (rewardIndex < 0) {
    return null;
  }

  final reward = text.substring(rewardIndex + 'reward:'.length).trim();
  final endIndex = reward.indexOf('.');
  return endIndex < 0 ? reward : reward.substring(0, endIndex).trim();
}

const correctChoiceId = 'ask-adult';
const _voicePlaybackRate = 0.82;
const _voiceVolume = 0.82;
const _iosWebVoiceVolume = 0.68;
const _lessonVideoVolume = 0.86;
const _iosWebLessonVideoVolume = 0.74;
const _voicePlaybackTimeout = Duration(seconds: 12);
const _voiceStartTimeout = Duration(milliseconds: 4000);
const _voiceSequenceGap = Duration(milliseconds: 360);
const _questionFallbackDuration = Duration(milliseconds: 3600);
const _choiceFallbackDuration = Duration(milliseconds: 2300);
const _voiceCompletionGrace = Duration(milliseconds: 420);
const _iosWebVoiceSequenceGap = Duration(milliseconds: 760);
const _iosWebChoiceFallbackDuration = Duration(milliseconds: 3400);
const _outsidePortraitOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
];
const _lessonLandscapeOrientations = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];
final _voiceAudioContext = AudioContext(
  android: const AudioContextAndroid(
    contentType: AndroidContentType.speech,
    usageType: AndroidUsageType.media,
    audioFocus: AndroidAudioFocus.none,
  ),
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playback,
    options: const {AVAudioSessionOptions.mixWithOthers},
  ),
);

final _mediaResolver = _BackendMediaResolver(SituationService());

String _voiceAssetPath(String asset) {
  const assetsPrefix = 'assets/';
  return asset.startsWith(assetsPrefix)
      ? asset.substring(assetsPrefix.length)
      : asset;
}

class _BackendMediaResolver {
  _BackendMediaResolver(this._situationService);

  final SituationService _situationService;
  final Map<int, SignedMediaUrl> _signedUrlCache = {};
  final Map<String, SignedMediaUrl> _signedVoiceUrlCache = {};

  Future<Uri?> signedVideoUrlFor(LessonVideoCopy copy) async {
    final stepId = copy.stepId;
    if (stepId == null || copy.asset == null || copy.asset!.trim().isEmpty) {
      return null;
    }
    if (copy.asset!.trim().startsWith('assets/')) {
      return null;
    }

    if (!_situationService.isEnabled) {
      throw const MediaConfigurationException(
        'SMARTSTEPS_API_BASE_URL is not configured.',
      );
    }

    final cachedUrl = _signedUrlCache[stepId];
    if (cachedUrl != null && cachedUrl.isFresh) {
      return cachedUrl.uri;
    }

    final signedUrl = await _situationService.createSignedMediaUrl(stepId);
    _signedUrlCache[stepId] = signedUrl;
    return signedUrl.uri;
  }

  Future<Uri?> signedVoiceUrlFor(String asset) async {
    final mediaUrl = asset.trim();
    if (mediaUrl.isEmpty || mediaUrl.startsWith('assets/')) {
      return null;
    }

    if (!_situationService.isEnabled) {
      throw const MediaConfigurationException(
        'SMARTSTEPS_API_BASE_URL is not configured.',
      );
    }

    final cachedUrl = _signedVoiceUrlCache[mediaUrl];
    if (cachedUrl != null && cachedUrl.isFresh) {
      return cachedUrl.uri;
    }

    final signedUrl = await _situationService.createSignedVoiceUrl(mediaUrl);
    _signedVoiceUrlCache[mediaUrl] = signedUrl;
    return signedUrl.uri;
  }
}

class LessonGameScreen extends StatefulWidget {
  const LessonGameScreen({
    super.key,
    required this.lesson,
    this.profileStorage,
    this.onLessonCompleted,
  });

  final SafetyLesson lesson;
  final LocalProfileStorage? profileStorage;
  final ValueChanged<ChildProfile>? onLessonCompleted;

  @override
  State<LessonGameScreen> createState() => _LessonGameScreenState();
}

class _LessonGameScreenState extends State<LessonGameScreen> {
  LessonPhase _phase = LessonPhase.introVideo;
  String? _selectedChoiceId;
  bool _parentReadingMode = false;
  bool _hasRecordedCompletion = false;
  Timer? _rewardTimer;
  SmartStepsAudioController? _audioController;

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

  bool get _isResultFocusPhase {
    return _phase == LessonPhase.correct ||
        _phase == LessonPhase.wrong ||
        _phase == LessonPhase.rewardBurst ||
        _phase == LessonPhase.reward;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_enterLessonViewingMode());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAudioController = SmartStepsAudioScope.maybeOf(context);
    if (_audioController == nextAudioController) {
      return;
    }

    _audioController?.restoreMusic();
    _audioController = nextAudioController;
    _audioController?.duckMusic();
  }

  @override
  void dispose() {
    _rewardTimer?.cancel();
    _audioController?.stopCelebration();
    _audioController?.restoreMusic();
    unawaited(_restoreSystemViewingMode());
    super.dispose();
  }

  Future<void> _enterLessonViewingMode() async {
    try {
      await SystemChrome.setPreferredOrientations(_lessonLandscapeOrientations);
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
    _audioController?.stopCelebration();
    setState(() {
      _selectedChoiceId = null;
      _hasRecordedCompletion = false;
      _phase = LessonPhase.introVideo;
    });
  }

  void _toggleReadingMode() {
    setState(() {
      _parentReadingMode = !_parentReadingMode;
    });
  }

  void _exitLesson() {
    _audioController?.stopCelebration();
    Navigator.of(context).maybePop();
  }

  void _completeVideo() {
    var shouldPlayCelebration = false;
    var shouldPlayWarning = false;

    setState(() {
      switch (_phase) {
        case LessonPhase.introVideo:
          _phase = LessonPhase.inspectObject;
        case LessonPhase.correctVideo:
          _phase = LessonPhase.correct;
          shouldPlayCelebration = true;
        case LessonPhase.wrongVideo:
          _phase = LessonPhase.wrong;
          shouldPlayWarning = true;
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

    if (shouldPlayCelebration) {
      _audioController?.playCelebration();
    } else if (shouldPlayWarning) {
      _audioController?.playWarning();
    }
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
    final selectedChoice = widget.lesson.choices.firstWhere(
      (choice) => choice.id == choiceId,
      orElse: () => widget.lesson.choices.last,
    );

    if (!selectedChoice.isCorrect) {
      unawaited(HapticFeedback.mediumImpact());
    }

    setState(() {
      _selectedChoiceId = choiceId;
      _phase = selectedChoice.isCorrect
          ? LessonPhase.correctVideo
          : LessonPhase.wrongVideo;
    });
  }

  void _retryChoice() {
    _audioController?.stopCelebration();
    setState(() {
      _selectedChoiceId = null;
      _phase = LessonPhase.inspectObject;
    });
  }

  void _showReward() {
    _rewardTimer?.cancel();
    _audioController?.stopCelebration();
    if (!_hasRecordedCompletion) {
      _hasRecordedCompletion = true;
      unawaited(_recordLessonCompletion());
    }
    _audioController?.playSuccess();
    setState(() {
      _phase = LessonPhase.rewardBurst;
    });

    _rewardTimer = Timer(_rewardBurstDuration, () {
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

  Future<void> _recordLessonCompletion() async {
    final profileStorage = widget.profileStorage;
    if (profileStorage == null) {
      return;
    }

    try {
      final lesson = widget.lesson;
      final profile = await profileStorage.recordLessonCompletion(
        situationId: lesson.situationId,
        islandId: lesson.islandId,
        islandName: lesson.islandName,
        lessonTitle: lesson.title,
        skillName: lesson.topic,
        skillDescription: lesson.parentNotes.skill,
        practicePrompt: lesson.parentNotes.practice,
        riskAlert: lesson.parentNotes.risk,
      );

      widget.onLessonCompleted?.call(profile);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cộng +1 điểm kỹ năng ${lesson.topic}.')),
      );
    } catch (error, stackTrace) {
      debugPrint('SmartSteps lesson completion save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final isFlashcardPhase = _phase == LessonPhase.inspectObject;
    final showFullHeader = !isFlashcardPhase && !_isResultFocusPhase;

    if (_isVideoPhase) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _buildStage(lesson)),
            Positioned(
              left: 14,
              top: 14,
              child: SafeArea(child: _LessonExitButton(onPressed: _exitLesson)),
            ),
          ],
        ),
      );
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
                if (showFullHeader) ...[
                  _GameHeader(
                    lesson: lesson,
                    hasReward: _hasReward,
                    isParentReadingMode: _parentReadingMode,
                    onToggleReadingMode: _toggleReadingMode,
                    onRestart: _restartLesson,
                    onExit: _exitLesson,
                  ),
                  const SizedBox(height: 10),
                ],
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (!isFlashcardPhase)
                        Positioned.fill(child: _buildStage(lesson)),
                      if (_phase == LessonPhase.correct)
                        _CorrectCelebrationOverlay(onTap: _showReward),
                      if (_phase == LessonPhase.wrong)
                        _WrongFeedbackOverlay(
                          title: lesson.wrongTitle,
                          body: lesson.wrongExplanation,
                          actionLabel: 'Thử lại lần nữa',
                          onAction: _retryChoice,
                        ),
                      if (_phase == LessonPhase.inspectObject)
                        _QuestionOverlay(
                          lesson: lesson,
                          selectedChoice: _selectedChoice,
                          isParentReadingMode: _parentReadingMode,
                          onSelectChoice: _selectChoice,
                        ),
                      if (isFlashcardPhase)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: _LessonExitButton(onPressed: _exitLesson),
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
                      if (_isResultFocusPhase)
                        _CompactLessonControls(
                          onRestart: _restartLesson,
                          onExit: _exitLesson,
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
        );
    }
  }
}

class _LessonExitButton extends StatelessWidget {
  const _LessonExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Thoát bài học',
      child: SmartStepsPressEffect(
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            fixedSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            foregroundColor: GameColors.ink,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.9),
                width: 3,
              ),
            ),
          ),
          child: const Icon(Icons.close_rounded, size: 26),
        ),
      ),
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({
    required this.lesson,
    required this.hasReward,
    required this.isParentReadingMode,
    required this.onToggleReadingMode,
    required this.onRestart,
    required this.onExit,
  });

  final SafetyLesson lesson;
  final bool hasReward;
  final bool isParentReadingMode;
  final VoidCallback onToggleReadingMode;
  final VoidCallback onRestart;
  final VoidCallback onExit;

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
                  label: 'Thoát bài học',
                  icon: Icons.close_rounded,
                  onPressed: onExit,
                ),
                const SizedBox(width: 8),
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

class _CompactLessonControls extends StatelessWidget {
  const _CompactLessonControls({required this.onRestart, required this.onExit});

  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: SafeArea(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SmallCircleIconButton(
              label: 'Chơi lại màn',
              icon: Icons.restart_alt_rounded,
              onPressed: onRestart,
            ),
            const SizedBox(width: 8),
            _SmallCircleIconButton(
              label: 'Thoát bài học',
              icon: Icons.close_rounded,
              onPressed: onExit,
            ),
          ],
        ),
      ),
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
  VideoPlayerController? _videoController;
  bool _hasStartedPlayback = false;
  bool _hasFinishedVideo = false;
  bool _hasVideoLoadFailed = false;
  String? _videoLoadErrorMessage;

  bool get _isWrong => widget.variant == LessonPhase.wrongVideo;
  bool get _isReady => _videoController?.value.isInitialized ?? false;
  bool get _isPlaying => _videoController?.value.isPlaying ?? false;

  double get _progress {
    final controller = _videoController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.duration.inMilliseconds == 0) {
      return 0;
    }

    final position = controller.value.position.inMilliseconds;
    final duration = controller.value.duration.inMilliseconds;
    return (position / duration).clamp(0.0, 1.0).toDouble();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initializeVideoController());
  }

  Future<void> _initializeVideoController() async {
    VideoPlayerController? controller;
    final mediaAsset = widget.copy.asset?.trim();

    if (mediaAsset == null || mediaAsset.isEmpty) {
      if (mounted) {
        setState(() {
          _hasVideoLoadFailed = true;
          _videoLoadErrorMessage =
              'Bài học này chưa có video. Bấm bỏ qua để học phần câu hỏi.';
        });
      }
      return;
    }

    try {
      final remoteVideoUrl = await _mediaResolver.signedVideoUrlFor(
        widget.copy,
      );
      controller = mediaAsset.startsWith('assets/')
          ? VideoPlayerController.asset(
              mediaAsset,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
            )
          : remoteVideoUrl != null
          ? VideoPlayerController.networkUrl(
              remoteVideoUrl,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
            )
          : throw const MediaConfigurationException(
              'Backend did not return a signed media URL.',
            );

      controller
        ..addListener(_handleVideoTick)
        ..setLooping(false);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _videoController = controller;
      await controller.initialize();

      if (!mounted) {
        return;
      }

      setState(() {});
      await _autoplayClip();

      if (mounted) {
        setState(() {});
      }
    } catch (error, stackTrace) {
      debugPrint('SmartSteps video load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (controller != null) {
        controller.removeListener(_handleVideoTick);
        await controller.dispose();
      }
      if (mounted) {
        setState(() {
          _hasVideoLoadFailed = true;
          _videoLoadErrorMessage = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_handleVideoTick);
      controller.dispose();
    }
    super.dispose();
  }

  void _handleVideoTick() {
    if (!mounted) {
      return;
    }

    final controller = _videoController;
    if (controller == null) {
      return;
    }

    final value = controller.value;
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
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    _hasFinishedVideo = false;
    await controller.seekTo(Duration.zero);

    try {
      await controller.setVolume(
        smartStepsIsIosWeb ? _iosWebLessonVideoVolume : _lessonVideoVolume,
      );
    } catch (_) {
      // Keep playback usable on platforms that do not expose volume control.
    }

    try {
      await controller.setPlaybackSpeed(1.0);
    } catch (_) {
      // Keep the clip usable even if a platform cannot apply playback speed.
    }

    try {
      await controller.play();
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
    final controller = _videoController;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying) {
      await controller.pause();
    }
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isWrong ? GameColors.danger : GameColors.safe;
    final controller = _videoController;
    final aspectRatio = _isReady && controller != null
        ? controller.value.aspectRatio
        : 16 / 9;

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
                    ? VideoPlayer(controller!)
                    : Center(
                        child: _hasVideoLoadFailed
                            ? _VideoLoadErrorBadge(
                                message: _videoLoadErrorMessage,
                              )
                            : const _VideoLoadingBadge(),
                      ),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SmartStepsPressEffect(
                      child: TextButton(
                        onPressed: () {
                          unawaited(onSkip());
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.52),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: Text(
                          copy.skipLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
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

class _VideoLoadErrorBadge extends StatelessWidget {
  const _VideoLoadErrorBadge({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      constraints: const BoxConstraints(maxWidth: 320),
      child: Text(
        message == null || message!.isEmpty ? 'Không tải được video' : message!,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
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
  });

  final SafetyLesson lesson;
  final LessonPhase phase;
  final VoidCallback onInspectObject;

  bool get _isObjectActive => phase == LessonPhase.opening;
  bool get _isWrong => phase == LessonPhase.wrong;
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

          return _WrongScreenShake(
            isActive: _isWrong,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    LessonAssets.livingRoom,
                    fit: BoxFit.cover,
                    alignment: compact
                        ? Alignment.center
                        : Alignment.centerRight,
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WrongScreenShake extends StatefulWidget {
  const _WrongScreenShake({required this.isActive, required this.child});

  final bool isActive;
  final Widget child;

  @override
  State<_WrongScreenShake> createState() => _WrongScreenShakeState();
}

class _WrongScreenShakeState extends State<_WrongScreenShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _WrongScreenShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward(from: 0);
    }
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
      child: widget.child,
      builder: (context, child) {
        if (!widget.isActive) {
          return child!;
        }

        final fade = 1 - Curves.easeOutCubic.transform(_controller.value);
        final dx = math.sin(_controller.value * math.pi * 8) * 5 * fade;
        final dy = math.cos(_controller.value * math.pi * 6) * 2 * fade;

        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
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
      child: SmartStepsPressEffect(
        enabled: widget.isActive,
        child: GestureDetector(
          key: const ValueKey('hazard-spot'),
          onTap: widget.isActive ? widget.onTap : null,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final pulse =
                  1 + math.sin(_controller.value * math.pi * 2) * 0.06;
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
    required this.isParentReadingMode,
    required this.onSelectChoice,
  });

  final SafetyLesson lesson;
  final LessonChoice? selectedChoice;
  final bool isParentReadingMode;
  final ValueChanged<String> onSelectChoice;

  @override
  State<_QuestionOverlay> createState() => _QuestionOverlayState();
}

class _QuestionOverlayState extends State<_QuestionOverlay> {
  late AudioPlayer _voicePlayer;
  String? _activeNarrationId;
  String? _focusedChoiceId;
  bool _hasPlayedOpeningNarration = false;
  int _openingSequenceId = 0;
  int _voiceRequestId = 0;
  int _voicePlayerGeneration = 0;

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
    if (id == 'question') {
      return _questionFallbackDuration;
    }

    return smartStepsIsIosWeb
        ? _iosWebChoiceFallbackDuration
        : _choiceFallbackDuration;
  }

  Duration get _sequenceGap =>
      smartStepsIsIosWeb ? _iosWebVoiceSequenceGap : _voiceSequenceGap;

  @override
  void initState() {
    super.initState();
    _activeNarrationId = widget.isParentReadingMode ? null : 'question';
    _voicePlayer = _createVoicePlayer();
    unawaited(_prepareVoicePlayer());
    if (!widget.isParentReadingMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_playOpeningNarrationOnce());
      });
    }
  }

  @override
  void didUpdateWidget(covariant _QuestionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isParentReadingMode == oldWidget.isParentReadingMode) {
      return;
    }

    if (widget.isParentReadingMode) {
      _openingSequenceId++;
      _voiceRequestId++;
      _hasPlayedOpeningNarration = false;
      _activeNarrationId = null;
      _focusedChoiceId = null;
      unawaited(_stopVoicePlayer());
      return;
    }

    _activeNarrationId = 'question';
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
      await _voicePlayer.setVolume(_voiceVolumeForPlatform);
    } catch (error, stackTrace) {
      debugPrint('SmartSteps voice player setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  double get _voiceVolumeForPlatform =>
      smartStepsIsIosWeb ? _iosWebVoiceVolume : _voiceVolume;

  AudioPlayer _createVoicePlayer() {
    if (!smartStepsIsIosWeb) {
      return AudioPlayer();
    }

    _voicePlayerGeneration += 1;
    return AudioPlayer(
      playerId: 'smartsteps-ios-voice-$_voicePlayerGeneration',
    );
  }

  Future<void> _setVoicePlaybackRate() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _voicePlayer.setPlaybackRate(1.0);
      } catch (_) {}
      return;
    }

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

      if (item.asset.trim().isEmpty) {
        continue;
      }

      final assetPath = _voiceAssetPath(item.asset);
      Uri? remoteVoiceUrl;
      try {
        remoteVoiceUrl = await _mediaResolver.signedVoiceUrlFor(item.asset);
      } catch (error, stackTrace) {
        debugPrint('SmartSteps voice signing failed for $assetPath: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (remoteVoiceUrl != null) {
        debugPrint('SmartSteps voice signed: $assetPath');
        continue;
      }

      if (!item.asset.trim().startsWith('assets/')) {
        continue;
      }

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
    if (_hasPlayedOpeningNarration || widget.isParentReadingMode) {
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
      await Future<void>.delayed(_sequenceGap);
    }

    if (mounted && sequenceId == _openingSequenceId) {
      setState(() {
        _activeNarrationId = null;
      });
    }
  }

  Future<void> _playNarration(String id, String asset, String text) async {
    if (widget.isParentReadingMode) {
      return;
    }

    _openingSequenceId++;
    await _playNarrationAsset(id, asset, text: text, clearWhenFinished: true);
  }

  void _focusNarration(String id, String asset) {
    if (widget.isParentReadingMode) {
      return;
    }

    unawaited(_playNarration(id, asset, _narrationTextFor(id)));
  }

  void _focusQuestionNarration() {
    if (widget.isParentReadingMode) {
      return;
    }

    setState(() {
      _focusedChoiceId = null;
      _activeNarrationId = 'question';
    });
    _focusNarration('question', widget.lesson.questionVoice.asset);
  }

  void _previewOrSelectChoice(LessonChoice choice) {
    if (_focusedChoiceId == choice.id) {
      _openingSequenceId++;
      _voiceRequestId++;
      unawaited(_stopVoicePlayer());
      widget.onSelectChoice(choice.id);
      return;
    }

    setState(() {
      _focusedChoiceId = choice.id;
      _activeNarrationId = choice.id;
    });
    _focusNarration(choice.id, choice.voice.asset);
  }

  void _clearFocusedNarration() {
    if (_focusedChoiceId == null && _activeNarrationId == null) {
      return;
    }

    _openingSequenceId++;
    _voiceRequestId++;
    setState(() {
      _focusedChoiceId = null;
      _activeNarrationId = null;
    });
    unawaited(_stopVoicePlayer());
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
    if (widget.isParentReadingMode) {
      return false;
    }

    final requestId = ++_voiceRequestId;
    if (asset.trim().isEmpty) {
      setState(() {
        _activeNarrationId = id;
      });
      await Future<void>.delayed(_fallbackDurationFor(id));
      if (mounted && clearWhenFinished && requestId == _voiceRequestId) {
        setState(() {
          _activeNarrationId = null;
        });
      }
      return true;
    }

    final assetPath = _voiceAssetPath(asset);
    try {
      final remoteVoiceUrl = await _mediaResolver.signedVoiceUrlFor(asset);

      setState(() {
        _activeNarrationId = id;
      });

      await _stopVoicePlayer();
      if (!mounted || requestId != _voiceRequestId) {
        return false;
      }

      final didStart = await _startVoicePlayback(
        asset: asset,
        assetPath: assetPath,
        remoteVoiceUrl: remoteVoiceUrl,
        requestId: requestId,
      );
      if (!didStart) {
        debugPrint('SmartSteps voice did not enter playing state: $assetPath');
        return false;
      }
      debugPrint('SmartSteps voice playing: $assetPath');
      final minimumHold = _fallbackDurationFor(id);
      final stopwatch = Stopwatch()..start();
      await Future.any<void>([
        _voicePlayer.onPlayerComplete.first.then<void>((_) {}),
        Future<void>.delayed(minimumHold + _voiceCompletionGrace),
      ]).timeout(_voicePlaybackTimeout, onTimeout: () {});
      stopwatch.stop();
      if (stopwatch.elapsed < minimumHold &&
          mounted &&
          requestId == _voiceRequestId) {
        await Future<void>.delayed(minimumHold - stopwatch.elapsed);
      }
      if (smartStepsIsIosWeb && mounted && requestId == _voiceRequestId) {
        await _resetVoicePlayerForNextClip();
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

  Future<bool> _startVoicePlayback({
    required String asset,
    required String assetPath,
    required Uri? remoteVoiceUrl,
    required int requestId,
  }) async {
    if (smartStepsIsIosWeb) {
      await _replaceVoicePlayerForNextClip();
      if (!mounted || requestId != _voiceRequestId) {
        return false;
      }

      final source = await _voiceSourceFor(
        asset: asset,
        assetPath: assetPath,
        remoteVoiceUrl: remoteVoiceUrl,
      );
      if (source == null || !mounted || requestId != _voiceRequestId) {
        return false;
      }

      final startedFuture = _voicePlayer.onPlayerStateChanged
          .where((state) => state == PlayerState.playing)
          .first
          .timeout(_voiceStartTimeout, onTimeout: () => _voicePlayer.state);
      await _voicePlayer.play(
        source,
        volume: _voiceVolumeForPlatform,
        ctx: _voiceAudioContext,
        mode: PlayerMode.mediaPlayer,
      );
      final startState = await startedFuture;
      return startState == PlayerState.playing ||
          _voicePlayer.state == PlayerState.playing;
    }

    final source = await _voiceSourceFor(
      asset: asset,
      assetPath: assetPath,
      remoteVoiceUrl: remoteVoiceUrl,
    );
    if (source == null || !mounted || requestId != _voiceRequestId) {
      return false;
    }

    await _voicePlayer.setSource(source);
    if (!mounted || requestId != _voiceRequestId) {
      return false;
    }
    await _setVoicePlaybackRate();
    if (!mounted || requestId != _voiceRequestId) {
      return false;
    }
    final startedFuture = _voicePlayer.onPlayerStateChanged
        .where((state) => state == PlayerState.playing)
        .first
        .timeout(_voiceStartTimeout, onTimeout: () => _voicePlayer.state);
    await _voicePlayer.resume();
    final startState = await startedFuture;
    return startState == PlayerState.playing ||
        _voicePlayer.state == PlayerState.playing;
  }

  Future<Source?> _voiceSourceFor({
    required String asset,
    required String assetPath,
    required Uri? remoteVoiceUrl,
  }) async {
    if (remoteVoiceUrl != null) {
      return UrlSource(remoteVoiceUrl.toString(), mimeType: 'audio/mpeg');
    }

    if (!asset.trim().startsWith('assets/')) {
      debugPrint('SmartSteps voice has no signed URL: $assetPath');
      return null;
    }

    await rootBundle.load(asset);
    return AssetSource(assetPath, mimeType: 'audio/mpeg');
  }

  Future<void> _resetVoicePlayerForNextClip() async {
    try {
      await _voicePlayer.stop();
      await _voicePlayer.release();
      await _prepareVoicePlayer();
    } catch (error, stackTrace) {
      debugPrint('SmartSteps voice reset failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _replaceVoicePlayerForNextClip() async {
    try {
      await _voicePlayer.stop();
      await _voicePlayer.dispose();
    } catch (_) {
      // Keep replacement best-effort for Safari's stricter audio lifecycle.
    }

    _voicePlayer = _createVoicePlayer();
    await _prepareVoicePlayer();
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
              padding: EdgeInsets.fromLTRB(
                isLandscape ? 68 : 16,
                isLandscape ? 8 : 62,
                isLandscape ? 16 : 16,
                isLandscape ? 12 : 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFFF2B7),
                    GameColors.cream,
                    GameColors.sky.withValues(alpha: 0.82),
                  ],
                ),
              ),
              child: _QuestionPanel(
                lesson: widget.lesson,
                selectedChoice: widget.selectedChoice,
                focusedChoiceId: _focusedChoiceId,
                activeNarrationId: _activeNarrationId,
                isLandscape: isLandscape,
                onQuestionTap: _focusQuestionNarration,
                onChoiceTap: _previewOrSelectChoice,
                onClearFocus: _clearFocusedNarration,
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
    required this.focusedChoiceId,
    required this.activeNarrationId,
    required this.isLandscape,
    required this.onQuestionTap,
    required this.onChoiceTap,
    required this.onClearFocus,
  });

  final SafetyLesson lesson;
  final LessonChoice? selectedChoice;
  final String? focusedChoiceId;
  final String? activeNarrationId;
  final bool isLandscape;
  final VoidCallback onQuestionTap;
  final ValueChanged<LessonChoice> onChoiceTap;
  final VoidCallback onClearFocus;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useHorizontalChoices = constraints.maxWidth >= 620;
        final compactCards =
            constraints.maxHeight < 430 || constraints.maxWidth < 430;
        final choices = lesson.choices.map((choice) {
          final isFocused = focusedChoiceId == choice.id;
          final isNarrating = activeNarrationId == choice.id;
          return _KidChoiceCard(
            choice: choice,
            isSelected: selectedChoice?.id == choice.id,
            isHighlighted: isFocused || isNarrating,
            isNarrating: isNarrating,
            isCompact: compactCards,
            onTap: () => onChoiceTap(choice),
          );
        }).toList();

        final prompt = _SimpleQuestionPrompt(
          lesson: lesson,
          isActive: activeNarrationId == 'question',
          isCompact: compactCards,
          onTap: onQuestionTap,
        );

        final choiceArea = useHorizontalChoices
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: choices.first),
                  const SizedBox(width: 16),
                  Expanded(child: choices.last),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: choices.first),
                  const SizedBox(height: 14),
                  Expanded(child: choices.last),
                ],
              );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClearFocus,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.fromLTRB(
              isLandscape ? 16 : 18,
              isLandscape ? 12 : 16,
              isLandscape ? 16 : 18,
              isLandscape ? 16 : 18,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.84),
                width: 4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2625324B),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: prompt,
                  ),
                ),
                SizedBox(height: isLandscape ? 14 : 18),
                Expanded(child: choiceArea),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SimpleQuestionPrompt extends StatelessWidget {
  const _SimpleQuestionPrompt({
    required this.lesson,
    required this.isActive,
    required this.isCompact,
    required this.onTap,
  });

  final SafetyLesson lesson;
  final bool isActive;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isActive ? 1.02 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: SmartStepsPressEffect(
          playSound: false,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 22,
                isCompact ? 12 : 16,
                isCompact ? 16 : 22,
                isCompact ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isActive ? GameColors.banana : Colors.white,
                  width: 4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F25324B),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                lesson.inspectQuestion,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GameColors.ink,
                  fontSize: isCompact ? 23 : 29,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KidChoiceCard extends StatelessWidget {
  const _KidChoiceCard({
    required this.choice,
    required this.isSelected,
    required this.isHighlighted,
    required this.isNarrating,
    required this.isCompact,
    required this.onTap,
  });

  final LessonChoice choice;
  final bool isSelected;
  final bool isHighlighted;
  final bool isNarrating;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDanger = choice.tone == ChoiceTone.danger;
    final accent = isDanger ? GameColors.danger : GameColors.safe;
    final isEmphasized = isHighlighted || isSelected;
    final highlightColor = isHighlighted ? GameColors.banana : accent;

    return Semantics(
      button: true,
      selected: isSelected,
      label: choice.accessibilityLabel,
      child: AnimatedScale(
        scale: isHighlighted ? 1.09 : (isSelected ? 1.04 : 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Material(
          color: Colors.transparent,
          child: SmartStepsPressEffect(
            playSound: false,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isEmphasized ? highlightColor : Colors.white,
                    width: isHighlighted ? 8 : (isSelected ? 6 : 5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: highlightColor.withValues(
                        alpha: isHighlighted ? 0.42 : 0.18,
                      ),
                      blurRadius: isHighlighted ? 34 : 18,
                      spreadRadius: isHighlighted ? 4 : 0,
                      offset: const Offset(0, 12),
                    ),
                    if (isHighlighted)
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.82),
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    const BoxShadow(
                      color: Color(0x2425324B),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      choice.imageAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0.34),
                          ],
                        ),
                      ),
                    ),
                    if (isHighlighted)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: GameColors.banana.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.94),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: isCompact ? 8 : 12,
                      right: isCompact ? 8 : 12,
                      bottom: isCompact ? 8 : 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.28),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3325324B),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 10 : 14,
                            vertical: isCompact ? 8 : 10,
                          ),
                          child: Text(
                            choice.label,
                            maxLines: isCompact ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: GameColors.ink,
                              fontSize: isCompact ? 17 : 22,
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isNarrating)
                      Positioned(
                        left: isCompact ? 8 : 12,
                        top: isCompact ? 8 : 12,
                        child: _ListeningIndicator(color: GameColors.banana),
                      ),
                    if (isHighlighted)
                      const Positioned(
                        right: 12,
                        top: 12,
                        child: _CardTapSelectHint(),
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
}

class _ListeningIndicator extends StatefulWidget {
  const _ListeningIndicator({required this.color});

  final Color color;

  @override
  State<_ListeningIndicator> createState() => _ListeningIndicatorState();
}

class _ListeningIndicatorState extends State<_ListeningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat();
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
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.78),
              width: 4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2025324B),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final phase = (_controller.value + index * 0.18) % 1.0;
              final height = 10 + Curves.easeInOutSine.transform(phase) * 17;

              return Container(
                width: 5,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: GameColors.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _CardTapSelectHint extends StatefulWidget {
  const _CardTapSelectHint();

  @override
  State<_CardTapSelectHint> createState() => _CardTapSelectHintState();
}

class _CardTapSelectHintState extends State<_CardTapSelectHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Nhấn lại để chọn đáp án',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = Curves.easeInOutSine.transform(_controller.value);

          return Transform.scale(
            scale: 1 + pulse * 0.12,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: GameColors.banana,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.92),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.banana.withValues(alpha: 0.32),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                color: GameColors.ink,
                size: 31,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CorrectCelebrationOverlay extends StatefulWidget {
  const _CorrectCelebrationOverlay({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CorrectCelebrationOverlay> createState() =>
      _CorrectCelebrationOverlayState();
}

class _CorrectCelebrationOverlayState extends State<_CorrectCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _confetti = <_ConfettiSpec>[
    _ConfettiSpec(
      alignment: Alignment(-0.92, -0.78),
      color: GameColors.safe,
      size: 15,
      drift: Offset(18, 90),
      delay: 0.00,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.66, -0.58),
      color: GameColors.banana,
      size: 11,
      drift: Offset(-10, 76),
      delay: 0.16,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.32, -0.86),
      color: GameColors.coral,
      size: 13,
      drift: Offset(26, 108),
      delay: 0.08,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.05, -0.70),
      color: GameColors.sky,
      size: 17,
      drift: Offset(-18, 96),
      delay: 0.22,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.42, -0.88),
      color: GameColors.mint,
      size: 12,
      drift: Offset(18, 112),
      delay: 0.04,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.74, -0.62),
      color: GameColors.banana,
      size: 16,
      drift: Offset(-24, 84),
      delay: 0.18,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.92, -0.82),
      color: GameColors.safe,
      size: 10,
      drift: Offset(-14, 102),
      delay: 0.11,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.80, 0.05),
      color: GameColors.sky,
      size: 12,
      drift: Offset(16, 70),
      delay: 0.28,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.48, 0.22),
      color: GameColors.banana,
      size: 18,
      drift: Offset(-18, 86),
      delay: 0.33,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.18, 0.16),
      color: GameColors.coral,
      size: 12,
      drift: Offset(22, 78),
      delay: 0.26,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.62, 0.04),
      color: GameColors.safe,
      size: 14,
      drift: Offset(-20, 92),
      delay: 0.38,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.86, 0.26),
      color: GameColors.mint,
      size: 11,
      drift: Offset(-24, 72),
      delay: 0.31,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.96, -0.28),
      color: GameColors.coral,
      size: 18,
      drift: Offset(36, 118),
      delay: 0.47,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.18, -0.46),
      color: GameColors.banana,
      size: 14,
      drift: Offset(-34, 132),
      delay: 0.52,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.34, -0.44),
      color: GameColors.safe,
      size: 20,
      drift: Offset(28, 126),
      delay: 0.57,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.96, -0.22),
      color: GameColors.sky,
      size: 15,
      drift: Offset(-42, 116),
      delay: 0.49,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.70, -0.94),
      color: GameColors.mint,
      size: 13,
      drift: Offset(18, 146),
      delay: 0.62,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.04, -0.96),
      color: GameColors.coral,
      size: 16,
      drift: Offset(-22, 150),
      delay: 0.67,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.58, -0.96),
      color: GameColors.safe,
      size: 12,
      drift: Offset(20, 142),
      delay: 0.71,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.98, 0.46),
      color: GameColors.banana,
      size: 17,
      drift: Offset(54, 76),
      delay: 0.78,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.98, 0.52),
      color: GameColors.coral,
      size: 14,
      drift: Offset(-56, 78),
      delay: 0.82,
    ),
    _ConfettiSpec(
      alignment: Alignment(-0.28, 0.48),
      color: GameColors.sky,
      size: 15,
      drift: Offset(-30, 96),
      delay: 0.88,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.42, 0.42),
      color: GameColors.mint,
      size: 18,
      drift: Offset(34, 92),
      delay: 0.92,
      isCircle: true,
    ),
    _ConfettiSpec(
      alignment: Alignment(0.00, -0.18),
      color: GameColors.banana,
      size: 22,
      drift: Offset(0, 118),
      delay: 0.96,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Semantics(
        button: true,
        label: 'Chạm để nhận sao',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final badgeAlignment = compact
                      ? const Alignment(-0.34, 0.10)
                      : const Alignment(-0.18, 0.08);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CelebrationRaysPainter(progress),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SideFireworksPainter(progress),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CenterBurstPainter(progress),
                        ),
                      ),
                      for (final spec in _confetti)
                        _CelebrationConfettiPiece(
                          spec: spec,
                          progress: progress,
                        ),
                      Align(
                        alignment: badgeAlignment,
                        child: _CelebrationBadge(
                          progress: progress,
                          compact: compact,
                        ),
                      ),
                      Align(
                        alignment: compact
                            ? const Alignment(0.78, 0.58)
                            : const Alignment(0.86, 0.42),
                        child: _TapActionPill(
                          key: const ValueKey('celebration-tap-hint'),
                          label: 'Chạm để nhận sao',
                          icon: Icons.touch_app_rounded,
                          color: GameColors.safe,
                          progress: progress,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CelebrationBadge extends StatelessWidget {
  const _CelebrationBadge({required this.progress, required this.compact});

  final double progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pulse = 1 + math.sin(progress * math.pi * 2) * 0.075;
    final float = math.sin(progress * math.pi * 2) * -11;

    return Transform.translate(
      offset: Offset(0, float),
      child: Transform.scale(
        scale: pulse,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: compact ? 250 : 326,
              height: compact ? 166 : 214,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    GameColors.banana.withValues(alpha: 0.72),
                    GameColors.safe.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.10 + math.sin(progress * math.pi * 2) * 0.055,
              child: Image.asset(
                LessonAssets.rewardStar,
                width: compact ? 144 : 196,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              bottom: compact ? -6 : -8,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 20,
                  vertical: compact ? 9 : 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: GameColors.banana.withValues(alpha: 0.92),
                    width: 5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4025324B),
                      blurRadius: 26,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Text(
                  'Tuyệt vời!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: GameColors.ink,
                    fontSize: compact ? 20 : 26,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TapActionPill extends StatelessWidget {
  const _TapActionPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.progress,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pulse = 1 + math.sin(progress * math.pi * 2) * 0.08;

    return Semantics(
      label: label,
      child: Transform.scale(
        scale: pulse,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.72), width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3325324B),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: GameColors.ink, size: 38),
        ),
      ),
    );
  }
}

class _CelebrationConfettiPiece extends StatelessWidget {
  const _CelebrationConfettiPiece({required this.spec, required this.progress});

  final _ConfettiSpec spec;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final localProgress = ((progress + spec.delay) % 1.0);
    final eased = Curves.easeOutCubic.transform(localProgress);
    final opacity = localProgress < 0.12
        ? localProgress / 0.12
        : localProgress > 0.90
        ? (1 - localProgress) / 0.10
        : 1.0;
    final rotation = (localProgress * math.pi * 4.4) + spec.delay * 10;
    final size = spec.size * 1.18;

    return Align(
      alignment: spec.alignment,
      child: Transform.translate(
        offset: Offset(
          spec.drift.dx * eased * 1.22,
          spec.drift.dy * eased * 1.18,
        ),
        child: Transform.rotate(
          angle: rotation,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0).toDouble(),
            child: Container(
              width: spec.isCircle ? size : size * 0.72,
              height: spec.isCircle ? size : size,
              decoration: BoxDecoration(
                color: spec.color,
                shape: spec.isCircle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: spec.isCircle ? null : BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.66),
                  width: 1.8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiSpec {
  const _ConfettiSpec({
    required this.alignment,
    required this.color,
    required this.size,
    required this.drift,
    required this.delay,
    this.isCircle = false,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final Offset drift;
  final double delay;
  final bool isCircle;
}

class _SideFireworksPainter extends CustomPainter {
  const _SideFireworksPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    _paintFirework(
      canvas,
      size,
      fromLeft: true,
      delay: 0.00,
      color: GameColors.banana,
      endY: 0.28,
    );
    _paintFirework(
      canvas,
      size,
      fromLeft: false,
      delay: 0.16,
      color: GameColors.safe,
      endY: 0.24,
    );
    _paintFirework(
      canvas,
      size,
      fromLeft: true,
      delay: 0.38,
      color: GameColors.coral,
      endY: 0.44,
    );
    _paintFirework(
      canvas,
      size,
      fromLeft: false,
      delay: 0.54,
      color: GameColors.sky,
      endY: 0.42,
    );
    _paintFirework(
      canvas,
      size,
      fromLeft: true,
      delay: 0.68,
      color: GameColors.mint,
      endY: 0.18,
    );
    _paintFirework(
      canvas,
      size,
      fromLeft: false,
      delay: 0.76,
      color: GameColors.coral,
      endY: 0.20,
    );
    _paintFirework(
      canvas,
      size,
      fromLeft: true,
      delay: 0.86,
      color: GameColors.safe,
      endY: 0.56,
    );
    _paintFirework(
      canvas,
      size,
      fromLeft: false,
      delay: 0.94,
      color: GameColors.banana,
      endY: 0.58,
    );
  }

  void _paintFirework(
    Canvas canvas,
    Size size, {
    required bool fromLeft,
    required double delay,
    required Color color,
    required double endY,
  }) {
    final local = (progress + delay) % 1.0;
    final launchProgress = (local / 0.34).clamp(0.0, 1.0).toDouble();
    final burstProgress = ((local - 0.30) / 0.70).clamp(0.0, 1.0).toDouble();
    final start = Offset(
      fromLeft ? -18 : size.width + 18,
      size.height * (fromLeft ? 0.76 : 0.72),
    );
    final end = Offset(
      size.width * (fromLeft ? 0.30 : 0.70),
      size.height * endY,
    );
    final rocketPosition = Offset.lerp(
      start,
      end,
      Curves.easeOutCubic.transform(launchProgress),
    )!;

    if (local < 0.36) {
      final trailPaint = Paint()
        ..color = color.withValues(alpha: 0.48)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, rocketPosition, trailPaint);
      canvas.drawCircle(
        rocketPosition,
        7 + math.sin(local * math.pi * 9).abs() * 4,
        Paint()..color = Colors.white.withValues(alpha: 0.86),
      );
      canvas.drawCircle(
        rocketPosition,
        16,
        Paint()..color = color.withValues(alpha: 0.34),
      );
      return;
    }

    if (burstProgress <= 0) {
      return;
    }

    final fade = 1 - Curves.easeInCubic.transform(burstProgress);
    final radius = 24 + Curves.easeOutCubic.transform(burstProgress) * 104;
    final linePaint = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 24; i++) {
      final angle = (math.pi * 2 / 24) * i + delay * math.pi * 2;
      final distance = radius * (0.70 + (i % 5) * 0.09);
      final particle =
          end + Offset(math.cos(angle), math.sin(angle)) * distance;
      final accent = i.isEven ? color : GameColors.banana;
      linePaint.color = accent.withValues(alpha: 0.44 * fade);
      dotPaint.color = accent.withValues(alpha: 0.90 * fade);

      canvas.drawLine(end, Offset.lerp(end, particle, 0.82)!, linePaint);
      canvas.drawCircle(particle, 4.2 + (i % 4), dotPaint);
    }

    canvas.drawCircle(
      end,
      12 + burstProgress * 16,
      Paint()..color = Colors.white.withValues(alpha: 0.70 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _SideFireworksPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CenterBurstPainter extends CustomPainter {
  const _CenterBurstPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.47, size.height * 0.45);
    final shortestSide = math.min(size.width, size.height);
    final colors = <Color>[
      GameColors.banana,
      GameColors.safe,
      GameColors.sky,
      GameColors.coral,
    ];

    for (var ring = 0; ring < 3; ring++) {
      final local = (progress + ring * 0.24) % 1.0;
      final eased = Curves.easeOutCubic.transform(local);
      final fade = 1 - Curves.easeInCubic.transform(local);
      final radius = shortestSide * (0.12 + eased * (0.28 + ring * 0.035));
      final stroke = Paint()
        ..strokeWidth = 2.8 - ring * 0.35
        ..strokeCap = StrokeCap.round;
      final dot = Paint()..style = PaintingStyle.fill;

      for (var i = 0; i < 28; i++) {
        final angle =
            (math.pi * 2 / 28) * i + progress * math.pi * (1.2 + ring * 0.25);
        final outer =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        final inner =
            center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.54);
        final accent = colors[(i + ring) % colors.length];
        stroke.color = accent.withValues(alpha: 0.46 * fade);
        dot.color = accent.withValues(alpha: 0.88 * fade);

        canvas.drawLine(inner, outer, stroke);
        canvas.drawCircle(outer, 2.8 + (i % 4) * 0.8, dot);
      }

      canvas.drawCircle(
        center,
        radius * 0.36,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..color = Colors.white.withValues(alpha: 0.30 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CenterBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CelebrationRaysPainter extends CustomPainter {
  const _CelebrationRaysPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.48, size.height * 0.53);
    final maxRadius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final rayPaint = Paint()..style = PaintingStyle.fill;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          maxRadius * 0.48,
          [
            GameColors.banana.withValues(alpha: 0.24),
            GameColors.safe.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          [0, 0.56, 1],
        ),
    );

    for (var i = 0; i < 24; i++) {
      final angle = (math.pi * 2 / 24) * i + progress * math.pi * 0.42;
      final spread = math.pi / 30;
      final opacity = i.isEven ? 0.20 : 0.12;
      rayPaint.color = (i.isEven ? GameColors.banana : GameColors.mint)
          .withValues(alpha: opacity);

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(angle - spread) * maxRadius,
          center.dy + math.sin(angle - spread) * maxRadius,
        )
        ..lineTo(
          center.dx + math.cos(angle + spread) * maxRadius,
          center.dy + math.sin(angle + spread) * maxRadius,
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = Colors.white.withValues(alpha: 0.34);
    final ringPulse = 0.48 + progress * 0.56;
    canvas.drawCircle(center, maxRadius * 0.16 * ringPulse, ringPaint);
    canvas.drawCircle(
      center,
      maxRadius * 0.25 * ((progress + 0.42) % 1),
      ringPaint..color = GameColors.banana.withValues(alpha: 0.26),
    );
    canvas.drawCircle(
      center,
      maxRadius * 0.32 * ((progress + 0.72) % 1),
      ringPaint..color = GameColors.safe.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _CelebrationRaysPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _WrongFeedbackOverlay extends StatefulWidget {
  const _WrongFeedbackOverlay({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  State<_WrongFeedbackOverlay> createState() => _WrongFeedbackOverlayState();
}

class _WrongFeedbackOverlayState extends State<_WrongFeedbackOverlay> {
  bool _isEffectFinished = false;
  bool _showRetryButton = false;

  void _markEffectFinished() {
    if (!mounted || _isEffectFinished) {
      return;
    }

    setState(() {
      _isEffectFinished = true;
    });
  }

  void _handleTap() {
    if (!_isEffectFinished || _showRetryButton) {
      return;
    }

    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _showRetryButton = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Semantics(
        liveRegion: true,
        label: 'Chưa an toàn. ${widget.body}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: Stack(
            children: [
              _WrongAnswerScrim(onFinished: _markEffectFinished),
              _WrongAnswerAlert(
                label: 'Sai rồi',
                title: widget.title,
                body: widget.body,
                actionLabel: widget.actionLabel,
                showRetryButton: _showRetryButton,
                showTapPrompt: _isEffectFinished && !_showRetryButton,
                onAction: widget.onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WrongAnswerScrim extends StatefulWidget {
  const _WrongAnswerScrim({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_WrongAnswerScrim> createState() => _WrongAnswerScrimState();
}

class _WrongAnswerScrimState extends State<_WrongAnswerScrim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _readyTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    )..repeat(reverse: true);
    _readyTimer = Timer(const Duration(milliseconds: 1200), widget.onFinished);
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -14,
      top: -10,
      right: -14,
      bottom: -14,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final flash = Curves.easeInOutSine.transform(_controller.value);

            return CustomPaint(
              painter: _WrongScreenBorderPainter(flash),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _WrongScreenBorderPainter extends CustomPainter {
  const _WrongScreenBorderPainter(this.flash);

  final double flash;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(math.min(36, size.shortestSide * 0.08));
    final rrect = RRect.fromRectAndRadius(rect.deflate(8), radius);
    final red = const Color(0xFFFF2424);
    final horizontalDepth = size.width / 3;
    final verticalDepth = size.height / 3;
    final edgeAlpha = 0.22 + flash * 0.36;
    final midAlpha = 0.10 + flash * 0.22;
    final edgeColors = [
      red.withValues(alpha: edgeAlpha),
      red.withValues(alpha: midAlpha),
      red.withValues(alpha: 0),
    ];
    const edgeStops = [0.0, 0.55, 1.0];

    void drawWarningBand(Rect band, Offset start, Offset end) {
      canvas.drawRect(
        band,
        Paint()..shader = ui.Gradient.linear(start, end, edgeColors, edgeStops),
      );
    }

    drawWarningBand(
      Rect.fromLTWH(0, 0, horizontalDepth, size.height),
      Offset.zero,
      Offset(horizontalDepth, 0),
    );
    drawWarningBand(
      Rect.fromLTWH(
        size.width - horizontalDepth,
        0,
        horizontalDepth,
        size.height,
      ),
      Offset(size.width, 0),
      Offset(size.width - horizontalDepth, 0),
    );
    drawWarningBand(
      Rect.fromLTWH(0, 0, size.width, verticalDepth),
      Offset.zero,
      Offset(0, verticalDepth),
    );
    drawWarningBand(
      Rect.fromLTWH(0, size.height - verticalDepth, size.width, verticalDepth),
      Offset(0, size.height),
      Offset(0, size.height - verticalDepth),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 38 + flash * 22
        ..color = red.withValues(alpha: 0.18 + flash * 0.24),
    );

    canvas.drawRRect(
      rrect.deflate(4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13 + flash * 8
        ..color = red.withValues(alpha: 0.56 + flash * 0.34),
    );

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 + flash * 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.34 + flash * 0.34);
    const cornerLength = 76.0;
    const inset = 26.0;

    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + cornerLength, inset),
      cornerPaint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset, inset + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset - cornerLength, inset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + cornerLength, size.height - inset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset, size.height - inset - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset - cornerLength, size.height - inset),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset, size.height - inset - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WrongScreenBorderPainter oldDelegate) {
    return oldDelegate.flash != flash;
  }
}

class _WrongAnswerAlert extends StatefulWidget {
  const _WrongAnswerAlert({
    required this.label,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.showRetryButton,
    required this.showTapPrompt,
    required this.onAction,
  });

  final String label;
  final String title;
  final String body;
  final String actionLabel;
  final bool showRetryButton;
  final bool showTapPrompt;
  final VoidCallback onAction;

  @override
  State<_WrongAnswerAlert> createState() => _WrongAnswerAlertState();
}

class _WrongAnswerAlertState extends State<_WrongAnswerAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: 46,
      child: Semantics(
        liveRegion: true,
        label: 'Chưa đúng rồi. ${widget.body}',
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final entrance = Curves.easeOutBack.transform(
              _controller.value.clamp(0.0, 1.0),
            );
            final shakeWindow = 1 - _controller.value.clamp(0.0, 1.0);
            final shake =
                math.sin(_controller.value * math.pi * 12) * 12 * shakeWindow;

            return Opacity(
              opacity: entrance.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(shake, (1 - entrance) * -22),
                child: Transform.scale(
                  scale: 0.90 + entrance * 0.10,
                  child: child,
                ),
              ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GlassPanel(
                        padding: EdgeInsets.all(compact ? 16 : 22),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _WrongAlertIcon(compact: compact),
                            SizedBox(width: compact ? 12 : 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _DockLabel(widget.label),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: GameColors.ink,
                                      fontSize: compact ? 30 : 42,
                                      fontWeight: FontWeight.w900,
                                      height: 0.98,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: GameColors.ink,
                                      fontSize: compact ? 20 : 26,
                                      fontWeight: FontWeight.w800,
                                      height: 1.08,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: widget.showRetryButton
                            ? _RetryPromptAction(
                                key: const ValueKey('retry-choice-button'),
                                label: widget.actionLabel,
                                color: GameColors.danger,
                                onPressed: widget.onAction,
                              )
                            : widget.showTapPrompt
                            ? Align(
                                key: const ValueKey('wrong-tap-prompt'),
                                alignment: Alignment.centerRight,
                                child: _TapActionPill(
                                  label: 'Chạm để tiếp tục',
                                  icon: Icons.touch_app_rounded,
                                  color: GameColors.danger,
                                  progress: _controller.value,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RetryPromptAction extends StatefulWidget {
  const _RetryPromptAction({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_RetryPromptAction> createState() => _RetryPromptActionState();
}

class _RetryPromptActionState extends State<_RetryPromptAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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
      label: widget.label,
      child: SmartStepsPressEffect(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final pulse = Curves.easeInOutSine.transform(_controller.value);
              final scale = 1 + pulse * 0.11;
              final lift = -pulse * 7;
              final angle = math.sin(_controller.value * math.pi * 2) * 0.16;

              return Transform.translate(
                offset: Offset(0, lift),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GameColors.ink,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.92),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    Transform.rotate(
                      angle: angle,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.color.withValues(alpha: 0.76),
                              width: 5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.24),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            color: GameColors.ink,
                            size: 58,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WrongAlertIcon extends StatefulWidget {
  const _WrongAlertIcon({required this.compact});

  final bool compact;

  @override
  State<_WrongAlertIcon> createState() => _WrongAlertIconState();
}

class _WrongAlertIconState extends State<_WrongAlertIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 76.0 : 98.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.86, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = _controller.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1 + pulse * 0.24,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: GameColors.coral.withValues(
                      alpha: 0.10 + pulse * 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.scale(scale: 1 + pulse * 0.035, child: child),
            ],
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: GameColors.danger,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: GameColors.coral.withValues(alpha: 0.26),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.priority_high_rounded,
            color: GameColors.ink,
            size: 52,
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
      duration: _rewardBurstDuration,
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
                0.12 + Curves.easeOutBack.transform(_controller.value) * 2.35;
            final opacity = _controller.value < 0.74
                ? 1.0
                : (1 - ((_controller.value - 0.74) / 0.26))
                      .clamp(0.0, 1.0)
                      .toDouble();
            final rotation = -0.34 + _controller.value * 0.82;

            return Container(
              color: GameColors.cream.withValues(alpha: 0.18),
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      GameColors.banana.withValues(alpha: 0.58),
                      GameColors.safe.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Image.asset(LessonAssets.rewardStar, width: 176),
            ],
          ),
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
    super.key,
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

    return SmartStepsPressEffect(
      enabled: onPressed != null,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: background,
          foregroundColor: GameColors.ink,
          disabledBackgroundColor: background.withValues(alpha: 0.58),
          disabledForegroundColor: GameColors.ink.withValues(alpha: 0.48),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.82),
              width: 3,
            ),
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
      child: SmartStepsPressEffect(
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(52, 52),
            fixedSize: const Size(52, 52),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white.withValues(alpha: 0.82),
            foregroundColor: GameColors.ink,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.82),
                width: 3,
              ),
            ),
          ),
          child: Icon(icon, size: 26),
        ),
      ),
    );
  }
}

class _SmallCircleIconButton extends StatelessWidget {
  const _SmallCircleIconButton({
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
      child: SmartStepsPressEffect(
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(42, 42),
            fixedSize: const Size(42, 42),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            foregroundColor: GameColors.ink,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(21),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.9),
                width: 3,
              ),
            ),
          ),
          child: Icon(icon, size: 23),
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

class _ParentalGateDialog extends StatefulWidget {
  const _ParentalGateDialog();

  @override
  State<_ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<_ParentalGateDialog> {
  final TextEditingController _answerController = TextEditingController();
  late int _num1;
  late int _num2;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    // Tạo phép nhân đơn giản ngẫu nhiên từ 2 đến 9
    _num1 = random.nextInt(8) + 2;
    _num2 = random.nextInt(8) + 2;
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    final answer = int.tryParse(_answerController.text.trim());
    // Kiểm tra kết quả phép tính
    if (answer == _num1 * _num2) {
      Navigator.of(context).pop(true); // Trả về true nếu tính đúng
    } else {
      setState(() {
        _errorText = 'Kết quả chưa chính xác!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Dành cho phụ huynh',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF7A1A)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Vui lòng giải phép tính sau để tiếp tục:',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '$_num1 x $_num2 = ?',
            key: const ValueKey('parental-gate-question'),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('parental-gate-answer-field'),
            controller: _answerController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Nhập kết quả',
              errorText: _errorText,
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Hủy',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
        FilledButton(
          onPressed: _checkAnswer,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFE99C),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
