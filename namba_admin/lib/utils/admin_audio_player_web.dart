// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void playAdminSound(String soundName) {
  try {
    js.context.callMethod('eval', [
      """
      (function() {
        try {
          if (window._adminPreviewAudio) {
            window._adminPreviewAudio.pause();
            window._adminPreviewAudio.currentTime = 0;
          }
          window._adminPreviewAudio = new Audio('assets/sounds/$soundName.wav');
          window._adminPreviewAudio.play().catch(function(err) {
            console.warn('Audio play prevented or file not found:', err);
          });
        } catch(e) {
          console.error('Web audio execution error:', e);
        }
      })()
      """
    ]);
  } catch (e) {
    // Ignore web audio exceptions
  }
}

void stopAdminSound() {
  try {
    js.context.callMethod('eval', [
      """
      (function() {
        try {
          if (window._adminPreviewAudio) {
            window._adminPreviewAudio.pause();
            window._adminPreviewAudio.currentTime = 0;
            window._adminPreviewAudio = null;
          }
        } catch(_) {}
      })()
      """
    ]);
  } catch (_) {}
}
