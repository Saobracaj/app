/// Поток входа: экран входа и всё, что открывается из него, — регистрация,
/// подтверждение кода, сброс пароля.
///
/// Вход требуется с самых разных экранов: с витрины тарифов над вопросом, из
/// плашки гостя в обсуждении, из приглашения в группу, из настроек. Routemaster
/// строит стек страниц из адреса, поэтому абсолютный `push('/login')`
/// выбрасывал всё, что было под экраном входа: после входа `pop()` возвращал
/// на главную, а не туда, где вход понадобился. А если экран с кнопкой был
/// открыт императивно (см. `pushScreen`), вход и вовсе оказывался *под* ним —
/// его видели, лишь уйдя с экрана.
///
/// Поэтому из интерфейса вход всегда открывается как обычный императивный
/// роут поверх текущего экрана — на корневом навигаторе, чтобы лечь и над
/// вкладками главной ([openLogin]). Переходы внутри потока (вход →
/// регистрация → код: [authFlowToRegister], [authFlowToConfirmCode], …) идут
/// тем же навигатором, а по завершении снимается весь поток разом
/// ([finishAuthFlow]), и пользователь оказывается на экране, с которого нажал
/// «Войти», уже вошедшим. Адреса `/login`, `/register`, … остаются для прямых
/// ссылок; когда экран открыт по адресу, те же переходы делает routemaster.
library;

import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';

import 'confirm_code_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'reset_password_page.dart';

/// Открывает экран входа поверх экрана [context] — всегда императивно: кнопка
/// «Войти» стоит на экране, у которого адреса может и не быть.
Future<void> openLogin(BuildContext context) =>
    openAuthFlow(context, path: loginPath, screen: () => const LoginPage());

const loginPath = '/login';
const registerPath = '/register';
const resetPasswordPath = '/resetPassword';
const confirmCodePath = '/confirmCode';

/// Адреса экранов потока входа — по ним `finishAuthFlow` понимает, где поток
/// кончается, когда он открыт по адресу, а не императивно.
bool isAuthFlowPath(String path) =>
    path.startsWith(loginPath) ||
    path.startsWith(registerPath) ||
    path.startsWith(resetPasswordPath) ||
    path.startsWith(confirmCodePath);

/// Со страницы входа — на регистрацию, и наоборот: экран заменяет текущий,
/// чтобы «назад» не водило по кругу.
void authFlowToRegister(BuildContext context) => authFlowReplace(
  context,
  path: registerPath,
  screen: () => const RegisterPage(),
);

void authFlowToLogin(BuildContext context) =>
    authFlowReplace(context, path: loginPath, screen: () => const LoginPage());

/// Аккаунт ещё не подтверждён: экран кода встаёт на место формы.
void authFlowToConfirmCode(BuildContext context, {required String email}) =>
    authFlowReplace(
      context,
      path: '$confirmCodePath?email=${Uri.encodeComponent(email)}',
      screen: () => ConfirmCodePage(email: email),
    );

/// «Забыли пароль?» — поверх формы входа, чтобы «назад» вернуло к ней.
void authFlowToResetPassword(BuildContext context) => authFlowPush(
  context,
  path: resetPasswordPath,
  screen: () => const ResetPasswordPage(),
);

/// Вход состоялся (или пользователь передумал): снять весь поток и вернуть
/// пользователя на экран, с которого он начал.
///
/// Поток, открытый по адресу, снимается routemaster'ом до первого экрана вне
/// потока; если под ним ничего нет (прямая ссылка на `/login`), остаётся
/// только главная.
Future<void> finishAuthFlow(BuildContext context) async {
  if (_isImperative(context)) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route is! AuthFlowRoute);
    return;
  }
  final routemaster = Routemaster.of(context);
  await routemaster.popUntil((route) => !isAuthFlowPath(route.path));
  if (isAuthFlowPath(routemaster.currentRoute.path)) routemaster.replace('/');
}

/// Императивный роут экрана из потока входа. Отдельный класс, чтобы
/// [finishAuthFlow] снимал ровно поток, не трогая того, что под ним; имя
/// роута — адрес экрана, его же видит аналитика.
class AuthFlowRoute<T> extends MaterialPageRoute<T> {
  AuthFlowRoute({required super.builder, required String path})
    : super(settings: RouteSettings(name: path));
}

/// Экран открыт не routemaster'ом (у его роута нет `Page`), а императивно —
/// значит, и дальше по потоку идти тем же навигатором.
bool _isImperative(BuildContext context) =>
    ModalRoute.of(context)?.settings is! Page;

/// Следующий экран потока поверх текущего: из потока, открытого по адресу,
/// — адресом же; иначе тем же навигатором.
Future<void> authFlowPush(
  BuildContext context, {
  required String path,
  required Widget Function() screen,
}) {
  if (!_isImperative(context)) {
    Routemaster.of(context).push(path);
    return Future.value();
  }
  return openAuthFlow(context, path: path, screen: screen);
}

/// Начало потока: [screen] ложится императивно поверх экрана [context], на
/// корневом навигаторе. [path] — адрес экрана, он же имя роута для аналитики.
Future<void> openAuthFlow(
  BuildContext context, {
  required String path,
  required Widget Function() screen,
}) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(AuthFlowRoute<void>(path: path, builder: (_) => screen()));

/// Следующий экран потока вместо текущего.
void authFlowReplace(
  BuildContext context, {
  required String path,
  required Widget Function() screen,
}) {
  if (!_isImperative(context)) {
    Routemaster.of(context).replace(path);
    return;
  }
  Navigator.of(context, rootNavigator: true).pushReplacement<void, void>(
    AuthFlowRoute<void>(path: path, builder: (_) => screen()),
  );
}
