import 'dart:math';

String generateTempPassword({int length = 10}) {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghijkmnpqrstuvwxyz';
  const digits = '23456789';
  const alphabet = '$upper$lower$digits';

  final rnd = Random.secure();
  final chars = <String>[
    upper[rnd.nextInt(upper.length)],
    lower[rnd.nextInt(lower.length)],
    digits[rnd.nextInt(digits.length)],
  ];

  while (chars.length < length) {
    chars.add(alphabet[rnd.nextInt(alphabet.length)]);
  }

  chars.shuffle(rnd);
  return chars.join();
}

String? validateStrongPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Digite a nova senha';
  }
  if (value.length < 8) {
    return 'A senha deve ter no mínimo 8 caracteres';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
    return 'A senha deve conter pelo menos uma letra';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'A senha deve conter pelo menos um número';
  }
  return null;
}
