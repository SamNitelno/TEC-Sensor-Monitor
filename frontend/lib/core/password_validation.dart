String? validatePassword(String password) {
  if (password.length < 8) {
    return 'Минимум 8 символов';
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Нужна хотя бы одна цифра';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
    return 'Нужны латинские буквы';
  }
  return null;
}
