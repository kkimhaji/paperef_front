import 'package:web/web.dart' as web;

void pushHistoryState() {
  web.window.history.pushState(null, 'Paperef', '/');
}
