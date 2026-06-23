# Template Thiết Kế Bài Học SmartSteps

## Mục tiêu

Khung này dùng để thiết kế các bài học SmartSteps theo dạng hành trình ngắn, có thể áp dụng cho nhiều chủ đề khác nhau như an toàn giao thông, người lạ, nhà bếp, hồ nước, đi lạc, bắt nạt, trường học, siêu thị hoặc kỹ năng xã hội.

Tài liệu tổng quan này nên giữ gọn. Phần build và debug lesson chi tiết đã được tách sang folder `template_lesson/`:

- `README.md`: cách dùng và map với app hiện tại.
- `lesson_blueprint.md`: khung điền từng bài.
- `island_2_plus_rules.md`: luật cải tiến cho đảo 2 và các đảo sau.
- `island_2_examples.md`: ví dụ riêng cho Đảo Tình Bạn.
- `debug_checklist.md`: checklist soát trước khi đưa vào app/backend.

Công thức cốt lõi:

```text
Observe → Choice → Why → Mini Challenge → Transfer
```

Ý nghĩa:

```text
Observe = nhìn ra dấu hiệu
Choice = chọn hành động đúng
Why = hiểu lý do
Mini Challenge = luyện lại bằng thao tác
Transfer = đổi bối cảnh để kiểm tra hiểu thật
```

---

## 1. Observe — Trẻ cần nhìn thấy điều gì?

### Mục tiêu

Phần này giúp trẻ nhận diện tín hiệu quan trọng trong cảnh trước khi chọn hành động.

Không nên hỏi trẻ chọn đúng/sai ngay. Trước tiên, trẻ cần quan sát và phát hiện dấu hiệu nguy hiểm, người liên quan, vật quan trọng hoặc bối cảnh cần chú ý.

### Câu lệnh mẫu

```text
Con hãy chạm vào những thứ cần chú ý trong hình.
```

Hoặc:

```text
Con nhìn thấy điều gì có thể nguy hiểm?
```

### Các loại chi tiết nên có

| Loại chi tiết | Ví dụ |
|---|---|
| Dấu hiệu nguy hiểm | xe đang chạy, ổ điện, vật sắc nhọn, nước sâu |
| Người liên quan | mẹ, cô giáo, người lạ, bạn đang buồn |
| Vật quan trọng | đèn đỏ, biển báo, điện thoại, balo |
| Bối cảnh | cổng trường, siêu thị, nhà bếp, hồ bơi |

### Ví dụ theo chủ đề

| Chủ đề | Observe nên tìm gì |
|---|---|
| Qua đường | đèn đỏ, xe đang chạy, vạch qua đường, tay người lớn |
| Người lạ | người lạ, cổng trường, cô giáo, điện thoại của bố mẹ |
| Hồ nước | nước sâu, biển cấm, không có người lớn, bạn đứng gần mép hồ |
| Nhà bếp | bếp nóng, dao, nồi nước sôi, tay người lớn |
| Bắt nạt | bạn đang khóc, nhóm bạn trêu chọc, cô giáo gần đó |
| Đi lạc | bé đứng một mình, quầy thông tin, bảo vệ, số điện thoại bố mẹ |

### Quy tắc thiết kế

- Ít chữ, nhiều hình.
- Mỗi cảnh chỉ nên có 2-4 chi tiết cần chạm.
- Khi trẻ chạm đúng, hiển thị highlight hoặc hiệu ứng nhỏ.
- Không nên đặt quá nhiều vật gây nhiễu ở bài đầu.
- Bài sau có thể thêm nhiễu nhẹ để tăng độ khó.

---

## 2. Choice — Trẻ nên làm gì?

### Mục tiêu

Sau khi trẻ đã quan sát được dấu hiệu, app đưa ra lựa chọn hành động. Đây là bước giúp trẻ chuyển từ “nhìn thấy vấn đề” sang “biết nên làm gì”.

### Câu lệnh mẫu

```text
Bây giờ con nên làm gì?
```

Hoặc:

```text
Mimi nên chọn cách nào an toàn hơn?
```

### Cấu trúc lựa chọn

Nên dùng 2-3 lựa chọn ngắn:

- 1 đáp án đúng.
- 1 đáp án sai rõ ràng.
- Có thể thêm 1 đáp án gây nhiễu nhẹ ở bài khó hơn.

### Ví dụ theo chủ đề

| Chủ đề | Choice |
|---|---|
| Qua đường | “Chạy qua ngay” / “Đứng lại chờ” |
| Người lạ rủ đi | “Đi theo để lấy kẹo” / “Nói không và gọi cô giáo” |
| Bếp nóng | “Chạm thử nồi” / “Nhờ người lớn giúp” |
| Đi lạc | “Chạy đi tìm bố mẹ” / “Đứng yên và tìm bảo vệ” |
| Bạn bị bắt nạt | “Cười theo” / “Báo cô giáo và giúp bạn” |
| Bóng lăn ra đường | “Chạy theo bóng” / “Dừng lại và gọi người lớn” |

### Quy tắc thiết kế

- Đáp án đúng không được luôn nằm cùng một vị trí.
- Câu trả lời phải ngắn, dễ hiểu.
- Không dùng đáp án sai quá vô lý nếu muốn kiểm tra thật.
- Với bài đầu, đáp án sai có thể rõ ràng.
- Với bài sau, thêm nhiễu nhẹ để trẻ phải suy nghĩ.

---

## 3. Why — Vì sao hành động đó đúng?

### Mục tiêu

Phần này giúp bài học có chiều sâu hơn. Trẻ không chỉ chọn đúng mà còn hiểu vì sao hành động đó an toàn.

Tuy nhiên, phần giải thích phải rất ngắn. Không biến thành bài giảng.

### Công thức giải thích

```text
Vì [nguy cơ cụ thể], nên mình cần [hành động an toàn].
```

### Ví dụ theo chủ đề

| Chủ đề | Why |
|---|---|
| Qua đường | Xe đang chạy nhanh, xe có thể không dừng kịp. Mình cần đứng lại chờ. |
| Người lạ | Mình chưa biết người đó có an toàn không. Mình cần ở gần cô giáo hoặc bố mẹ. |
| Nhà bếp | Nồi có thể rất nóng. Mình nhờ người lớn giúp để không bị bỏng. |
| Hồ nước | Nước sâu có thể làm mình trượt ngã. Mình chỉ lại gần khi có người lớn. |
| Đi lạc | Nếu chạy lung tung, bố mẹ khó tìm thấy mình. Mình đứng yên và nhờ người đáng tin cậy. |
| Bắt nạt | Bạn đang buồn và cần được giúp. Mình không cười theo, mình báo cô giáo. |

### Câu hỏi vì sao

Sau khi giải thích, có thể hỏi trẻ:

```text
Vì sao mình nên làm vậy?
```

Ví dụ lựa chọn lý do:

- Vì xe có thể không dừng kịp.
- Vì nồi có thể nóng.
- Vì người lạ chưa chắc an toàn.
- Vì bạn cần được giúp.

### Quy tắc thiết kế

- Mỗi feedback chỉ nên có 1-2 câu.
- Tránh hù dọa quá mức.
- Sai thì cho gợi ý và thử lại.
- Đúng thì củng cố lý do ngắn gọn.
- Không dùng khái niệm quá trừu tượng với trẻ nhỏ.

---

## 4. Mini Challenge — Luyện lại bằng thao tác ngắn

### Mục tiêu

Mini Challenge giúp bài học bớt tuyến tính và thú vị hơn. Đây là nơi trẻ luyện lại kỹ năng vừa học bằng thao tác tương tác.

### Câu lệnh mẫu

```text
Con thử làm lại kỹ năng này nhé.
```

Hoặc:

```text
Sắp xếp các bước an toàn theo đúng thứ tự.
```

### Các dạng Mini Challenge dùng chung

| Dạng thử thách | Cách dùng |
|---|---|
| Sắp xếp 3 bước | Dùng cho quy trình an toàn |
| Kéo thả Đúng/Sai | Dùng cho phân loại hành vi |
| Chạm điểm nguy hiểm | Dùng cho nhận biết rủi ro |
| Chọn câu nên nói | Dùng cho giao tiếp xã hội |
| Tìm người đáng tin cậy | Dùng cho đi lạc, người lạ, bị bắt nạt |
| Nghe tình huống và chọn phản ứng | Dùng cho bài có audio/story |

### Ví dụ theo chủ đề

| Chủ đề | Mini Challenge |
|---|---|
| Qua đường | Sắp xếp: Dừng lại → Nắm tay người lớn → Chờ an toàn rồi đi |
| Người lạ | Chọn câu nói đúng: “Cháu không đi. Cháu sẽ gọi cô giáo.” |
| Nhà bếp | Kéo dao, bếp nóng vào ô “Cần người lớn giúp” |
| Đi lạc | Chọn người nên nhờ: bảo vệ / nhân viên quầy / cô giáo |
| Hồ nước | Chạm vào 3 điểm nguy hiểm quanh hồ |
| Bắt nạt | Chọn 2 hành động đúng: an ủi bạn, báo cô giáo |

### Quy tắc thiết kế

- Thời lượng: 30-60 giây.
- Tối đa 2 lần thử.
- Nếu sai lần 1: đưa gợi ý.
- Nếu sai lần 2: hiển thị mẫu đúng.
- Không để trẻ bị kẹt quá lâu.
- Mỗi challenge chỉ nên kiểm tra 1 kỹ năng chính.

---

## 5. Transfer — Áp dụng ở bối cảnh mới

### Mục tiêu

Transfer kiểm tra xem trẻ có hiểu kỹ năng thật không, hay chỉ nhớ đáp án trong cảnh vừa học.

Phần này giữ nguyên kỹ năng nhưng đổi bối cảnh.

### Câu lệnh mẫu

```text
Nếu chuyện tương tự xảy ra ở chỗ khác, con sẽ làm gì?
```

Hoặc:

```text
Nếu gặp tình huống này ngoài đời, con nên làm gì?
```

### Ví dụ theo chủ đề

| Bài chính | Transfer |
|---|---|
| Qua đường có đèn đỏ | Bóng lăn ra đường thì con làm gì? |
| Người lạ ở cổng trường | Người lạ nhắn tin rủ gửi ảnh thì con làm gì? |
| Bếp nóng ở nhà | Thấy bàn là đang nóng thì con làm gì? |
| Đi lạc trong siêu thị | Đi lạc ở công viên thì con làm gì? |
| Hồ bơi | Thấy bạn đứng gần ao sâu thì con làm gì? |
| Bắt nạt ở lớp | Thấy bạn bị trêu ở sân chơi thì con làm gì? |

### Quy tắc thiết kế

- Không nên làm Transfer khó hơn quá nhiều.
- Chỉ đổi bối cảnh, không thêm quá nhiều thông tin mới.
- Kỹ năng chính phải giống bài học vừa học.
- Dùng câu hỏi ngắn, hình ảnh rõ.
- Có thể thêm Parent Note để phụ huynh ôn lại ngoài đời.

---

## Template Chuẩn Cho Mỗi Bài

```text
Tên bài:
Kỹ năng chính:
Bối cảnh chính:
Nhân vật:
Rủi ro chính:

1. Observe
Trẻ cần chạm vào:
- Chi tiết 1
- Chi tiết 2
- Chi tiết 3

2. Choice
Câu hỏi:
Đáp án A:
Đáp án B:
Đáp án C nếu có:
Đáp án đúng:

3. Why
Giải thích ngắn:
Câu hỏi vì sao:
Lý do đúng:

4. Mini Challenge
Loại challenge:
Nhiệm vụ:
Số lần thử:
Feedback khi sai:
Feedback khi đúng:

5. Transfer
Bối cảnh mới:
Câu hỏi:
Đáp án đúng:
Parent Note:
```

---

## Ví dụ 1: Qua Đường An Toàn

```text
Tên bài:
Qua đường an toàn

Kỹ năng chính:
Dừng lại, quan sát và chờ an toàn trước khi qua đường

Bối cảnh chính:
Vạch qua đường có đèn giao thông

Nhân vật:
Mimi muốn sang đường mua kem

Rủi ro chính:
Đèn đỏ và xe đang chạy

1. Observe
Trẻ cần chạm vào:
- Đèn đỏ
- Xe đang chạy
- Vạch qua đường
- Tay người lớn

2. Choice
Câu hỏi:
Mimi nên làm gì?

Đáp án A:
Chạy qua ngay

Đáp án B:
Đứng lại và nắm tay người lớn

Đáp án đúng:
B

3. Why
Giải thích ngắn:
Xe đang chạy nhanh. Nếu mình chạy qua, xe có thể không dừng kịp. Mình cần đứng lại chờ.

Câu hỏi vì sao:
Vì sao Mimi cần chờ?

Lý do đúng:
Vì xe có thể không dừng kịp.

4. Mini Challenge
Loại challenge:
Sắp xếp 3 bước

Nhiệm vụ:
Sắp xếp các bước qua đường an toàn.

Các bước:
- Dừng lại
- Nắm tay người lớn
- Chờ an toàn rồi đi

Số lần thử:
2

Feedback khi sai:
Thứ tự này chưa an toàn. Mình cần dừng lại trước nhé.

Feedback khi đúng:
Đúng rồi. Mimi đã biết qua đường an toàn.

5. Transfer
Bối cảnh mới:
Quả bóng lăn ra đường.

Câu hỏi:
Mimi nên làm gì?

Đáp án đúng:
Dừng lại và gọi người lớn giúp.

Parent Note:
Tuần này khi đi bộ, hãy cho bé chỉ đèn đỏ/xanh và nói: “Khi nào mình được đi?”
```

---

## Ví dụ 2: Không Đi Theo Người Lạ

```text
Tên bài:
Không đi theo người lạ

Kỹ năng chính:
Nói không và tìm người lớn đáng tin cậy

Bối cảnh chính:
Cổng trường

Nhân vật:
Mimi đang chờ mẹ đón

Rủi ro chính:
Một người lạ rủ Mimi đi mua kẹo

1. Observe
Trẻ cần chạm vào:
- Người lạ
- Cổng trường
- Cô giáo gần đó
- Điện thoại/số của mẹ

2. Choice
Câu hỏi:
Mimi nên làm gì?

Đáp án A:
Đi theo để lấy kẹo

Đáp án B:
Nói không và đi về phía cô giáo

Đáp án đúng:
B

3. Why
Giải thích ngắn:
Mimi chưa biết người đó có an toàn không. Mimi cần ở gần cô giáo hoặc gọi mẹ.

Câu hỏi vì sao:
Vì sao Mimi không nên đi theo?

Lý do đúng:
Vì đó là người Mimi chưa quen biết.

4. Mini Challenge
Loại challenge:
Chọn câu nên nói

Nhiệm vụ:
Chọn câu Mimi nên nói với người lạ.

Đáp án đúng:
“Cháu không đi. Cháu sẽ gọi cô giáo.”

Số lần thử:
2

Feedback khi sai:
Câu này chưa đủ an toàn. Mimi cần nói rõ là không đi.

Feedback khi đúng:
Đúng rồi. Mimi đã biết nói không và tìm người lớn đáng tin cậy.

5. Transfer
Bối cảnh mới:
Một người lạ nhắn tin bảo Mimi gửi ảnh.

Câu hỏi:
Mimi nên làm gì?

Đáp án đúng:
Không gửi ảnh và báo bố mẹ.

Parent Note:
Tuần này, hãy cùng bé luyện câu: “Con không đi. Con sẽ gọi bố mẹ/cô giáo.”
```

---

## Ví dụ 3: Cẩn Thận Trong Nhà Bếp

```text
Tên bài:
Cẩn thận trong nhà bếp

Kỹ năng chính:
Nhận biết vật nóng và nhờ người lớn giúp

Bối cảnh chính:
Nhà bếp

Nhân vật:
Mimi muốn lấy bánh gần bếp

Rủi ro chính:
Nồi nóng và bếp đang bật

1. Observe
Trẻ cần chạm vào:
- Bếp đang bật
- Nồi nóng
- Dao trên bàn
- Người lớn gần đó

2. Choice
Câu hỏi:
Mimi nên làm gì?

Đáp án A:
Tự với tay lấy bánh

Đáp án B:
Nhờ người lớn lấy giúp

Đáp án đúng:
B

3. Why
Giải thích ngắn:
Bếp và nồi có thể rất nóng. Mimi nhờ người lớn để không bị bỏng.

Câu hỏi vì sao:
Vì sao Mimi nên nhờ người lớn?

Lý do đúng:
Vì bếp và nồi có thể rất nóng.

4. Mini Challenge
Loại challenge:
Kéo thả Đúng/Sai

Nhiệm vụ:
Kéo các vật nguy hiểm vào ô “Cần người lớn giúp”.

Vật:
- Nồi nóng
- Dao
- Ổ điện
- Gấu bông

Số lần thử:
2

Feedback khi sai:
Vật này chưa đúng. Hãy tìm đồ có thể nóng, sắc hoặc nguy hiểm.

Feedback khi đúng:
Đúng rồi. Những vật này cần người lớn giúp.

5. Transfer
Bối cảnh mới:
Mimi thấy bàn là đang nóng.

Câu hỏi:
Mimi nên làm gì?

Đáp án đúng:
Không chạm vào và gọi người lớn.

Parent Note:
Khi ở nhà, hãy chỉ cho bé 2 vật “chỉ người lớn mới được chạm”.
```

---

## Lesson Beat Map

Dùng bảng này để kiểm tra nhịp bài học trước khi sản xuất.

| Beat | Cảm giác của trẻ | Mục tiêu học |
|---|---|---|
| Hook | Có chuyện gì vậy? | Tạo tò mò |
| Observe | Mình thấy gì nguy hiểm? | Nhận biết tín hiệu |
| Choice | Mình nên làm gì? | Chọn hành động |
| Feedback / Why | À, vì sao vậy? | Hiểu hậu quả |
| Mini Challenge | Mình thử lại được rồi | Luyện kỹ năng |
| Transfer | Gặp chỗ khác mình cũng biết làm | Áp dụng |
| Reward | Mình giỏi hơn rồi | Củng cố tiến bộ |

---

## Quy tắc thời lượng

| Phần | Thời lượng gợi ý |
|---|---|
| Hook | 20-40 giây |
| Observe | 30-60 giây |
| Choice | 20-40 giây |
| Why | 20-40 giây |
| Mini Challenge | 30-60 giây |
| Transfer | 30-60 giây |
| Reward | 15-30 giây |

Tổng bài học nên khoảng 7-10 phút nếu có nhiều cảnh nhỏ. Với bài đầu tiên của mỗi đảo, có thể rút gọn còn 5-7 phút.

---

## Quy tắc tăng độ khó

| Mức | Mục tiêu | Cách thiết kế |
|---|---|---|
| Mức 1 | Nhận biết | Chạm vào dấu hiệu nguy hiểm |
| Mức 2 | Chọn hành động | Chọn việc nên làm |
| Mức 3 | Giải thích | Chọn lý do đơn giản |
| Mức 4 | Áp dụng | Đổi bối cảnh, giữ cùng kỹ năng |

### Gợi ý triển khai

- Bài đầu mỗi đảo: dễ, nhiều gợi ý, ít nhiễu.
- Bài giữa: thêm câu hỏi “vì sao”.
- Bài cuối đảo: ít gợi ý hơn, thêm nhiễu nhẹ, Transfer rõ hơn.
- Không dùng điểm phạt nặng với trẻ nhỏ.
- Nên dùng Safety Stars theo từng kỹ năng.
### Quy tắc riêng cho đảo 2 và các đảo sau

- Không tăng độ khó bằng cách thêm chữ hoặc làm tình huống đáng sợ hơn.
- Tăng độ khó bằng cách thêm bối cảnh thật: lời rủ rê, áp lực bạn bè, vật hấp dẫn, nơi công cộng, hoặc người đáng tin cậy ở gần.
- Mỗi bài vẫn chỉ kiểm tra một kỹ năng chính.
- Đảo 2 nên ưu tiên câu trẻ có thể nói thành lời: “Con không đi”, “Mình không làm vậy”, “Con sẽ gọi cô giáo/bố mẹ”.
- Bài đầu của đảo dạy rõ quy tắc. Bài giữa thêm nhiễu nhẹ. Bài cuối đổi bối cảnh để kiểm tra Transfer.
- Chi tiết đầy đủ để build/debug nằm trong `template_lesson/island_2_plus_rules.md`.

---

## Rubric Cuối Bài

Có thể lưu tiến độ chi tiết theo 4 nhóm kỹ năng:

| Kỹ năng | Ý nghĩa |
|---|---|
| Quan sát | Trẻ nhận ra dấu hiệu quan trọng |
| Chọn hành động | Trẻ chọn được hành động an toàn |
| Giải thích | Trẻ hiểu lý do đơn giản |
| Áp dụng thực tế | Trẻ dùng kỹ năng ở bối cảnh mới |

Ví dụ hiển thị sau mỗi phần:

```text
Con đã tìm ra nguy hiểm.
Con đã chọn hành động an toàn.
Con đã giải thích được lý do.
Con đã áp dụng vào tình huống mới.
```

---

## Lưu ý quan trọng

Không nên để 5 phần hỏi lại cùng một ý.

Ví dụ chưa tốt:

```text
Observe: Chạm vào đèn đỏ.
Choice: Có nên đi khi đèn đỏ không?
Why: Vì sao không đi khi đèn đỏ?
Mini Challenge: Kéo đèn đỏ vào ô nguy hiểm.
Transfer: Thấy đèn đỏ thì làm gì?
```

Cách này bị lặp.

Ví dụ tốt hơn:

```text
Observe: Tìm đèn đỏ và xe đang chạy.
Choice: Chọn đứng lại chờ.
Why: Vì xe có thể không dừng kịp.
Mini Challenge: Sắp xếp 3 bước qua đường an toàn.
Transfer: Bóng lăn ra đường thì con làm gì?
```

Mỗi phần phải tăng thêm một lớp kỹ năng. Như vậy bài học dài hơn nhưng không bị lê thê, trẻ thấy mình tiến bộ thật.


