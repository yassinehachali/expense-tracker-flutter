import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AppStrings {
  static String language = 'en';
  static final ValueNotifier<String> languageNotifier = ValueNotifier<String>('en');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') ?? 'en';
    languageNotifier.value = language;
  }

  static Future<void> setLanguage(String lang) async {
    if (['en', 'fr', 'ar'].contains(lang)) {
      language = lang;
      languageNotifier.value = lang;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', lang);
    }
  }

  static Map<String, String> get _currentMap {
    switch (language) {
      case 'fr': return _fr;
      case 'ar': return _ar;
      default: return _en;
    }
  }

  // Helper for lookup with fallback
  static String _t(String key) => _currentMap[key] ?? _en[key] ?? key;

  // Notification Channels
  static String get updatesChannelId => 'updates_channel'; // Technical IDs stay const-ish usually, but methods fine
  static String get updatesChannelName => _t('updatesChannelName');
  static String get updatesChannelDesc => _t('updatesChannelDesc');
  
  static String get reminderChannelId => 'reminder_channel_v2';
  static String get reminderChannelName => _t('reminderChannelName');
  static String get reminderChannelDesc => _t('reminderChannelDesc');

  // Notification Content
  static String get updateTitle => _t('updateTitle');
  static String get updateBody => _t('updateBody');

  static String get dailyReminderTitle => _t('dailyReminderTitle');
  static String get dailyReminderBody => _t('dailyReminderBody');
  
  // Payloads
  static const String payloadUpdateCheck = 'update_check'; // Technical value

  // Login Screen
  static String get appTitle => _t('appTitle');
  static String get loginSubtitle => _t('loginSubtitle');
  static String get signupSubtitle => _t('signupSubtitle');
  static String get loginBtn => _t('loginBtn');
  static String get signupBtn => _t('signupBtn');
  static String get signupTitle => _t('signupTitle');
  static String get loginTitle => _t('loginTitle');
  static String get emailHint => _t('emailHint');
  static String get passwordHint => _t('passwordHint');
  static String get confirmPasswordHint => _t('confirmPasswordHint');
  static String get guestLogin => _t('guestLogin');
  static String get guestLoginFailed => _t('guestLoginFailed');
  static String get passwordMismatch => _t('passwordMismatch');
  static String get passwordLength => _t('passwordLength');
  static String get toSignupText => _t('toSignupText');
  static String get toLoginText => _t('toLoginText');
  static String get orText => _t('orText');
  static String get signInWithGoogle => _t('signInWithGoogle');

  // Dashboard & Common
  static String get welcomeBack => _t('welcomeBack');
  static String get totalRemaining => _t('totalRemaining');
  static String get income => _t('income');
  static String get spent => _t('spent');
  static String get topSpending => _t('topSpending');
  static String get noDataMonth => _t('noDataMonth');
  static String get recentActivity => _t('recentActivity');
  static String get viewAll => _t('viewAll');
  
  // Transaction Actions
  static String get editTransaction => _t('editTransaction');
  static String get recordRepayment => _t('recordRepayment');
  static String get deleteTransaction => _t('deleteTransaction');
  static String get cancel => _t('cancel');
  static String get confirm => _t('confirm');
  
  // Repayment Dialog
  static String get totalLoan => _t('totalLoan');
  static String get remaining => _t('remaining');
  static String get amountReturned => _t('amountReturned');
  static String get enterAmount => _t('enterAmount');
  static String get errorAmountExceeds => _t('errorAmountExceeds');
  static String get repaidPrefix => _t('repaidPrefix');

  // Transactions Screen
  static String get historyTitle => _t('historyTitle');
  static String get noTransactions => _t('noTransactions');
  static String get filterAll => _t('filterAll');
  static String get filterExpenses => _t('filterExpenses');
  static String get filterLoans => _t('filterLoans');
  static String get filterIncome => _t('filterIncome');
  
  // Lending Actions
  static String get markAsPending => _t('markAsPending');
  
  // Borrowing
  static String get borrow => _t('borrow');
  static String get loansManager => _t('loansManager');
  static String get repay => _t('repay');
  static String get totalBorrowed => _t('totalBorrowed');
  static String get descHintBorrow => _t('descHintBorrow');
  
  // Add/Edit Expense Screen
  static String get addTransaction => _t('addTransaction');
  static String get saveTransaction => _t('saveTransaction');
  static String get transactionSaved => _t('transactionSaved');
  static String get transactionUpdated => _t('transactionUpdated');
  static String get invalidAmount => _t('invalidAmount');
  static String get errorPrefix => _t('errorPrefix');
  static String get amountLabel => _t('amountLabel');
  static String get amountHint => _t('amountHint');
  static String get descLabel => _t('descLabel');
  static String get descLabelLoan => _t('descLabelLoan');
  static String get descHint => _t('descHint');
  static String get descHintLoan => _t('descHintLoan');
  static String get categoryLabel => _t('categoryLabel');
  static String get dateLabel => _t('dateLabel');
  static String get userNotLoggedIn => _t('userNotLoggedIn');
  static String get legacyTransactionLabel => _t('legacyTransactionLabel');
  static String get legacyTransactionHint => _t('legacyTransactionHint');

  // Settings Screen
  static String get settingsTitle => _t('settingsTitle');
  static String get salaryCycleOption => _t('salaryCycleOption');
  static String get categoriesOption => _t('categoriesOption');
  static String get categoriesSubtitle => _t('categoriesSubtitle');
  static String get changePasswordOption => _t('changePasswordOption');
  static String get checkUpdatesOption => _t('checkUpdatesOption');
  static String get resetDataOption => _t('resetDataOption');
  static String get logoutOption => _t('logoutOption');
  static String get guestUser => _t('guestUser');
  static String get languageOption => _t('languageOption');
  static String get selectLanguage => _t('selectLanguage');
  static String get currencyOption => _t('currencyOption');
  static String get selectCurrency => _t('selectCurrency');

  // Salary Dialog
  static String get customizeCycle => _t('customizeCycle');
  static String get salaryAmount => _t('salaryAmount');
  static String get cycleStartsIn => _t('cycleStartsIn');
  static String get cycleStartDay => _t('cycleStartDay');
  static String get cycleHelperText => _t('cycleHelperText');
  static String get save => _t('save');
  
  // Change Password Dialog
  static String get currentPassword => _t('currentPassword');
  static String get newPassword => _t('newPassword');
  static String get confirmNewPassword => _t('confirmNewPassword');
  static String get passwordUpdateSuccess => _t('passwordUpdateSuccess');
  static String get newPasswordMismatch => _t('newPasswordMismatch');
  
  // Reset Dialog
  static String get resetDataTitle => _t('resetDataTitle');
  static String get resetDataConfirm => _t('resetDataConfirm');
  static String get deleteAll => _t('deleteAll');
  static String get typeDeleteToConfirm => _t('typeDeleteToConfirm');
  static String get allDataReset => _t('allDataReset');
  
  // Updates
  static String get updateAvailableTitle => _t('updateAvailableTitle');
  static String get changelog => _t('changelog');
  static String get later => _t('later');
  static String get updateNow => _t('updateNow');
  static String get upToDate => _t('upToDate');
  static String get checkFailed => _t('checkFailed');
  static String get startDownload => _t('startDownload');
  static String get downloading => _t('downloading');
  static String get launchingInstaller => _t('launchingInstaller');
  static String get installFailed => _t('installFailed');
  static String get downloadFailed => _t('downloadFailed');
  
  // Category Screen
  static String get manageCategories => _t('manageCategories');
  static String get addNewCategory => _t('addNewCategory');
  static String get categoryName => _t('categoryName');
  static String get categoryNameHint => _t('categoryNameHint');
  static String get selectColor => _t('selectColor');
  static String get selectIcon => _t('selectIcon');
  static String get createCategory => _t('createCategory');
  static String get myCategories => _t('myCategories');
  static String get noCustomCategories => _t('noCustomCategories');
  static String get pleaseLogin => _t('pleaseLogin');
  
  // Expense Card
  static String get deleteConfirmationTitle => _t('deleteConfirmationTitle');
  static String get deleteConfirmationBody => _t('deleteConfirmationBody');
  static String get deleteAction => _t('deleteAction');
  static String get loanReturned => _t('loanReturned');
  static String get returnedLabel => _t('returnedLabel');

  // Fixed Charges (Added Late)
  static String get fixedCharges => _t('fixedCharges');
  static String get fixedChargesSubtitle => _t('fixedChargesSubtitle');
  static String get noFixedCharges => _t('noFixedCharges');
  static String get addFixedCharge => _t('addFixedCharge');
  static String get autoApply => _t('autoApply');
  static String get waitForDueDate => _t('waitForDueDate');
  static String get totalFixedCharges => _t('totalFixedCharges');

  // Insurance (Added Late)
  static String get insurance => _t('insurance');
  static String get insuranceSubtitle => _t('insuranceSubtitle');
  static String get addClaim => _t('addClaim');
  static String get settleClaim => _t('settleClaim');
  static String get policyNumber => _t('policyNumber');

  static String get manualChargesHeader => _t('manualChargesHeader');
  static String get allManualApplied => _t('allManualApplied');
  static String get applyManualTitle => _t('applyManualTitle');
  static String get editClaim => _t('editClaim');
  static String get descriptionLabel => _t('descriptionLabel');
  static String get totalAmountLabel => _t('totalAmountLabel');
  
  static String get applyAllThisMonth => _t('applyAllThisMonth');
  static String get applyAllNextMonth => _t('applyAllNextMonth');
  static String get manualChargesConfirm => _t('manualChargesConfirm');
  static String get chargesApplied => _t('chargesApplied');
  static String get dayOfMonth => _t('dayOfMonth');
  static String get autoApplySubtitle => _t('autoApplySubtitle');
  static String get waitForDueDateSubtitle => _t('waitForDueDateSubtitle');
  static String get appliedFor => _t('appliedFor');
  static String get applyChargeTitle => _t('applyChargeTitle');
  static String get apply => _t('apply');
  static String get deleteChargeTitle => _t('deleteChargeTitle');
  static String get deleteChargeConfirm => _t('deleteChargeConfirm');
  static String get delete => _t('delete');
  static String get saveChanges => _t('saveChanges');
  static String get noInsuranceClaims => _t('noInsuranceClaims');
  static String get newClaim => _t('newClaim');
  static String get addCharge => _t('addCharge');
  
  // Insurance New
  static String get healthInsuranceTitle => _t('healthInsuranceTitle');
  static String get pendingClaimsSection => _t('pendingClaimsSection');
  static String get historySection => _t('historySection');
  static String get newInsuranceClaimTitle => _t('newInsuranceClaimTitle');
  static String get claimDescriptionHint => _t('claimDescriptionHint');
  static String get totalAmountPaidHint => _t('totalAmountPaidHint');
  static String get refundedPrefix => _t('refundedPrefix');
  static String get settleRefund => _t('settleRefund');
  static String get deleteClaimTitle => _t('deleteClaimTitle');
  static String get deleteClaimContent => _t('deleteClaimContent');
  static String get settleClaimTitle => _t('settleClaimTitle');
  static String get totalPaidPrefix => _t('totalPaidPrefix');
  static String get refundAmountReceivedLabel => _t('refundAmountReceivedLabel');
  static String get refundDatePrefix => _t('refundDatePrefix');
  static String get confirmRefundBtn => _t('confirmRefundBtn');

  // New General
  static String get fixedChargesDesc => _t('fixedChargesDesc');
  static String get manageDebtsDesc => _t('manageDebtsDesc');
  static String get healthInsuranceDesc => _t('healthInsuranceDesc');
  static String get rolloverHistory => _t('rolloverHistory');
  static String get manageRollovers => _t('manageRollovers');
  static String get statusApplied => _t('statusApplied');
  static String get statusIgnored => _t('statusIgnored');
  static String get enable => _t('enable');
  static String get disable => _t('disable');
  static String get noHistory => _t('noHistory');
  static String get rolloverAvailable => _t('rolloverAvailable');
  static String get rolloverMessage => _t('rolloverMessage');
  static String get applyRolloverConfirm => _t('applyRolloverConfirm');
  static String get yesApply => _t('yesApply');
  static String get no => _t('no');
  static String get close => _t('close');
  static String get versionPrefix => _t('versionPrefix');
  static String get updatingTitle => _t('updatingTitle');
  static String get noDebtsMessage => _t('noDebtsMessage');
  static String get unknownLender => _t('unknownLender');
  static String get repayLoanTitle => _t('repayLoanTitle');
  static String get receivePaymentTitle => _t('receivePaymentTitle');
  static String get amountExceedsDebt => _t('amountExceedsDebt');
  static String get markAsReturned => _t('markAsReturned');
  static String get dashboard => _t('dashboard');
  static String get noLendingsMessage => _t('noLendingsMessage');

  // Categories
  static String get catHousing => _t('catHousing');
  static String get catFood => _t('catFood');
  static String get catTransport => _t('catTransport');
  static String get catUtilities => _t('catUtilities');
  static String get catEntertainment => _t('catEntertainment');
  static String get catShopping => _t('catShopping');
  static String get catHealth => _t('catHealth');
  static String get catOthers => _t('catOthers');

  static String getCategoryName(String dbName) {
     switch(dbName) {
       case 'Housing': return catHousing;
       case 'Food': return catFood;
       case 'Transport': return catTransport;
       case 'Utilities': return catUtilities;
       case 'Entertainment': return catEntertainment;
       case 'Shopping': return catShopping;
       case 'Health': return catHealth;
       case 'Others': return catOthers;
       default: return dbName; // Custom category
     }
  }
  // --------------------------------------------------------
  // TRANSLATION MAPS
  // --------------------------------------------------------
  
  static const Map<String, String> _en = {
    'manualChargesHeader': 'Manual Application',
    'allManualApplied': 'All manual charges applied!',
    'applyManualTitle': 'Apply Manual Expenses',
    'editClaim': 'Edit Claim',
    'descriptionLabel': 'Description',
    'totalAmountLabel': 'Total Amount',
    'updatesChannelName': 'App Updates',
    'updatesChannelDesc': 'Notifications for new app updates',
    'reminderChannelName': 'Daily Reminders',
    'reminderChannelDesc': 'Daily reminders to record expenses',
    'updateTitle': 'Update Available: ',
    'updateBody': 'A new version is available. Tap to update.',
    'dailyReminderTitle': 'Daily Reminder 📝',
    'dailyReminderBody': "Don't forget to record your expenses for today!",
    'appTitle': 'Expense Tracker',
    'loginSubtitle': 'Manage your finances with ease',
    'signupSubtitle': 'Create your account',
    'loginBtn': 'Sign In',
    'signupBtn': 'Create Account',
    'signupTitle': 'Sign Up',
    'loginTitle': 'Login',
    'emailHint': 'Email Address',
    'passwordHint': 'Password',
    'confirmPasswordHint': 'Confirm Password',
    'guestLogin': 'Continue as Guest',
    'guestLoginFailed': 'Guest login failed.',
    'passwordMismatch': 'Passwords do not match',
    'passwordLength': 'Password must be at least 6 characters',
    'toSignupText': "Don't have an account? Sign Up",
    'toLoginText': "Already have an account? Login",
    'orText': 'OR',
    'signInWithGoogle': 'Sign in with Google',
    'welcomeBack': 'Welcome back',
    'totalRemaining': 'Total Remaining',
    'income': 'Income',
    'spent': 'Spent',
    'topSpending': 'Top Spending',
    'noDataMonth': 'No data for this month',
    'recentActivity': 'Recent Activity',
    'viewAll': 'View All',
    'editTransaction': 'Edit Transaction',
    'recordRepayment': 'Record Repayment',
    'deleteTransaction': 'Delete Transaction',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'totalLoan': 'Total Lent: ',
    'remaining': 'Remaining: ',
    'amountReturned': 'Amount Returned',
    'enterAmount': 'Enter amount',
    'errorAmountExceeds': 'Amount cannot exceed remaining balance',
    'repaidPrefix': 'Repaid ',
    'historyTitle': 'History',
    'noTransactions': 'No transactions found',
    'filterAll': 'All',
    'filterExpenses': 'Expenses',
    'filterLoans': 'Lending',
    'filterIncome': 'Income',
    'markAsPending': 'Mark as Pending',
    'borrow': 'Borrow',
    'loansManager': 'Loans Manager',
    'repay': 'Repay',
    'totalBorrowed': 'Total Borrowed: ',
    'descHintBorrow': 'Who are you borrowing from?',
    'addTransaction': 'Add Transaction',
    'saveTransaction': 'Save Transaction',
    'transactionSaved': 'Transaction saved!',
    'transactionUpdated': 'Transaction updated!',
    'invalidAmount': 'Please enter a valid amount',
    'errorPrefix': 'Error: ',
    'amountLabel': 'Amount',
    'amountHint': '0.00',
    'descLabel': 'Description (Optional)',
    'descLabelLoan': 'Person Name',
    'descHint': 'What is this for?',
    'descHintLoan': 'Who are you lending to?',
    'categoryLabel': 'Category',
    'dateLabel': 'Date',
    'userNotLoggedIn': 'User not logged in',
    'settingsTitle': 'Settings',
    'salaryCycleOption': 'Salary & Cycle',
    'categoriesOption': 'Categories',
    'categoriesSubtitle': 'Manage your categories',
    'changePasswordOption': 'Change Password',
    'checkUpdatesOption': 'Check for Updates',
    'resetDataOption': 'Reset All Data',
    'logoutOption': 'Log Out',
    'guestUser': 'Guest User',
    'languageOption': 'Language',
    'selectLanguage': 'Select Language',
    'customizeCycle': 'Customize the salary and start date for this specific month.',
    'salaryAmount': 'Salary Amount',
    'cycleStartsIn': 'Cycle Starts In:',
    'cycleStartDay': 'Day ',
    'cycleHelperText': 'This cycle will start on ',
    'save': 'Save',
    'currentPassword': 'Current Password',
    'newPassword': 'New Password',
    'confirmNewPassword': 'Confirm New Password',
    'passwordUpdateSuccess': 'Password updated successfully',
    'newPasswordMismatch': 'New passwords do not match',
    'resetDataTitle': 'Reset Data',
    'resetDataConfirm': 'Are you sure you want to delete ALL expenses and reset your salary? This cannot be undone.',
    'deleteAll': 'Delete All',
    'typeDeleteToConfirm': "Type 'delete' to confirm:",
    'allDataReset': 'All data has been reset.',
    'updateAvailableTitle': 'Update Available 🚀',
    'changelog': 'Changelog:',
    'later': 'Later',
    'updateNow': 'Update Now',
    'upToDate': 'Up to date!',
    'checkFailed': 'Check failed',
    'startDownload': 'Starting download...',
    'downloading': 'Downloading: ',
    'launchingInstaller': 'Launching Installer...',
    'installFailed': 'Install failed: ',
    'downloadFailed': 'Download failed',
    'manageCategories': 'Manage Categories',
    'addNewCategory': 'Add New Category',
    'categoryName': 'Category Name',
    'categoryNameHint': 'Category Name',
    'selectColor': 'Select Color',
    'selectIcon': 'Select Icon',
    'createCategory': 'Create Category',
    'myCategories': 'My Categories',
    'noCustomCategories': 'No custom categories yet.',
    'pleaseLogin': 'Please login',
    'deleteConfirmationTitle': 'Delete Transaction?',
    'deleteConfirmationBody': 'This action cannot be undone.',
    'deleteAction': 'Delete',
    'loanReturned': 'Repaid',
    'returnedLabel': 'Returned: ',
    'fixedCharges': 'Fixed Charges',
    'totalFixedCharges': 'Total Fixed Charges',
    'fixedChargesSubtitle': 'Manage rent, subscriptions, bills',
    'noFixedCharges': 'No fixed charges yet',
    'addFixedCharge': 'Add Charge',
    'autoApply': 'Auto-Apply (Recurring)',
    'waitForDueDate': 'Wait for Due Date?',
    'insurance': 'Insurance',
    'insuranceSubtitle': 'Track claims and refunds',
    'addClaim': 'Add Claim',
    'settleClaim': 'Settle Claim',
    'policyNumber': 'Policy Number',
    'applyAllThisMonth': 'Apply All to This Month',
    'applyAllNextMonth': 'Apply All to Next Month',
    'manualChargesConfirm': "This will add all 'Manual' fixed charges as expenses for that cycle.",
    'chargesApplied': 'Charges applied successfully!',
    'dayOfMonth': 'Day of Month',
    'autoApplySubtitle': 'Automatically add this expense every month',
    'waitForDueDateSubtitle': "If on, charge is created only when the day arrives. If off, it's created at cycle start.",
    'appliedFor': 'Applied for',
    'applyChargeTitle': 'Apply Charge?',
    'apply': 'Apply',
    'deleteChargeTitle': 'Delete Charge?',
    'deleteChargeConfirm': 'Delete',
    'delete': 'Delete',
    'saveChanges': 'Save Changes',
    'noInsuranceClaims': 'No insurance claims yet',
    'newClaim': 'New Claim',
    'addCharge': 'Add Charge',
    'healthInsuranceTitle': 'Health Insurance',
    'pendingClaimsSection': 'Pending Claims',
    'historySection': 'History',
    'newInsuranceClaimTitle': 'New Insurance Claim',
    'claimDescriptionHint': 'Description (e.g. Doctor Visit)',
    'totalAmountPaidHint': 'Total Amount Paid',
    'refundedPrefix': 'Refunded: ',
    'settleRefund': 'Settle Refund',
    'deleteClaimTitle': 'Delete Claim?',
    'deleteClaimContent': 'This will remove the claim history.',
    'settleClaimTitle': 'Settle Claim',
    'totalPaidPrefix': 'Total Paid: ',
    'refundAmountReceivedLabel': 'Refund Amount Received',
    'refundDatePrefix': 'Refund Date: ',
    'confirmRefundBtn': 'Confirm Refund',
    'fixedChargesDesc': 'Manage recurring expenses',
    'manageDebtsDesc': 'Manage loans and debts',
    'healthInsuranceDesc': 'Track claims & refunds',
    'rolloverHistory': 'Rollover History',
    'manageRollovers': 'Manage monthly carry-overs',
    'statusApplied': 'Applied',
    'statusIgnored': 'Ignored',
    'enable': 'Enable',
    'disable': 'Disable',
    'noHistory': 'No history found',
    'rolloverAvailable': 'Rollover Available',
    'rolloverMessage': 'You have a remaining balance from the last month.',
    'applyRolloverConfirm': 'Do you want to apply this balance?',
    'yesApply': 'Yes, Apply',
    'no': 'No',
    'versionPrefix': 'Version: ',
    'updatingTitle': 'Updating...',
    'noDebtsMessage': 'You have no debts!',
    'unknownLender': 'Unknown Lender',
    'repayLoanTitle': 'Repay Loan',
    'amountExceedsDebt': 'Amount exceeds remaining debt',
    'markAsReturned': 'Mark as Returned',
    'dashboard': 'Dashboard',
    'catHousing': 'Housing',
    'catFood': 'Food',
    'catTransport': 'Transport',
    'catUtilities': 'Utilities',
    'catEntertainment': 'Entertainment',
    'catShopping': 'Shopping',
    'catHealth': 'Health',
    'catOthers': 'Others',
    'receivePaymentTitle': 'Receive Payment',
    'noLendingsMessage': "You haven't lent money to anyone.",
    'currencyOption': 'Currency',
    'selectCurrency': 'Select Currency',
    'legacyTransactionLabel': 'Old Transaction (Pre-App)',
    'legacyTransactionHint': "Don't affect current balance",
  };

  static const Map<String, String> _fr = {
    'manualChargesHeader': 'Application Manuelle',
    'allManualApplied': 'Charges manuelles appliquées!',
    'applyManualTitle': 'Appliquer les Dépenses',
    'editClaim': 'Modifier Réclamation',
    'descriptionLabel': 'Description',
    'totalAmountLabel': 'Montant Total',
    'updatesChannelName': 'Mises à jour',
    'updatesChannelDesc': 'Notifications pour les nouvelles versions',
    'reminderChannelName': 'Rappels Quotidiens',
    'reminderChannelDesc': 'Rappels pour enregistrer vos dépenses',
    'updateTitle': 'Mise à jour disponible: ',
    'updateBody': 'Une nouvelle version est disponible. Appuyez pour mettre à jour.',
    'dailyReminderTitle': 'Rappel Quotidien 📝',
    'dailyReminderBody': "N'oubliez pas d'enregistrer vos dépenses aujourd'hui!",
    'appTitle': 'Suivi des Dépenses',
    'loginSubtitle': 'Gérez vos finances facilement',
    'signupSubtitle': 'Créez votre compte',
    'loginBtn': 'Se connecter',
    'signupBtn': 'Créer un compte',
    'signupTitle': 'Inscription',
    'loginTitle': 'Connexion',
    'emailHint': 'Adresse Email',
    'passwordHint': 'Mot de passe',
    'confirmPasswordHint': 'Confirmer le mot de passe',
    'guestLogin': 'Continuer en invité',
    'guestLoginFailed': 'Échec de la connexion invité.',
    'passwordMismatch': 'Les mots de passe ne correspondent pas',
    'passwordLength': 'Le mot de passe doit contenir au moins 6 caractères',
    'toSignupText': "Vous n'avez pas de compte? Inscrivez-vous",
    'toLoginText': "Vous avez déjà un compte? Connectez-vous",
    'orText': 'OU',
    'signInWithGoogle': 'Se connecter avec Google',
    'welcomeBack': 'Bon retour',
    'totalRemaining': 'Reste à dépenser',
    'income': 'Revenus',
    'spent': 'Dépensé',
    'topSpending': 'Top Dépenses',
    'noDataMonth': 'Pas de données pour ce mois',
    'recentActivity': 'Activité Récente',
    'viewAll': 'Voir Tout',
    'editTransaction': 'Modifier la transaction',
    'recordRepayment': 'Enregistrer un remboursement',
    'deleteTransaction': 'Supprimer la transaction',
    'cancel': 'Annuler',
    'confirm': 'Confirmer',
    'totalLoan': 'Total Prêté: ',
    'remaining': 'Restant: ',
    'amountReturned': 'Montant Retourné',
    'enterAmount': 'Entrer le montant',
    'errorAmountExceeds': 'Le montant ne peut pas dépasser le solde restant',
    'repaidPrefix': 'Remboursé ',
    'historyTitle': 'Historique',
    'noTransactions': 'Aucune transaction trouvée',
    'filterAll': 'Tous',
    'filterExpenses': 'Dépenses',
    'filterLoans': 'Prêts',
    'filterIncome': 'Revenus',
    'markAsPending': 'Marquer comme En Attente',
    'borrow': 'Emprunter',
    'loansManager': 'Gestion des Prêts',
    'repay': 'Rembourser',
    'totalBorrowed': 'Total Emprunté: ',
    'descHintBorrow': 'À qui empruntez-vous?',
    'addTransaction': 'Ajouter une Transaction',
    'saveTransaction': 'Enregistrer',
    'transactionSaved': 'Transaction enregistrée!',
    'transactionUpdated': 'Transaction mise à jour!',
    'invalidAmount': 'Veuillez entrer un montant valide',
    'errorPrefix': 'Erreur: ',
    'amountLabel': 'Montant',
    'amountHint': '0.00',
    'descLabel': 'Description (Optionnel)',
    'descLabelLoan': 'Nom de la personne',
    'descHint': "C'est pour quoi?",
    'descHintLoan': 'À qui prêtez-vous?',
    'categoryLabel': 'Catégorie',
    'dateLabel': 'Date',
    'userNotLoggedIn': 'Utilisateur non connecté',
    'settingsTitle': 'Paramètres',
    'salaryCycleOption': 'Salaire & Cycle',
    'categoriesOption': 'Catégories',
    'categoriesSubtitle': 'Gérez vos catégories',
    'changePasswordOption': 'Changer le mot de passe',
    'checkUpdatesOption': 'Vérifier les mises à jour',
    'resetDataOption': 'Réinitialiser toutes les données',
    'logoutOption': 'Se Déconnecter',
    'guestUser': 'Utilisateur Invité',
    'languageOption': 'Langue',
    'selectLanguage': 'Choisir la langue',
    'customizeCycle': 'Personnaliser le salaire et la date de début pour ce mois.',
    'salaryAmount': 'Montant du Salaire',
    'cycleStartsIn': 'Le cycle commence dans:',
    'cycleStartDay': 'Jour ',
    'cycleHelperText': 'Ce cycle commencera le ',
    'save': 'Enregistrer',
    'currentPassword': 'Mot de passe actuel',
    'newPassword': 'Nouveau mot de passe',
    'confirmNewPassword': 'Confirmer le nouveau mot de passe',
    'passwordUpdateSuccess': 'Mot de passe mis à jour',
    'newPasswordMismatch': 'Les nouveaux mots de passe ne correspondent pas',
    'resetDataTitle': 'Réinitialiser les données',
    'resetDataConfirm': 'Êtes-vous sûr de vouloir supprimer TOUTES les dépenses et réinitialiser votre salaire? Cela ne peut pas être annulé.',
    'deleteAll': 'Tout Supprimer',
    'typeDeleteToConfirm': "Tapez 'delete' pour confirmer:",
    'allDataReset': 'Toutes les données ont été réinitialisées.',
    'updateAvailableTitle': 'Mise à jour disponible 🚀',
    'changelog': 'Nouveautés:',
    'later': 'Plus tard',
    'updateNow': 'Mettre à jour maintenant',
    'upToDate': 'À jour!',
    'checkFailed': 'Échec de la vérification',
    'startDownload': 'Téléchargement...',
    'downloading': 'Téléchargement: ',
    'launchingInstaller': 'Lancement de l\'installateur...',
    'installFailed': 'Échec de l\'installation: ',
    'downloadFailed': 'Échec du téléchargement',
    'manageCategories': 'Gérer les Catégories',
    'addNewCategory': 'Ajouter une Catégorie',
    'categoryName': 'Nom de la Catégorie',
    'categoryNameHint': 'Nom de la Catégorie',
    'selectColor': 'Choisir la Couleur',
    'selectIcon': 'Choisir l\'Icône',
    'createCategory': 'Créer la Catégorie',
    'myCategories': 'Mes Catégories',
    'noCustomCategories': 'Pas de catégories personnalisées.',
    'pleaseLogin': 'Veuillez vous connecter',
    'deleteConfirmationTitle': 'Supprimer la transaction?',
    'deleteConfirmationBody': 'Cette action est irréversible.',
    'deleteAction': 'Supprimer',
    'loanReturned': 'Remboursé',
    'returnedLabel': 'Retourné: ',
    'fixedCharges': 'Charges Fixes',
    'totalFixedCharges': 'Total des Charges',
    'fixedChargesSubtitle': 'Loyer, abonnements, factures',
    'noFixedCharges': 'Aucune charge fixe',
    'addFixedCharge': 'Ajouter',
    'autoApply': 'Appliquer Auto (Récurrent)',
    'waitForDueDate': 'Attendre la date d\'échéance?',
    'insurance': 'Assurance',
    'insuranceSubtitle': 'Suivi des réclamations',
    'addClaim': 'Ajouter Réclamation',
    'settleClaim': 'Régler Réclamation',
    'policyNumber': 'Numéro de Police',
    'applyAllThisMonth': 'Appliquer à ce Mois',
    'applyAllNextMonth': 'Appliquer au Mois Suivant',
    'manualChargesConfirm': "Cela ajoutera toutes les charges fixes 'Manuelles' comme dépenses pour ce cycle.",
    'chargesApplied': 'Charges appliquées avec succès!',
    'dayOfMonth': 'Jour du Mois',
    'autoApplySubtitle': 'Ajouter automatiquement cette dépense chaque mois',
    'waitForDueDateSubtitle': "Si activé, la charge est créée seulement le jour J. Sinon, au début du cycle.",
    'appliedFor': 'Appliqué pour',
    'applyChargeTitle': 'Appliquer la Charge?',
    'apply': 'Appliquer',
    'deleteChargeTitle': 'Supprimer la Charge?',
    'deleteChargeConfirm': 'Supprimer',
    'delete': 'Supprimer',
    'saveChanges': 'Enregistrer les modifications',
    'noInsuranceClaims': 'Aucune réclamation d\'assurance',
    'newClaim': 'Nouvelle Réclamation',
    'addCharge': 'Ajouter Charge',
    'healthInsuranceTitle': 'Assurance Santé',
    'pendingClaimsSection': 'Réclamations en Attente',
    'historySection': 'Historique',
    'newInsuranceClaimTitle': 'Nouvelle Réclamation',
    'claimDescriptionHint': 'Description (ex: Visite Médicale)',
    'totalAmountPaidHint': 'Montant Total Payé',
    'refundedPrefix': 'Remboursé: ',
    'settleRefund': 'Régler le Remboursement',
    'deleteClaimTitle': 'Supprimer la Réclamation?',
    'deleteClaimContent': "Cela supprimera l'historique de la réclamation.",
    'settleClaimTitle': 'Régler la Réclamation',
    'totalPaidPrefix': 'Total Payé: ',
    'refundAmountReceivedLabel': 'Montant du Remboursement Reçu',
    'refundDatePrefix': 'Date de Remboursement: ',
    'confirmRefundBtn': 'Confirmer le Remboursement',
    'fixedChargesDesc': 'Gérer les dépenses récurrentes',
    'manageDebtsDesc': 'Gérer les prêts et dettes',
    'healthInsuranceDesc': 'Suivre les réclamations et remboursements',
    'rolloverHistory': 'Historique de Report',
    'manageRollovers': 'Gérer les reports mensuels',
    'statusApplied': 'Appliqué',
    'statusIgnored': 'Ignoré',
    'enable': 'Activer',
    'disable': 'Désactiver',
    'noHistory': 'Aucun historique',
    'rolloverAvailable': 'Report Disponible',
    'rolloverMessage': 'Vous avez un solde restant du mois dernier.',
    'applyRolloverConfirm': 'Voulez-vous appliquer ce solde ?',
    'yesApply': 'Oui, Appliquer',
    'no': 'Non',
    'versionPrefix': 'Version: ',
    'updatingTitle': 'Mise à jour...',
    'noDebtsMessage': "Vous n'avez aucune dette!",
    'noLendingsMessage': "Vous n'avez prêté d'argent à personne.",
    'unknownLender': 'Prêteur Inconnu',
    'repayLoanTitle': 'Rembourser le Prêt',
    'receivePaymentTitle': 'Recevoir le paiement',
    'amountExceedsDebt': 'Le montant dépasse la dette restante',
    'markAsReturned': 'Marquer comme Retourné',
    'dashboard': 'Tableau de bord',
    'catHousing': 'Logement',
    'catFood': 'Nourriture',
    'catTransport': 'Transport',
    'catUtilities': 'Services Publics',
    'catEntertainment': 'Divertissement',
    'catShopping': 'Achats',
    'catHealth': 'Santé',
    'catOthers': 'Autres',
    'currencyOption': 'Devise',
    'selectCurrency': 'Choisir la Devise',
    'legacyTransactionLabel': 'Ancienne Transaction (Hors-App)',
    'legacyTransactionHint': "N'affecte pas le solde actuel",
  };

  static const Map<String, String> _ar = {
    'manualChargesHeader': 'تطبيق يدوي',
    'allManualApplied': 'تم تطبيق الرسوم!',
    'applyManualTitle': 'تطبيق المصروفات',
    'editClaim': 'تعديل المطالبة',
    'descriptionLabel': 'الوصف',
    'totalAmountLabel': 'المبلغ الإجمالي',
    'updatesChannelName': 'تحديثات التطبيق',
    'updatesChannelDesc': 'إشعارات التحديثات الجديدة',
    'reminderChannelName': 'تذكيرات يومية',
    'reminderChannelDesc': 'تذكير يومي لتسجيل المصروفات',
    'updateTitle': 'تحديث متاح: ',
    'updateBody': 'نسخة جديدة متاحة. اضغط للتحديث.',
    'dailyReminderTitle': 'تذكير يومي 📝',
    'dailyReminderBody': 'لا تنس تسجيل مصروفاتك لليوم!',
    'appTitle': 'متتبع المصروفات', // User correction
    'loginSubtitle': 'أدر مواردك المالية بسهولة',
    'signupSubtitle': 'أنشئ حسابك',
    'loginBtn': 'تسجيل الدخول',
    'signupBtn': 'إنشاء حساب',
    'signupTitle': 'تسجيل جديد',
    'loginTitle': 'الدخول',
    'emailHint': 'البريد الإلكتروني',
    'passwordHint': 'كلمة المرور',
    'confirmPasswordHint': 'تأكيد كلمة المرور',
    'guestLogin': 'المتابعة كضيف',
    'guestLoginFailed': 'فشل دخول الضيف.',
    'passwordMismatch': 'كلمات المرور غير متطابقة',
    'passwordLength': 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
    'toSignupText': 'ليس لديك حساب؟ سجل الآن',
    'toLoginText': 'لديك حساب بالفعل؟ سجل الدخول',
    'orText': 'أو',
    'signInWithGoogle': 'تسجيل الدخول عبر Google',
    'welcomeBack': 'مرحباً بعودتك',
    'totalRemaining': 'المتبقي',
    'income': 'الدخل',
    'spent': 'المصروفات',
    'topSpending': 'الأكثر إنفاقاً',
    'noDataMonth': 'لا توجد بيانات لهذا الشهر',
    'recentActivity': 'النشاط الأخير',
    'viewAll': 'عرض الكل',
    'editTransaction': 'تعديل المعاملة',
    'recordRepayment': 'تسجيل سداد',
    'deleteTransaction': 'حذف المعاملة',
    'cancel': 'إلغاء',
    'confirm': 'تأكيد',
    'totalLoan': 'إجمالي المُقرض: ',
    'remaining': 'المتبقي: ',
    'amountReturned': 'المبلغ المسترد',
    'enterAmount': 'أدخل المبلغ',
    'errorAmountExceeds': 'المبلغ لا يمكن أن يتجاوز الرصيد المتبقي',
    'repaidPrefix': 'تم سداد ',
    'historyTitle': 'السجل',
    'noTransactions': 'لا توجد معاملات',
    'filterAll': 'الكل',
    'filterExpenses': 'مصروفات',
    'filterLoans': 'إقراض',
    'filterIncome': 'دخل',
    'markAsPending': 'وضع قيد الانتظار',
    'borrow': 'اقترض',
    'loansManager': 'إدارة الديون',

    'repay': 'سداد',
    'legacyTransactionLabel': 'معاملة قديمة (قبل التطبيق)',
    'legacyTransactionHint': 'لا تؤثر على الرصيد الحالي',
    'totalBorrowed': 'إجمالي المقترض: ',
    'descHintBorrow': 'ممن تقترض؟',
    'addTransaction': 'إضافة معاملة',
    'saveTransaction': 'حفظ',
    'transactionSaved': 'تم حفظ المعاملة!',
    'transactionUpdated': 'تم تحديث المعاملة!',
    'currencyOption': 'العملة',
    'selectCurrency': 'اختر العملة',
    'invalidAmount': 'الرجاء إدخال مبلغ صحيح',
    'errorPrefix': 'خطأ: ',
    'amountLabel': 'المبلغ',
    'amountHint': '0.00',
    'descLabel': 'الوصف (اختياري)',
    'descLabelLoan': 'اسم الشخص',
    'descHint': 'ما الغرض من هذا؟',
    'descHintLoan': 'لمن تقرض المال؟',
    'categoryLabel': 'الفئة',
    'dateLabel': 'التاريخ',
    'userNotLoggedIn': 'المستخدم غير مسجل الدخول',
    'settingsTitle': 'الإعدادات',
    'salaryCycleOption': 'الراتب والدورة',
    'categoriesOption': 'الفئات',
    'categoriesSubtitle': 'إدارة فئات المصروفات',
    'changePasswordOption': 'تغيير كلمة المرور',
    'checkUpdatesOption': 'التحقق من التحديثات',
    'resetDataOption': 'إعادة تعيين جميع البيانات',
    'logoutOption': 'تسجيل الخروج',
    'guestUser': 'مستخدم ضيف',
    'languageOption': 'اللغة',
    'selectLanguage': 'اختر اللغة',
    'customizeCycle': 'تخصيص الراتب وتاريخ البدء لهذا الشهر.',
    'salaryAmount': 'مبلغ الراتب',
    'cycleStartsIn': 'تبدأ الدورة في:',
    'cycleStartDay': 'يوم ',
    'cycleHelperText': 'ستبدأ هذه الدورة في ',
    'save': 'حفظ',
    'currentPassword': 'كلمة المرور الحالية',
    'newPassword': 'كلمة المرور الجديدة',
    'confirmNewPassword': 'تأكيد كلمة المرور الجديدة',
    'passwordUpdateSuccess': 'تم تحديث كلمة المرور',
    'newPasswordMismatch': 'كلمات المرور الجديدة غير متطابقة',
    'resetDataTitle': 'إعادة تعيين البيانات',
    'resetDataConfirm': 'هل أنت متأكد من حذف جميع المصروفات وإعادة تعيين الراتب؟ لا يمكن التراجع عن هذا.',
    'deleteAll': 'حذف الكل',
    'typeDeleteToConfirm': "اكتب 'delete' للتأكيد:",
    'allDataReset': 'تمت إعادة تعيين جميع البيانات.',
    'updateAvailableTitle': 'تحديث متاح 🚀',
    'changelog': 'سجل التغييرات:',
    'later': 'لاحقاً',
    'updateNow': 'تحديث الآن',
    'upToDate': 'التطبيق محدث!',
    'checkFailed': 'فشل التحقق',
    'startDownload': 'جاري التحميل...',
    'downloading': 'تحميل: ',
    'launchingInstaller': 'تشغيل المثبت...',
    'installFailed': 'فشل التثبيت: ',
    'downloadFailed': 'فشل التحميل',
    'manageCategories': 'إدارة الفئات',
    'addNewCategory': 'إضافة فئة جديدة',
    'categoryName': 'اسم الفئة',
    'categoryNameHint': 'اسم الفئة',
    'selectColor': 'اختر اللون',
    'selectIcon': 'اختر الرمز',
    'createCategory': 'إنشاء الفئة',
    'myCategories': 'فئاتي',
    'noCustomCategories': 'لا توجد فئات مخصصة بعد.',
    'pleaseLogin': 'الرجاء تسجيل الدخول',
    'deleteConfirmationTitle': 'حذف المعاملة؟',
    'deleteConfirmationBody': 'لا يمكن التراجع عن هذا الإجراء.',
    'deleteAction': 'حذف',
    'loanReturned': 'تم السداد',
    'returnedLabel': 'المرتجع: ',
    'fixedCharges': 'مصروفات ثابتة',
    'totalFixedCharges': 'إجمالي المصروفات الثابتة',
    'fixedChargesSubtitle': 'إيجار، اشتراكات، فواتير',
    'noFixedCharges': 'لا توجد مصروفات ثابتة',
    'addFixedCharge': 'إضافة',
    'autoApply': 'تطبيق تلقائي (متكرر)',
    'waitForDueDate': 'انتظار تاريخ الاستحقاق؟',
    'insurance': 'تأمين',
    'insuranceSubtitle': 'تتبع المطالبات',
    'addClaim': 'إضافة مطالبة',
    'settleClaim': 'تسوية مطالبة',
    'policyNumber': 'رقم الوثيقة',
    'applyAllThisMonth': 'تطبيق على هذا الشهر',
    'applyAllNextMonth': 'تطبيق على الشهر القادم',
    'manualChargesConfirm': 'سيؤدي هذا إلى إضافة جميع المصروفات الثابتة اليدوية كمعاملات لهذه الدورة.',
    'chargesApplied': 'تم تطبيق المصروفات بنجاح!',
    'dayOfMonth': 'يوم في الشهر',
    'autoApplySubtitle': 'إضافة هذه المصروفات تلقائياً كل شهر',
    'waitForDueDateSubtitle': 'إذا مفعّل، يتم إنشاء المصروف في يوم الاستحقاق. إذا معطل، في بداية الدورة.',
    'appliedFor': 'تم التطبيق لـ',
    'applyChargeTitle': 'تطبيق المصروف؟',
    'apply': 'تطبيق',
    'deleteChargeTitle': 'حذف المصروف الثابت؟',
    'deleteChargeConfirm': 'حذف',
    'delete': 'حذف',
    'saveChanges': 'حفظ التغييرات',
    'noInsuranceClaims': 'لا توجد مطالبات تأمين بعد',
    'newClaim': 'مطالبة جديدة',
    'addCharge': 'إضافة مصروف',
    'healthInsuranceTitle': 'تأمين صحي',
    'pendingClaimsSection': 'مطالبات معلقة',
    'historySection': 'السجل',
    'newInsuranceClaimTitle': 'مطالبة جديدة',
    'claimDescriptionHint': 'الوصف (مثال: زيارة طبيب)',
    'totalAmountPaidHint': 'المبلغ الإجمالي المدفوع',
    'refundedPrefix': 'تم استرداد: ',
    'settleRefund': 'تسوية الاسترداد',
    'deleteClaimTitle': 'حذف المطالبة؟',
    'deleteClaimContent': 'سيؤدي هذا إلى حذف سجل المطالبة.',
    'settleClaimTitle': 'تسوية المطالبة',
    'totalPaidPrefix': 'الإجمالي المدفوع: ',
    'refundAmountReceivedLabel': 'مبلغ الاسترداد المستلم',
    'refundDatePrefix': 'تاريخ الاسترداد: ',
    'confirmRefundBtn': 'تأكيد الاسترداد',
    'fixedChargesDesc': 'إدارة المصروفات المتكررة',
    'manageDebtsDesc': 'إدارة الديون',
    'healthInsuranceDesc': 'تتبع المطالبات والاسترداد',
    'rolloverHistory': 'سجل ترحيل الرصيد',
    'manageRollovers': 'إدارة الرصيد المرحل',
    'statusApplied': 'مطبق',
    'statusIgnored': 'مرفوض',
    'enable': 'تفعيل',
    'disable': 'تعطيل',
    'noHistory': 'لا يوجد سجل',
    'rolloverAvailable': 'رصيد مرحل متاح',
    'rolloverMessage': 'لديك رصيد متبقي من الشهر الماضي.',
    'applyRolloverConfirm': 'هل تريد تطبيق هذا الرصيد؟',
    'yesApply': 'نعم، تطبيق',
    'no': 'لا',
    'close': 'إغلاق',
    'versionPrefix': 'الإصدار: ',
    'updatingTitle': 'جاري التحديث...',
    'noDebtsMessage': 'ليس لديك ديون!',
    'unknownLender': 'مقرض غير معروف',
    'repayLoanTitle': 'سداد القرض',
    'amountExceedsDebt': 'المبلغ يتجاوز الدين المتبقي',
    'markAsReturned': 'تحديد كمسترد',
    'receivePaymentTitle': 'استلام الدفعة',
    'noLendingsMessage': 'لم تقرض المال لأي شخص.',
    'dashboard': 'لوحة التحكم',
    'catHousing': 'سكن',
    'catFood': 'طعام',
    'catTransport': 'مواصلات',
    'catUtilities': 'فواتير ومرافق',
    'catEntertainment': 'ترفيه',
    'catShopping': 'تسوق',
    'catHealth': 'صحة',
    'catOthers': 'أخرى',
  };
}
