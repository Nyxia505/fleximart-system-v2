import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/price_formatter.dart';

class PaymentFlowDialog extends StatefulWidget {
  final String orderId;
  final double amount;

  const PaymentFlowDialog({
    super.key,
    required this.orderId,
    required this.amount,
  });

  @override
  State<PaymentFlowDialog> createState() => _PaymentFlowDialogState();
}

class _PaymentFlowDialogState extends State<PaymentFlowDialog> {
  bool _isProcessing = false;
  String _selectedMethod = 'GCash';

  final List<String> _paymentMethods = ['GCash', 'PayMaya', 'Bank Transfer', 'Cash on Delivery'];

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppColors.mainGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${widget.orderId.substring(0, 8).toUpperCase()}',
                      style: AppTextStyles.heading3(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Amount: ${PriceFormatter.formatPrice(widget.amount)}',
                      style: AppTextStyles.heading2(color: AppColors.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Select Payment Method',
                      style: AppTextStyles.heading3(),
                    ),
                    const SizedBox(height: 12),
                    ..._paymentMethods.map((method) {
                      return RadioListTile<String>(
                        title: Text(method),
                        value: method,
                        groupValue: _selectedMethod,
                        onChanged: (value) {
                          setState(() => _selectedMethod = value!);
                        },
                        activeColor: AppColors.primary,
                      );
                    }),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Proceed to Payment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

