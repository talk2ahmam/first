import 'dart:math' as math;

/// A self-contained scientific expression evaluator.
/// Supports: + - * / ^ ! % parentheses, sin/cos/tan, asin/acos/atan,
/// ln, log (base 10), sqrt, abs, and the constants pi and e.
class ScientificCalculatorEngine {
  static double evaluate(String expression, {bool degrees = true}) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) return 0;

    final tokens = _tokenize(trimmed);
    final parser = _Parser(tokens, degrees);
    final result = parser.parseExpression();

    if (parser.hasRemainingTokens) {
      throw FormatException('Unexpected token: ${parser.current}');
    }
    if (result.isNaN || result.isInfinite) {
      throw const FormatException('Math error');
    }
    return result;
  }

  static List<String> _tokenize(String input) {
    final clean = input.replaceAll(' ', '');
    final tokens = <String>[];
    int i = 0;

    while (i < clean.length) {
      final ch = clean[i];

      if (RegExp(r'[0-9.]').hasMatch(ch)) {
        final buffer = StringBuffer();
        while (i < clean.length && RegExp(r'[0-9.]').hasMatch(clean[i])) {
          buffer.write(clean[i]);
          i++;
        }
        tokens.add(buffer.toString());
        continue;
      }

      if (RegExp(r'[a-zA-Z]').hasMatch(ch)) {
        final buffer = StringBuffer();
        while (i < clean.length && RegExp(r'[a-zA-Z]').hasMatch(clean[i])) {
          buffer.write(clean[i]);
          i++;
        }
        tokens.add(buffer.toString());
        continue;
      }

      if ('+-*/^()!%'.contains(ch)) {
        tokens.add(ch);
        i++;
        continue;
      }

      throw FormatException('Unexpected character: $ch');
    }

    return tokens;
  }
}

class _Parser {
  _Parser(this.tokens, this.degrees);

  final List<String> tokens;
  final bool degrees;
  int pos = 0;

  static const List<String> _functions = [
    'asin', 'acos', 'atan', 'sin', 'cos', 'tan', 'ln', 'log', 'sqrt', 'abs',
  ];

  String? get current => pos < tokens.length ? tokens[pos] : null;
  bool get hasRemainingTokens => pos < tokens.length;

  double parseExpression() {
    double value = _parseTerm();
    while (current == '+' || current == '-') {
      final op = current!;
      pos++;
      final rhs = _parseTerm();
      value = op == '+' ? value + rhs : value - rhs;
    }
    return value;
  }

  double _parseTerm() {
    double value = _parsePower();
    while (current == '*' || current == '/') {
      final op = current!;
      pos++;
      final rhs = _parsePower();
      if (op == '*') {
        value = value * rhs;
      } else {
        if (rhs == 0) throw const FormatException('Division by zero');
        value = value / rhs;
      }
    }
    return value;
  }

  double _parsePower() {
    final value = _parseUnary();
    if (current == '^') {
      pos++;
      final rhs = _parsePower(); // right-associative
      return math.pow(value, rhs).toDouble();
    }
    return value;
  }

  double _parseUnary() {
    if (current == '-') {
      pos++;
      return -_parseUnary();
    }
    if (current == '+') {
      pos++;
      return _parseUnary();
    }
    return _parsePostfix();
  }

  double _parsePostfix() {
    double value = _parsePrimary();
    while (current == '!' || current == '%') {
      final op = current!;
      pos++;
      value = op == '!' ? _factorial(value) : value / 100;
    }
    return value;
  }

  double _parsePrimary() {
    final tok = current;
    if (tok == null) {
      throw const FormatException('Unexpected end of expression');
    }

    if (tok == '(') {
      pos++;
      final value = parseExpression();
      if (current != ')') {
        throw const FormatException('Missing closing parenthesis');
      }
      pos++;
      return value;
    }

    if (double.tryParse(_normalizeNumber(tok)) != null) {
      pos++;
      return double.parse(_normalizeNumber(tok));
    }

    if (tok == 'pi') {
      pos++;
      return math.pi;
    }
    if (tok == 'e') {
      pos++;
      return math.e;
    }

    if (_functions.contains(tok)) {
      pos++;
      if (current != '(') {
        throw FormatException('Expected ( after $tok');
      }
      pos++;
      final arg = parseExpression();
      if (current != ')') {
        throw const FormatException('Missing closing parenthesis');
      }
      pos++;
      return _applyFunction(tok, arg);
    }

    throw FormatException('Unexpected token: $tok');
  }

  String _normalizeNumber(String tok) {
    String norm = tok;
    if (norm.startsWith('.')) norm = '0$norm';
    if (norm.endsWith('.')) norm = '${norm}0';
    return norm;
  }

  double _applyFunction(String name, double arg) {
    final radArg = degrees ? arg * math.pi / 180 : arg;
    switch (name) {
      case 'sin':
        return math.sin(radArg);
      case 'cos':
        return math.cos(radArg);
      case 'tan':
        return math.tan(radArg);
      case 'asin':
        final r = math.asin(arg);
        return degrees ? r * 180 / math.pi : r;
      case 'acos':
        final r = math.acos(arg);
        return degrees ? r * 180 / math.pi : r;
      case 'atan':
        final r = math.atan(arg);
        return degrees ? r * 180 / math.pi : r;
      case 'ln':
        if (arg <= 0) throw const FormatException('ln requires a positive number');
        return math.log(arg);
      case 'log':
        if (arg <= 0) throw const FormatException('log requires a positive number');
        return math.log(arg) / math.ln10;
      case 'sqrt':
        if (arg < 0) throw const FormatException('Cannot take sqrt of a negative number');
        return math.sqrt(arg);
      case 'abs':
        return arg.abs();
      default:
        throw FormatException('Unknown function: $name');
    }
  }

  double _factorial(double value) {
    if (value < 0 || value != value.roundToDouble()) {
      throw const FormatException('Factorial requires a non-negative integer');
    }
    final n = value.toInt();
    if (n > 170) {
      throw const FormatException('Number too large for factorial');
    }
    double result = 1;
    for (int i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }
}
