// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/features/auth/providers/auth_notifier_provider.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneController = useTextEditingController(text: '+1');
    final authState = ref.watch(authNotifierProvider);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // SnackBar'ları dinle
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      // Başarı: sadece false -> true geçişinde yönlendir
      final bool becameAuthenticated =
          (previous?.isAuthenticated == false) &&
          (next.isAuthenticated == true) &&
          (next.isLoading == false) &&
          (next.errorMessage == null);

      // Başarı yönlendirmesini submitLogin içinde yapıyoruz. Burada yalnızca opsiyonel olarak info gösterilebilir.
      // Navigation kaldırıldı ki istenmeyen yönlendirmeler olmasın.
      if (becameAuthenticated) {
        // İstersen burada sadece log bırakabilirsin.
      }

      // Hata: yeni bir hata oluştuğunda göster
      final bool gotNewError =
          next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage;
      if (gotNewError) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    });

    String? validatePhoneNumber(String? value) {
      if (value == null || value.isEmpty) {
        return 'Telefon numarası boş olamaz';
      }
      // ABD formatı için daha spesifik regex (isteğe bağlı)
      // Örn: +1 ile başlar, 10 rakam takip eder: RegExp(r'^\+1\d{10}$')
      final phoneRegex = RegExp(r'^\+\d{10,}$'); // Genel + ve en az 10 rakam
      if (!phoneRegex.hasMatch(value)) {
        return 'Geçersiz format (Örn: +1XXXXXXXXXX)';
      }
      return null; // Geçerli
    }

    // "Giriş Yap" fonksiyonu (async)
    Future<void> submitLogin() async {
      if (!(formKey.currentState?.validate() ?? false) || authState.isLoading) {
        return;
      }
      final ok = await ref
          .read(authNotifierProvider.notifier)
          .login(phoneNumber: phoneController.text.trim());
      if (!context.mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Giriş başarılı!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Giriş Yap / Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Telefon numaran ile giriş yap.',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefon Numarası',
                  hintText: '+15551234567',
                  border: const OutlineInputBorder(),
                  // Hata mesajını state'ten oku (SnackBar'a ek olarak)
                  errorText: authState.errorMessage,
                ),
                keyboardType: TextInputType.phone,
                validator: validatePhoneNumber,
                enabled: !authState.isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) {
                  // Kullanıcı yazarken hatayı temizle
                  ref.read(authNotifierProvider.notifier).clearError();
                },
              ),
              const SizedBox(height: 20),

              // Giriş Butonu
              if (authState.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  // Yüklenmiyorsa submitLogin'i çağır
                  onPressed: authState.isLoading ? null : submitLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Devam Et'),
                ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: authState.isLoading
                    ? null
                    : () {
                        ref.read(authNotifierProvider.notifier).clearError();
                        context.go('/register');
                      },
                child: const Text('Hesabın yok mu? Kayıt Ol'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
