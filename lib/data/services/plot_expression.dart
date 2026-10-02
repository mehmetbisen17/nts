import 'dart:math' as math;

/// y = f(x) from the on-device model's `expression`, e.g. "x^2 - 4x + 3" or
/// "e^{-0.2t} * cos(2t)". Allows implicit multiplication, {} as brackets,
/// "y =" in front, and t instead of x.
///
/// Throws [FormatException] if it can't be read, including any character
/// it doesn't know (so "x² + |x|" fails instead of quietly drawing x + x).
double Function(double x) parseExpression(String source) {
  final text = source
      .toLowerCase()
      .replaceAll('{', '(')
      .replaceAll('}', ')')
      .replaceAll('**', '^')
      .replaceAll('²', '^2')
      .replaceAll('³', '^3')
      .replaceAll('π', 'pi')
      .replaceAll(RegExp('[×·]'), '*')
      .replaceAll('−', '-')
      // "y =", "f(x) ="
      .replaceAll(RegExp(r'^\s*[a-z]\w*(\([a-z]\))?\s*='), '');
  final tokens = RegExp(r'\d*\.?\d+|[a-z]+|[-+*/^()]')
      .allMatches(text)
      .map((m) => m[0]!)
      .toList();
  if (tokens.join() != text.replaceAll(RegExp(r'\s'), '')) {
    throw FormatException('Unknown symbol', source);
  }

  var i = 0;
  String? peek() => i < tokens.length ? tokens[i] : null;
  const functions = <String, double Function(double)>{
    'sin': math.sin,
    'cos': math.cos,
    'tan': math.tan,
    'sqrt': math.sqrt,
    'exp': math.exp,
    'ln': math.log,
    'log': _log10,
    'abs': _abs,
  };

  late double Function(double) Function() expr;
  double Function(double) primary() {
    final t = peek();
    if (t == null) throw const FormatException('Unexpected end');
    i++;
    if (t == '(') {
      final inner = expr();
      if (peek() != ')') throw const FormatException('Missing )');
      i++;
      return inner;
    }
    final n = double.tryParse(t);
    if (n != null) return (_) => n;
    if (t == 'x' || t == 't') return (x) => x;
    if (t == 'pi') return (_) => math.pi;
    if (t == 'e') return (_) => math.e;
    final f = functions[t];
    if (f == null) throw FormatException('Unknown name $t');
    final arg = primary();
    return (x) => f(arg(x));
  }

  double Function(double) unary() {
    if (peek() == '-') {
      i++;
      final u = unary();
      return (x) => -u(x);
    }
    if (peek() == '+') {
      i++;
      return unary();
    }
    final base = primary();
    if (peek() != '^') return base;
    i++;
    final exponent = unary(); // right-associative, allows 2^-x
    return (x) => math.pow(base(x), exponent(x)).toDouble();
  }

  double Function(double) term() {
    var left = unary();
    while (true) {
      final t = peek();
      if (t == '*' || t == '/') {
        i++;
        final l = left, r = unary();
        left = t == '*' ? (x) => l(x) * r(x) : (x) => l(x) / r(x);
      } else if (t != null && !'+-)^'.contains(t)) {
        final l = left, r = unary(); // implicit: 4x, 2(x+1), x sin(x)
        left = (x) => l(x) * r(x);
      } else {
        return left;
      }
    }
  }

  expr = () {
    var left = term();
    while (peek() == '+' || peek() == '-') {
      final minus = tokens[i++] == '-';
      final l = left, r = term();
      left = minus ? (x) => l(x) - r(x) : (x) => l(x) + r(x);
    }
    return left;
  };

  final f = expr();
  if (i != tokens.length) throw FormatException('Unexpected ${tokens[i]}');
  return f;
}

double _log10(double x) => math.log(x) / math.ln10;
double _abs(double x) => x.abs();
