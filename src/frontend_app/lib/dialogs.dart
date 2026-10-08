import 'package:flutter/material.dart';

import 'format.dart';
import 'ledger.dart';
import 'models.dart';
import 'theme.dart';

Future<Budget?> showCreateBudgetDialog(BuildContext context, {required String ownerName}) {
  return showDialog<Budget>(
    context: context,
    builder: (_) => _CreateBudgetDialog(ownerName: ownerName),
  );
}

class _CreateBudgetDialog extends StatefulWidget {
  final String ownerName;

  const _CreateBudgetDialog({required this.ownerName});

  @override
  State<_CreateBudgetDialog> createState() => _CreateBudgetDialogState();
}

class _CreateBudgetDialogState extends State<_CreateBudgetDialog> {
  final _nameController = TextEditingController();
  final _memberController = TextEditingController();
  final _members = <Member>[];
  BudgetRole _role = BudgetRole.editor;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberController.text.trim();
    if (name.isEmpty) return;
    final taken = name.toLowerCase() == widget.ownerName.toLowerCase() ||
        _members.any((member) => member.name.toLowerCase() == name.toLowerCase());
    if (taken) {
      setState(() => _error = '$name is already on this budget.');
      return;
    }
    setState(() {
      _error = null;
      _members.add(Member(name, _role));
      _memberController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create budget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('budget-name-field'),
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Budget name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            const Text('People', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              '${widget.ownerName} is the owner. Add anyone else who should work on this budget.',
              style: const TextStyle(fontSize: 12, color: AppColors.inkFade),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onSubmitted: (_) => _addMember(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<BudgetRole>(
                  value: _role,
                  items: const [BudgetRole.editor, BudgetRole.viewer]
                      .map((role) => DropdownMenuItem(value: role, child: Text(role.label)))
                      .toList(),
                  onChanged: (role) => setState(() => _role = role ?? _role),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.moss),
                  onPressed: _addMember,
                ),
              ],
            ),
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final member in _members)
                    Chip(
                      label: Text('${member.name} · ${member.role.label}', style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.paper,
                      side: const BorderSide(color: AppColors.hairline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      onDeleted: () => setState(() => _members.remove(member)),
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.rust, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              setState(() => _error = 'Give this budget a name.');
              return;
            }
            Navigator.of(context).pop(
              Budget(
                id: newId(),
                name: name,
                members: [Member(widget.ownerName, BudgetRole.owner), ..._members],
                categories: [],
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

Future<Member?> showAddMemberDialog(BuildContext context, Budget budget) {
  return showDialog<Member>(
    context: context,
    builder: (_) => _AddMemberDialog(budget: budget),
  );
}

class _AddMemberDialog extends StatefulWidget {
  final Budget budget;

  const _AddMemberDialog({required this.budget});

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _nameController = TextEditingController();
  BudgetRole _role = BudgetRole.editor;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add person'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('member-name-field'),
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BudgetRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [BudgetRole.editor, BudgetRole.viewer]
                .map((role) => DropdownMenuItem(value: role, child: Text(role.label)))
                .toList(),
            onChanged: (role) => setState(() => _role = role ?? _role),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.rust, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              setState(() => _error = 'Enter a name.');
              return;
            }
            final taken = widget.budget.members.any(
              (member) => member.name.toLowerCase() == name.toLowerCase(),
            );
            if (taken) {
              setState(() => _error = '$name is already on this budget.');
              return;
            }
            Navigator.of(context).pop(Member(name, _role));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

Future<BudgetCategory?> showCategoryDialog(BuildContext context) {
  return showDialog<BudgetCategory>(
    context: context,
    builder: (_) => const _CategoryDialog(),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  CategoryKind _kind = CategoryKind.recurring;
  PayFrequency _frequency = PayFrequency.monthly;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recurring = _kind == CategoryKind.recurring;
    return AlertDialog(
      title: const Text('Add category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('category-name-field'),
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Category name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CategoryKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: CategoryKind.values
                  .map((kind) => DropdownMenuItem(value: kind, child: Text(kind.label)))
                  .toList(),
              onChanged: (kind) => setState(() => _kind = kind ?? _kind),
            ),
            if (recurring) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<PayFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Limit resets'),
                items: PayFrequency.values
                    .map((frequency) => DropdownMenuItem(value: frequency, child: Text(frequency.label)))
                    .toList(),
                onChanged: (frequency) => setState(() => _frequency = frequency ?? _frequency),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('category-amount-field'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: _kind.targetLabel, prefixText: '\$'),
            ),
            const SizedBox(height: 8),
            Text(
              recurring
                  ? 'Expenses in this category count against the limit.'
                  : 'Amounts you add count toward the savings goal.',
              style: const TextStyle(fontSize: 12, color: AppColors.inkFade),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.rust, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final amount = parseMoney(_amountController.text);
            if (name.isEmpty || amount == null || amount <= 0) {
              setState(() => _error = 'Enter a name and an amount greater than zero.');
              return;
            }
            Navigator.of(context).pop(
              BudgetCategory(
                id: newId(),
                name: name,
                kind: _kind,
                frequency: _frequency,
                target: amount,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

Future<Expense?> showExpenseDialog(BuildContext context) {
  return showDialog<Expense>(
    context: context,
    builder: (_) => const _ExpenseDialog(),
  );
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog();

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _labelController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add expense'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('expense-label-field'),
            controller: _labelController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'What was it'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('expense-amount-field'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: _pickDate, child: Text(dateShort(_date))),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.rust, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final label = _labelController.text.trim();
            final amount = parseMoney(_amountController.text);
            if (label.isEmpty || amount == null || amount <= 0) {
              setState(() => _error = 'Enter a name and an amount greater than zero.');
              return;
            }
            Navigator.of(context).pop(
              Expense(id: newId(), label: label, amount: amount, date: _date),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

Future<IncomeSource?> showIncomeDialog(
  BuildContext context, {
  required List<Budget> budgets,
  Budget? lockedBudget,
  IncomeSource? existing,
}) {
  return showDialog<IncomeSource>(
    context: context,
    builder: (_) => _IncomeDialog(
      budgets: budgets,
      lockedBudget: lockedBudget,
      existing: existing,
    ),
  );
}

class _IncomeDialog extends StatefulWidget {
  final List<Budget> budgets;
  final Budget? lockedBudget;
  final IncomeSource? existing;

  const _IncomeDialog({
    required this.budgets,
    this.lockedBudget,
    this.existing,
  });

  @override
  State<_IncomeDialog> createState() => _IncomeDialogState();
}

class _IncomeDialogState extends State<_IncomeDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late IncomeKind _kind;
  late PayFrequency _frequency;
  late String _budgetId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    final startingAmount = existing?.paycheckAmount;
    _amountController = TextEditingController(
      text: startingAmount == null || startingAmount == 0 ? '' : startingAmount.toStringAsFixed(2),
    );
    _kind = existing?.kind ?? IncomeKind.paycheck;
    _frequency = existing?.frequency ?? PayFrequency.biweekly;
    _budgetId = existing?.budgetId ?? widget.lockedBudget?.id ?? widget.budgets.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _isPaycheck => _kind == IncomeKind.paycheck;

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit paycheck' : 'Add income'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!editing) ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Automatic'),
                    selected: _isPaycheck,
                    onSelected: (_) => setState(() => _kind = IncomeKind.paycheck),
                  ),
                  ChoiceChip(
                    label: const Text('Manual'),
                    selected: !_isPaycheck,
                    onSelected: (_) => setState(() => _kind = IncomeKind.sideHustle),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isPaycheck
                    ? 'A set amount that is counted automatically each week, every two weeks, or month.'
                    : 'A side hustle or other income you update by logging what came in.',
                style: const TextStyle(fontSize: 12, color: AppColors.inkFade),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('income-name-field'),
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: _isPaycheck ? 'Paycheck name' : 'Side hustle name'),
            ),
            if (widget.lockedBudget == null && widget.existing == null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _budgetId,
                decoration: const InputDecoration(labelText: 'Budget'),
                items: widget.budgets
                    .map((budget) => DropdownMenuItem(value: budget.id, child: Text(budget.name)))
                    .toList(),
                onChanged: (id) => setState(() => _budgetId = id ?? _budgetId),
              ),
            ],
            if (_isPaycheck) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('income-amount-field'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Payment amount', prefixText: '\$'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PayFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'How often'),
                items: PayFrequency.values
                    .map((frequency) => DropdownMenuItem(value: frequency, child: Text(frequency.label)))
                    .toList(),
                onChanged: (frequency) => setState(() => _frequency = frequency ?? _frequency),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.rust, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              setState(() => _error = 'Give this income a name.');
              return;
            }
            if (_isPaycheck) {
              final amount = parseMoney(_amountController.text);
              if (amount == null || amount <= 0) {
                setState(() => _error = 'Enter the amount of each payment.');
                return;
              }
              final existing = widget.existing;
              if (existing != null) {
                existing
                  ..name = name
                  ..paycheckAmount = amount
                  ..frequency = _frequency;
                Navigator.of(context).pop(existing);
                return;
              }
              Navigator.of(context).pop(
                IncomeSource(
                  id: newId(),
                  budgetId: _budgetId,
                  name: name,
                  kind: IncomeKind.paycheck,
                  frequency: _frequency,
                  paycheckAmount: amount,
                ),
              );
              return;
            }
            Navigator.of(context).pop(
              IncomeSource(
                id: newId(),
                budgetId: _budgetId,
                name: name,
                kind: IncomeKind.sideHustle,
              ),
            );
          },
          child: Text(editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

Future<IncomePayment?> showLogIncomeDialog(BuildContext context) {
  return showDialog<IncomePayment>(
    context: context,
    builder: (_) => const _LogIncomeDialog(),
  );
}

class _LogIncomeDialog extends StatefulWidget {
  const _LogIncomeDialog();

  @override
  State<_LogIncomeDialog> createState() => _LogIncomeDialogState();
}

class _LogIncomeDialogState extends State<_LogIncomeDialog> {
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log money'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter what this side hustle brought in. It is added to the running total.',
            style: TextStyle(fontSize: 12, color: AppColors.inkFade),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('log-amount-field'),
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Text(dateShort(_date)),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.rust, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final amount = parseMoney(_amountController.text);
            if (amount == null || amount <= 0) {
              setState(() => _error = 'Enter an amount greater than zero.');
              return;
            }
            Navigator.of(context).pop(
              IncomePayment(id: newId(), amount: amount, date: _date),
            );
          },
          child: const Text('Log'),
        ),
      ],
    );
  }
}
