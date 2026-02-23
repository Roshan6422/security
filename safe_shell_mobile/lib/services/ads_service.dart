import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  BannerAd createBanner({
    required String adUnitId,
    required void Function() onLoaded,
    required void Function(LoadAdError err) onFailed,
  }) {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (_, e) => onFailed(e),
      ),
      request: const AdRequest(),
    );
    ad.load();
    return ad;
  }

  RewardedAd? _rewarded;
  void loadRewarded(String adUnitId) {
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  void showRewarded({
    required void Function() onRewardEarned,
  }) {
    final ad = _rewarded;
    if (ad == null) return;
    ad.show(onUserEarnedReward: (_, __) => onRewardEarned());
    _rewarded = null;
  }
}
