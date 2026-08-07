// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

Stream<String> openEventTextStream(Uri uri, Map<String, String> headers) {
  late html.HttpRequest request;
  var consumed = 0;
  late final StreamController<String> controller;

  controller = StreamController<String>(
    onListen: () {
      request = html.HttpRequest();
      request.open('GET', uri.toString());
      headers.forEach(request.setRequestHeader);

      void emitAvailableText() {
        final text = request.responseText ?? '';
        if (text.length <= consumed) return;
        controller.add(text.substring(consumed));
        consumed = text.length;
      }

      request.onProgress.listen((_) => emitAvailableText());
      request.onLoad.listen((_) {
        emitAvailableText();
        final status = request.status ?? 0;
        if (status >= 200 && status < 300) {
          controller.close();
        } else {
          controller
              .addError(StateError('Event stream failed with status $status'));
          controller.close();
        }
      });
      request.onError.listen((_) {
        controller.addError(StateError('Event stream connection failed'));
        controller.close();
      });
      request.onAbort.listen((_) => controller.close());
      request.send();
    },
    onCancel: () => request.abort(),
  );
  return controller.stream;
}
