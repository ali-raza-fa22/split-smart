import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth.dart';
import '../services/balance_service.dart';
import '../widgets/profile_card.dart';
import '../widgets/chart_builders.dart';
import '../utils/app_constants.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final BalanceService _balanceService = BalanceService();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _expenseShares = [];
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppConstants.defaultAnimationDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures = await Future.wait([
        _authService.getUserProfile(),
        _chatService.getUserExpenseShares(),
        _chatService.getUserCreatedExpenses(),
        _chatService.getUserGroupsWithDetails(),
        _balanceService.getBalanceStatistics(),
      ]);

      if (mounted) {
        setState(() {
          _profile = futures[0] as Map<String, dynamic>;
          _expenseShares = futures[1] as List<Map<String, dynamic>>;
          _groups = futures[3] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppConstants.loadingError}$e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      AppConstants.loadingMessage,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileCard(profile: _profile),
                        const SizedBox(height: AppConstants.defaultSpacing),
                        ChartBuilders.buildExpenseSharesChart(
                          context,
                          _expenseShares,
                          theme,
                        ),
                        const SizedBox(height: AppConstants.largeSpacing),
                        ChartBuilders.buildGroupActivityChart(
                          context,
                          _groups,
                          theme,
                        ),
                        const SizedBox(height: AppConstants.largeSpacing),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
