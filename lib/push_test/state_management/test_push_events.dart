/// События экрана «Тестовый пуш».
sealed class TestPushEvent {}

/// Экран открылся: подставляем в поле почты адрес самого администратора —
/// проверить доставку на себе хочется чаще всего.
class TestPushOpened extends TestPushEvent {}

class TestPushEmailChanged extends TestPushEvent {
  TestPushEmailChanged(this.email);

  final String email;
}

class TestPushTitleChanged extends TestPushEvent {
  TestPushTitleChanged(this.title);

  final String title;
}

class TestPushBodyChanged extends TestPushEvent {
  TestPushBodyChanged(this.body);

  final String body;
}

class TestPushLinkChanged extends TestPushEvent {
  TestPushLinkChanged(this.link);

  final String link;
}

class TestPushSubmitted extends TestPushEvent {}
