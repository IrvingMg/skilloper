import 'package:web/web.dart' as web;

/// Copies text to clipboard using execCommand fallback for web compatibility.
/// Returns true on success, false on failure.
///
/// Note: This implementation uses web-only APIs and is intended for Flutter web.
Future<bool> copyToClipboard(String text) {
  try {
    final textArea =
        web.document.createElement('textarea') as web.HTMLTextAreaElement;
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-9999px';
    web.document.body?.appendChild(textArea);
    textArea.select();
    final success = web.document.execCommand('copy');
    if (textArea.parentNode != null) {
      textArea.remove();
    }
    return Future.value(success);
  } on Object {
    return Future.value(false);
  }
}
