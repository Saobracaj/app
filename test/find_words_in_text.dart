import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final questionsFile = File('assets/allQuestions.json');
  final questionsString = await questionsFile.readAsString();

  final List<dynamic> questionsJson = jsonDecode(questionsString);
//зауставна трака трамвајска баштица
//   final regexp = RegExp(r'зауставн[а-я]*\s+трак[а-я]*', caseSensitive: false, unicode: true);
//   final regexp = RegExp(r'раскрсни[а-я]*', caseSensitive: false, unicode: true);
  /*final regexp = RegExp(
    r'саобраћај[а-яђјљњћџ]*\s+трак[а-яђјљњћџ]*\s+за\s+возил[а-яђјљњћџ]*\s+јавн[а-яђјљњћџ]*\s+превоз[а-яђјљњћџ]*\s+путник[а-яђјљњћџ]*',
    caseSensitive: false,
    unicode: true,
  );*/
  final s = 'дневн одмо';
  String regExpS = s.split(' ').join(r'\p{Script=Cyrillic}*\s+');
  regExpS = regExpS + r'\p{Script=Cyrillic}*';
  print(regExpS);


  final regexp = RegExp(
    regExpS,
    // r'регистрова\p{Script=Cyrillic}*\s+воз\p{Script=Cyrillic}*',
    caseSensitive: false,
    unicode: true,
  );
  /*final regexp = RegExp(
    r'мотокултиват\p{Script=Cyrillic}*',
    caseSensitive: false,
    unicode: true,
  );*/
 /* final regexp = RegExp(
    r'пешач\p{Script=Cyrillic}*-\s*бициклист\p{Script=Cyrillic}*\s+стаз\p{Script=Cyrillic}*',
    caseSensitive: false,
    unicode: true,
  );*/
 /* final regexp = RegExp(
    r'прелаз\p{Script=Cyrillic}*\s+пут\p{Script=Cyrillic}*\s+преко\s+пруг\p{Script=Cyrillic}*',
    caseSensitive: false,
    unicode: true,
  );*/




  final Set<String> matches = {};

  for (final question in questionsJson) {
    final text = question['Text'] as String?;
    if (text != null) {
      for (final match in regexp.allMatches(text)) {
        matches.add(match.group(0)!.toLowerCase());
      }
    }

    final choices = question['Choices'] as List<dynamic>?;
    if (choices != null) {
      for (final choice in choices) {
        final choiceText = choice['Text'] as String?;
        if (choiceText != null) {
          for (final match in regexp.allMatches(choiceText)) {
            matches.add(match.group(0)!.toLowerCase());
          }
        }
      }
    }
  }

  final output = matches.map((e) => "'$e'").toList();
  print(output);
}
