import 'dart:js_interop';

import 'meta_signup_result.dart';

bool get isMetaEmbeddedSignupSupported => true;

@JS('supportHubMetaSignup')
external JSPromise<JSString> _supportHubMetaSignup(
  JSString appId,
  JSString configurationId,
  JSString graphVersion,
);

@JS('supportHubOpenWhatsAppManager')
external void _supportHubOpenWhatsAppManager(
  JSString businessId,
  JSString wabaId,
);

Future<MetaSignupResult> startMetaEmbeddedSignup({
  required String appId,
  required String configurationId,
  required String graphVersion,
}) async {
  final payload = await _supportHubMetaSignup(
    appId.toJS,
    configurationId.toJS,
    graphVersion.toJS,
  ).toDart;
  return MetaSignupResult.fromJsonString(payload.toDart);
}

Future<void> openWhatsAppManager({
  required String businessId,
  required String wabaId,
}) async {
  _supportHubOpenWhatsAppManager(businessId.toJS, wabaId.toJS);
}
