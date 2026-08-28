import 'package:flutter_test/flutter_test.dart';

import '../lib/services/screen_automation_service.dart';

void main() {
  test('formats semantic nodes with task relevance and bounds', () {
    final summary = ScreenAutomationService.formatCompactScreenState(
      packageName: 'com.android.settings',
      task: 'open Wi-Fi settings',
      nodes: [
        {
          'index': 1,
          'text': 'Wi-Fi',
          'contentDescription': '',
          'className': 'android.widget.TextView',
          'isClickable': true,
          'isEditable': false,
          'isScrollable': false,
          'isChecked': false,
          'isEnabled': true,
          'bounds': {'left': 0, 'top': 0, 'right': 1080, 'bottom': 160},
        },
      ],
    );

    expect(summary, contains('package=com.android.settings'));
    expect(summary, contains('Wi-Fi'));
    expect(summary, contains('clickable'));
    expect(summary, contains('bounds=[0,0,1080,160]'));
  });
}
