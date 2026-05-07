import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/utils/validators.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/core/widgets/loading_overlay.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/features/sessions/providers/session_provider.dart';
import 'package:daddies_app/services/data_service.dart';

class EditSessionScreen extends StatefulWidget {
  final SessionModel session;

  const EditSessionScreen({super.key, required this.session});

  @override
  State<EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<EditSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _venueController;
  late final TextEditingController _timeStartController;
  late final TextEditingController _timeEndController;
  late final TextEditingController _maxPlayersController;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.session.title);
    _venueController = TextEditingController(text: widget.session.venue);
    _timeStartController = TextEditingController(text: widget.session.timeStart);
    _timeEndController = TextEditingController(text: widget.session.timeEnd);
    _maxPlayersController =
        TextEditingController(text: widget.session.maxPlayers.toString());
    _priceController =
        TextEditingController(text: widget.session.pricePerPlayer.toString());
    _notesController = TextEditingController(text: widget.session.notes ?? '');
    _selectedDate = widget.session.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _timeStartController.dispose();
    _timeEndController.dispose();
    _maxPlayersController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final sessionProv = context.read<SessionProvider>();
    final updated = widget.session.copyWith(
      title: _titleController.text.trim(),
      venue: _venueController.text.trim(),
      date: _selectedDate,
      timeStart: _timeStartController.text.trim(),
      timeEnd: _timeEndController.text.trim(),
      maxPlayers: int.parse(_maxPlayersController.text.trim()),
      pricePerPlayer:
          int.parse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    final success = await sessionProv.updateSession(updated);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      SnackbarHelper.showSuccess(context, 'Sesi berhasil diperbarui');
      Navigator.of(context).pop(true);
    } else {
      SnackbarHelper.showError(
          context, sessionProv.errorMessage ?? 'Gagal memperbarui sesi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Sesi'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: LoadingOverlay(
        isLoading: _isSaving,
        message: 'Menyimpan...',
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Sesi',
                  hintText: 'e.g. Main Sore Jumat',
                ),
                validator: (v) => Validators.required(v, 'Judul'),
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
                validator: (v) => Validators.required(v, 'Venue'),
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
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) {
                      return Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.forestInk,
                            onPrimary: AppColors.agedLinen,
                            surface: AppColors.agedLinen,
                            onSurface: AppColors.deepCharcoal,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    suffixIcon: Icon(Icons.calendar_today,
                        size: 18, color: AppColors.mossAccent),
                  ),
                  child: Text(
                    DateFormat('EEEE, d MMM yyyy', 'id_ID')
                        .format(_selectedDate),
                    style: const TextStyle(
                      color: AppColors.deepCharcoal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _timeStartController,
                      decoration: const InputDecoration(
                        labelText: 'Mulai',
                        hintText: '19:00',
                      ),
                      validator: Validators.timeFormat,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _timeEndController,
                      decoration: const InputDecoration(
                        labelText: 'Selesai',
                        hintText: '21:00',
                      ),
                      validator: Validators.timeFormat,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Max players & price row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxPlayersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maks Pemain',
                      ),
                      validator: Validators.maxPlayers,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga/Orang',
                        hintText: '150000',
                      ),
                      validator: Validators.price,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestInk,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Simpan Perubahan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
