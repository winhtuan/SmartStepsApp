import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/registration_avatar_service.dart';
import '../theme/duo_theme.dart';
import '../widgets/smartsteps_press_effect.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.onRegister});

  final void Function(BuildContext context)? onRegister;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _genderOptions = ['Nam', 'Nữ'];

  late final PageController _avatarPageController;
  late final List<RegistrationAvatar> _avatarOptions;
  String _selectedGender = _genderOptions.first;
  int _selectedAvatarIndex = 0;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _avatarOptions = RegistrationAvatarService.registrationAvatars;
    _avatarPageController = PageController(viewportFraction: 0.34);
  }

  @override
  void dispose() {
    _avatarPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuoColors.primaryYellow,
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final scale = (width / 412).clamp(0.86, 1.16);

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: DuoColors.primaryYellow,
                    ),
                    child: Align(
                      alignment: const Alignment(0, -0.78),
                      child: Image.asset(
                        'assets/images/mascot/mascot-cat-happy.png',
                        width: 136 * scale,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: (height * 0.77).clamp(620.0, 720.0),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(36),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        34 * scale,
                        44,
                        34 * scale,
                        28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          const Text(
                            'ĐĂNG KÝ',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Bạn đã có tài khoản?',
                                  style: TextStyle(
                                    color: Color(0xFF7A7A7A),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).maybePop();
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(64, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    color: Color(0xFFFF3F3F),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const _RegisterInput(label: 'Tên của bé'),
                          const SizedBox(height: 13),
                          _RegisterInput(
                            label: 'Tuổi',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          const SizedBox(height: 20),
                          const _FieldLabel('Giới tính'),
                          const SizedBox(height: 9),
                          _GenderSelector(
                            options: _genderOptions,
                            selectedGender: _selectedGender,
                            onChanged: (gender) {
                              setState(() {
                                _selectedGender = gender;
                              });
                            },
                          ),
                          const SizedBox(height: 22),
                          const _FieldLabel('Chọn avatar mascot'),
                          const SizedBox(height: 11),
                          _AvatarSelector(
                            controller: _avatarPageController,
                            avatars: _avatarOptions,
                            selectedIndex: _selectedAvatarIndex,
                            onChanged: (index) {
                              setState(() {
                                _selectedAvatarIndex = index;
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          _TermsCheckbox(
                            value: _acceptedTerms,
                            onOpenTerms: _showTermsDialog,
                            onChanged: (value) {
                              setState(() {
                                _acceptedTerms = value ?? false;
                              });
                            },
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: SmartStepsPressEffect(
                              enabled: _acceptedTerms,
                              child: FilledButton(
                                key: const ValueKey('register-submit-button'),
                                onPressed: _acceptedTerms
                                    ? () {
                                        widget.onRegister?.call(context);
                                      }
                                    : null,
                                style: FilledButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: const Color(0xFFFFEDA0),
                                  disabledBackgroundColor: const Color(
                                    0xFFFFEDA0,
                                  ).withValues(alpha: 0.55),
                                  foregroundColor: Colors.black,
                                  disabledForegroundColor: Colors.black
                                      .withValues(alpha: 0.42),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: const Text('Đăng ký'),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Future<void> _showTermsDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text(
            'Điều khoản sử dụng',
            style: TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'SmartSteps dùng thông tin hồ sơ để cá nhân hóa trải nghiệm học tập an toàn cho bé. Phụ huynh chịu trách nhiệm kiểm tra thông tin trước khi sử dụng. Nội dung trong ứng dụng chỉ hỗ trợ giáo dục kỹ năng an toàn và không thay thế hướng dẫn trực tiếp từ người lớn.',
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Đóng',
                style: TextStyle(
                  color: Color(0xFFFBB901),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RegisterInput extends StatelessWidget {
  const _RegisterInput({
    required this.label,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 49,
      child: TextField(
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          labelStyle: const TextStyle(
            color: Colors.black,
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
    required this.options,
    required this.selectedGender,
    required this.onChanged,
  });

  final List<String> options;
  final String selectedGender;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final gender in options) ...[
          Expanded(
            child: _GenderButton(
              label: gender,
              isSelected: selectedGender == gender,
              onPressed: () => onChanged(gender),
            ),
          ),
          if (gender != options.last) const SizedBox(width: 9),
        ],
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  const _GenderButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: SmartStepsPressEffect(
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected
                ? const Color(0xFFFFEDA0)
                : Colors.white,
            foregroundColor: Colors.black,
            side: BorderSide(
              color: isSelected ? const Color(0xFFFBB901) : Colors.black,
              width: isSelected ? 2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _AvatarSelector extends StatelessWidget {
  const _AvatarSelector({
    required this.controller,
    required this.avatars,
    required this.selectedIndex,
    required this.onChanged,
  });

  final PageController controller;
  final List<RegistrationAvatar> avatars;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 104,
          child: PageView.builder(
            controller: controller,
            padEnds: false,
            itemCount: avatars.length,
            onPageChanged: onChanged,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _AvatarButton(
                  avatar: avatars[index],
                  isSelected: selectedIndex == index,
                  onPressed: () {
                    controller.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                    );
                    onChanged(index);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < avatars.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selectedIndex == index ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: selectedIndex == index
                      ? const Color(0xFFFBB901)
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.avatar,
    required this.isSelected,
    required this.onPressed,
  });

  final RegistrationAvatar avatar;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: avatar.label,
      child: SmartStepsPressEffect(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 94,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
            decoration: BoxDecoration(
              color: avatar.color,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.transparent,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AvatarImage(avatar: avatar),
                const SizedBox(height: 5),
                Text(
                  avatar.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFFBB901),
              checkColor: Colors.black,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => onChanged(!value),
                    child: const Text(
                      'Tôi đồng ý với các ',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onOpenTerms,
                    child: const Text(
                      'điều khoản sử dụng',
                      style: TextStyle(
                        color: Color(0xFFFBB901),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFFBB901),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.avatar});

  final RegistrationAvatar avatar;

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatar.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Text(avatar.emoji, style: const TextStyle(fontSize: 31));
    }

    return SizedBox(
      width: 42,
      height: 42,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(avatar.emoji, style: const TextStyle(fontSize: 31)),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black.withValues(alpha: 0.58),
              ),
            ),
          );
        },
      ),
    );
  }
}
