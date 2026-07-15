import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'upi_pin_screen.dart';

/// UI-only placeholder bank account (Task 6.6) — no real bank integration.
class BankAccountOption {
  final String id;
  final String bankName;
  final String maskedNumber;
  final String label;

  const BankAccountOption({
    required this.id,
    required this.bankName,
    required this.maskedNumber,
    required this.label,
  });

  String get displayLabel => '$bankName • $maskedNumber';
}

const BankAccountOption kDefaultBankAccount = BankAccountOption(
  id: 'sbi-4321',
  bankName: 'State Bank of India',
  maskedNumber: 'XXXX 4321',
  label: 'Primary Account',
);

const List<BankAccountOption> kBankAccounts = [
  kDefaultBankAccount,
  BankAccountOption(
    id: 'hdfc-7788',
    bankName: 'HDFC Bank',
    maskedNumber: 'XXXX 7788',
    label: 'Savings Account',
  ),
];

/// Bank Account selection — UI simulation only (no real bank is contacted).
class BankAccountScreen extends StatefulWidget {
  final int amountPaise;
  final int currentBalancePaise;

  const BankAccountScreen({super.key, required this.amountPaise, required this.currentBalancePaise});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  String _selectedId = kDefaultBankAccount.id;

  void _select(String id) => setState(() => _selectedId = id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Bank Account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            'This is a UI simulation — no real bank is contacted.',
            style: AppTypography.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          RadioGroup<String>(
            groupValue: _selectedId,
            onChanged: (value) {
              if (value != null) _select(value);
            },
            child: Column(
              children: kBankAccounts
                  .map(
                    (account) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.base),
                      child: _BankAccountTile(
                        account: account,
                        selected: _selectedId == account.id,
                        onTap: () => _select(account.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          PrimaryButton(
            key: const Key('bank-account-continue'),
            label: 'Continue',
            icon: Symbols.arrow_forward_rounded,
            onPressed: () => Navigator.of(context).push(sharedAxisRoute(
              UpiPinScreen(amountPaise: widget.amountPaise),
            )),
          ),
        ],
      ),
    );
  }
}

class _BankAccountTile extends StatelessWidget {
  final BankAccountOption account;
  final bool selected;
  final VoidCallback onTap;

  const _BankAccountTile({required this.account, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('bank-account-${account.id}'),
      onTap: onTap,
      borderRadius: AppRadius.lgRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Radio<String>(value: account.id),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.bankName, style: AppTypography.textTheme.titleMedium),
                  Text(account.maskedNumber, style: AppTypography.textTheme.bodyMedium),
                  Text(account.label, style: AppTypography.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
