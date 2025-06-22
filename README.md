# Split Smart - Expense Sharing App

A Flutter-based expense sharing application that helps groups manage and split expenses efficiently. Built with Supabase for backend services and real-time features.

## Features

- **User Authentication**: Secure login/register with email verification
- **Password Reset**: Forgot password functionality with OTP verification
- **Group Management**: Create and manage expense groups
- **Expense Tracking**: Add, edit, and categorize expenses
- **Real-time Chat**: Group and direct messaging
- **Expense Splitting**: Automatic calculation of who owes what
- **Payment Tracking**: Mark expenses as paid/unpaid
- **Statistics**: Visual insights into spending patterns
- **CSV Export**: Export expense reports for record keeping
- **Profile Management**: Update user profiles and settings

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Supabase
- **Database**: PostgreSQL
- **Authentication**: Supabase Auth
- **Real-time**: Supabase Realtime
- **Storage**: Supabase Storage

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code
- Supabase account

### Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd split_smart_supabase
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Environment Setup**

   - Create a `.env` file in the root directory
   - Add your Supabase credentials:
     ```
     PROJECT_URL=your_supabase_project_url
     API_KEY=your_supabase_anon_key
     ```

4. **Database Setup**

   - Run the SQL migrations in the `supabase/migrations/` folder
   - Execute them in chronological order (by timestamp)

5. **Email Templates Setup**

   - See [Email Templates Setup Guide](supabase/email_templates/README.md) for detailed instructions
   - Configure password reset and email verification templates in Supabase dashboard

6. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
split_smart_supabase/
├── lib/
│   ├── screens/          # UI screens
│   ├── services/         # Business logic and API calls
│   ├── utils/           # Utility functions
│   └── widgets/         # Reusable UI components
├── supabase/
│   ├── migrations/      # Database migrations
│   └── email_templates/ # Email templates and setup guide
├── assets/              # Images and static files
└── test/               # Unit and widget tests
```

## Authentication Flow

1. **Registration**: User signs up with email and password
2. **Email Verification**: OTP sent to verify email address
3. **Login**: User logs in with verified credentials
4. **Password Reset**: Forgot password with OTP verification

## Key Features

### Expense Management

- Create expense groups
- Add expenses with categories
- Split expenses among group members
- Track payment status
- Generate expense reports

### Real-time Communication

- Group chat for expense discussions
- Direct messaging between users
- Real-time notifications

### Data Export

- CSV export for expense reports
- Detailed breakdowns by group
- Payment summaries

## Configuration

### Supabase Setup

1. Create a new Supabase project
2. Run database migrations
3. Configure Row Level Security (RLS) policies
4. Set up email templates for authentication

### Email Templates

For detailed email template setup instructions, see:
**[📧 Email Templates Setup Guide](supabase/email_templates/README.md)**

This guide includes:

- HTML and text email templates
- Supabase dashboard configuration
- Template customization options
- Troubleshooting tips

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:

- Check the [Email Templates Setup Guide](supabase/email_templates/README.md) for authentication issues
- Review the Supabase documentation
- Open an issue in the repository

## Acknowledgments

- Flutter team for the amazing framework
- Supabase for the backend infrastructure
- The open-source community for various packages and tools
