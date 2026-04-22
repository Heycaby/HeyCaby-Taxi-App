class HeyCabyValidators {
  HeyCabyValidators._();

  static bool isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email.trim());
  }

  static bool isValidName(String name) {
    return name.trim().length >= 2;
  }
}
