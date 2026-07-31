import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? emailValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return LocaleKeys.auth_errors_emptyEmail.tr();
  }
  if (!_emailRegex.hasMatch(value.trim())) {
    return LocaleKeys.auth_errors_invalidEmail.tr();
  }
  return null;
}

String? passwordValidator(String? value) {
  if (value == null || value.isEmpty) {
    return LocaleKeys.auth_errors_emptyPassword.tr();
  }
  if (value.length < 6) {
    return LocaleKeys.auth_errors_shortPassword.tr();
  }
  return null;
}

FormFieldValidator<String> repeatPasswordValidator(
  TextEditingController other,
) => (value) {
  if (value != other.text) {
    return LocaleKeys.auth_errors_passwordMismatch.tr();
  }
  return null;
};

String? codeValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return LocaleKeys.auth_errors_emptyCode.tr();
  }
  return null;
}
