import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    GraniteApp(
      initialUrl: Uri.parse(AppConstants.defaultWebUrl),
    ),
  );
}
