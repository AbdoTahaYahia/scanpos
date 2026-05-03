import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_styles.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_input.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  const AddEditProductScreen({super.key, this.product});
  bool get isEditing => product != null;

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productService = ProductService();
  final _imagePicker = ImagePicker();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _categoryCtrl;

  File? _selectedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name);
    _priceCtrl = TextEditingController(text: widget.product?.price.toString());
    _qtyCtrl = TextEditingController(text: widget.product?.quantityInStock.toString());
    _barcodeCtrl = TextEditingController(text: widget.product?.barcode);
    _categoryCtrl = TextEditingController(text: widget.product?.category);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _barcodeCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _scanBarcode() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _BarcodeScanDialog(),
    );
    if (result != null) _barcodeCtrl.text = result;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final storeId = context.read<AuthProvider>().appUser!.storeId!;
      if (widget.isEditing) {
        final updated = widget.product!.copyWith(
          name: _nameCtrl.text.trim(),
          price: double.parse(_priceCtrl.text.trim()),
          quantityInStock: int.parse(_qtyCtrl.text.trim()),
          barcode: _barcodeCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
        );
        await _productService.updateProduct(updated, newImageFile: _selectedImage);
      } else {
        await _productService.addProduct(
          storeId: storeId,
          name: _nameCtrl.text.trim(),
          price: double.parse(_priceCtrl.text.trim()),
          quantity: int.parse(_qtyCtrl.text.trim()),
          barcode: _barcodeCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
          imageFile: _selectedImage,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_rounded, size: 48, color: AppTheme.black),
            AppStyles.gap16,
            Text('Delete Product?', style: AppTheme.headlineMd),
            AppStyles.gap8,
            Text('"${widget.product!.name}" will be permanently removed.',
                style: AppTheme.bodySm.copyWith(color: AppTheme.onSurfaceVariant), textAlign: TextAlign.center),
            AppStyles.gap24,
            SizedBox(width: double.infinity, child: PillButton(label: 'Delete', onPressed: () => Navigator.of(ctx).pop(true))),
            AppStyles.gap12,
            SizedBox(width: double.infinity, child: PillButton(label: 'Cancel', variant: PillButtonVariant.secondary, onPressed: () => Navigator.of(ctx).pop(false))),
          ]),
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await _productService.deleteProduct(widget.product!.storeId, widget.product!.id);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
              AppStyles.gapW8,
              Text(widget.isEditing ? 'Edit Product' : 'Add Product', style: AppTheme.headlineLg),
              const Spacer(),
              if (widget.isEditing)
                IconButton(icon: const Icon(Icons.delete_rounded), color: AppTheme.error, onPressed: _delete),
            ]),
          ),
          AppStyles.gap16,
          Expanded(
            child: SingleChildScrollView(
              padding: AppStyles.paddingHorizontal,
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Image
                  Center(
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (ctx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text('Add Product Photo', style: AppTheme.headlineMd),
                              AppStyles.gap24,
                              SizedBox(width: double.infinity, child: PillButton(label: 'Take Photo', icon: Icons.camera_alt_rounded, onPressed: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); })),
                              AppStyles.gap12,
                              SizedBox(width: double.infinity, child: PillButton(label: 'Choose from Gallery', icon: Icons.photo_library_rounded, variant: PillButtonVariant.secondary, onPressed: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); })),
                            ]),
                          ),
                        ),
                      ),
                      child: Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.black, width: 2),
                          image: _selectedImage != null
                              ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                              : widget.product?.imageUrl != null
                                  ? DecorationImage(image: NetworkImage(widget.product!.imageUrl!), fit: BoxFit.cover)
                                  : null,
                        ),
                        child: (_selectedImage == null && widget.product?.imageUrl == null)
                            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.camera_alt_rounded, size: 36, color: AppTheme.outline),
                                SizedBox(height: 8),
                                Text('Add Photo', style: TextStyle(color: AppTheme.outline, fontSize: 12, fontWeight: FontWeight.w600)),
                              ])
                            : null,
                      ),
                    ),
                  ),
                  AppStyles.gap24,
                  PillInput(label: 'Product Name', hint: 'e.g. Organic Milk 1L', controller: _nameCtrl, textInputAction: TextInputAction.next, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                  AppStyles.gap16,
                  PillInput(label: 'Price (EGP)', hint: '0.00', controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next, validator: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (double.tryParse(v.trim()) == null) return 'Enter valid price'; return null; }),
                  AppStyles.gap16,
                  PillInput(label: 'Quantity in Stock', hint: '0', controller: _qtyCtrl, keyboardType: TextInputType.number, textInputAction: TextInputAction.next, validator: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (int.tryParse(v.trim()) == null) return 'Enter valid number'; return null; }),
                  AppStyles.gap16,
                  PillInput(label: 'Barcode Number', hint: 'Scan or type barcode', controller: _barcodeCtrl, textInputAction: TextInputAction.next, suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.black), onPressed: _scanBarcode), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                  AppStyles.gap16,
                  PillInput(label: 'Category', hint: 'e.g. Dairy, Beverages', controller: _categoryCtrl, textInputAction: TextInputAction.done, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                  AppStyles.gap32,
                  SizedBox(width: double.infinity, child: PillButton(label: widget.isEditing ? 'Update Product' : 'Add Product', onPressed: _isSaving ? null : _save, isLoading: _isSaving, height: 64)),
                  AppStyles.gap48,
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BarcodeScanDialog extends StatefulWidget {
  @override
  State<_BarcodeScanDialog> createState() => _BarcodeScanDialogState();
}

class _BarcodeScanDialogState extends State<_BarcodeScanDialog> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Scan Barcode', style: AppTheme.headlineMd),
          AppStyles.gap16,
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: SizedBox(height: 250, width: double.infinity, child: MobileScanner(controller: _ctrl, onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull?.rawValue;
              if (barcode != null) { _scanned = true; Navigator.of(context).pop(barcode); }
            })),
          ),
          AppStyles.gap16,
          SizedBox(width: double.infinity, child: PillButton(label: 'Cancel', variant: PillButtonVariant.secondary, onPressed: () => Navigator.of(context).pop())),
        ]),
      ),
    );
  }
}
