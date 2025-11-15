class AppConstants {
  static const maxMembersAllowed = 6; // included admin would be + 1
  static const documentsPath =
      '/storage/emulated/0/documents/split_smart_expenses'; // for android

  static String getTransactionTypeLabel(String? type) {
    switch (type) {
      case 'add':
        return 'Added';
      case 'spend':
        return 'Spent';
      case 'loan':
        return 'Loan';
      case 'repay':
        return 'Repayment';
      default:
        return type ?? '-';
    }
  }
}
