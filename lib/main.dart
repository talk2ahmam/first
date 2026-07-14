import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'calculator_engine.dart';

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7351FF);
    return MaterialApp(
      title: 'Scientific Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String? _errorText;
  bool _degrees = true;
  bool _justCalculated = false;
  double _memory = 0;
  final List<String> _history = [];

  static const List<List<String>> _buttonRows = [
    ['C', '(', ')', 'DEL'],
    ['sin', 'cos', 'tan', '^'],
    ['ln', 'log', '√', '!'],
    ['7', '8', '9', '/'],
    ['4', '5', '6', '*'],
    ['1', '2', '3', '-'],
    ['0', '.', 'π', '+'],
    ['MC', 'MR', 'M+', 'M-'],
    ['DEG', '%', 'e', '='],
  ];

  static const Set<String> _operators = {'+', '-', '*', '/', '^'};

  String get _displayExpression {
    return _expression
        .replaceAll('sqrt', '√')
        .replaceAll('pi', 'π')
        .replaceAll('*', '×')
        .replaceAll('/', '÷');
  }

  String get _livePreview {
    if (_expression.trim().isEmpty) return '';
    try {
      final value = ScientificCalculatorEngine.evaluate(_expression, degrees: _degrees);
      return _formatNumber(value);
    } catch (_) {
      return '';
    }
  }

  bool _lastCharIsValueEnd() {
    if (_expression.isEmpty) return false;
    final lastChar = _expression[_expression.length - 1];
    if (RegExp(r'[0-9)]').hasMatch(lastChar)) return true;
    if (_expression.endsWith('pi') || _expression.endsWith('e')) return true;
    return false;
  }

  bool _currentNumberHasDot() {
    int i = _expression.length - 1;
    final buffer = StringBuffer();
    while (i >= 0 && RegExp(r'[0-9.]').hasMatch(_expression[i])) {
      buffer.write(_expression[i]);
      i--;
    }
    return buffer.toString().contains('.');
  }

  void _insertToken(String token, {bool allowImplicitMultiply = false}) {
    HapticFeedback.lightImpact();
    setState(() {
      _errorText = null;
      if (allowImplicitMultiply && _lastCharIsValueEnd()) {
        _expression += '*';
      }
      _expression += token;
    });
  }

  double? _currentValueOrNull() {
    try {
      return ScientificCalculatorEngine.evaluate(_expression, degrees: _degrees);
    } catch (_) {
      return null;
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    String s = value.toStringAsPrecision(12);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  void _calculate() {
    if (_expression.trim().isEmpty) return;
    try {
      final result = ScientificCalculatorEngine.evaluate(_expression, degrees: _degrees);
      setState(() {
        _history.insert(0, '$_displayExpression = ${_formatNumber(result)}');
        if (_history.length > 20) _history.removeLast();
        _expression = _formatNumber(result);
        _errorText = null;
        _justCalculated = true;
      });
    } catch (_) {
      setState(() => _errorText = 'Error');
    }
  }

  void _onButtonPressed(String value) {
    // Handle continuation-after-'=' behavior first.
    if (_justCalculated) {
      final isStateButton = {'C', 'DEL', '=', 'DEG', 'MC', 'MR', 'M+', 'M-'}.contains(value);
      if (_operators.contains(value)) {
        _justCalculated = false; // keep result, append operator below
      } else if (!isStateButton) {
        setState(() {
          _expression = '';
        });
        _justCalculated = false;
      }
    }

    switch (value) {
      case 'C':
        setState(() {
          _expression = '';
          _errorText = null;
          _justCalculated = false;
        });
        return;
      case 'DEL':
        setState(() {
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
          }
          _errorText = null;
        });
        return;
      case '=':
        _calculate();
        return;
      case 'DEG':
        setState(() => _degrees = !_degrees);
        return;
      case 'MC':
        setState(() => _memory = 0);
        return;
      case 'MR':
        _insertToken(_formatNumber(_memory), allowImplicitMultiply: true);
        return;
      case 'M+':
        final v = _currentValueOrNull();
        if (v != null) setState(() => _memory += v);
        return;
      case 'M-':
        final v = _currentValueOrNull();
        if (v != null) setState(() => _memory -= v);
        return;
      case 'π':
        _insertToken('pi', allowImplicitMultiply: true);
        return;
      case 'e':
        _insertToken('e', allowImplicitMultiply: true);
        return;
      case '√':
        _insertToken('sqrt(', allowImplicitMultiply: true);
        return;
      case 'sin':
      case 'cos':
      case 'tan':
      case 'ln':
      case 'log':
        _insertToken('$value(', allowImplicitMultiply: true);
        return;
      case '(':
        _insertToken('(', allowImplicitMultiply: true);
        return;
      case '.':
        if (!_currentNumberHasDot()) {
          _insertToken('.');
        }
        return;
      default:
        _insertToken(value);
    }
  }

  Color _buttonColor(String label) {
    if (label == '=') return Theme.of(context).colorScheme.primary;
    if (_operators.contains(label) || label == '%' || label == '!') {
      return const Color(0xFF2A2A38);
    }
    if (['C', 'DEL'].contains(label)) return const Color(0xFF3A2020);
    if (['MC', 'MR', 'M+', 'M-', 'DEG'].contains(label)) return const Color(0xFF20303A);
    if (RegExp(r'^[0-9.]$').hasMatch(label)) return const Color(0xFF1E1E1E);
    return const Color(0xFF262230);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scientific Calculator'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _degrees ? 'DEG' : 'RAD',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_history.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.builder(
                  reverse: true,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _history[index],
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _errorText ?? (_displayExpression.isEmpty ? '0' : _displayExpression),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w300,
                          color: _errorText != null ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_errorText == null && _livePreview.isNotEmpty && !_justCalculated)
                      Text(
                        '= $_livePreview',
                        style: const TextStyle(fontSize: 18, color: Colors.white38),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _buttonRows.map((row) {
                  return Expanded(
                    child: Row(
                      children: row.map((label) {
                        final displayLabel = label == 'DEG' ? (_degrees ? 'DEG' : 'RAD') : label;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _buttonColor(label),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                elevation: 0,
                              ),
                              onPressed: () => _onButtonPressed(label),
                              child: Text(
                                displayLabel,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
