import 'dart:async';

import 'package:flutter/material.dart';

import '../models/situation.dart';
import '../services/situation_service.dart';
import '../theme/duo_theme.dart';
import '../widgets/duo_components.dart';

class _LearnMascots {
  const _LearnMascots._();

  static const happyWave = 'assets/images/mascot/mascot-cat-happy-wave.png';
  static const speaking = 'assets/images/mascot/mascot-cat-speaking.png';
  static const confident = 'assets/images/mascot/mascot-cat-confident.png';
  static const sulking = 'assets/images/mascot/mascot-cat-sulking.png';
}

class ParentReportPage extends StatefulWidget {
  const ParentReportPage({
    super.key,
    required this.situationService,
    required this.isActive,
  });

  final SituationService situationService;
  final bool isActive;

  @override
  State<ParentReportPage> createState() => _ParentReportPageState();
}

class _ParentReportPageState extends State<ParentReportPage> {
  List<_ParentReportEntry> _entries = _fallbackParentReportEntries;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      unawaited(_loadReport());
    }
  }

  @override
  void didUpdateWidget(covariant ParentReportPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.situationService != widget.situationService) {
      setState(() {
        _entries = _fallbackParentReportEntries;
        _isLoading = false;
        _hasLoaded = false;
        _error = null;
      });
      if (widget.isActive) {
        unawaited(_loadReport(force: true));
      }
      return;
    }

    if (!oldWidget.isActive && widget.isActive && !_hasLoaded && !_isLoading) {
      unawaited(_loadReport());
    }
  }

  Future<void> _loadReport({bool force = false}) async {
    if (_isLoading || (!force && _hasLoaded)) {
      return;
    }

    if (!widget.situationService.isEnabled) {
      setState(() {
        _entries = _fallbackParentReportEntries;
        _isLoading = false;
        _hasLoaded = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _fetchReportEntries();
      if (!mounted) {
        return;
      }

      setState(() {
        _entries = entries.isEmpty ? _fallbackParentReportEntries : entries;
        _error = entries.isEmpty ? 'Chưa có dữ liệu báo cáo từ backend.' : null;
        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (error, stackTrace) {
      debugPrint('SmartSteps parent report failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      setState(() {
        _entries = _fallbackParentReportEntries;
        _error =
            'Đang hiển thị dữ liệu mẫu vì chưa tải được báo cáo từ backend.';
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  Future<List<_ParentReportEntry>> _fetchReportEntries() async {
    final islands = await widget.situationService.getIslands();
    final summariesByIsland = await Future.wait(
      islands.map(
        (island) =>
            widget.situationService.getIslandSituations(island.islandId),
      ),
    );
    final summaries = summariesByIsland
        .expand((items) => items)
        .toList(growable: false);

    if (summaries.isEmpty) {
      return const [];
    }

    final sortedSummaries = summaries.toList(growable: false)
      ..sort((a, b) {
        final islandCompare = a.islandId.compareTo(b.islandId);
        if (islandCompare != 0) {
          return islandCompare;
        }

        return a.orderIndex.compareTo(b.orderIndex);
      });
    final details = await Future.wait(
      sortedSummaries.map(
        (summary) =>
            widget.situationService.getSituationDetail(summary.situationId),
      ),
    );
    final entries =
        details
            .map(_ParentReportEntry.fromDetail)
            .where((entry) => entry.skillName.trim().isNotEmpty)
            .toList(growable: false)
          ..sort((a, b) {
            final islandCompare = a.islandId.compareTo(b.islandId);
            if (islandCompare != 0) {
              return islandCompare;
            }

            return a.situationOrder.compareTo(b.situationOrder);
          });

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final displayEntries = _entries.isEmpty
        ? _fallbackParentReportEntries
        : _entries;
    final focusEntry = _preferredFocusEntry(displayEntries);
    final isInitialLoading =
        _isLoading && !_hasLoaded && widget.situationService.isEnabled;

    return ColoredBox(
      color: DuoColors.background,
      child: SafeArea(
        bottom: false,
        child: isInitialLoading
            ? const _ParentReportLoadingView()
            : RefreshIndicator(
                color: DuoColors.success,
                onRefresh: () => _loadReport(force: true),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding = constraints.maxWidth > 520
                        ? 24.0
                        : 18.0;

                    return ListView(
                      key: const ValueKey('parent-report-page'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        24,
                      ),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _LearnHeader(
                                  focusEntry: focusEntry,
                                  isLoading: _isLoading,
                                ),
                                const SizedBox(height: 18),
                                if (_error != null) ...[
                                  _ReportNotice(message: _error!),
                                  const SizedBox(height: 16),
                                ],
                                _MascotInsightCard(focusEntry: focusEntry),
                                const SizedBox(height: 16),
                                _ForgottenFocusCard(focusEntry: focusEntry),
                                const SizedBox(height: 16),
                                _NextLessonSuggestionCard(
                                  focusEntry: focusEntry,
                                  entries: displayEntries,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _LearnHeader extends StatelessWidget {
  const _LearnHeader({required this.focusEntry, required this.isLoading});

  final _ParentReportEntry focusEntry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(
              child: _LearnMetricChip(
                icon: Icons.local_fire_department_rounded,
                label: '7 ngày',
                color: Color(0xFFFF8A00),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _LearnMetricChip(
                icon: Icons.bolt_rounded,
                label: '1.240 điểm',
                color: DuoColors.success,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _LearnMetricChip(
                icon: Icons.military_tech_rounded,
                label: 'Cấp 4',
                color: DuoColors.darkYellow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DuoCard(
          color: DuoColors.primaryYellow,
          borderColor: DuoColors.darkYellow.withValues(alpha: 0.32),
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
          child: Row(
            children: [
              Container(
                width: 82,
                height: 82,
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  _LearnMascots.happyWave,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tiến bộ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 27,
                                  height: 1,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HeaderContinueButton(
                          isLoading: isLoading,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bé An đang học ${focusEntry.skillName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DuoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const DuoProgressBar(value: 0.62, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LearnMetricChip extends StatelessWidget {
  const _LearnMetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DuoColors.border, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DuoColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderContinueButton extends StatelessWidget {
  const _HeaderContinueButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 42,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.72),
          foregroundColor: DuoColors.textPrimary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: DuoColors.darkYellow,
                ),
              )
            : const Text(
                'Tiếp tục',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}

class _ParentReportLoadingView extends StatelessWidget {
  const _ParentReportLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LearnHeader(
                  focusEntry: _fallbackParentReportEntries.first,
                  isLoading: true,
                ),
                const SizedBox(height: 18),
                DuoCard(
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: DuoColors.success,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Đang tải báo cáo',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SmartSteps đang tổng hợp kỹ năng và câu hỏi cho phụ huynh.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({required this.focusEntry});

  final _ParentReportEntry focusEntry;

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      color: Colors.white,
      borderColor: DuoColors.primaryYellow.withValues(alpha: 0.58),
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: DuoColors.primaryYellow,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: DuoColors.textPrimary,
              size: 44,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Tiếp tục học'),
                const SizedBox(height: 7),
                Text(
                  focusEntry.lessonTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  focusEntry.skillName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                const DuoProgressBar(value: 0.62, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotInsightCard extends StatelessWidget {
  const _MascotInsightCard({required this.focusEntry});

  final _ParentReportEntry focusEntry;

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      color: const Color(0xFFFFFDF4),
      borderColor: DuoColors.border,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(_LearnMascots.speaking, width: 84),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Trợ lý AI'),
                const SizedBox(height: 8),
                Text(
                  'Nhận xét hôm nay',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bé phản hồi tốt khi được hỏi về ${_lowerFirst(focusEntry.skillName)}.',
                  maxLines: 3,
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

class _ForgottenFocusCard extends StatelessWidget {
  const _ForgottenFocusCard({required this.focusEntry});

  final _ParentReportEntry focusEntry;

  @override
  Widget build(BuildContext context) {
    final forgottenItems = _forgottenItemsFor(focusEntry);

    return DuoCard(
      padding: const EdgeInsets.all(16),
      borderColor: DuoColors.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(_LearnMascots.sulking, width: 70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bé hay quên',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final item in forgottenItems) ...[
                  _YellowReportRow(icon: Icons.lightbulb_rounded, text: item),
                  const SizedBox(height: 8),
                ],
                Text(
                  focusEntry.realLifeQuestion,
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

class _NextLessonSuggestionCard extends StatelessWidget {
  const _NextLessonSuggestionCard({
    required this.focusEntry,
    required this.entries,
  });

  final _ParentReportEntry focusEntry;
  final List<_ParentReportEntry> entries;

  @override
  Widget build(BuildContext context) {
    final questions = _reportQuestionsFor(entries, focusEntry);

    return DuoCard(
      color: const Color(0xFFF4FFE8),
      borderColor: DuoColors.success.withValues(alpha: 0.32),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(_LearnMascots.confident, width: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Đề xuất bài học tiếp theo'),
                const SizedBox(height: 9),
                Text(
                  'Nhận biết đèn giao thông',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 9),
                Text(
                  questions.isEmpty
                      ? focusEntry.practicePrompt
                      : questions.first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: DuoColors.textSecondary,
                            size: 18,
                          ),
                          SizedBox(width: 5),
                          Text(
                            '5 phút',
                            style: TextStyle(
                              color: DuoColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DuoPrimaryButton(
                        label: 'Bắt đầu ngay',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () {},
                        backgroundColor: DuoColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  focusEntry.practicePrompt,
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

class _YellowReportRow extends StatelessWidget {
  const _YellowReportRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: DuoColors.softYellow,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: DuoColors.darkYellow, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: DuoColors.darkYellow,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _ReportNotice extends StatelessWidget {
  const _ReportNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DuoColors.border, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: DuoColors.darkYellow),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ParentReportEntry {
  const _ParentReportEntry({
    required this.situationId,
    required this.islandId,
    required this.situationOrder,
    required this.islandName,
    required this.lessonTitle,
    required this.skillName,
    required this.skillDescription,
    required this.realLifeQuestion,
    required this.practicePrompt,
    required this.watchOut,
  });

  factory _ParentReportEntry.fromDetail(SituationDetail detail) {
    final skill = detail.skills.isNotEmpty ? detail.skills.first : null;
    final parentReview = detail.parentReview;

    return _ParentReportEntry(
      situationId: detail.situationId,
      islandId: detail.islandId,
      situationOrder: detail.orderIndex,
      islandName: detail.islandName,
      lessonTitle: detail.title,
      skillName: _firstNonEmpty([skill?.name, detail.title]),
      skillDescription: _firstNonEmpty([
        skill?.description,
        detail.intro,
        detail.title,
      ]),
      realLifeQuestion: _firstNonEmpty([
        detail.flashcard?.question,
        parentReview?.questionText,
        detail.intro,
      ]),
      practicePrompt: _firstNonEmpty([
        parentReview?.questionText,
        detail.flashcard?.correctFeedback,
        detail.intro,
      ]),
      watchOut: _firstNonEmpty([
        parentReview?.suggestedActivity,
        detail.flashcard?.wrongFeedback,
        detail.intro,
      ]),
    );
  }

  final int situationId;
  final int islandId;
  final int situationOrder;
  final String islandName;
  final String lessonTitle;
  final String skillName;
  final String skillDescription;
  final String realLifeQuestion;
  final String practicePrompt;
  final String watchOut;
}

String _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final text = value?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }

  return '';
}

_ParentReportEntry _preferredFocusEntry(List<_ParentReportEntry> entries) {
  for (final entry in entries) {
    if (entry.skillName.toLowerCase().contains('giao thông')) {
      return entry;
    }
  }

  return entries.first;
}

List<String> _reportQuestionsFor(
  List<_ParentReportEntry> entries,
  _ParentReportEntry focusEntry,
) {
  final questions = <String>[];
  void add(String value) {
    final text = value.trim();
    if (text.isNotEmpty && !questions.contains(text)) {
      questions.add(text);
    }
  }

  add(focusEntry.realLifeQuestion);
  add(focusEntry.practicePrompt);
  for (final entry in entries) {
    if (entry.islandId == focusEntry.islandId) {
      add(entry.realLifeQuestion);
    }
  }
  for (final entry in entries) {
    add(entry.realLifeQuestion);
  }

  return questions.take(3).toList(growable: false);
}

List<String> _forgottenItemsFor(_ParentReportEntry entry) {
  return [
    _compactReportText(entry.watchOut),
    _compactReportText('Ôn lại ${entry.lessonTitle}'),
  ];
}

String _lowerFirst(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return text;
  }

  return '${text[0].toLowerCase()}${text.substring(1)}';
}

String _compactReportText(String value) {
  final text = value.trim();
  if (text.length <= 78) {
    return text;
  }

  return '${text.substring(0, 75)}...';
}

const _fallbackParentReportEntries = [
  _ParentReportEntry(
    situationId: 1,
    islandId: 1,
    situationOrder: 1,
    islandName: 'An toàn cá nhân',
    lessonTitle: 'Bài 1: Vật tròn lấp lánh',
    skillName: 'An toàn dị vật',
    skillDescription: 'Nhận biết đồ vật nhỏ có nguy cơ gây hóc hoặc nuốt phải.',
    realLifeQuestion:
        'Nếu con thấy một vật nhỏ lấp lánh trên sàn, con sẽ làm gì?',
    practicePrompt:
        'Cùng bé kiểm tra đồ chơi xem có chi tiết nhỏ bị rơi ra không.',
    watchOut: 'Giữ pin nút, nam châm và dị vật nhỏ xa tầm tay của bé.',
  ),
  _ParentReportEntry(
    situationId: 2,
    islandId: 1,
    situationOrder: 2,
    islandName: 'An toàn cá nhân',
    lessonTitle: 'Bài 2: Bàn tay kỳ diệu và các cái lỗ',
    skillName: 'An toàn điện',
    skillDescription:
        'Nhận biết ổ điện nguy hiểm và không chọc vật lạ vào ổ cắm.',
    realLifeQuestion:
        'Ổ cắm điện có phải đồ chơi không? Con nên đứng gần hay tránh xa?',
    practicePrompt:
        'Đi một vòng quanh nhà và chỉ cho bé các vị trí ổ điện cần tránh.',
    watchOut: 'Ưu tiên dùng nắp đậy ổ điện ở các vị trí thấp trong nhà.',
  ),
  _ParentReportEntry(
    situationId: 3,
    islandId: 2,
    situationOrder: 1,
    islandName: 'An toàn đường phố',
    lessonTitle: 'Bài 3: Nhận biết đèn giao thông',
    skillName: 'An toàn giao thông',
    skillDescription:
        'Nhận biết màu đèn và chờ người lớn trước khi sang đường.',
    realLifeQuestion:
        'Khi đèn đỏ bật lên, con cần dừng lại hay chạy qua đường?',
    practicePrompt: 'Chơi trò chỉ màu đèn giao thông và nói hành động đúng.',
    watchOut: 'Bé còn dễ nhầm giữa chờ đèn xanh và tự ý chạy qua đường.',
  ),
];
