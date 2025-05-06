import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PrivacyPolicyWidget extends StatefulWidget {
  @override
  _PrivacyPolicyWidgetState createState() => _PrivacyPolicyWidgetState();
}

class _PrivacyPolicyWidgetState extends State<PrivacyPolicyWidget> {
  String _language = 'ru';

  final Map<String, String> _privacyTexts = {
    'ru': '''
**Политика конфиденциальности**

Ваше доверие важно для нас. Настоящая Политика конфиденциальности объясняет, как наше приложение обрабатывает ваши данные.

1. Сбор данных  
Наше приложение **не собирает**, **не хранит** и **не передаёт** никакие персональные данные. Оно работает **полностью оффлайн**.

2. Использование данных  
Поскольку мы не собираем данные, мы не используем их.

3. Передача третьим лицам  
Мы не передаём данные третьим лицам, так как у нас их нет.

4. Безопасность  
Рекомендуем соблюдать стандартные меры безопасности на устройстве.

5. Изменения  
При изменении политики, новая версия будет доступна в приложении.

6. Контакты  
Email: [info@gleb.at](mailto:info@gleb.at), Telegram: [GlebKl](https://t.me/GlebKl)
''',
    'en': '''
**Privacy Policy**

Your privacy is important to us. This Privacy Policy explains how our application handles your data.

1. Data Collection  
Our app does **not collect**, **store**, or **transmit** any personal data. It operates **entirely offline**.

2. Use of Data  
Since we collect no data, we use none.

3. Third-Party Sharing  
We share no data with third parties.

4. Security  
We recommend standard device security practices.

5. Changes  
Any changes will be reflected in future updates.

6. Contact  
Email: [info@gleb.at](mailto:info@gleb.at), Telegram: [GlebKl](https://t.me/GlebKl)
''',
    'sr': '''
**Политика приватности**

Ваша приватност нам је важна. Ова политика објашњава како апликација обрађује ваше податке.

1. Прикупљање података  
Апликација **не прикупља**, **не чува** и **не преноси** личне податке. Ради **потпуно офлајн**.

2. Употреба података  
Пошто не прикупљамо податке, не користимо их.

3. Дељење са трећим странама  
Нема дељења података.

4. Безбедност  
Препоручујемо уобичајене мере заштите уређаја.

5. Промене  
Све промене ће бити доступне у ажурирању.

6. Контакт  
Email: [info@gleb.at](mailto:info@gleb.at), Telegram: [GlebKl](https://t.me/GlebKl)
''',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 30,
          child: DropdownMenu(
            initialSelection: _language,
            inputDecorationTheme: InputDecorationTheme(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              constraints: BoxConstraints.tight(const Size.fromHeight(40)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            dropdownMenuEntries: [
              DropdownMenuEntry(value: 'ru', label: 'Русский'),
              DropdownMenuEntry(value: 'en', label: 'English'),
              DropdownMenuEntry(value: 'sr', label: 'Српски'),
            ],
            onSelected: (value) {
              if (value != null) {
                setState(() => _language = value);
              }
            },
          ),
        ),

        /* DropdownButton<String>(
          value: _language,
          onChanged: (value) {
            if (value != null) {
              setState(() => _language = value);
            }
          },
          items: const [
            DropdownMenuItem(value: 'ru', child: Text('Русский')),
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'sr', child: Text('Српски')),
          ],
        )*/
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Markdown(shrinkWrap: true, selectable: false, data: _privacyTexts[_language] ?? ''),
            ),
          ),
        ],
      ),
    );
  }
}
