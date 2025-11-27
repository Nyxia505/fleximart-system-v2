import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/quotation_model.dart';
import '../services/quotation_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/price_formatter.dart';

/// Staff Quotation Price Screen
/// 
/// Allows staff/admin to:
/// - View all quotation details
/// - Enter estimatedPrice (double)
/// - Enter priceNote (string)
/// - Mark status = "done"
/// - Save updates to Firestore
/// - Auto-update updatedAt
/// - Send notification to customer
class StaffQuotationPriceScreen extends StatefulWidget {
  final String quotationId;

  const StaffQuotationPriceScreen({
    super.key,
    required this.quotationId,
  });

  @override
  State<StaffQuotationPriceScreen> createState() => _StaffQuotationPriceScreenState();
}

class _StaffQuotationPriceScreenState extends State<StaffQuotationPriceScreen> {
  final QuotationService _quotationService = QuotationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _priceNoteController = TextEditingController();
  
  bool _isLoading = false;
  bool _markAsDone = false;
  Quotation? _quotation;

  @override
  void initState() {
    super.initState();
    _loadQuotation();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _priceNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadQuotation() async {
    setState(() => _isLoading = true);
    try {
      final quotation = await _quotationService.getQuotationById(widget.quotationId);
      if (quotation != null) {
        setState(() {
          _quotation = quotation;
          if (quotation.estimatedPrice != null) {
            _priceController.text = PriceFormatter.formatPriceOnly(quotation.estimatedPrice!);
          }
          if (quotation.priceNote != null) {
            _priceNoteController.text = quotation.priceNote!;
          }
          _markAsDone = quotation.status.toLowerCase() == 'done';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading quotation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final estimatedPrice = double.tryParse(_priceController.text.trim());
      final priceNote = _priceNoteController.text.trim();

      await _quotationService.updateQuotationPrice(
        quotationId: widget.quotationId,
        estimatedPrice: estimatedPrice,
        priceNote: priceNote.isEmpty ? null : priceNote,
        markAsDone: _markAsDone,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotation updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating quotation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _quotation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quotation Pricing'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_quotation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quotation Pricing'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'Quotation not found',
            style: AppTextStyles.heading3(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quotation Pricing'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.mainGradient,
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quotation Details Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quotation Details',
                        style: AppTextStyles.heading2(),
                      ),
                      const Divider(),
                      _buildDetailRow('Customer', _quotation!.customerName ?? 'N/A'),
                      if (_quotation!.customerEmail != null)
                        _buildDetailRow('Email', _quotation!.customerEmail!),
                      if (_quotation!.productName != null)
                        _buildDetailRow('Product', _quotation!.productName!),
                      if (_quotation!.productId != null)
                        _buildDetailRow('Product ID', _quotation!.productId!),
                      if (_quotation!.length != null || _quotation!.width != null)
                        _buildDetailRow(
                          'Size',
                          '${_quotation!.length ?? 0}" × ${_quotation!.width ?? 0}"',
                        ),
                      if (_quotation!.glassType != null)
                        _buildDetailRow('Glass Type', _quotation!.glassType!),
                      if (_quotation!.aluminumType != null)
                        _buildDetailRow('Aluminum Type', _quotation!.aluminumType!),
                      if (_quotation!.notes != null && _quotation!.notes!.isNotEmpty)
                        _buildDetailRow('Notes', _quotation!.notes!),
                      _buildDetailRow('Status', _quotation!.status.toUpperCase()),
                      _buildDetailRow('Created', _formatDate(_quotation!.createdAt)),
                      if (_quotation!.updatedAt != null)
                        _buildDetailRow('Last Updated', _formatDate(_quotation!.updatedAt)),
                    ],
                  ),
                ),
              ),
              // Uploaded Reference Image
              if (_quotation!.imageUrl != null && _quotation!.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reference Image',
                          style: AppTextStyles.heading2(),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _quotation!.imageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey[400],
                                      size: 48,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Failed to load image',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Pricing Form Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pricing Information',
                        style: AppTextStyles.heading2(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Estimated Price (₱)',
                          hintText: 'Enter price',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter estimated price';
                          }
                          final price = double.tryParse(value.trim());
                          if (price == null || price <= 0) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceNoteController,
                        decoration: InputDecoration(
                          labelText: 'Price Note (Optional)',
                          hintText: 'Enter any notes about the pricing',
                          prefixIcon: const Icon(Icons.note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Mark as Done'),
                        subtitle: const Text('Set status to "done" after saving'),
                        value: _markAsDone,
                        onChanged: (value) {
                          setState(() => _markAsDone = value ?? false);
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveQuotation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Save Quotation',
                          style: AppTextStyles.buttonLarge(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.caption(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium(),
            ),
          ),
        ],
      ),
    );
  }
}

