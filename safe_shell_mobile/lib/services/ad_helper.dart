import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static Future<void> initGoogleMobileAds() async {
    await MobileAds.instance.initialize();
  }

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android test banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS test banner
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android test interstitial
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS test interstitial
    }
    throw UnsupportedError('Unsupported platform');
  }

  static void showInterstitialAd(void Function() onClosed) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onClosed();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              onClosed();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (err) {
          if (kDebugMode) debugPrint('Failed to load interstitial ad: $err');
          onClosed();
        },
      ),
    );
  }
}
