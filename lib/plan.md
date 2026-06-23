# Tách Lesson Flow Theo Đảo

## Summary

Tạo khung module lesson chạy được, để `home_screen.dart` chỉ còn mở bài học qua một router. Flow hiện tại giữ nguyên cho `islandId == 1`; từ `islandId >= 2` dùng template mới gồm 5 beat tối thiểu: Observe, Choice, Why, Mini Challenge, Transfer.

Không thêm dependency mới. Không đổi schema backend/offline hiện tại trong bước đầu; template mới sẽ map từ `SituationDetail` để chạy được ngay.

## Key Changes

- Tạo feature folder mới dưới `lib/screens/lesson/`:
  - `lesson_entry_screen.dart`: entry/router nhận `SituationDetail`, `LocalProfileStorage?`, `onLessonCompleted`.
  - `island1/island1_lesson_game_screen.dart`: chứa flow cũ hiện đang là `LessonGameScreen`.
  - `template_lesson/template_lesson_screen.dart`: flow mới cho đảo 2+.
  - `models/lesson_runtime_models.dart`: các model dùng chung như `SafetyLesson`, `LessonChoice`, `ParentNotes`, media/voice copy.
  - `mappers/lesson_mapper.dart`: map `SituationDetail -> SafetyLesson`.
  - `shared/lesson_assets.dart`, `shared/lesson_colors.dart`, `shared/lesson_completion.dart`: asset/color/record completion dùng chung.

- Refactor `home_screen.dart`:
  - `_activeLesson` đổi từ `SafetyLesson?` sang `SituationDetail?` hoặc giữ summary/detail rõ ràng để không phụ thuộc model UI.
  - `_openLesson()` push `LessonEntryScreen(detail: activeDetail, ...)`.
  - Xóa dần các class lesson runtime khỏi `home_screen.dart`; giữ lại island map/home UI.
  - `LessonAssets` nếu còn được home map dùng thì chuyển sang shared import, không copy trùng.

- Flow đảo 1:
  - Giữ nguyên hành vi hiện tại: intro video -> flashcard choice -> wrong video/retry hoặc reward.
  - Giữ key test quan trọng: `start-lesson-button`, text `Bỏ qua intro`, reward `Hoàn thành màn chơi!`, `lesson-reward-continue-button`.

- Flow đảo 2+:
  - `TemplateLessonScreen` dùng enum riêng, ví dụ `TemplateLessonPhase { observe, choice, why, miniChallenge, transfer, reward }`.
  - Observe hiển thị scenario/intro và 2-4 hotspot text fallback từ template mapper.
  - Choice dùng `Flashcard` hiện có.
  - Why hiển thị feedback đúng/sai ngắn, có nút tiếp tục.
  - Mini Challenge bản v1 dùng thao tác chọn/sắp xếp tối giản từ dữ liệu fallback, không cần drag-drop thật ở bước khung xương.
  - Transfer dùng `parentReview.questionText` hoặc fallback từ `practicePrompt` để hỏi lại trong bối cảnh mới.
  - Hoàn thành vẫn gọi `LocalProfileStorage.recordLessonCompletion` giống flow cũ.

## Interfaces

- Public widget mới:
  - `LessonEntryScreen({required SituationDetail detail, LocalProfileStorage? profileStorage, ValueChanged<ChildProfile>? onLessonCompleted})`
- Routing rule cố định:
  - `detail.islandId == 1` -> `Island1LessonGameScreen`
  - `detail.islandId >= 2` -> `TemplateLessonScreen`
- Mapper rule:
  - Không đổi `SituationDetail`, `Flashcard`, `SituationStep`, `ParentReviewQuestion`.
  - Nếu thiếu dữ liệu template mới, mapper dùng fallback từ `intro`, `steps`, `flashcard`, `skills`, `parentReview`.

## Test Plan

- Update test hiện có `safe lesson flow uses injected lesson data` để vẫn pass cho island 1.
- Thêm widget test cho island 2:
  - mở island 2 lesson.
  - xác nhận vào template flow mới thay vì intro video cũ.
  - đi qua Observe -> Choice -> Why -> Mini Challenge -> Transfer -> Reward.
  - xác nhận completion được record với đúng `situationId`, `islandId`, `lessonTitle`.
- Chạy:
  - `flutter test`
  - nếu có lỗi import/analyze rõ ràng thì chạy thêm `flutter analyze`.

## Assumptions

- `islandId == 1` là flow cũ duy nhất.
- `islandId >= 2` dùng template mới, kể cả island 3 và các đảo sau.
- Bước này là khung xương chạy được, chưa làm UI cuối cùng cho Mini Challenge/Transfer.
- Chưa đổi backend schema; dữ liệu template chi tiết có thể thêm sau khi module đã tách ổn.
- Không xử lý asset/audio mới trong bước này, ngoài việc giữ nguyên audio/video hiện có cho đảo 1.
