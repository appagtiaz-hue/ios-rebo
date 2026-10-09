import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'database_service.dart';
import 'auth_service.dart';

class InAppPurchaseService {
  static final InAppPurchaseService _instance =
      InAppPurchaseService._internal();
  static InAppPurchaseService get instance => _instance;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;
  Future<void> _appleUpdates = Future<void>.value();
  Future<void>? _appleInitialization;

  // Callback for UI to listen to updates
  Function(String message, bool isError)? _statusCallback;
  Function(String transactionId, String productId)? _onPurchaseSuccess;

  InAppPurchaseService._internal();

  /// Check if the store is available
  bool get isStoreAvailable => _isAvailable;

  bool get _isGooglePlayBillingPlatform => Platform.isAndroid;
  bool get _isSupportedStore => _isGooglePlayBillingPlatform || Platform.isIOS;

  /// Initialize the purchase stream listener
  Future<void> initialize() => Platform.isIOS
      ? (_appleInitialization ??= _initializeStore())
      : _initializeStore();

  Future<void> _initializeStore() async {
    if (!_isSupportedStore) {
      _isAvailable = false;
      print('In-app purchases are disabled on this platform.');
      return;
    }

    // Check store availability first
    _isAvailable = await _iap.isAvailable();

    if (!_isAvailable) {
      print('⚠️ In-App Purchase Store is not available');
      return;
    }

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        if (Platform.isIOS) {
          // Serialize Apple updates so restore and purchase cannot grant twice.
          _appleUpdates = _appleUpdates
              .then((_) => _listenToPurchaseUpdated(purchaseDetailsList))
              .catchError((Object error) {
                _statusCallback?.call(
                  'تعذر معالجة شراء أبل؛ أعد استعادة المشتريات',
                  true,
                );
              });
        } else {
          _listenToPurchaseUpdated(purchaseDetailsList);
        }
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        print('❌ Purchase Stream Error: $error');
        if (_statusCallback != null) {
          _statusCallback!('Store Error: ${error.toString()}', true);
        }
      },
    );

    print(
      '✅ In-App Purchase Service Initialized (Store Available: $_isAvailable)',
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  void setCallbacks({
    Function(String, bool)? onStatus,
    Function(String, String)? onSuccess,
  }) {
    _statusCallback = onStatus;
    _onPurchaseSuccess = onSuccess;
  }

  /// Load products from the store
  Future<List<ProductDetails>> loadProducts(List<String> productIds) async {
    if (Platform.isIOS) {
      await initialize();
    }
    if (!_isSupportedStore) {
      _statusCallback?.call('المشتريات غير متاحة حالياً على iOS', true);
      return [];
    }

    if (!_isAvailable) {
      _isAvailable = await _iap.isAvailable();
    }

    if (!_isAvailable) {
      if (_statusCallback != null) {
        _statusCallback!(
          Platform.isIOS ? 'متجر أبل غير متاح' : 'متجر Google Play غير متاح',
          true,
        );
      }
      return [];
    }

    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(
        productIds.toSet(),
      );

      if (response.notFoundIDs.isNotEmpty) {
        print('⚠️ Products not found in store: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        print('❌ Product query error: ${response.error!.message}');
        if (_statusCallback != null) {
          _statusCallback!(
            'خطأ في تحميل المنتجات: ${response.error!.message}',
            true,
          );
        }
        return [];
      }

      print('✅ Loaded ${response.productDetails.length} products from store');
      return response.productDetails;
    } catch (e) {
      print('❌ Exception loading products: $e');
      if (_statusCallback != null) {
        _statusCallback!('خطأ في الاتصال بالمتجر', true);
      }
      return [];
    }
  }

  /// Initiate a purchase
  Future<bool> buyProduct(ProductDetails product) async {
    if (Platform.isIOS) {
      await initialize();
    }
    if (!_isSupportedStore) {
      _statusCallback?.call('المشتريات غير متاحة حالياً على iOS', true);
      return false;
    }

    if (!_isAvailable) {
      if (_statusCallback != null) {
        _statusCallback!(
          Platform.isIOS ? 'متجر أبل غير متاح' : 'متجر Google Play غير متاح',
          true,
        );
      }
      return false;
    }

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: Platform.isIOS ? await _appleAccountToken() : null,
      );

      // Use buyNonConsumable for subscriptions and one-time purchases
      final bool success = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        if (_statusCallback != null) {
          _statusCallback!('فشل بدء عملية الشراء', true);
        }
      }

      return success;
    } catch (e) {
      print('❌ Buy product error: $e');
      if (_statusCallback != null) {
        _statusCallback!('خطأ في عملية الشراء: $e', true);
      }
      return false;
    }
  }

  /// Restore previous purchases (for users who reinstall or change devices)
  Future<void> restorePurchases() async {
    if (Platform.isIOS) {
      await initialize();
    }
    if (!_isSupportedStore) {
      _statusCallback?.call('استعادة المشتريات غير متاحة حالياً على iOS', true);
      return;
    }

    if (!_isAvailable) {
      if (_statusCallback != null) {
        _statusCallback!(
          Platform.isIOS ? 'متجر أبل غير متاح' : 'متجر Google Play غير متاح',
          true,
        );
      }
      return;
    }

    try {
      if (_statusCallback != null) {
        _statusCallback!('جاري استعادة المشتريات...', false);
      }

      if (Platform.isIOS) {
        await _iap.restorePurchases(
          applicationUserName: await _appleAccountToken(),
        );
      } else {
        await _iap.restorePurchases();
      }
      // Results will come through the purchase stream
    } catch (e) {
      print('❌ Restore purchases error: $e');
      if (_statusCallback != null) {
        _statusCallback!('خطأ في استعادة المشتريات: $e', true);
      }
    }
  }

  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      bool appleVerified = false;
      print(
        '📦 Purchase Update: ${purchaseDetails.productID} - Status: ${purchaseDetails.status}',
      );

      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (_statusCallback != null) {
          _statusCallback!('جاري معالجة الشراء...', false);
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        if (_statusCallback != null) {
          _statusCallback!('تم إلغاء الشراء', true);
        }
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          final errorMessage =
              purchaseDetails.error?.message ?? 'خطأ غير معروف';
          print('❌ Purchase Error: $errorMessage');
          if (_statusCallback != null) {
            _statusCallback!('فشل الشراء: $errorMessage', true);
          }
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final isRestored = purchaseDetails.status == PurchaseStatus.restored;
          if (_statusCallback != null) {
            _statusCallback!(
              isRestored
                  ? 'جاري التحقق من الاشتراك المستعاد...'
                  : 'جاري التحقق من الشراء...',
              false,
            );
          }

          final bool valid = await _verifyPurchase(purchaseDetails);
          appleVerified = valid;
          if (valid) {
            if (_onPurchaseSuccess != null) {
              _onPurchaseSuccess!(
                purchaseDetails.purchaseID ??
                    purchaseDetails.transactionDate ??
                    'GP_${DateTime.now().millisecondsSinceEpoch}',
                purchaseDetails.productID,
              );
            }
          } else {
            if (_statusCallback != null) {
              _statusCallback!('فشل التحقق من الشراء', true);
            }
          }
        }

        if (purchaseDetails.pendingCompletePurchase &&
            (!Platform.isIOS ||
                appleVerified ||
                purchaseDetails.status == PurchaseStatus.error ||
                purchaseDetails.status == PurchaseStatus.canceled)) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Verify purchase with our backend
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    if (Platform.isIOS) {
      return _verifyApplePurchase(purchaseDetails);
    }
    if (!_isGooglePlayBillingPlatform) {
      return false;
    }

    try {
      final String userId = await _getCurrentUserId();

      if (userId.isEmpty) {
        print('❌ No user ID found for verification');
        return false;
      }

      print('🌐 Verifying purchase for product: ${purchaseDetails.productID}');

      // Extract verification data
      final verificationData = purchaseDetails.verificationData;

      final response = await http
          .post(
            Uri.parse(
              '${EnvironmentConfig.baseUrl}/mobile/api/payment/verify-google-play',
            ),
            headers: await AuthService.authHeaders(),
            body: jsonEncode({
              'userId': userId,
              'productId': purchaseDetails.productID,
              'purchaseToken': verificationData.serverVerificationData,
              'orderId': purchaseDetails.purchaseID,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Purchase verified successfully');
          if (_statusCallback != null) {
            _statusCallback!('تم التحقق من الشراء بنجاح!', false);
          }
          return true;
        }
      }

      print('❌ Backend Verification Failed: ${response.body}');
      return false;
    } catch (e) {
      print('❌ Verification error: $e');
      return false;
    }
  }

  Future<String> _appleAccountToken() async {
    final response = await http
        .get(
          Uri.parse(
            '${EnvironmentConfig.baseUrl}/mobile/api/payment/apple/context',
          ),
          headers: await AuthService.authHeaders(),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError(
        'تعذر تجهيز شراء أبل؛ تأكد من تسجيل الدخول وإعداد السيرفر',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['appAccountToken'];
    if (data['success'] != true ||
        token is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
        ).hasMatch(token)) {
      throw StateError('بيانات حساب الشراء غير صحيحة');
    }
    return token;
  }

  Future<bool> _verifyApplePurchase(PurchaseDetails purchase) async {
    if (purchase.purchaseID == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse(
              '${EnvironmentConfig.baseUrl}/mobile/api/payment/verify-apple',
            ),
            headers: await AuthService.authHeaders(),
            body: jsonEncode({
              'productId': purchase.productID,
              'transactionId': purchase.purchaseID,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
    } catch (error) {
      // Keep the transaction unfinished so a later restore can retry verification.
      debugPrint('Apple purchase verification is temporarily unavailable.');
    }
    return false;
  }

  // Get current user ID from DatabaseService
  Future<String> _getCurrentUserId() async {
    final user = await DatabaseService.getCurrentUser();
    return user?.id ?? '';
  }
}
