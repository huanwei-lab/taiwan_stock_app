import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_checker/services/intraday_controller.dart';
import 'package:stock_checker/services/intraday_service.dart';

class NoopService extends IntradayService {
  bool started = false;
  @override
  void start() {
    started = true;
  }

  @override
  void stop() {
    started = false;
  }
}

void main() {
  test('controller enables/disables and persists pref', () async {
    SharedPreferences.setMockInitialValues({});
    final service = NoopService();
    final controller = await IntradayController.create(service: service);

    expect(controller.enabled, false);
    await controller.enable();
    expect(controller.enabled, true);
    expect(service.started, true);

    await controller.disable();
    expect(controller.enabled, false);
    expect(service.started, false);
  });
}
