/// Screen 5 — Edit Profile. Avatar with the "Change photo" badge, the
/// Account and Birth Details sections with the design's underline fields,
/// native date/time pickers, gender pills, and the subtle Om note that
/// changing birth time recalculates the chart. Save posts to the backend,
/// which recomputes the chart and regenerates Gemini insights.
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/cosmic_theme.dart';
import '../model/user_profile.dart';
import '../view_model/profile_view_model.dart';

class EditProfileScreen extends HookConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cosmic = context.cosmic;
    final existing = ref.read(profileViewModelProvider).valueOrNull;

    // Hook-managed form state, seeded from the stored profile when editing.
    final name = useTextEditingController(text: existing?.name ?? '');
    final place = useTextEditingController(text: existing?.birthPlace ?? '');
    // TODO(v2): geocode the place name to lat/lon automatically; manual
    // coordinate entry is the v1 compromise.
    final lat = useTextEditingController(text: existing?.lat.toString() ?? '');
    final lon = useTextEditingController(text: existing?.lon.toString() ?? '');
    final tz = useTextEditingController(
        text: (existing?.tzOffset ?? 5.5).toString());
    final dob = useState<String>(existing?.dob ?? '');
    final birthTime = useState<String>(existing?.birthTime ?? '');
    final gender = useState<String?>(existing?.gender);
    final saving = useState(false);

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(dob.value) ?? DateTime(2000),
        firstDate: DateTime(1920),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        dob.value = picked.toIso8601String().substring(0, 10);
      }
    }

    Future<void> pickTime() async {
      final parts = birthTime.value.split(':');
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 12,
          minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
        ),
      );
      if (picked != null) {
        birthTime.value =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      }
    }

    Future<void> save() async {
      // Minimal client-side validation; the backend re-validates and
      // refuses details that can't produce a chart (422).
      if (name.text.trim().isEmpty ||
          dob.value.isEmpty ||
          birthTime.value.isEmpty ||
          place.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please fill name, date, time and place.')),
        );
        return;
      }

      saving.value = true;
      final error = await ref.read(profileViewModelProvider.notifier).save(
            UserProfile(
              name: name.text.trim(),
              dob: dob.value,
              birthTime: birthTime.value,
              birthPlace: place.text.trim(),
              lat: double.tryParse(lat.text) ?? 0,
              lon: double.tryParse(lon.text) ?? 0,
              tzOffset: double.tryParse(tz.text) ?? 5.5,
              gender: gender.value,
            ),
          );
      saving.value = false;

      if (!context.mounted) return;
      if (error == null) {
        context.pop(); // back to the profile with its fresh chart
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          // --- Avatar + "Change photo" badge ---
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: cosmic.gold.withValues(alpha: 0.18),
                  child: Text(
                    name.text.isEmpty ? 'ॐ' : name.text[0].toUpperCase(),
                    style: TextStyle(fontSize: 30, color: cosmic.gold),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {
                      // TODO(v2): image_picker + Firebase Storage upload.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Photo upload coming soon ✨')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cosmic.panel,
                        border: Border.all(color: cosmic.panelBorder),
                      ),
                      child: Icon(Icons.photo_camera_outlined,
                          size: 14, color: cosmic.gold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _SectionLabel('ACCOUNT', cosmic: cosmic),
          const SizedBox(height: 8),
          _Underline(label: 'FULL NAME', controller: name, cosmic: cosmic),
          const SizedBox(height: 24),

          _SectionLabel('BIRTH DETAILS', cosmic: cosmic),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  label: 'DATE OF BIRTH',
                  value: dob.value.isEmpty ? 'Select date' : dob.value,
                  icon: Icons.calendar_today_outlined,
                  cosmic: cosmic,
                  onTap: pickDate,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PickerField(
                  label: 'TIME OF BIRTH',
                  value: birthTime.value.isEmpty ? 'Select time' : birthTime.value,
                  icon: Icons.schedule_outlined,
                  cosmic: cosmic,
                  onTap: pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Underline(
              label: 'PLACE OF BIRTH',
              controller: place,
              cosmic: cosmic,
              hint: 'Jaipur, India'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _Underline(
                      label: 'LATITUDE',
                      controller: lat,
                      cosmic: cosmic,
                      numeric: true)),
              const SizedBox(width: 16),
              Expanded(
                  child: _Underline(
                      label: 'LONGITUDE',
                      controller: lon,
                      cosmic: cosmic,
                      numeric: true)),
              const SizedBox(width: 16),
              Expanded(
                  child: _Underline(
                      label: 'UTC OFFSET',
                      controller: tz,
                      cosmic: cosmic,
                      numeric: true)),
            ],
          ),
          const SizedBox(height: 20),

          // --- Gender pills ---
          _SectionLabel('GENDER', cosmic: cosmic),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final g in const ['Male', 'Female', 'Other']) ...[
                _GenderPill(
                  label: g,
                  selected: gender.value == g,
                  cosmic: cosmic,
                  onTap: () => gender.value = g,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // --- The Om note from the design ---
          Row(
            children: [
              Text('ॐ', style: TextStyle(fontSize: 13, color: cosmic.gold)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Changing your birth time recalculates your entire chart.',
                  style: TextStyle(fontSize: 12, color: cosmic.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Save / Cancel ---
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: saving.value ? null : save,
              style: FilledButton.styleFrom(
                backgroundColor: cosmic.gold,
                foregroundColor: const Color(0xFF2A2110),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
              child: saving.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF2A2110)),
                    )
                  : const Text('Save changes'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: saving.value ? null : () => context.pop(),
              child: Text('Cancel',
                  style: TextStyle(fontSize: 14, color: cosmic.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Field widgets (design's underline style) ----------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.cosmic});

  final String text;
  final CosmicTokens cosmic;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style:
            TextStyle(fontSize: 11, letterSpacing: 2, color: cosmic.muted));
  }
}

class _Underline extends StatelessWidget {
  const _Underline({
    required this.label,
    required this.controller,
    required this.cosmic,
    this.hint,
    this.numeric = false,
  });

  final String label;
  final TextEditingController controller;
  final CosmicTokens cosmic;
  final String? hint;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, letterSpacing: 1.5, color: cosmic.muted)),
        TextField(
          controller: controller,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(
                  decimal: true, signed: true)
              : TextInputType.text,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: cosmic.muted.withValues(alpha: 0.5)),
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cosmic.border)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cosmic.gold)),
          ),
        ),
      ],
    );
  }
}

/// Read-only underline field that opens a native picker.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.cosmic,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final CosmicTokens cosmic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, letterSpacing: 1.5, color: cosmic.muted)),
          Container(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cosmic.border)),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(value, style: const TextStyle(fontSize: 15))),
                Icon(icon, size: 16, color: cosmic.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderPill extends StatelessWidget {
  const _GenderPill({
    required this.label,
    required this.selected,
    required this.cosmic,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final CosmicTokens cosmic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color:
              selected ? cosmic.gold.withValues(alpha: 0.22) : cosmic.surface,
          border:
              Border.all(color: selected ? cosmic.gold : cosmic.border),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 13, color: selected ? cosmic.gold : cosmic.muted),
        ),
      ),
    );
  }
}
