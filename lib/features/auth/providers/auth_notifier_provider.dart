// lib/features/auth/providers/auth_notifier_provider.dart
import 'package:flutter/foundation.dart'; // @immutable için
import 'package:flutter_baab_sport_field_app/features/auth/repositories/auth_repository.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // <-- JWT Decoder'ı import et
import 'package:flutter_baab_sport_field_app/models/user.dart'; // <-- User modelini import et

// 1. Yeni State Sınıfımız
@immutable // State'in değişmez olmasını sağlamak için
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated; // Eski AuthStatus yerine
  final User? currentUser; // <-- YENİ ALAN: Giriş yapmış kullanıcı

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false, // Varsayılan olarak giriş yapmamış
    this.currentUser, // <-- Constructor'a ekle
  });

  // State'i kopyalayıp güncellemek için yardımcı metot
  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
    ValueGetter<User?>? currentUser, // <-- Nullable User için ValueGetter
    bool clearError = false, // Hata mesajını temizlemek için flag
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      // clearError true ise null yap, değilse yeni değeri veya eski değeri kullan
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentUser: currentUser != null
          ? currentUser()
          : this.currentUser, // <-- Güncelle
    );
  }

  // Eşitlik kontrolü ve toString (debugging için iyi)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage &&
          isAuthenticated == other.isAuthenticated &&
          currentUser == other.currentUser;

  @override
  int get hashCode =>
      isLoading.hashCode ^
      errorMessage.hashCode ^
      isAuthenticated.hashCode ^
      currentUser.hashCode;

  @override
  String toString() {
    return 'AuthState{isLoading: $isLoading, errorMessage: $errorMessage, isAuthenticated: $isAuthenticated, currentUser: $currentUser}';
  }
}

// 2. Notifier'ı yeni state'i kullanacak şekilde güncelle
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState(isLoading: true)) {
    // Başlangıçta yükleniyor (token kontrolü için)
    checkAuthStatus();
  }

  // Mevcut kullanıcıyı backend'den tazeleyip state'e yazar
  Future<void> refreshCurrentUser() async {
    try {
      final user = await _authRepository.getCurrentUserDetails();
      if (mounted) {
        state = state.copyWith(currentUser: () => user);
      }
    } catch (e) {
      // Sessiz geç: UI çalışmaya devam etsin
      debugPrint('refreshCurrentUser failed: $e');
    }
  }

  void updateCurrentUser(User user) {
    if (mounted) {
      state = state.copyWith(currentUser: () => user);
    }
  }

  // Kullanıcı ID'sini token'dan çıkaran helper metot
  String? _getUserIdFromToken(String token) {
    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      // Backend'de 'sub' claim'ini user ID olarak ayarlamıştık
      return decodedToken['sub'] as String?;
    } catch (e) {
      print("Token decode error: $e");
      return null;
    }
  }

  void clearError() {
    if (!mounted) return;
    if (state.errorMessage == null) return; // No change -> no notify
    state = state.copyWith(clearError: true);
  }

  Future<void> checkAuthStatus() async {
    final token = await _authRepository.getToken();
    User? fetchedUser; // Nullable User
    String? userId = (token != null) ? _getUserIdFromToken(token) : null;
    bool isAuth = false;

    if (userId != null) {
      isAuth = true;
      // Gerçek kullanıcı detaylarını backend'den çek
      try {
        fetchedUser = await _authRepository.getCurrentUserDetails();
      } catch (e) {
        // Hata olursa minimal placeholder oluştur (uygulama çalışmaya devam etsin)
        fetchedUser = User(
          id: userId,
          phoneNumber: '',
          fullName: '',
          createdAt: DateTime.now(),
        );
      }
    }

    if (mounted) {
      state = AuthState(
        isAuthenticated: isAuth,
        isLoading: false,
        currentUser: fetchedUser, // State'e User'ı (veya null) ata
      );
    }
  }

  // --- GÜNCELLENMİŞ LOGIN FONKSİYONU ---
  Future<bool> login({required String phoneNumber}) async {
    // Yeni giriş denemesinde hatayı temizle, yükleniyor yap ve geçici olarak unauthenticated yap
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentUser: () => null,
    ); // Kullanıcıyı temizle
    try {
      await _authRepository.login(phoneNumber: phoneNumber);
      // Başarı sonrası token'ı tekrar oku ve kullanıcıyı state'e ekle
      final token = await _authRepository.getToken();
      User? loggedInUser;
      String? userId = (token != null) ? _getUserIdFromToken(token) : null;
      if (userId != null) {
        // Gerçek kullanıcı detaylarını çek
        try {
          loggedInUser = await _authRepository.getCurrentUserDetails();
        } catch (e) {
          // Hata olursa minimum bilgilerle placeholder oluştur
          loggedInUser = User(
            id: userId,
            phoneNumber: phoneNumber,
            fullName: '',
            createdAt: DateTime.now(),
          );
        }
      }
      if (mounted) {
        state = state.copyWith(
          isAuthenticated: loggedInUser != null,
          isLoading: false,
          currentUser: () => loggedInUser, // State'e kullanıcıyı ekle
        );
      }
      return loggedInUser != null;
    } catch (e) {
      // HATA DURUMU
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false, // Başarısız olduğu için false
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
      debugPrint('Login hatası: ${state.errorMessage}');
      return false; // Başarısızlığı bildir
    }
  }

  // --- GÜNCELLENMİŞ REGISTER FONKSİYONU ---
  Future<bool> register({
    // Artık bool döndürüyor
    required String phoneNumber,
    required String fullName,
    String? birthDate,
    String? city,
    String? userState,
    String? zipCode,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentUser: () => null,
    );
    try {
      await _authRepository.register(
        phoneNumber: phoneNumber,
        fullName: fullName,
        birthDate: birthDate,
        city: city,
        state: userState,
        zipCode: zipCode,
      );
      // SADECE BAŞARILI OLURSA authenticated yap
      // (Register içindeki login de başarılıysa burası çalışır)
      final token = await _authRepository.getToken();
      User? registeredUser;
      String? userId = (token != null) ? _getUserIdFromToken(token) : null;
      if (userId != null) {
        // TODO: Tam User nesnesini çek
        registeredUser = User(
          id: userId,
          phoneNumber: phoneNumber,
          fullName: fullName,
          createdAt: DateTime.now(),
        );
      }

      if (mounted) {
        state = state.copyWith(
          isAuthenticated: registeredUser != null,
          isLoading: false,
          currentUser: () => registeredUser,
        );
      }
      return registeredUser != null;
    } catch (e) {
      // HATA DURUMU
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        );
      }
      debugPrint('Register hatası: ${state.errorMessage}');
      return false; // Başarısızlığı bildir
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    if (mounted) {
      state = const AuthState(
        isAuthenticated: false,
        isLoading: false,
        currentUser: null,
      );
    }
  }
}

// 3. Provider'ı yeni state tipiyle güncelle
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});
