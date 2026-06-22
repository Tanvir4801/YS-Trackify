import '../../models/payment.dart';
import '../hive_service.dart';

class PaymentService {
  PaymentService({required HiveService hiveService})
      : _hiveService = hiveService;

  final HiveService _hiveService;

  List<Payment> getPaymentsForLabour(String labourId) {
    return _hiveService.getPaymentsForLabour(labourId);
  }

  Future<void> recordPayment({
    required String labourId,
    required double amount,
    required String date,
  }) async {
    final payment = Payment(
      id: _generateId(),
      labourId: labourId,
      amount: amount,
      date: date,
    );
    await _hiveService.addPayment(payment);
  }

  double getTotalPaymentForLabour(String labourId) {
    final payments = _hiveService.getPaymentsForLabour(labourId);
    return payments.fold<double>(0, (sum, payment) => sum + payment.amount);
  }

  String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecondsSinceEpoch % 1000}';
}
