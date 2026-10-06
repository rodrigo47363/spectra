import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_std/hetu_std.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/utils/platform.dart';

class MetadataAuthEndpoint {
  final Hetu hetu;

  MetadataAuthEndpoint(this.hetu);

  Stream get authStateStream {
    try {
      final res = hetu.eval("metadataPlugin.auth.authStateStream");
      if (res is Stream) return res;
      return Stream.empty();
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return Stream.empty();
    }
  }

  Future<void> authenticate() async {
    try {
      await hetu.eval("metadataPlugin.auth.authenticate()");
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      rethrow;
    }
  }

  bool isAuthenticated() {
    try {
      return (hetu.eval("metadataPlugin.auth.isAuthenticated()") as bool?) ?? false;
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await hetu.eval("metadataPlugin.auth.logout()");
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }
    if (kIsMobile) {
      WebStorageManager.instance().deleteAllData();
      CookieManager.instance().deleteAllCookies();
    }
    if (kIsDesktop) {
      await WebviewWindow.clearAll();
    }
  }
}
