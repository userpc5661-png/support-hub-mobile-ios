import 'meta_signup_result.dart';

bool get isMetaEmbeddedSignupSupported => false;

Future<MetaSignupResult> startMetaEmbeddedSignup({
  required String appId,
  required String configurationId,
  required String graphVersion,
}) {
  throw UnsupportedError(
    'Meta Embedded Signup is available in the secure web dashboard.',
  );
}

Future<void> openWhatsAppManager({
  required String businessId,
  required String wabaId,
}) {
  throw UnsupportedError(
    'WhatsApp Manager can be opened from the secure web dashboard.',
  );
}
