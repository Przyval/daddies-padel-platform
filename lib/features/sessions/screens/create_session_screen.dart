import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/widgets/success_overlay.dart';
import 'package:daddies_app/core/utils/haptic_helper.dart';
import 'package:daddies_app/features/auth/providers/auth_provider.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/services/data_service.dart';

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _venueController = TextEditingController();
  final _maxPlayersController = TextEditingController(text: '8');
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  int? _selectedCourt;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _timeStart = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _timeEnd = const TimeOfDay(hour: 19, minute: 0);

  bool _isSubmitting = false;

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // ---------------------------------------------------------------------------
  // Template data
  // ---------------------------------------------------------------------------

  static const List<_SessionTemplate> _templates = [
    _SessionTemplate(
      name: 'Jumat Sore',
      venue: 'Genesis Padel',
      timeStart: TimeOfDay(hour: 17, minute: 0),
      timeEnd: TimeOfDay(hour: 19, minute: 0),
      maxPlayers: 8,
      pricePerPlayer: 150000,
    ),
    _SessionTemplate(
      name: 'Sabtu Pagi',
      venue: 'Padel Haus BSD',
      timeStart: TimeOfDay(hour: 8, minute: 0),
      timeEnd: TimeOfDay(hour: 10, minute: 0),
      maxPlayers: 8,
      pricePerPlayer: 175000,
    ),
    _SessionTemplate(
      name: 'Minggu Siang',
      venue: 'The Padel Club PIK',
      timeStart: TimeOfDay(hour: 10, minute: 0),
      timeEnd: TimeOfDay(hour: 12, minute: 0),
      maxPlayers: 4,
      pricePerPlayer: 200000,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _maxPlayersController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Template action
  // ---------------------------------------------------------------------------

  void _applyTemplate(_SessionTemplate template) {
    setState(() {
      _titleController.text = template.name;
      _venueController.text = template.venue;
      _timeStart = template.timeStart;
      _timeEnd = template.timeEnd;
      _maxPlayersController.text = template.maxPlayers.toString();
      _priceController.text = template.pricePerPlayer.toString();
    });
  }

  // ---------------------------------------------------------------------------
  // Date / time pickers
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.forestInk,
                  onPrimary: AppColors.textOnPrimary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTimeStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeStart,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.forestInk,
                  onPrimary: AppColors.textOnPrimary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _timeStart = picked);
    }
  }

  Future<void> _pickTimeEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeEnd,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.forestInk,
                  onPrimary: AppColors.textOnPrimary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _timeEnd = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final sessionProvider = context.read<SessionProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final maxPlayers = int.tryParse(_maxPlayersController.text.trim());
    final price = int.tryParse(
      _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );

    if (maxPlayers == null || maxPlayers <= 0) return;
    if (price == null || price <= 0) return;

    // Validate timeEnd > timeStart
    final startMinutes = _timeStart.hour * 60 + _timeStart.minute;
    final endMinutes = _timeEnd.hour * 60 + _timeEnd.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam selesai harus lebih dari jam mulai')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final timeStartStr =
        '${_timeStart.hour.toString().padLeft(2, '0')}:${_timeStart.minute.toString().padLeft(2, '0')}';
    final timeEndStr =
        '${_timeEnd.hour.toString().padLeft(2, '0')}:${_timeEnd.minute.toString().padLeft(2, '0')}';

    try {
      final success = await sessionProvider.createSession(
        title: _titleController.text.trim(),
        venue: _venueController.text.trim(),
        date: _selectedDate,
        timeStart: timeStartStr,
        timeEnd: timeEndStr,
        maxPlayers: maxPlayers,
        pricePerPlayer: price,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        courtNumber: _selectedCourt,
      );
      if (!success) throw Exception(sessionProvider.errorMessage);

      if (!mounted) return;

      HapticHelper.success();
      SuccessOverlay.show(context, message: 'Sesi berhasil dibuat!');
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat sesi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Sesi Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -- Template Cepat section ------------------------------------
            _buildSectionHeader('Template Cepat'),
            const SizedBox(height: 12),
            _buildTemplateRow(),
            const SizedBox(height: 24),

            // -- Divider with "atau isi manual" ----------------------------
            _buildDividerWithLabel('atau isi manual'),
            const SizedBox(height: 24),

            // -- Form fields -----------------------------------------------
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Sesi',
                      hintText: 'Contoh: Jumat Sore',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Masukkan judul sesi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Venue
                  TextFormField(
                    controller: _venueController,
                    decoration: const InputDecoration(
                      labelText: 'Venue',
                      hintText: 'Pilih atau ketik venue baru',
                      suffixIcon: Icon(Icons.location_on_outlined, size: 20),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Masukkan nama venue';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: DataService().venues.map((v) {
                      final isSelected = _venueController.text == v.name;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _venueController.text = v.name;
                        }),
                        child: Chip(
                          label: Text(v.name),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.agedLinen
                                : AppColors.forestInk,
                          ),
                          backgroundColor: isSelected
                              ? AppColors.forestInk
                              : AppColors.forestInk.withValues(alpha: 0.08),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.forestInk
                                : AppColors.forestInk.withValues(alpha: 0.15),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      hintText: 'Contoh: Bawa bola sendiri',
                      suffixIcon: Icon(Icons.sticky_note_2_outlined, size: 20),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),

                  // Date picker
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Tanggal',
                          hintText: 'Pilih tanggal',
                          suffixIcon: const Icon(Icons.calendar_today, size: 20),
                        ),
                        controller: TextEditingController(
                          text: DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                              .format(_selectedDate),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time Start + Time End
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickTimeStart,
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Jam Mulai',
                                suffixIcon:
                                    const Icon(Icons.access_time, size: 20),
                              ),
                              controller: TextEditingController(
                                text: _formatTimeOfDay(_timeStart),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickTimeEnd,
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Jam Selesai',
                                suffixIcon:
                                    const Icon(Icons.access_time, size: 20),
                              ),
                              controller: TextEditingController(
                                text: _formatTimeOfDay(_timeEnd),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Max Players + Price per Player
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _maxPlayersController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maks Pemain',
                            hintText: '8',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Wajib diisi';
                            }
                            final parsed = int.tryParse(value.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Harus > 0';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga / Pemain (Rp)',
                            hintText: '150000',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Wajib diisi';
                            }
                            final parsed = int.tryParse(
                              value.replaceAll(RegExp(r'[^0-9]'), ''),
                            );
                            if (parsed == null || parsed <= 0) {
                              return 'Harus > 0';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Publish button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forestInk,
                        foregroundColor: AppColors.textOnPrimary,
                        disabledBackgroundColor:
                            AppColors.forestInk.withValues(alpha: 0.5),
                        shape: const StadiumBorder(),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.textOnPrimary),
                              ),
                            )
                          : const Text(
                              'Publish Sesi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section header
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.deepCharcoal,
        letterSpacing: -0.3,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Template row
  // ---------------------------------------------------------------------------

  Widget _buildTemplateRow() {
    return Row(
      children: _templates.map((template) {
        final index = _templates.indexOf(template);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 5,
              right: index == _templates.length - 1 ? 0 : 5,
            ),
            child: _buildTemplateCard(template),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTemplateCard(_SessionTemplate template) {
    return GestureDetector(
      onTap: () => _applyTemplate(template),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.mossAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sports_tennis,
                color: AppColors.mossAccent,
                size: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              template.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              template.venue,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${_formatTimeOfDay(template.timeStart)} - ${_formatTimeOfDay(template.timeEnd)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${template.maxPlayers} pemain',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _currencyFormat.format(template.pricePerPlayer),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.forestInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Divider with label
  // ---------------------------------------------------------------------------

  Widget _buildDividerWithLabel(String label) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }
}

// =============================================================================
// Session template data class
// =============================================================================

class _SessionTemplate {
  final String name;
  final String venue;
  final TimeOfDay timeStart;
  final TimeOfDay timeEnd;
  final int maxPlayers;
  final int pricePerPlayer;

  const _SessionTemplate({
    required this.name,
    required this.venue,
    required this.timeStart,
    required this.timeEnd,
    required this.maxPlayers,
    required this.pricePerPlayer,
  });
}
