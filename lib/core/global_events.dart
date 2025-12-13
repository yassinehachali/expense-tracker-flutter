import 'dart:async';

class GlobalEvents {
  static final StreamController<String> _controller = StreamController.broadcast();
  
  static Stream<String> get stream => _controller.stream;
  
  static void trigger(String event) {
    _controller.add(event);
  }
}
