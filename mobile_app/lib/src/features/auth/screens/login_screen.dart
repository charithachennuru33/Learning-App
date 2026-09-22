import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/api_exception.dart';
import '../../../app_scope.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../util/format.dart';
import '../../../widgets/common.dart';

/// Phone number and OTP on one screen: step 2 appears once a code is sent.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _codeLength = 6;

  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _timer;

  String? _sentTo; // phone the code went to; non-null = step 2 visible
  int _resendIn = 0;
  bool _sending = false;
  bool _verifying = false;
  String? _phoneError;
  String? _codeError;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  /// Adds +91 for local 10-digit input; the server does the real validation.
  String get _phoneForApi {
    final raw = _phone.text.trim();
    return raw.startsWith('+') ? raw : '+91 $raw';
  }

  void _startCountdown(Duration d) {
    _timer?.cancel();
    setState(() => _resendIn = d.inSeconds);
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (_resendIn <= 1) t.cancel();
      if (mounted) setState(() => _resendIn = (_resendIn - 1).clamp(0, 1 << 30));
    });
  }

  Future<void> _sendCode() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(() => _phoneError = 'Enter a valid mobile number');
      return;
    }
    setState(() {
      _sending = true;
      _phoneError = null;
      _codeError = null;
    });
    final phone = _phoneForApi;
    try {
      final challenge = await AppScope.of(context).repository.requestOtp(phone);
      _showStep2(phone, challenge.resendAfter);
    } on ApiException catch (e) {
      if (e.code == 'OTP_RESEND_TOO_SOON') {
        // A code went out moments ago: let them type it rather than blocking.
        _showStep2(phone, e.retryAfter ?? Duration(seconds: 30));
      } else if (mounted) {
        setState(() => _phoneError = e.fields['phone'] ?? e.message);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showStep2(String phone, Duration resendAfter) {
    if (!mounted) return;
    setState(() {
      _sentTo = phone;
      _code.clear();
    });
    _startCountdown(resendAfter);
    WidgetsBinding.instance.addPostFrameCallback((_) => _codeFocus.requestFocus());
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != _codeLength) {
      setState(() => _codeError = 'Enter the $_codeLength-digit code');
      return;
    }
    setState(() {
      _verifying = true;
      _codeError = null;
    });
    try {
      // On success the router sees the signed-in state and opens Home.
      await AppScope.of(context).auth.verifyOtp(_sentTo!, code);
    } on ApiException catch (e) {
      if (!mounted) return;
      _code.clear();
      setState(() => _codeError = switch (e.code) {
            'INVALID_OTP' => 'That code is wrong or has expired.',
            'OTP_ATTEMPTS_EXCEEDED' => 'Too many wrong attempts. Request a new code.',
            _ => e.fields['otp'] ?? e.message,
          });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demoMode = AppScope.of(context).demoMode;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Align(alignment: Alignment.centerRight, child: ThemeToggleButton()),
                        ),
                        SizedBox(height: 8),
                        Align(alignment: Alignment.centerLeft, child: BrandLogo(height: 64, markOnly: true)),
                        SizedBox(height: 10),
                        Text('Ram Intellect', style: AppText.display),
                        SizedBox(height: 28),
                        Text('Enter your number', style: AppText.title),
                        SizedBox(height: 10),
                        Text('We send a six-digit code. No password to remember.', style: AppText.bodyMuted),
                        if (demoMode) ...[SizedBox(height: 16), DemoNotice()],
                        SizedBox(height: 24),
                        _phoneRow(),
                        SizedBox(height: 20),
                        FilledButton(
                          key: Key('sendCodeButton'),
                          onPressed: _sending || (_sentTo != null && _resendIn > 0) ? null : _sendCode,
                          child: _sending
                              ? SizedBox.square(
                                  dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                              : Text(_sentTo == null ? 'Send code' : 'Code sent'),
                        ),
                        if (_sentTo != null) ..._step2(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Keeps the legal line at the bottom on tall screens; scrolls with the form on short ones.
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                  child: Text(
                    'By continuing you agree to the Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: AppText.tiny,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 82,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.muted),
        ]),
      ),
      SizedBox(width: 10),
      Expanded(
        child: TextField(
          key: Key('phoneField'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.send,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.6),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            LengthLimitingTextInputFormatter(16),
          ],
          decoration: InputDecoration(
            hintText: '98765 43210',
            errorText: _phoneError,
            errorMaxLines: 3,
            semanticCounterText: 'Mobile number',
          ),
          onChanged: (_) {
            if (_sentTo != null) setState(() => _sentTo = null); // number changed: back to step 1
          },
          onSubmitted: (_) => _sending ? null : _sendCode(),
        ),
      ),
    ]);
  }

  List<Widget> _step2() {
    return [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Row(children: [
          Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('STEP 2 · VERIFY', style: AppText.label),
          ),
          Expanded(child: Divider(color: AppColors.border)),
        ]),
      ),
      Text('Code sent to ${Fmt.phone(_normalized(_sentTo!))}',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      SizedBox(height: 8),
      Text('Enter the six-digit code from the SMS.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
      SizedBox(height: 14),
      TextField(
        key: Key('otpField'),
        controller: _code,
        focusNode: _codeFocus,
        keyboardType: TextInputType.number,
        autofillHints: [AutofillHints.oneTimeCode],
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 9),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(_codeLength),
        ],
        decoration: InputDecoration(
          hintText: '– – – – – –',
          hintStyle: TextStyle(color: AppColors.disabled, letterSpacing: 4),
          counterText: '',
          errorText: _codeError,
          errorMaxLines: 3,
        ),
        onChanged: (v) {
          if (v.length == _codeLength && !_verifying) _verify();
        },
      ),
      SizedBox(height: 16),
      FilledButton(
        key: Key('verifyButton'),
        onPressed: _verifying ? null : _verify,
        child: _verifying
            ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
            : Text('Verify'),
      ),
      SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
          child: Text(_resendIn > 0 ? 'Resend in ${Fmt.countdown(_resendIn)}' : 'Didn’t get it?',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ),
        TextButton(
          onPressed: _resendIn > 0 || _sending ? null : _sendCode,
          style: TextButton.styleFrom(disabledForegroundColor: AppColors.disabled),
          child: Text('Resend code'),
        ),
      ]),
    ];
  }

  /// "+91 98765 43210" -> "+919876543210" for display formatting.
  static String _normalized(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return '+$digits';
  }
}
