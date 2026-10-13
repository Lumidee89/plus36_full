import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/json_cache.dart';
import '../../core/theme.dart';
import '../../core/widgets/success_bottom_sheet.dart';
import '../children/selected_child.dart';
import '../home/home_screen.dart';

final feeInvoicesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return JsonCache.through<List<dynamic>>('parent_fee_invoices', () async {
    final response = await ref
        .watch(apiClientProvider)
        .get('/parent/fee-invoices');
    return List<dynamic>.from(response.data['data'] as List);
  });
});

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String? _startingInvoiceId;
  String? _awaitingInvoiceId;
  String? _verifyingInvoiceId;
  final Map<String, int> _selectedInstallments = {};

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = AppLifecycleListener(
      onResume: () {
        final id = _awaitingInvoiceId;
        if (id != null) _verify(id, quiet: true);
      },
    );
  }

  late final AppLifecycleListener _lifecycleObserver;

  @override
  void dispose() {
    _lifecycleObserver.dispose();
    super.dispose();
  }

  Future<void> _pay(
    Map<String, dynamic> invoice, {
    Map<String, dynamic>? installment,
  }) async {
    final id = invoice['id'].toString();
    setState(() => _startingInvoiceId = id);

    try {
      final response = await ref
          .read(apiClientProvider)
          .post(
            '/parent/fee-invoices/$id/initialize-payment',
            data: {
              'idempotency_key': const Uuid().v4(),
              if (installment != null) 'installment_id': installment['id'],
            },
          );
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      final checkoutUrl = Uri.tryParse(
        data['authorization_url']?.toString() ?? '',
      );

      if (checkoutUrl == null ||
          !await launchUrl(checkoutUrl, mode: LaunchMode.externalApplication)) {
        throw StateError('Unable to open the secure payment page.');
      }
      if (mounted) setState(() => _awaitingInvoiceId = id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiMessage(error))));
    } finally {
      if (mounted) setState(() => _startingInvoiceId = null);
    }
  }

  Future<void> _verify(String id, {bool quiet = false}) async {
    if (_verifyingInvoiceId != null) return;
    setState(() => _verifyingInvoiceId = id);
    try {
      final response = await ref
          .read(apiClientProvider)
          .post('/parent/fee-invoices/$id/verify-payment');
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      ref.invalidate(feeInvoicesProvider);
      await ref.read(feeInvoicesProvider.future);
      if (!mounted) return;
      final paid = data['payment_status'] == 'paid';
      if (paid) {
        setState(() => _awaitingInvoiceId = null);
        await showSuccessBottomSheet(
          context,
          title: 'Payment successful',
          message: 'Your payment has been confirmed and your balance updated.',
          actionLabel: 'View payments',
        );
      } else if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment is still being confirmed. Try again shortly.',
            ),
          ),
        );
      }
    } catch (error) {
      ref.invalidate(feeInvoicesProvider);
      if (!quiet && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _verifyingInvoiceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final dashboard = ref.watch(dashboardProvider).valueOrNull;
    final children = dashboard?['children'] as List? ?? [];
    final activeChild = selectedChild(
      children,
      ref.watch(selectedChildIdProvider),
    );

    return RefreshIndicator(
      onRefresh: () => ref.refresh(feeInvoicesProvider.future),
      child: ref
          .watch(feeInvoicesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 180),
                Center(child: Text(apiMessage(error))),
              ],
            ),
            data: (invoices) {
              final visibleInvoices = children.length > 1
                  ? invoices.where((raw) {
                      final invoice = raw as Map;
                      final student = invoice['student'] as Map?;
                      return student?['id'].toString() ==
                          activeChild['id'].toString();
                    }).toList()
                  : invoices;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Payments',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Review outstanding invoices and pay securely with Paystack.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (children.length > 1) ...[
                    const SizedBox(height: 18),
                    ChildSwitcher(children: children),
                  ],
                  const SizedBox(height: 18),
                  if (visibleInvoices.isEmpty)
                    const Card(
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('There are no fee invoices yet.'),
                      ),
                    ),
                  ...visibleInvoices.map((rawInvoice) {
                    final invoice = Map<String, dynamic>.from(
                      rawInvoice as Map,
                    );
                    final student = Map<String, dynamic>.from(
                      (invoice['student'] as Map?) ?? const {},
                    );
                    final balance =
                        (invoice['balance'] as num?)?.toDouble() ?? 0;
                    final isStarting =
                        _startingInvoiceId == invoice['id'].toString();
                    final id = invoice['id'].toString();
                    final isVerifying = _verifyingInvoiceId == id;
                    final awaiting = _awaitingInvoiceId == id;
                    final installments = (invoice['installments'] as List? ?? [])
                        .map((item) => Map<String, dynamic>.from(item as Map))
                        .where((item) => item['status'] == 'pending')
                        .toList();
                    final selectedInstallmentId = _selectedInstallments[id] ??
                        (installments.isEmpty
                            ? null
                            : installments.first['id'] as int);
                    final selectedInstallment = installments.isEmpty
                        ? null
                        : installments.firstWhere(
                            (item) => item['id'] == selectedInstallmentId,
                            orElse: () => installments.first,
                          );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    student['name']?.toString() ?? 'Student',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    invoice['status']?.toString() ?? 'pending',
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${invoice['invoice_number']} • Due ${invoice['due_on'] ?? '—'}',
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Outstanding balance',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              currency.format(balance),
                              style: const TextStyle(
                                color: AppColors.forest,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (balance > 0) ...[
                              if (installments.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'Choose installment',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: installments
                                      .map(
                                        (part) => ChoiceChip(
                                          selected:
                                              selectedInstallmentId == part['id'],
                                          label: Text(
                                            '${part['sequence']}. ${currency.format(part['amount'])}',
                                          ),
                                          onSelected: (_) => setState(
                                            () => _selectedInstallments[id] =
                                                part['id'] as int,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _startingInvoiceId == null
                                    ? () => _pay(
                                        invoice,
                                        installment: selectedInstallment,
                                      )
                                    : null,
                                icon: isStarting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.lock_outline_rounded),
                                label: Text(
                                  isStarting
                                      ? 'Opening checkout…'
                                      : installments.isEmpty
                                      ? 'Pay balance'
                                      : 'Pay selected installment',
                                ),
                              ),
                              if (awaiting) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: isVerifying
                                      ? null
                                      : () => _verify(id),
                                  icon: isVerifying
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh_rounded),
                                  label: Text(
                                    isVerifying
                                        ? 'Checking…'
                                        : 'Check payment status',
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
    );
  }
}
