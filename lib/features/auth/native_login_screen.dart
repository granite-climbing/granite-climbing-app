import 'package:flutter/material.dart';

class NativeLoginScreen extends StatelessWidget {
  const NativeLoginScreen({
    required this.onProviderSelected,
    this.isStarting = false,
    super.key,
  });

  final ValueChanged<String> onProviderSelected;
  final bool isStarting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(
                child: Center(
                  child: Text(
                    'GRANITE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              const Text(
                'Granite 시작하기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              _ProviderButton(
                label: 'Apple로 시작하기',
                provider: 'apple',
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                enabled: !isStarting,
                onPressed: onProviderSelected,
              ),
              const SizedBox(height: 12),
              _ProviderButton(
                label: 'Google로 시작하기',
                provider: 'google',
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                enabled: !isStarting,
                onPressed: onProviderSelected,
              ),
              const SizedBox(height: 12),
              _ProviderButton(
                label: '카카오로 시작하기',
                provider: 'kakao',
                backgroundColor: const Color(0xFFFFE100),
                foregroundColor: Colors.black,
                enabled: !isStarting,
                onPressed: onProviderSelected,
              ),
              const SizedBox(height: 12),
              _ProviderButton(
                label: '네이버로 시작하기',
                provider: 'naver',
                backgroundColor: const Color(0xFF5CC968),
                foregroundColor: Colors.white,
                enabled: !isStarting,
                onPressed: onProviderSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.provider,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final String provider;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool enabled;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.45),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.45),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: enabled ? () => onPressed(provider) : null,
        child: Text(label),
      ),
    );
  }
}
