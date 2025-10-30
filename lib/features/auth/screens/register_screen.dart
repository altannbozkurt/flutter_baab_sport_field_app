// lib/features/auth/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/features/auth/providers/auth_notifier_provider.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneController = useTextEditingController(text: '+1');
    final nameController = useTextEditingController();
    final stateController = useTextEditingController();
    final zipCodeController = useTextEditingController();

    final authState = ref.watch(authNotifierProvider);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // SnackBar'ları dinle
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      // Başarı SnackBar'ı ve yönlendirme
      if (previous?.isLoading == true &&
          !next.isLoading &&
          next.isAuthenticated &&
          next.errorMessage == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarılı! Giriş yapıldı.'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/');
        }
      }
      // Hata SnackBar'ı
      if (next.errorMessage != null && previous?.errorMessage == null) {
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

    // Validator fonksiyonları
    String? validatePhoneNumber(String? value) {
      if (value == null || value.isEmpty) return 'Telefon numarası zorunludur';
      final phoneRegex = RegExp(r'^\+\d{10,}$');
      if (!phoneRegex.hasMatch(value))
        return 'Geçersiz format (Örn: +1XXXXXXXXXX)';
      return null;
    }

    String? validateName(String? value) {
      if (value == null || value.isEmpty) return 'İsim Soyisim zorunludur';
      return null;
    }

    String? validateZipCode(String? value) {
      if (value != null && value.isNotEmpty) {
        final zipRegex = RegExp(r'^\d{5}$');
        if (!zipRegex.hasMatch(value))
          return 'Geçersiz posta kodu formatı (5 haneli)';
      }
      return null;
    }

    // "Hesap Oluştur" fonksiyonu (async değil)
    void submitRegister() async {
      if (!(formKey.currentState?.validate() ?? false) || authState.isLoading) {
        return;
      }
      await ref
          .read(authNotifierProvider.notifier)
          .register(
            phoneNumber: phoneController.text.trim(),
            fullName: nameController.text.trim(),
            userState: stateController.text.trim().isNotEmpty
                ? stateController.text.trim()
                : null,
            zipCode: zipCodeController.text.trim().isNotEmpty
                ? zipCodeController.text.trim()
                : null,
          );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Hesap Oluştur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Telefon Numarası
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Telefon Numarası (Zorunlu)',
                  hintText: '+15551234567',
                  border: const OutlineInputBorder(),
                  // Telefonla ilgili backend hatasını göster
                  errorText:
                      authState.errorMessage?.contains('telefon numarası') ??
                          false
                      ? authState.errorMessage
                      : null,
                ),
                keyboardType: TextInputType.phone,
                validator: validatePhoneNumber,
                enabled: !authState.isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),

              // İsim Soyisim
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'İsim Soyisim (Zorunlu)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.name,
                validator: validateName,
                enabled: !authState.isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),

              // Eyalet
              TextFormField(
                controller: stateController,
                decoration: const InputDecoration(
                  labelText: 'Eyalet (Opsiyonel)',
                  hintText: 'PA',
                  border: OutlineInputBorder(),
                ),
                enabled: !authState.isLoading,
              ),
              const SizedBox(height: 16),

              // Posta Kodu
              TextFormField(
                controller: zipCodeController,
                decoration: InputDecoration(
                  labelText: 'Posta Kodu (Opsiyonel)',
                  hintText: '15213',
                  border: const OutlineInputBorder(),
                  // Posta koduyla ilgili backend hatasını göster
                  errorText:
                      authState.errorMessage?.contains('postal code') ?? false
                      ? authState.errorMessage
                      : null,
                ),
                keyboardType: TextInputType.number,
                validator: validateZipCode,
                enabled: !authState.isLoading,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 24),

              // Genel Hata (Eğer spesifik alanla ilgili değilse ve SnackBar'a ek olarak)
              if (authState.errorMessage != null &&
                  !(authState.errorMessage?.contains('telefon numarası') ??
                      false) &&
                  !(authState.errorMessage?.contains('postal code') ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    authState.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Kayıt Ol Butonu
              if (authState.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: authState.isLoading ? null : submitRegister,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Hesap Oluştur'),
                ),

              // Giriş Ekranına Geri Dön
              TextButton(
                onPressed: authState.isLoading
                    ? null
                    : () {
                        ref.read(authNotifierProvider.notifier).clearError();
                        context.go('/login');
                      },
                child: const Text('Zaten bir hesabın var mı? Giriş Yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
