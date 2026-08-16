import 'package:flutter/material.dart';

/// Экран списка, первую страницу которого загрузить не удалось.
///
/// Раньше на этом месте оставался индикатор загрузки: ошибка гасила флаг
/// «грузится», но «загружено» так и не выставлялось — и вкладка навсегда
/// оставалась с крутящимся колесом, а единственное объяснение уезжало вместе со
/// снек-баром. Здесь вместо этого написано, что связи нет, и есть кнопка
/// «попробовать снова».
///
/// Список прокручиваемый — чтобы поверх него работал pull-to-refresh.
class LoadFailedList extends StatelessWidget {
  const LoadFailedList({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}
