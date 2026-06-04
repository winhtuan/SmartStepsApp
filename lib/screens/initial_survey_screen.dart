import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/child_profile.dart';
import '../services/local_profile_storage.dart';
import '../widgets/smartsteps_press_effect.dart';

class InitialSurveyScreen extends StatefulWidget {
  const InitialSurveyScreen({
    super.key,
    required this.profileStorage,
    required this.onCompleted,
  });

  final LocalProfileStorage profileStorage;
  final VoidCallback onCompleted;

  @override
  State<InitialSurveyScreen> createState() => _InitialSurveyScreenState();
}

class _InitialSurveyScreenState extends State<InitialSurveyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _selectedGender;
  bool _acceptedTerms = false;
  bool _isSaving = false;
  final Set<int> _selectedGoals = {0, 1};

  bool get _canSubmit {
    if (_isSaving) {
      return false;
    }

    return _nameController.text.trim().isNotEmpty &&
        _ageController.text.trim().isNotEmpty &&
        _selectedGender != null &&
        _selectedGoals.isNotEmpty &&
        _acceptedTerms;
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleFieldChanged);
    _ageController.addListener(_handleFieldChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    _ageController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFieldChanged() {
    setState(() {});
  }

  void _toggleGoal(int index, bool value) {
    setState(() {
      if (value) {
        _selectedGoals.add(index);
      } else {
        _selectedGoals.remove(index);
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final profile = ChildProfile(
        childName: _nameController.text.trim(),
        age: _ageController.text.trim(),
        gender: _selectedGender!,
        learningGoals: _selectedGoals
            .toList(growable: false)
            .map((index) => _learningGoals[index])
            .toList(growable: false),
        acceptedTerms: _acceptedTerms,
        completedAt: DateTime.now(),
      );
      await widget.profileStorage.saveProfile(profile);

      if (!mounted) {
        return;
      }

      widget.onCompleted();
    } catch (error, stackTrace) {
      debugPrint('SmartSteps profile save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa lưu được thông tin. Vui lòng thử lại.'),
        ),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('initial-survey-screen'),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 520 ? 34.0 : 30.0;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                30,
              ),
              children: [
                const _SurveyTitle(),
                const SizedBox(height: 16),
                const _MascotGreeting(),
                const SizedBox(height: 22),
                _SurveyTextField(
                  key: const ValueKey('child-name-field'),
                  controller: _nameController,
                  hintText: 'Tên',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SurveyTextField(
                        key: const ValueKey('child-age-field'),
                        controller: _ageController,
                        hintText: 'Tuổi',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _GenderMenu(
                        selectedGender: _selectedGender,
                        onChanged: (gender) {
                          setState(() {
                            _selectedGender = gender;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _GoalSection(
                  selectedGoals: _selectedGoals,
                  onChanged: _toggleGoal,
                ),
                const SizedBox(height: 34),
                _TermsSection(
                  acceptedTerms: _acceptedTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptedTerms = value;
                    });
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 56,
                  child: SmartStepsPressEffect(
                    enabled: _canSubmit,
                    child: FilledButton(
                      key: const ValueKey('initial-survey-submit-button'),
                      onPressed: _canSubmit
                          ? () {
                              unawaited(_submit());
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8DBB43),
                        disabledBackgroundColor: const Color(
                          0xFF8DBB43,
                        ).withValues(alpha: 0.38),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.72,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Bắt đầu'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SurveyTitle extends StatelessWidget {
  const _SurveyTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'THÔNG TIN CƠ BẢN',
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Color(0xFF8DBB43),
        fontSize: 34,
        fontWeight: FontWeight.w900,
        height: 1.05,
      ),
    );
  }
}

class _MascotGreeting extends StatelessWidget {
  const _MascotGreeting();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/mascot/mascot-cat-happy-wave.png',
                width: 245,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            right: 26,
            bottom: 60,
            child: CustomPaint(
              painter: const _SpeechTailPainter(color: Color(0xFFFFBE55)),
              child: Container(
                width: 118,
                height: 86,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFBE55),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'Xin Chào',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechTailPainter extends CustomPainter {
  const _SpeechTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(6, size.height * 0.58)
      ..lineTo(-32, size.height * 0.78)
      ..lineTo(15, size.height * 0.72)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeechTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SurveyTextField extends StatelessWidget {
  const _SurveyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 25,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Colors.black,
            fontSize: 25,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: const Color(0xFFFFEFA8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 30),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(33),
            borderSide: const BorderSide(color: Colors.black, width: 1.6),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(33),
            borderSide: const BorderSide(color: Colors.black, width: 2),
          ),
        ),
      ),
    );
  }
}

class _GenderMenu extends StatelessWidget {
  const _GenderMenu({required this.selectedGender, required this.onChanged});

  final String? selectedGender;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const ValueKey('gender-menu-button'),
      onSelected: onChanged,
      itemBuilder: (context) {
        return const [
          PopupMenuItem(value: 'Nam', child: Text('Nam')),
          PopupMenuItem(value: 'Nữ', child: Text('Nữ')),
          PopupMenuItem(value: 'Khác', child: Text('Khác')),
        ];
      },
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFA8),
          borderRadius: BorderRadius.circular(33),
          border: Border.all(color: Colors.black, width: 1.6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedGender ?? 'Giới tính',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Colors.black),
          ],
        ),
      ),
    );
  }
}

class _GoalSection extends StatelessWidget {
  const _GoalSection({required this.selectedGoals, required this.onChanged});

  final Set<int> selectedGoals;
  final void Function(int index, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'MỤC TIÊU HỌC',
            style: TextStyle(
              color: Colors.black,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < _learningGoals.length; index++) ...[
            _GoalRow(
              index: index,
              label: _learningGoals[index],
              isSelected: selectedGoals.contains(index),
              onChanged: (value) => onChanged(index, value),
            ),
            if (index != _learningGoals.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.index,
    required this.label,
    required this.isSelected,
    required this.onChanged,
  });

  final int index;
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SmartStepsPressEffect(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(!isSelected),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.fromLTRB(18, 5, 10, 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEFA8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SurveyCheckbox(
                key: ValueKey('goal-checkbox-$index'),
                value: isSelected,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.acceptedTerms, required this.onChanged});

  final bool acceptedTerms;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 1.6),
      ),
      child: Column(
        children: [
          const Text(
            'Điều khoản của App',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 42),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tôi đồng ý các điều khoản của app',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _SurveyCheckbox(
                key: const ValueKey('initial-survey-terms-checkbox'),
                value: acceptedTerms,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurveyCheckbox extends StatelessWidget {
  const _SurveyCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Checkbox(
          value: value,
          onChanged: (nextValue) => onChanged(nextValue ?? false),
          activeColor: const Color(0xFF8DBB43),
          checkColor: Colors.white,
          side: const BorderSide(color: Colors.black, width: 1.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
    );
  }
}

const _learningGoals = [
  'Biết quan sát và đặt câu hỏi',
  'Tư duy logic qua tình huống thực tế',
  'Rèn tư duy sáng tạo qua trò chơi thực tế',
  'Học cách thử sai và sửa lỗi',
  'Tự tin nói chuyện với người khác',
  'Biết xử lý khi bị lạc',
  'Nhận biết người lạ nguy hiểm',
  'Nhận biết tình huống khẩn cấp',
  'Học quản lý thời gian đơn giản',
  'Tìm hiểu văn hoá và cuộc sống',
];
