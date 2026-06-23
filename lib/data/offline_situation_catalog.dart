import '../models/situation.dart';

const _personalSafetyIsland = 'Đảo An Toàn';
const _socialSafetyIsland = 'Đảo Tình Bạn';
const _environmentSafetyIsland = 'Đảo Trường Học';

const offlineIslandSummaries = [
  IslandSummary(
    islandId: 1,
    name: _personalSafetyIsland,
    description:
        'Bé học cách nhận biết nguy hiểm gần cơ thể và đồ dùng quen thuộc.',
    imageUrl: 'assets/images/Island_Icon.webp',
    orderIndex: 1,
    status: 'Published',
    situationCount: 3,
  ),
  IslandSummary(
    islandId: 2,
    name: _socialSafetyIsland,
    description:
        'Bé luyện cách xử lý khi gặp người lạ, bạn bè và các tình huống xã hội.',
    imageUrl: 'assets/images/Island_Icon.webp',
    orderIndex: 2,
    status: 'Published',
    situationCount: 3,
  ),
  IslandSummary(
    islandId: 3,
    name: _environmentSafetyIsland,
    description: 'Bé học giữ an toàn khi đi lại, ở nơi công cộng và gần nước.',
    imageUrl: 'assets/images/Island_Icon.webp',
    orderIndex: 3,
    status: 'Published',
    situationCount: 3,
  ),
];

final offlineSituationDetails = <SituationDetail>[
  _lesson(
    situationId: 101,
    islandId: 1,
    islandName: _personalSafetyIsland,
    title: 'Bài 1: Vật tròn lấp lánh',
    intro:
        'Bé học cách nhận biết vật nhỏ lạ, không bỏ vào miệng và đưa cho người lớn.',
    scenario:
        'Bé đang chơi xếp hình thì một viên bi đồ chơi hình tròn lấp lánh văng ra khỏi mô hình.',
    question: 'Con nên làm gì khi nhặt được vật tròn nhỏ lấp lánh trên sàn?',
    optionA: 'Bỏ vào miệng để nếm thử xem sao.',
    optionB: 'Mang đến đưa cho bố mẹ và nói con nhặt được cái này.',
    wrongStory:
        'Đồ vật nhỏ không phải đồ ăn, bỏ vào miệng sẽ gây hóc, nghẹt thở và làm đau bụng.',
    correctStory:
        'Bé đưa vật nhỏ cho mẹ để mẹ cất vào tủ cao. Reward: Bé không bỏ vật lạ vào miệng! +1 Safety Star.',
    correctFeedback:
        'Bé ngoan lắm! Gặp đồ vật nhỏ lạ rơi trên sàn, hãy đưa ngay cho người lớn nhé.',
    wrongFeedback:
        'Nguy hiểm quá! Đồ vật nhỏ không phải đồ ăn và có thể làm bé bị hóc.',
    skillName: 'An toàn dị vật',
    skillDescription:
        'Nhận biết đồ vật nguy hiểm có nguy cơ gây hóc/nuốt phải; biết phân biệt đồ ăn được và không ăn được.',
    practicePrompt:
        'Nếu con nhặt được một viên bi hoặc vật nhỏ lạ trên sàn, con nên làm gì?',
    riskAlert:
        'Trẻ nhỏ khám phá thế giới bằng cách ngậm đồ vật. Hãy giữ các loại pin nút, nam châm hoặc những dị vật xa tầm tay bé.',
    introMedia:
        'https://res.cloudinary.com/dtm5a4bwr/video/upload/v1781136864/Safety_smallitems_intro_cw1tlh.mp4',
    wrongMedia:
        'https://res.cloudinary.com/dtm5a4bwr/video/upload/v1781136866/Safety_smallitems_wrong_pjogba.mp4',
    correctMedia:
        'https://res.cloudinary.com/dtm5a4bwr/video/upload/v1781136882/Safety_smallitems_correct_u5ubla.mp4',
    questionVoice: 'assets/voices/Safety_smallitems/question.mp3',
    optionAVoice: 'assets/voices/Safety_smallitems/choice-put-mouth.mp3',
    optionBVoice: 'assets/voices/Safety_smallitems/choice-ask-adult.mp3',
    optionAImage: 'assets/images/flashCard/Safety_smallitems/wrong.webp',
    optionBImage: 'assets/images/flashCard/Safety_smallitems/Correct.webp',
  ),
  _lesson(
    situationId: 201,
    islandId: 2,
    islandName: _socialSafetyIsland,
    title: 'Bài 1: Người lạ "biết tên bé"',
    intro:
        'Bé học cảnh giác với người lạ giả danh người quen dù họ biết tên mình.',
    scenario:
        'Một người phụ nữ lạ mặt đi ô tô đến cổng trường, gọi đúng tên bé và nói mẹ nhờ đón.',
    question: 'Người lạ nói mẹ nhờ đến đón. Con sẽ xử lý thế nào?',
    optionA: 'Tin lời cô, bước lên xe ô tô để về với mẹ.',
    optionB: 'Lùi lại, nói to "Cháu không đi!" và chạy vào trường báo cô giáo.',
    wrongStory: 'Kẻ xấu có thể giả vờ quen biết mẹ để lừa bắt cóc con.',
    correctStory:
        'Bé lùi lại, chạy thẳng vào cổng trường gọi cô giáo. Reward: Bé không mắc mưu kẻ xấu! +1 Brave Star.',
    correctFeedback:
        'Quá xuất sắc! Cảnh giác và chạy đi tìm người lớn tin cậy là cách bảo vệ mình thông minh nhất.',
    wrongFeedback: 'Tuyệt đối không đi theo người lạ dù họ biết tên con.',
    skillName: 'Kỹ năng đối phó kẻ gian tinh vi',
    skillDescription: 'Cảnh giác với người lạ giả danh người quen.',
    practicePrompt:
        'Nếu một người lạ gọi đúng tên con và bảo lên xe để chở về với bố mẹ, con có đi theo không?',
    riskAlert:
        'Bé rất dễ mất cảnh giác khi người lạ ăn mặc đẹp, tỏ ra thân thiện và biết rõ tên bé.',
    introMedia:
        'https://res.cloudinary.com/dtm5a4bwr/video/upload/v1781136847/Safety_stranger_Intro_chanol.mp4',
    wrongMedia:
        'https://res.cloudinary.com/dtm5a4bwr/video/upload/v1781136791/Safety_stranger_wrong_dgsjbj.mp4',
    correctMedia:
        'https://res.cloudinary.com/dtm5a4bwr/video/upload/v1781136761/Safety_stranger_correct_rkwehk.mp4',
    questionVoice: 'assets/voices/Safety_stranger/question_l3.mp3',
    optionAVoice: 'assets/voices/Safety_stranger/wrong_l3.mp3',
    optionBVoice: 'assets/voices/Safety_stranger/correct_l3.mp3',
    optionAImage: 'assets/images/flashCard/Safety_stranger/Wrong.webp',
    optionBImage: 'assets/images/flashCard/Safety_stranger/Correct.webp',
  ),
  _lesson(
    situationId: 202,
    islandId: 2,
    islandName: _socialSafetyIsland,
    title: 'Bài 2: Lời thách đố của bạn bè',
    intro:
        'Bé học từ chối áp lực bạn bè và không làm việc nguy hiểm để chứng tỏ bản thân.',
    scenario:
        'Bạn bè xúi bé trèo rào sang sân nhà hàng xóm có chó dữ để nhặt bóng.',
    question: 'Khi bạn ép con làm một việc nguy hiểm, con nên làm gì?',
    optionA: 'Trèo rào sang lấy bóng để chứng tỏ mình không nhát gan.',
    optionB: 'Kiên quyết từ chối và đi tìm người lớn nhờ lấy giúp.',
    wrongStory:
        'Cố chứng tỏ bản thân bằng cách làm việc nguy hiểm không phải là dũng cảm.',
    correctStory:
        'Bé nói không, chạy đi gọi người lớn lấy bóng giúp. Reward: Bé biết nói không với nguy hiểm! +1 Shield Star.',
    correctFeedback:
        'Tuyệt vời! Biết nói không với trò chơi nguy hiểm chứng tỏ con rất trưởng thành.',
    wrongFeedback:
        'Không ai có quyền ép con làm việc nguy hiểm. Từ chối lời thách đố dại dột mới là bản lĩnh.',
    skillName: 'Kỹ năng đối mặt áp lực đồng trang lứa',
    skillDescription:
        'Từ chối áp lực bạn bè và không làm việc nguy hiểm để chứng tỏ bản thân.',
    practicePrompt:
        'Nếu bị bạn bè rủ rê hoặc thách thức chơi một trò nguy hiểm, con có làm theo không?',
    riskAlert:
        'Ở độ tuổi này, bé rất sợ bị bạn bè chê cười hoặc tẩy chay, nên dễ nhắm mắt làm liều.',
  ),
  _lesson(
    situationId: 203,
    islandId: 2,
    islandName: _socialSafetyIsland,
    title: 'Bài 3: Chiếc ví bị đánh rơi',
    intro:
        'Bé học kiểm soát cám dỗ và trung thực trả lại đồ không phải của mình.',
    scenario:
        'Bé thấy một người đi trước làm rơi chiếc ví có nhiều tiền trong khu vui chơi.',
    question: 'Nhặt được đồ không phải của mình, con nên làm gì?',
    optionA: 'Lén nhặt chiếc ví giấu vào túi quần để mang về.',
    optionB: 'Nhặt lên và gọi người đánh rơi để trả lại.',
    wrongStory:
        'Lấy đồ của người khác sẽ làm họ buồn khổ và chính con cũng cảm thấy tội lỗi.',
    correctStory:
        'Bé nhặt ví chạy theo đưa tận tay người đánh rơi. Reward: Bé là em bé trung thực! +1 Honesty Star.',
    correctFeedback:
        'Rất đáng tự hào! Sự trung thực của con đáng giá hơn bất kỳ món đồ chơi nào.',
    wrongFeedback:
        'Đồ không phải của mình thì tuyệt đối không được lấy, dù không ai thấy con nhé.',
    skillName: 'Kỹ năng kiểm soát cám dỗ và trung thực',
    skillDescription: 'Vượt qua lòng tham, trung thực trả lại của rơi.',
    practicePrompt:
        'Nếu nhặt được chiếc ví hoặc đồ chơi của người khác đánh rơi, con sẽ làm gì?',
    riskAlert:
        'Bé dễ bị cám dỗ bởi suy nghĩ "Không ai nhìn thấy thì không sao".',
  ),
  _lesson(
    situationId: 301,
    islandId: 3,
    islandName: _environmentSafetyIsland,
    title: 'Bài 1: Qua đường an toàn',
    intro: 'Bé học chờ đèn xanh, nắm tay người lớn và quan sát khi qua đường.',
    scenario:
        'Bé đi bộ cùng mẹ, phía bên kia đường có tiệm kem nhưng đèn giao thông đang màu đỏ.',
    question: 'Xe đang chạy rất đông. Con nên làm gì trước khi qua đường?',
    optionA: 'Chạy nhanh qua đường.',
    optionB: 'Đứng lại chờ đèn xanh.',
    wrongStory:
        'Qua đường khi đèn đỏ rất nguy hiểm vì xe có thể không dừng kịp.',
    correctStory:
        'Bé đứng cạnh mẹ, chờ đèn xanh rồi hai mẹ con nắm tay qua đường. Reward: Bé biết chờ đèn xanh! +1 Safety Star.',
    correctFeedback:
        'Giỏi lắm! Chúng ta luôn chờ đèn xanh để qua đường an toàn.',
    wrongFeedback: 'Khi qua đường, mình phải chờ đèn xanh và nhìn hai bên.',
    skillName: 'An toàn giao thông',
    skillDescription: 'Biết chờ đèn xanh trước khi qua đường.',
    practicePrompt: 'Đèn màu gì thì mình mới được đi qua đường hả con?',
    riskAlert: 'Bé vẫn hay quên nhìn hai bên trước khi qua đường.',
    introMedia:
        'https://res.cloudinary.com/dtm5a4bwr/video/upload/v1781136588/cross-road-intro_tnrhmy.mp4',
    wrongMedia:
        'https://res.cloudinary.com/dtm5a4bwr/video/upload/v1781136583/cross-road-wrong_fnc8fg.mp4',
    correctMedia:
        'https://res.cloudinary.com/dtm5a4bwr/video/upload/v1781136648/cross-road-correct_r36izw.mp4',
    questionVoice: 'assets/voices/Crossroad/Question.mp3',
    optionAVoice: 'assets/voices/Crossroad/wrong.mp3',
    optionBVoice: 'assets/voices/Crossroad/correct.mp3',
    optionAImage: 'assets/images/flashCard/Crossroad/Wrong.webp',
    optionBImage: 'assets/images/flashCard/Crossroad/Correct.webp',
  ),
  _lesson(
    situationId: 302,
    islandId: 3,
    islandName: _environmentSafetyIsland,
    title: 'Bài 2: Bị lạc trong siêu thị',
    intro: 'Bé học đứng yên và tìm người lớn đáng tin cậy khi bị lạc.',
    scenario:
        'Bé đang đi siêu thị cùng mẹ, quay lại nhìn đồ chơi rồi không thấy mẹ đâu.',
    question: 'Nếu bị lạc trong siêu thị, con nên làm gì?',
    optionA: 'Chạy đi tìm mẹ khắp nơi.',
    optionB: 'Đứng yên và tìm nhân viên giúp đỡ.',
    wrongStory: 'Chạy lung tung có thể làm mình lạc xa hơn.',
    correctStory:
        'Bé gặp cô nhân viên, cô phát loa và mẹ tìm thấy bé. Reward: Bé biết xử lý khi bị lạc! +1 Safety Star.',
    correctFeedback: 'Giỏi lắm! Nhờ người lớn giúp đỡ là cách an toàn nhất.',
    wrongFeedback: 'Nếu bị lạc, hãy đứng yên và tìm người lớn đáng tin cậy.',
    skillName: 'Xử lý khi bị lạc',
    skillDescription: 'Biết tìm người giúp đỡ khi bị lạc.',
    practicePrompt:
        'Nếu chẳng may bị lạc mất bố mẹ trong siêu thị, con nên làm gì?',
    riskAlert: 'Bé vẫn chọn chạy đi tìm mẹ khi bị lạc.',
  ),
  _lesson(
    situationId: 303,
    islandId: 3,
    islandName: _environmentSafetyIsland,
    title: 'Bài 3: Hồ nước / hồ bơi',
    intro:
        'Bé học tránh xa hồ nước sâu và tìm người lớn giúp đỡ khi gặp nguy hiểm.',
    scenario:
        'Bé đá bóng trong công viên gần hồ nước, quả bóng lăn xuống gần mép hồ.',
    question: 'Nếu đồ chơi rơi xuống hồ nước, con nên làm gì?',
    optionA: 'Tự chạy lại lấy bóng.',
    optionB: 'Tìm người lớn giúp đỡ.',
    wrongStory:
        'Chơi gần hồ nước một mình rất nguy hiểm và có thể bị trượt chân.',
    correctStory:
        'Bé chạy tới chú bảo vệ nhờ lấy bóng giúp. Reward: Bé biết tránh xa hồ nước sâu! +1 Safety Star.',
    correctFeedback:
        'Giỏi lắm! Khi gặp nơi nguy hiểm, hãy nhờ người lớn giúp đỡ.',
    wrongFeedback:
        'Nếu đồ chơi rơi xuống nước, mình phải tìm người lớn giúp đỡ.',
    skillName: 'An toàn gần nước',
    skillDescription: 'Biết tìm người lớn giúp đỡ khi gặp nguy hiểm.',
    practicePrompt: 'Nếu đồ chơi bị rơi xuống hồ nước sâu, con nên làm gì?',
    riskAlert: 'Bé vẫn có xu hướng tự đến gần mép nước.',
  ),
];

SituationDetail _lesson({
  required int situationId,
  required int islandId,
  required String islandName,
  required String title,
  required String intro,
  required String scenario,
  required String question,
  required String optionA,
  required String optionB,
  required String wrongStory,
  required String correctStory,
  required String correctFeedback,
  required String wrongFeedback,
  required String skillName,
  required String skillDescription,
  required String practicePrompt,
  required String riskAlert,
  String? introMedia,
  String? wrongMedia,
  String? correctMedia,
  String? questionVoice,
  String? optionAVoice,
  String? optionBVoice,
  String? optionAImage,
  String? optionBImage,
}) {
  final orderIndex = situationId % 100;

  return SituationDetail(
    situationId: situationId,
    islandId: islandId,
    islandName: islandName,
    title: title,
    intro: intro,
    orderIndex: orderIndex,
    status: 'Published',
    steps: [
      SituationStep(
        stepId: situationId * 10 + 1,
        stepType: 'Intro',
        orderIndex: 1,
        mediaUrl: introMedia,
        content: scenario,
      ),
      SituationStep(
        stepId: situationId * 10 + 2,
        stepType: 'Flashcard',
        orderIndex: 2,
        content: 'A. $optionA B. $optionB',
      ),
      SituationStep(
        stepId: situationId * 10 + 3,
        stepType: 'Story',
        orderIndex: 3,
        mediaUrl: wrongMedia,
        content: wrongStory,
      ),
      SituationStep(
        stepId: situationId * 10 + 4,
        stepType: 'Result',
        orderIndex: 4,
        mediaUrl: correctMedia,
        content: correctStory,
      ),
    ],
    flashcard: Flashcard(
      flashcardId: situationId,
      question: question,
      optionA: optionA,
      optionB: optionB,
      correctAnswer: 'B',
      questionVoiceUrl: questionVoice,
      optionAVoiceUrl: optionAVoice,
      optionBVoiceUrl: optionBVoice,
      optionAImageUrl: optionAImage,
      optionBImageUrl: optionBImage,
      correctFeedback: correctFeedback,
      wrongFeedback: wrongFeedback,
    ),
    skills: [
      SituationSkill(
        skillId: situationId,
        name: skillName,
        description: skillDescription,
      ),
    ],
    parentReview: ParentReviewQuestion(
      questionId: situationId,
      skillId: situationId,
      questionText: practicePrompt,
      suggestedActivity: practicePrompt,
      watchOutTip: riskAlert,
    ),
  );
}

List<SituationSummary> offlineSituationSummaries() {
  return [
    ...offlineSituationDetails.map(
      (detail) => SituationSummary(
        situationId: detail.situationId,
        islandId: detail.islandId,
        islandName: detail.islandName,
        title: detail.title,
        intro: detail.intro,
        orderIndex: detail.orderIndex,
        status: detail.status,
      ),
    ),
    SituationSummary(
      situationId: 102,
      islandId: 1,
      islandName: _personalSafetyIsland,
      title: '',
      intro: '',
      orderIndex: 2,
      status: 'Draft',
    ),
    SituationSummary(
      situationId: 103,
      islandId: 1,
      islandName: _personalSafetyIsland,
      title: '',
      intro: '',
      orderIndex: 3,
      status: 'Draft',
    ),
  ];
}

List<SituationSummary> offlineSituationSummariesForIsland(int islandId) {
  final summaries = offlineSituationSummaries()
      .where((summary) => summary.islandId == islandId)
      .toList(growable: false);

  return summaries..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
}

SituationDetail? offlineSituationDetailById(int situationId) {
  for (final detail in offlineSituationDetails) {
    if (detail.situationId == situationId) {
      return detail;
    }
  }

  return null;
}

List<ParentReviewQuestion> getQuickReviewQuestions({int limit = 5}) {
  final questions = <ParentReviewQuestion>[];

  for (final detail in offlineSituationDetails) {
    if (questions.length >= limit) {
      break;
    }
    if (detail.parentReview != null) {
      questions.add(detail.parentReview!);
    }
  }

  return questions;
}
