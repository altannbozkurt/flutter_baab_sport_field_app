// lib/features/profile/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_baab_sport_field_app/features/auth/providers/auth_notifier_provider.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart'; // Doğum tarihi formatlama için
import 'package:flutter_baab_sport_field_app/features/profile/repositories/profile_repository.dart'; // Repository'yi çağırmak için
import 'package:flutter_baab_sport_field_app/features/profile/providers/profile_provider.dart'; // Mevcut profili almak için
// TODO: ProfileRepository (güncelleme için)

// TODO: Profile Update Notifier (state yönetimi için)
import 'package:flutter_baab_sport_field_app/models/user.dart';

// Düzenlenebilir alanlar için seçenekler
const List<String> footOptions = ['right', 'left', 'both'];
const List<String> positionOptions = [
  'forward',
  'midfielder',
  'defender',
  'goalkeeper',
];

class EditProfileScreen extends HookConsumerWidget {
  final User? initialUser;
  const EditProfileScreen({super.key, this.initialUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mevcut profil verisini al (kendi profilimiz olduğunu varsayıyoruz)
    // Dikkat: userProfileByIdProvider User döndürür, userProfileProvider PlayerProfile
    // İkisini birleştiren veya sadece User döndüren bir provider daha iyi olabilir.
    // Şimdilik userProfileByIdProvider'ı kendi ID'mizle çağıralım.
    final currentUser = ref.watch(authNotifierProvider).currentUser;
    final profileAsyncValue = currentUser != null
        ? ref.watch(userProfileByIdProvider(currentUser.id))
        : const AsyncValue<User>.error(
            "Kullanıcı bulunamadı",
            StackTrace.empty,
          );

    // Form anahtarı
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Controller'ları initialUser verisiyle BAŞLATMAK için useEffect kullan
    // Sadece widget ilk oluşturulduğunda çalışır
    final nameController = useTextEditingController(
      text: initialUser?.fullName,
    );
    final cityController = useTextEditingController(
      text: initialUser?.city ?? '',
    );
    final stateController = useTextEditingController(
      text: initialUser?.state ?? '',
    );
    final zipCodeController = useTextEditingController(
      text: initialUser?.zipCode ?? '',
    );
    final imageUrlController = useTextEditingController(
      text: initialUser?.profileImageUrl ?? '',
    );
    final birthDate = useState<DateTime?>(
      initialUser?.birthDate,
    ); // DateTime olarak tutalım

    // Dropdownlar için state'ler (initial değerlerle)
    String? normalizeFoot(String? v) {
      final s = v?.toLowerCase();
      if (s == null) return null;
      if (s == 'sol' || s == 'left') return 'left';
      if (s == 'sağ' || s == 'sag' || s == 'right') return 'right';
      if (s == 'both' || s == 'ikisi' || s == 'iki') return 'both';
      return null;
    }

    String toFootLabel(String? v) {
      switch (v) {
        case 'left':
          return 'Sol';
        case 'right':
          return 'Sağ';
        case 'both':
          return 'İki Ayak';
        default:
          return 'Seçilmedi';
      }
    }

    String? mapFootOutbound(String? v) {
      switch (v) {
        case 'left':
          return 'left';
        case 'right':
          return 'right';
        case 'both':
          return 'both';
        default:
          return null;
      }
    }

    final selectedFoot = useState<String?>(
      normalizeFoot(initialUser?.playerProfile?.preferredFoot),
    );
    final selectedPosition = useState<String?>(
      initialUser?.playerProfile?.preferredPosition,
    );

    // Yüklenme ve Hata state'i (güncelleme işlemi için)
    final isUpdating = useState(false);
    final errorText = useState<String?>(null);

    // Doğum tarihi seçici
    Future<void> _selectBirthDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: birthDate.value ?? DateTime(2000), // Varsayılan başlangıç
        firstDate: DateTime(1920), // Makul bir alt sınır
        lastDate: DateTime.now().subtract(
          const Duration(days: 365 * 10),
        ), // En az 10 yaşında olmalı?
      );
      if (picked != null && picked != birthDate.value) {
        birthDate.value = picked;
      }
    }

    // Kaydetme fonksiyonu
    void submitUpdateProfile() async {
      if (isUpdating.value || !(formKey.currentState?.validate() ?? false)) {
        return;
      }

      if (!context.mounted) return;
      isUpdating.value = true;
      errorText.value = null;

      // Backend'e gönderilecek veriyi oluştur (sadece değişenleri göndermek daha iyi olur ama şimdilik hepsini gönderelim)
      final Map<String, dynamic> updateData = {
        'full_name': nameController.text.trim(),
        'birth_date': birthDate.value != null
            ? DateFormat('yyyy-MM-dd').format(birthDate.value!)
            : null,
        'city': cityController.text.trim().isEmpty
            ? null
            : cityController.text.trim(),
        'state': stateController.text.trim().isEmpty
            ? null
            : stateController.text.trim(),
        'zip_code': zipCodeController.text.trim().isEmpty
            ? null
            : zipCodeController.text.trim(),
        'profile_image_url': imageUrlController.text.trim().isEmpty
            ? null
            : imageUrlController.text.trim(),
        'preferred_foot': mapFootOutbound(selectedFoot.value),
        'preferred_position': selectedPosition.value,
      };
      // Null değerleri Map'ten temizleyelim (Backend DTO'su @IsOptional olduğu için)
      updateData.removeWhere((key, value) => value == null);

      try {
        // Repository'yi çağır (Repository'ye updateMyProfile ekleyeceğiz)
        final updatedUser = await ref
            .read(profileRepositoryProvider)
            .updateMyProfile(updateData);

        // AuthNotifier'daki currentUser'ı güncelle (opsiyonel ama iyi olur)
        ref.read(authNotifierProvider.notifier).updateCurrentUser(updatedUser);

        // ProfileScreen'deki provider'ları yenile
        ref.invalidate(
          userProfileByIdProvider(updatedUser.id),
        ); // Kendi profilimizi yenile
        // Eğer sadece PlayerProfile dönen provider varsa onu da yenile:
        // ref.invalidate(userProfileProvider);

        if (!context.mounted) return;
        context.pop(); // Geri git (ProfileScreen'e)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        final errorMessage = e.toString().replaceFirst("Exception: ", "");
        errorText.value = errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $errorMessage"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } finally {
        if (!context.mounted) return;
        isUpdating.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profili Düzenle')),
      body: profileAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text("Profil yüklenemedi: $err")),
        data: (user) {
          // PlayerProfile null olamaz (Backend'den User ile gelmeli)
          final profile = user.playerProfile;
          if (profile == null)
            return const Center(child: Text('Oyuncu Profili verisi eksik.'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Form Alanları ---
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'İsim Soyisim *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'İsim boş olamaz' : null,
                    enabled: !isUpdating.value,
                  ),
                  const SizedBox(height: 16),
                  // TODO: Doğum tarihi seçici
                  TextFormField(
                    controller: cityController,
                    decoration: const InputDecoration(
                      labelText: 'Şehir',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isUpdating.value,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    // Eyalet ve Posta Kodu yan yana
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: stateController,
                          decoration: const InputDecoration(
                            labelText: 'Eyalet',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isUpdating.value,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: zipCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Posta Kodu',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            // Opsiyonel ama girildiyse format kontrolü
                            if (value != null && value.isNotEmpty) {
                              final zipRegex = RegExp(r'^\d{5}$');
                              if (!zipRegex.hasMatch(value))
                                return '5 haneli olmalı';
                            }
                            return null;
                          },
                          enabled: !isUpdating.value,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Profil Resmi URL',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    enabled: !isUpdating.value,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: selectedFoot.value,
                    decoration: const InputDecoration(
                      labelText: 'Tercih Edilen Ayak',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Seçilmedi'),
                      ), // Null seçeneği
                      ...['left', 'right', 'both'].map(
                        (foot) => DropdownMenuItem(
                          value: foot,
                          child: Text(toFootLabel(foot)),
                        ),
                      ),
                    ],
                    onChanged: isUpdating.value
                        ? null
                        : (value) => selectedFoot.value = value,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: selectedPosition.value,
                    decoration: const InputDecoration(
                      labelText: 'Tercih Edilen Pozisyon',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Seçilmedi'),
                      ), // Null seçeneği
                      ...positionOptions.map(
                        (pos) => DropdownMenuItem(value: pos, child: Text(pos)),
                      ),
                    ],
                    onChanged: isUpdating.value
                        ? null
                        : (value) => selectedPosition.value = value,
                  ),

                  const SizedBox(height: 24),
                  // Genel Hata Mesajı
                  if (errorText.value != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(errorText.value! /*...*/),
                    ),

                  // Kaydet Butonu
                  if (isUpdating.value)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: isUpdating.value ? null : submitUpdateProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('Değişiklikleri Kaydet'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
