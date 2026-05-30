import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_feedback.dart';
import '../models/child_profile.dart';

class LocalProfileStorage {
  const LocalProfileStorage({Directory? directoryOverride})
    : _directoryOverride = directoryOverride;

  final Directory? _directoryOverride;

  Future<bool> hasProfile() async {
    final profile = await readProfile();
    return profile != null;
  }

  Future<ChildProfile?> readProfile() async {
    try {
      final file = await _profileFile();
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic>) {
        return null;
      }

      return ChildProfile.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('SmartSteps profile read failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> saveProfile(ChildProfile profile) async {
    final file = await _profileFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(profile.toJson()), flush: true);
  }

  Future<ChildProfile> activatePremium(String code) async {
    if (code.trim().toUpperCase() != premiumActivationCode) {
      throw const PremiumActivationException('Mã Premium không hợp lệ.');
    }

    final currentProfile = await readProfile();
    if (currentProfile == null) {
      throw const PremiumActivationException(
        'Cần hoàn tất khảo sát ban đầu trước khi nâng cấp.',
      );
    }

    final updatedProfile = currentProfile.copyWith(
      isPremium: true,
      premiumCode: premiumActivationCode,
      premiumActivatedAt: DateTime.now(),
    );
    await saveProfile(updatedProfile);
    return updatedProfile;
  }

  Future<ChildProfile> recordLessonCompletion({
    required int situationId,
    required int islandId,
    required String islandName,
    required String lessonTitle,
    required String skillName,
    required String skillDescription,
    required String practicePrompt,
    required String riskAlert,
    int points = 1,
  }) async {
    final currentProfile = await readProfile();
    if (currentProfile == null) {
      throw const ProfileStorageException(
        'Cần hoàn tất khảo sát ban đầu trước khi lưu tiến độ.',
      );
    }

    final now = DateTime.now();
    final progress = currentProfile.skillProgress.toList(growable: true);
    final existingIndex = progress.indexWhere(
      (item) => item.situationId == situationId,
    );

    if (existingIndex >= 0) {
      final existing = progress[existingIndex];
      progress[existingIndex] = existing.copyWith(
        islandName: islandName,
        lessonTitle: lessonTitle,
        skillName: skillName,
        skillDescription: skillDescription,
        practicePrompt: practicePrompt,
        riskAlert: riskAlert,
        points: existing.points + points,
        completedCount: existing.completedCount + 1,
        lastCompletedAt: now,
      );
    } else {
      progress.add(
        SkillProgress(
          situationId: situationId,
          islandId: islandId,
          islandName: islandName,
          lessonTitle: lessonTitle,
          skillName: skillName,
          skillDescription: skillDescription,
          practicePrompt: practicePrompt,
          riskAlert: riskAlert,
          points: points,
          completedCount: 1,
          firstCompletedAt: now,
          lastCompletedAt: now,
        ),
      );
    }

    progress.sort((a, b) {
      final islandCompare = a.islandId.compareTo(b.islandId);
      if (islandCompare != 0) {
        return islandCompare;
      }

      return a.situationId.compareTo(b.situationId);
    });

    final updatedProfile = currentProfile.copyWith(skillProgress: progress);
    await saveProfile(updatedProfile);
    return updatedProfile;
  }

  Future<List<AppFeedbackEntry>> readAppFeedbackEntries() async {
    try {
      final file = await _feedbackFile();
      if (!await file.exists()) {
        return const [];
      }

      final content = await file.readAsString();
      final json = jsonDecode(content);
      if (json is! List) {
        return const [];
      }

      return json
          .whereType<Map<String, dynamic>>()
          .map(AppFeedbackEntry.fromJson)
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('SmartSteps feedback read failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<void> saveAppFeedback(AppFeedbackEntry feedback) async {
    final entries = await readAppFeedbackEntries();
    final updatedEntries = [...entries, feedback];
    final file = await _feedbackFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert(
        updatedEntries.map((entry) => entry.toJson()).toList(growable: false),
      ),
      flush: true,
    );

    final promptState = await readFeedbackPromptState();
    await _saveFeedbackPromptState(
      promptState.copyWith(
        hasSubmittedFeedback: true,
        lastFeedbackAt: feedback.submittedAt,
      ),
    );
  }

  Future<AppFeedbackPromptState> readFeedbackPromptState() async {
    try {
      final file = await _feedbackPromptStateFile();
      if (!await file.exists()) {
        return const AppFeedbackPromptState();
      }

      final content = await file.readAsString();
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic>) {
        return const AppFeedbackPromptState();
      }

      return AppFeedbackPromptState.fromJson(json);
    } catch (error, stackTrace) {
      debugPrint('SmartSteps feedback state read failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const AppFeedbackPromptState();
    }
  }

  Future<void> markFirstExitObserved() async {
    final promptState = await readFeedbackPromptState();
    if (promptState.hasObservedFirstExit) {
      return;
    }

    await _saveFeedbackPromptState(
      promptState.copyWith(
        hasObservedFirstExit: true,
        firstExitAt: DateTime.now(),
      ),
    );
  }

  Future<bool> shouldPromptFeedbackAfterFirstExit() async {
    final promptState = await readFeedbackPromptState();
    return promptState.hasObservedFirstExit &&
        !promptState.hasShownFirstExitPrompt &&
        !promptState.hasSubmittedFeedback;
  }

  Future<void> markFirstExitFeedbackPromptShown() async {
    final promptState = await readFeedbackPromptState();
    await _saveFeedbackPromptState(
      promptState.copyWith(
        hasShownFirstExitPrompt: true,
        firstPromptShownAt: DateTime.now(),
      ),
    );
  }

  Future<void> _saveFeedbackPromptState(
    AppFeedbackPromptState promptState,
  ) async {
    final file = await _feedbackPromptStateFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert(promptState.toJson()),
      flush: true,
    );
  }

  Future<File> _profileFile() async {
    final directory = _directoryOverride ?? await _profileDirectory();
    return File('${directory.path}${Platform.pathSeparator}child_profile.json');
  }

  Future<File> _feedbackFile() async {
    final directory = _directoryOverride ?? await _profileDirectory();
    return File('${directory.path}${Platform.pathSeparator}app_feedback.json');
  }

  Future<File> _feedbackPromptStateFile() async {
    final directory = _directoryOverride ?? await _profileDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}feedback_prompt_state.json',
    );
  }

  Future<Directory> _profileDirectory() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      return Directory(
        '${documentsDirectory.path}${Platform.pathSeparator}SmartSteps',
      );
    } catch (error, stackTrace) {
      debugPrint('SmartSteps profile directory fallback: $error');
      debugPrintStack(stackTrace: stackTrace);
      return Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}SmartSteps',
      );
    }
  }
}

const premiumActivationCode = 'PREMIUM';

class PremiumActivationException implements Exception {
  const PremiumActivationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileStorageException implements Exception {
  const ProfileStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
