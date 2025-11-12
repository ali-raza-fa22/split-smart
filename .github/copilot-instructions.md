# Split Smart - Copilot Instructions

## Project Overview

Split Smart is a Flutter-based expense sharing application that helps groups manage and split expenses efficiently. It uses Supabase for backend services, real-time features, authentication, and storage.

## Tech Stack

- **Frontend**: Flutter 3.7.2+ (Dart)
- **Backend**: Supabase (PostgreSQL database)
- **Authentication**: Supabase Auth with OTP email verification
- **Real-time**: Supabase Realtime for messaging
- **Storage**: Supabase Storage for avatars
- **Charts**: fl_chart for data visualization
- **State Management**: StatefulWidget pattern

## Key Dependencies

```yaml
supabase_flutter: ^2.9.1
flutter_dotenv: ^5.2.1
intl: ^0.20.2
fl_chart: ^0.69.0
flutter_svg: ^2.2.0
image_picker: ^1.1.2
path_provider: ^2.1.5
permission_handler: ^12.0.0+1
```

## Project Structure

### `/lib/screens/` - UI Screens

- **Authentication Screens**:

  - `login_screen.dart` - User login
  - `register_screen.dart` - User registration
  - `verify_email_screen.dart` - OTP email verification
  - `forgot_password_screen.dart` - Password reset request
  - `reset_password_screen.dart` - Password reset with OTP

- **Main Screens**:

  - `home_screen.dart` - Dashboard with balance display and recent expenses
  - `expenses_screen.dart` - List of all expenses
  - `profile_screen.dart` - User profile management
  - `edit_profile_screen.dart` - Profile editing
  - `stats_screen.dart` - Statistics and charts

- **Chat Screens**:

  - `chat_list_screen.dart` - List of direct messages and groups
  - `chat_detail_screen.dart` - Direct message conversation
  - `group_chat_detail_screen.dart` - Group message conversation

- **Group Management**:

  - `create_group_screen.dart` - Create new expense group
  - `group_management_screen.dart` - Manage group members and settings

- **Expense Management**:

  - `add_expense_screen.dart` - Add new expense to group
  - `all_expenses_screen.dart` - View all expenses
  - `all_expense_shares_screen.dart` - View user's expense shares
  - `all_created_expenses_screen.dart` - View expenses created by user

- **Balance & Transactions**:
  - `all_balance_transactions_screen.dart` - Transaction history
  - `balance_transaction_detail_screen.dart` - Transaction details

### `/lib/services/` - Business Logic

#### `auth.dart` - Authentication Service

- User registration and login
- Email verification with OTP
- Password reset functionality
- Profile management
- Session handling

**Key Methods**:

```dart
Future<AuthResponse> register({required String email, required String password})
Future<AuthResponse> login({required String email, required String password})
Future<void> sendOTP(String email)
Future<AuthResponse> verifyOTP({required String email, required String token})
Future<void> sendPasswordResetOTP(String email)
Future<void> resetPasswordWithOTP({required String email, required String token, required String newPassword})
Future<Map<String, dynamic>?> getUserProfile()
Future<void> updateProfile({String? username, String? displayName, String? avatarUrl})
```

#### `balance_service.dart` - Balance Management

- User balance tracking
- Transaction history (add, spend, loan, repay)
- Automatic loan repayment when adding balance
- Balance statistics

**Key Methods**:

```dart
Future<Map<String, dynamic>?> getUserBalance()
Future<Map<String, dynamic>> addBalance({required double amount, required String title, String? description})
Future<Map<String, dynamic>> spendFromBalance({required double amount, required String title, String? description, String? expenseShareId, String? groupId})
Future<void> repayLoan({required double amount, required String title, String? description})
Future<List<Map<String, dynamic>>> getTransactionHistory({String? transactionType, int? limit, int? offset})
Future<double> getCurrentBalance()
Future<double> getOutstandingLoan()
```

**Transaction Types**:

- `add` - Add money to balance
- `spend` - Spend from balance
- `loan` - Take a loan when balance is insufficient
- `repay` - Repay outstanding loan

**Important Balance Logic**:

- When adding balance, outstanding loans are automatically repaid first
- When spending, if balance is insufficient, the remainder is taken as a loan
- Loans must be repaid before the balance can be used freely

#### `chat_service.dart` - Chat & Expense Management

Handles both messaging and expense-related functionality.

**Group Management**:

```dart
Future<String> createGroup({required String name, required List<String> memberIds})
Future<List<Map<String, dynamic>>> getUserGroups()
Future<List<Map<String, dynamic>>> getGroupMembers(String groupId)
Future<bool> isGroupAdmin(String groupId)
Future<void> addMemberToGroup({required String groupId, required String userId})
Future<void> removeMemberFromGroup({required String groupId, required String userId})
Future<void> renameGroup({required String groupId, required String newName})
Future<void> deleteGroup(String groupId)
```

**Messaging**:

```dart
Future<void> sendGroupMessage({required String groupId, required String content, String category = 'general', Map<String, dynamic>? expenseData, Map<String, dynamic>? paymentData})
Future<List<Map<String, dynamic>>> getGroupChatHistory(String groupId)
Future<void> sendMessage({required String receiverId, required String content})
Future<List<Map<String, dynamic>>> getChatHistory(String otherUserId)
Future<void> markMessagesAsRead(String senderId)
Future<void> markGroupMessagesAsRead(String groupId)
```

**Message Categories**:

- `general` - Regular chat messages
- `expense` - Expense creation notifications
- `payment` - Payment confirmation messages

**Expense Management**:

```dart
Future<String> createExpense({required String groupId, required String title, required double totalAmount, required String paidBy, String? description})
Future<List<Map<String, dynamic>>> getGroupExpenses(String groupId)
Future<List<Map<String, dynamic>>> getUserExpenseShares()
Future<List<Map<String, dynamic>>> getUserCreatedExpenses()
Future<Map<String, dynamic>> markExpenseShareAsPaid(String expenseShareId)
Future<Map<String, dynamic>> getGroupExpenseSummary(String groupId)
Future<List<Map<String, dynamic>>> getAllUserExpenses()
```

**Real-time Streams**:

```dart
Stream<List<Map<String, dynamic>>> subscribeToGroupMessages(String groupId)
Stream<List<Map<String, dynamic>>> subscribeToMessages(String otherUserId)
Stream<void> getGroupMessagesStream()
Stream<void> getDirectMessagesStream()
```

#### `csv_export_service.dart` - CSV Export

- Export balance transactions to CSV
- Export expense data to CSV

#### `transaction_export_service.dart` - Transaction Export

- Generate transaction reports

### `/lib/widgets/` - Reusable Components

**Dialogs**:

- `add_balance_dialog.dart` - Dialog to add balance with default titles
- `categoryfilter_dialog.dart` - Filter expenses by category
- `datefilter_dialog.dart` - Filter by date range
- `details_modal.dart` - Generic details modal
- `expense_details_modal.dart` - Expense details with payment status
- `edit_group_name_dialog.dart` - Edit group name

**UI Components**:

- `auth_wrapper.dart` - Authentication state wrapper
- `brand_button_2.dart` - Custom styled button
- `chat_list_item.dart` - Chat list item with unread badge
- `csv_export_button.dart` - CSV export button
- `empty_chat_state.dart` - Empty state for chat
- `empty_state.dart` - Generic empty state
- `expense_list_item.dart` - Expense list item
- `group_actions_bottom_sheet.dart` - Group action bottom sheet
- `pie_chart_widget.dart` - Pie chart visualization
- `profile_card.dart` - User profile card
- `save_transaction_button.dart` - Save transaction button
- `stat_item.dart` - Statistics item

## Quick guidance for AI contributors

This Flutter app (SPLITSMART) is a Supabase-backed expense-sharing project. Keep guidance short and actionable so an AI agent can be productive immediately.

Key patterns (refer to these files when making changes):

- Supabase client singleton: `final supabase = Supabase.instance.client;` (used across `lib/services/*`, e.g. `lib/services/auth.dart`).
- Service layer lives in `lib/services/` and returns plain Maps/Lists from Supabase queries (e.g. `Future<List<Map<String,dynamic>>>`).
- UI screens under `lib/screens/` follow StatefulWidget + async load patterns (see `home_screen.dart`, `login_screen.dart`).
- Reusable helpers in `lib/utils/app_utils.dart` (validation, formatting) — prefer using these utilities.
- Theme/colors in `lib/theme/theme.dart` — use Theme.of(context) and the app's color tokens.

What to do first when editing code:

- Read the service in `lib/services/` that a screen depends on (e.g. `auth.dart`, `balance_service.dart`, `chat_service.dart`).
- Preserve Supabase RLS assumptions: services expect authenticated user context and rely on server policies.

Concrete examples to copy/paste

- Supabase singleton usage:

```dart
/// Use the shared Supabase client
final supabase = Supabase.instance.client;
```

- Comment style for public helpers (put examples above functions):

```dart
/// Get current timestamp in "yyyyMMddHHmmss" format
static String getCurrentTimestamp() {
  final currentTime = DateTime.now();
  return '${currentTime.year}${currentTime.month.toString().padLeft(2,'0')}${currentTime.day.toString().padLeft(2,'0')}${currentTime.hour.toString().padLeft(2,'0')}${currentTime.minute.toString().padLeft(2,'0')}${currentTime.second.toString().padLeft(2,'0')}';
}
```

Developer workflows & commands (Windows PowerShell):

- Install deps: `flutter pub get`
- Run app on default device: `flutter run`
- Run tests: `flutter test`
- Build APK: `flutter build apk --release`
- Optional: adb over Wi‑Fi (for Android debugging):
  ```powershell
  adb tcpip 5555; adb connect <device-ip>:5555
  flutter run -d <device-id>
  ```

Project-specific conventions

- Keep business logic in `lib/services/*`; UI code in `lib/screens/*`; shared widgets in `lib/widgets/*`.
- Services should be small, stateless wrappers around Supabase calls and return JSON-like Dart maps/lists. Callers transform into UI models.
- Real-time behavior: prefer using Streams returned by services (see `chat_service.dart`) and cancel subscriptions in `dispose()`.

Integration points to watch

- Supabase (env vars in `.env`): `SUPABASE_URL`, `SUPABASE_ANON_KEY` (loaded with `flutter_dotenv`).
- SQL/migrations are under `supabase/` — if schema changes, update SQL and Supabase RLS policies.
- Storage (avatars) uses Supabase Storage — check bucket policies when image upload fails.

When to ask the repo owner

- Any schema or RLS changes. They must be tested on Supabase dashboard.
- If a new real-time channel is required (add to `chat_service.dart` patterns).

If you change behavior, add a small manual test note showing how to exercise it (screen, expected data, quick checks).

Short checklist for PRs from AI edits

- Include a 1-line summary and one manual test step in PR description.
- Reference which service/screen was changed and why.
- If schema changes, include required SQL and RLS updates (or call out that a migration is needed).

Feedback: tell me which part felt unclear (auth flows, balance rules, or realtime) and I'll expand the section with concrete files/examples.

- `user_id` (UUID, references profiles.id)
- `current_balance` (numeric, default 0)
- `total_added` (numeric, default 0)
- `total_spent` (numeric, default 0)
- `total_loans` (numeric, default 0)
- `total_repaid` (numeric, default 0)
- `created_at` (timestamp)
- `updated_at` (timestamp)

**balance_transactions**

- `id` (UUID, primary key)
- `user_id` (UUID, references profiles.id)
- `transaction_type` (text: 'add', 'spend', 'loan', 'repay')
- `amount` (numeric)
- `title` (text)
- `description` (text, nullable)
- `expense_share_id` (UUID, nullable, references expense_shares.id)
- `group_id` (UUID, nullable, references groups.id)
- `created_at` (timestamp)

**messages** (Direct Messages)

- `id` (UUID, primary key)
- `sender_id` (UUID, references profiles.id)
- `receiver_id` (UUID, references profiles.id)
- `content` (text)
- `is_read` (boolean, default false)
- `is_deleted` (boolean, default false)
- `deleted_for_users` (text[], array of user IDs)
- `created_at` (timestamp)

**group_messages**

- `id` (UUID, primary key)
- `group_id` (UUID, references groups.id)
- `sender_id` (UUID, references profiles.id)
- `content` (text)
- `category` (text: 'general', 'expense', 'payment')
- `expense_data` (jsonb, nullable)
- `payment_data` (jsonb, nullable)
- `is_deleted` (boolean, default false)
- `deleted_for_users` (text[], array of user IDs)
- `created_at` (timestamp)

**group_message_reads**

- `id` (UUID, primary key)
- `message_id` (UUID, references group_messages.id)
- `user_id` (UUID, references profiles.id)
- `read_at` (timestamp)

**default_balance_titles**

- `id` (UUID, primary key)
- `title` (text)
- `category` (text: 'income', 'expense')
- `is_active` (boolean)

## Key Features & Workflows

### 1. User Authentication Flow

1. User registers with email and password
2. OTP is sent to email for verification
3. User verifies email with OTP code
4. Profile is created automatically after verification
5. User can reset password using OTP if forgotten

### 2. Balance Management Flow

1. User adds balance through "Add Balance" dialog
2. System checks for outstanding loans
3. If loans exist, balance is used to auto-repay first
4. Remaining balance is added to user's account
5. All transactions are logged in `balance_transactions`

### 3. Expense Creation & Payment Flow

1. Admin creates a group and adds members
2. Any member can create an expense
3. Database trigger automatically creates equal expense shares for all members
4. Expense notification is sent to group chat
5. Members mark their share as paid
6. Payment deducts from balance or creates loan if insufficient
7. Payment confirmation is sent to group chat

### 4. Group Chat Flow

1. Messages support three categories: general, expense, payment
2. Real-time updates via Supabase streams
3. Unread message tracking with read receipts
4. Messages can be deleted for self or everyone

### 5. Statistics & Reports

1. Dashboard shows current balance, outstanding loans, recent expenses
2. Stats screen displays charts and spending patterns
3. CSV export available for transactions
4. Expense summaries per group

## Coding Patterns & Best Practices

### 1. Service Layer Pattern

```dart
// Services are stateless and use Supabase client
final supabase = Supabase.instance.client;

// Always handle errors with try-catch
Future<void> someMethod() async {
  try {
    final result = await supabase.from('table').select();
    return result;
  } catch (e) {
    rethrow; // Let caller handle the error
  }
}
```

### 2. State Management

```dart
// Use StatefulWidget with async data loading
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await someService.getData();
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Show error
    }
  }
}
```

### 3. Real-time Subscriptions

```dart
// Subscribe to changes and rebuild UI
StreamSubscription? _subscription;

@override
void initState() {
  super.initState();
  _subscription = _chatService
    .subscribeToGroupMessages(groupId)
    .listen((messages) {
      setState(() => _messages = messages);
    });
}

@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

### 4. Error Handling

```dart
// Always show user-friendly error messages
try {
  await someOperation();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Success message')),
    );
  }
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Something bad happened.')),
    );
  }
}
```

### 5. Navigation

```dart
// Use named routes for main screens
Navigator.of(context).pushReplacementNamed('/login');

// Use MaterialPageRoute for detail screens
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => DetailScreen(id: id),
  ),
);

// Pop with result
Navigator.pop(context, true);
```

### 6. Theme Usage

```dart
// Access theme colors
final colorScheme = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;

// Use theme colors
Container(
  color: colorScheme.primary,
  child: Text(
    'Title',
    style: textTheme.titleLarge?.copyWith(
      color: colorScheme.onPrimary,
    ),
  ),
)
```

### 7. Data Transformation

```dart
// Services return List<Map<String, dynamic>>
// Transform data before displaying

// Example: Combine data from multiple tables
final expenses = await supabase.from('expenses').select('*');
final profiles = await supabase.from('profiles').select('*').inFilter('id', userIds);

final profilesMap = {for (var p in profiles) p['id']: p};
final result = expenses.map((expense) => {
  ...expense,
  'profiles': profilesMap[expense['paid_by']],
}).toList();
```

## Error Handling Strategy

We follow a consistent, testable pattern for error handling so errors are logged, user-friendly, and safe.

- Centralize exception types in `lib/utils/app_exceptions.dart` (example):

```dart
/// lib/utils/app_exceptions.dart
abstract class AppException implements Exception { final String message; final String? code; final dynamic originalError; AppException(this.message,{this.code,this.originalError}); }
class AppAuthException extends AppException { AppAuthException(String message,{String? code,dynamic originalError}): super(message, code: code, originalError: originalError); }
class NetworkException extends AppException { NetworkException(String message,{String? code,dynamic originalError}): super(message, code: code, originalError: originalError); }
class DatabaseException extends AppException { DatabaseException(String message,{String? code,dynamic originalError}): super(message, code: code, originalError: originalError); }
class ValidationException extends AppException { final Map<String,String>? fieldErrors; ValidationException(String message,{this.fieldErrors,String? code,dynamic originalError}): super(message, code: code, originalError: originalError); }
class BusinessLogicException extends AppException { BusinessLogicException(String message,{String? code,dynamic originalError}): super(message, code: code, originalError: originalError); }
class UnknownException extends AppException { UnknownException(String message,{String? code,dynamic originalError}): super(message, code: code, originalError: originalError); }
```

- Convert low-level errors to AppExceptions using `lib/services/error_handler_service.dart`.
  - The service maps `PostgrestException`, Supabase auth/storage exceptions, network errors and generic exceptions to typed `AppException`s and logs via `LoggerService`.
  - Example usage inside a service method:

```dart
final _errorHandler = ErrorHandlerService();
try {
  final res = await supabase.from('profiles').select().eq('id', id).single();
  return res;
} catch (e) {
  // If it's already an AppException, rethrow to preserve code/message
  if (e is AppException) rethrow;
  // Convert and rethrow
  throw _errorHandler.handleError(e, context: 'ProfileService.getProfile');
}
```

- Auth service pattern (example in `lib/services/auth.dart`):

```dart
try {
  final resp = await supabase.auth.signInWithPassword(email: email, password: pwd);
  return resp;
} catch (e) {
  throw _errorHandler.handleError(e, context: 'AuthService.login');
}
```

- UI handling: surface typed errors with a helper widget `lib/widgets/error_display.dart`.
  - Use `ErrorDisplay.showErrorSnackBar(context, error)` to show friendly messages.
  - For critical screens use a full-page `ErrorStateWidget` with a retry callback.

Example in a login/register screen:

```dart
try {
  await _authService.login(email: e, password: p);
} on AppAuthException catch (e) {
  if (e.code == 'EMAIL_NOT_CONFIRMED') {
    Navigator.push(... VerifyEmailScreen(...));
  } else {
    ErrorDisplay.showErrorSnackBar(context, e);
  }
} on AppException catch (e) {
  ErrorDisplay.showErrorSnackBar(context, e);
} catch (e) {
  ErrorDisplay.showErrorSnackBar(context, UnknownException('An unexpected error occurred'));
}
```

- Logger: `lib/services/logger_service.dart` is used for contextual logging. In debug it prints details; in production wire it to Crashlytics/Sentry.

- Service checklist (apply to all services):

  1. Validate inputs early. Throw `ValidationException`/`BusinessLogicException` for user input/flow errors.
  2. Wrap Supabase calls in try/catch.
  3. If caught error is an `AppException` rethrow it.
  4. Otherwise call `ErrorHandlerService.handleError(e, context: ...)` and throw the returned `AppException`.
  5. Keep UI-friendly messages in `AppException.message` and use `code` for programmatic branching.

- Testing: add unit tests for `ErrorHandlerService` mappings (example test file `test/services/error_handler_service_test.dart`) and for services to ensure they throw `AppException` types on failures.

## Testing

### Manual Testing Checklist

- [ ] User registration and email verification
- [ ] Login and logout
- [ ] Password reset
- [ ] Profile editing with avatar upload
- [ ] Adding balance with automatic loan repayment
- [ ] Creating groups with multiple members
- [ ] Adding expenses to groups
- [ ] Marking expenses as paid
- [ ] Sending direct messages
- [ ] Sending group messages
- [ ] Real-time message updates
- [ ] Unread message badges
- [ ] CSV export
- [ ] Statistics charts

## Important Notes

### Security

- All data access is controlled by Supabase RLS (Row Level Security) policies
- Users can only access data they have permission to view
- Authentication required for all operations

### Performance

- Use `.limit()` on queries to avoid fetching too much data
- Implement pagination for large lists
- Use real-time streams only when necessary
- Clean up subscriptions in `dispose()`

### Currency

- All amounts are in PKR (Pakistani Rupees)
- Currency symbol: `Rs`
- Always format amounts to 2 decimal places

### Database Triggers

- Profile creation trigger: Creates user balance when profile is created
- Expense shares trigger: Automatically creates equal shares for all group members when expense is created
- Balance update trigger: Updates `user_balances` when transactions are created

### Constraints

- Maximum group members: Defined in `AppConstants.maxMembersAllowed`
- Email must be verified before accessing the app
- Group admin cannot remove themselves
- Cannot repay more than outstanding loan amount

## Common Tasks

### Adding a New Screen

1. Create screen file in `/lib/screens/`
2. Implement StatefulWidget
3. Add navigation route
4. Follow existing screen patterns

### Adding a New Service Method

1. Add method to appropriate service file
2. Follow async/await pattern
3. Use try-catch for error handling
4. Return appropriate data types
5. Document with comments

### Adding a New Widget

1. Create widget file in `/lib/widgets/`
2. Make it reusable with parameters
3. Use theme colors and text styles
4. Add to appropriate screen

### Modifying Database Schema

1. Update Supabase schema via SQL or dashboard
2. Update RLS policies if needed
3. Update service methods to match new schema
4. Test thoroughly

## Troubleshooting

### Common Issues

1. **Real-time not working**: Check Supabase Realtime is enabled for tables
2. **RLS errors**: Verify user has correct permissions in Supabase policies
3. **State not updating**: Ensure `setState()` is called and widget is mounted
4. **Navigation errors**: Check route names and context
5. **Image upload fails**: Verify storage bucket permissions and policies

### Debug Tips

- Use `print()` statements for quick debugging
- Check Supabase logs for database errors
- Use Flutter DevTools for performance issues
- Test authentication flow in incognito/private mode

## Environment Setup

### Prerequisites

- Flutter SDK 3.7.2+
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Supabase account

### Configuration

1. Create `.env` file in project root
2. Add Supabase credentials:

```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

3. Configure Supabase in app:

```dart
await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL']!,
  anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
);
```

## Resources

- Flutter Documentation: https://flutter.dev/docs
- Supabase Documentation: https://supabase.io/docs
- fl_chart Documentation: https://pub.dev/packages/fl_chart
