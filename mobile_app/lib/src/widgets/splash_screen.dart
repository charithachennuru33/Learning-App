import 'package:flutter/material.dart';

import 'common.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BrandLogo(height: 160),
          SizedBox(height: 32),
          CircularProgressIndicator(),
        ]),
      ),
    );
  }
}
