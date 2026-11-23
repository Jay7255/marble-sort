import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad unit IDs. The test IDs are Google's public sample units: they always
/// fill, never pay, and are safe to tap. Before release, set [useTestAds]
/// to false and paste your own IDs from the AdMob dashboard.
class AdIds {
  static const bool useTestAds = true;

  static String get banner => useTestAds
      ? (Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716')
      : (Platform.isAndroid ? 'YOUR_ANDROID_BANNER_ID' : 'YOUR_IOS_BANNER_ID');

  static String get interstitial => useTestAds
      ? (Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910')
      : (Platform.isAndroid ? 'YOUR_ANDROID_INTERSTITIAL_ID' : 'YOUR_IOS_INTERSTITIAL_ID');

  static String get rewarded => useTestAds
      ? (Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313')
      : (Platform.isAndroid ? 'YOUR_ANDROID_REWARDED_ID' : 'YOUR_IOS_REWARDED_ID');
}

/// Loads and shows ads. Asks for consent first (required in the EU/UK),
/// and keeps one interstitial and one rewarded ad preloaded.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _ready = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  /// True when the privacy settings button should be shown (EU/UK users).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);
  final ValueNotifier<bool> canShowBanner = ValueNotifier(false);

  Future<void> init() async {
    final consent = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) debugPrint('Consent form: ${error.message}');
          if (!consent.isCompleted) consent.complete();
        });
      },
      (FormError error) {
        debugPrint('Consent info: ${error.message}');
        if (!consent.isCompleted) consent.complete();
      },
    );
    await consent.future;

    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    privacyOptionsRequired.value =
        status == PrivacyOptionsRequirementStatus.required;

    if (await ConsentInformation.instance.canRequestAds()) {
      await _start();
    }
  }

  Future<void> _start() async {
    if (_ready) return;
    await MobileAds.instance.initialize();
    _ready = true;
    canShowBanner.value = true;
    _loadInterstitial();
    _loadRewarded();
  }

  /// Opens Google's privacy options form so players can change consent.
  void showPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((FormError? error) async {
      if (error != null) debugPrint('Privacy form: ${error.message}');
      if (await ConsentInformation.instance.canRequestAds()) _start();
    });
  }

  void _loadInterstitial() {
    if (!_ready || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('Interstitial failed: ${error.message}');
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  void _loadRewarded() {
    if (!_ready || _loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          debugPrint('Rewarded failed: ${error.message}');
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  bool get rewardedReady => _rewarded != null;

  /// Shows an interstitial if one is loaded. Completes when it closes.
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
    );
    ad.show();
    return done.future;
  }

  /// Shows a rewarded ad. Completes with true only if the reward was earned.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (ad, reward) => earned = true);
    return done.future;
  }
}

/// A 320×50 banner that appears once ads are allowed and loaded.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.canShowBanner.addListener(_maybeLoad);
    _maybeLoad();
  }

  void _maybeLoad() {
    if (_ad != null || !AdService.instance.canShowBanner.value) return;
    _ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          debugPrint('Banner failed: ${error.message}');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    AdService.instance.canShowBanner.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _loaded && ad != null ? 50 : 0,
      color: Colors.black.withValues(alpha: .35),
      alignment: Alignment.center,
      child: _loaded && ad != null
          ? SizedBox(width: 320, height: 50, child: AdWidget(ad: ad))
          : null,
    );
  }
}
