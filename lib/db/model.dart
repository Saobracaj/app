class AnswerRecord {
  final int? id;
  final int questionId;
  final DateTime date;
  final bool isWrong;

  AnswerRecord({
    this.id,
    required this.questionId,
    required this.date,
    required this.isWrong,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionId': questionId,
      'date': date.toIso8601String(),
      'isWrong': isWrong ? 1 : 0,
    };
  }

  factory AnswerRecord.fromMap(Map<String, dynamic> map) {
    return AnswerRecord(
      id: map['id'],
      questionId: map['questionId'],
      date: DateTime.parse(map['date']),
      isWrong: map['isWrong'] == 1,
    );
  }
}
