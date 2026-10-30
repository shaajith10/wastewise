import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _txs = [];
  List<Map<String, dynamic>> _myVouchers = [];
  List<Map<String, dynamic>> _catalog = [];
  bool _loading = true;
  String? _error;

  final List<Map<String, dynamic>> _defaultCatalog = [
    {
      'id': 'v_elec',
      'title': '\$10 Electricity / Utility Credit',
      'cost': 300,
      'category': 'Utilities',
      'icon': Icons.electric_bolt,
      'color': const Color(0xFF1976D2),
      'perk': 'Direct credit applied to municipal electricity or water bill',
    },
    {
      'id': 'v_groc',
      'title': '\$5 Eco Grocery Supermarket Voucher',
      'cost': 150,
      'category': 'Shopping',
      'icon': Icons.shopping_bag,
      'color': const Color(0xFF388E3C),
      'perk': 'Usable at partner retail & organic grocery stores',
    },
    {
      'id': 'v_bus',
      'title': 'Free 7-Day Public Transit Bus Pass',
      'cost': 250,
      'category': 'Transport',
      'icon': Icons.directions_bus,
      'color': const Color(0xFF7B1FA2),
      'perk': 'Unlimited 7-day municipal bus transit across all city zones',
    },
    {
      'id': 'v_tree',
      'title': 'Plant a Community Tree in Your Name',
      'cost': 100,
      'category': 'Eco Contribution',
      'icon': Icons.park,
      'color': const Color(0xFF2E7D32),
      'perk': 'A real sapling planted and geo-tagged with your certificate',
    },
    {
      'id': 'v_coffee',
      'title': 'Free Hot Beverage / Artisan Cafe Voucher',
      'cost': 80,
      'category': 'Food & Drink',
      'icon': Icons.local_cafe,
      'color': const Color(0xFF8D6E63),
      'perk': 'Free coffee or tea in a reusable cup at local participating cafes',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    // 1. Sync user profile for real-time balance
    try {
      await context.read<AuthProvider>().refreshProfile();
    } catch (_) {}

    // 2. Load catalog safely
    try {
      final catalogData = await ApiClient.get('/rewards/catalog');
      final list = catalogData['catalog'] as List?;
      if (list != null && list.isNotEmpty) {
        _catalog = List<Map<String, dynamic>>.from(list);
      } else {
        _catalog = _defaultCatalog;
      }
    } catch (_) {
      _catalog = _defaultCatalog;
    }

    // 3. Load active vouchers safely
    try {
      final voucherData = await ApiClient.get('/rewards/my-vouchers');
      _myVouchers = List<Map<String, dynamic>>.from(voucherData['vouchers'] ?? []);
    } catch (_) {
      _myVouchers = [];
    }

    // 4. Load transactions statement safely
    try {
      final txData = await ApiClient.get('/rewards/transactions');
      _txs = List<Map<String, dynamic>>.from(txData['transactions'] ?? []);
    } catch (_) {
      _txs = [];
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _claimBonus() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final res = await ApiClient.post('/rewards/bonus', {});
      if (mounted) Navigator.pop(context);

      final newBal = (res['newBalance'] as num?)?.toInt();
      if (newBal != null) {
        context.read<AuthProvider>().updateRewardBalance(newBal);
      }

      await _loadAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Claimed +50 Eco-Reward Points! Added to your wallet.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bonus error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _redeemVoucher(Map<String, dynamic> item) async {
    final auth = context.read<AuthProvider>();
    final balance = auth.rewardBalance;
    final cost = (item['cost'] as num?)?.toInt() ?? 100;

    if (balance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient points! You have $balance pts, but $cost pts are needed.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.stars, color: Color(0xFFF57F17)),
            const SizedBox(width: 10),
            const Text('Confirm Redemption'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Redeem "${item['title']}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Points to Deduct:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('-$cost pts', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Remaining Balance: ${balance - cost} pts', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Redeem'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Call backend API to redeem
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final res = await ApiClient.post('/rewards/redeem', {
        'voucherId': item['id'],
        'title': item['title'],
        'cost': cost,
        'category': item['category'],
      });

      if (mounted) Navigator.pop(context); // close progress

      final voucher = res['voucher'] as Map<String, dynamic>? ?? {};
      final newBalance = res['newBalance'] as int? ?? (balance - cost);

      auth.updateRewardBalance(newBalance);

      // Refresh list
      _loadAll();

      if (mounted) {
        _showVoucherPassDialog(voucher.isNotEmpty ? voucher : {
          'title': item['title'],
          'code': 'ECO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.error));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Redemption error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _showVoucherPassDialog(Map<String, dynamic> voucher) {
    final code = voucher['code'] ?? 'ECO-VOUCHER';
    final title = voucher['title'] ?? 'Reward Voucher';
    final expiry = voucher['expiresAt'] != null ? voucher['expiresAt'].toString().substring(0, 10) : '30 days';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.check_circle, color: AppTheme.success, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Voucher Ready!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 20),

            // Voucher Coupon Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  const Text('YOUR REDEMPTION CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  SelectableText(
                    code,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryDark, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  Text('Valid until: $expiry', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Show this coupon code at partner store checkout or apply during utility bill payment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📋 Code copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Code'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecyclingCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        double weight = 5.0;
        int rate = 50;
        String selectedMat = 'Plastic';

        final materials = [
          {'name': 'Plastic', 'rate': 50, 'icon': Icons.recycling},
          {'name': 'Paper & Cardboard', 'rate': 30, 'icon': Icons.description},
          {'name': 'Metals & Aluminum', 'rate': 80, 'icon': Icons.inventory_2},
          {'name': 'E-Waste', 'rate': 150, 'icon': Icons.devices},
          {'name': 'Glass', 'rate': 40, 'icon': Icons.wine_bar},
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            final points = (weight * rate).round();
            final dollarVal = (points / 100).toStringAsFixed(2);

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('♻️ Waste Value Calculator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const Text('See how much you can earn before scheduling a pickup:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 16),
                  const Text('Material Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: materials.map((m) {
                      final sel = selectedMat == m['name'];
                      return ChoiceChip(
                        selected: sel,
                        avatar: Icon(m['icon'] as IconData, size: 16, color: sel ? Colors.white : AppTheme.primary),
                        label: Text('${m['name']} (${m['rate']} pts/kg)'),
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87, fontSize: 12),
                        onSelected: (_) {
                          setModalState(() {
                            selectedMat = m['name'] as String;
                            rate = m['rate'] as int;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated Weight:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryDark)),
                    ],
                  ),
                  Slider(
                    value: weight,
                    min: 1.0,
                    max: 30.0,
                    divisions: 29,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setModalState(() => weight = v),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF388E3C)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Points Earned', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('+$points pts', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(width: 1, height: 40, color: Colors.white24),
                        Column(
                          children: [
                            const Text('Reward Value', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('\$$dollarVal', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/citizen/submit');
                    },
                    child: const Text('Schedule This Pickup Now'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Recent';
    final str = date.toString();
    if (str.length >= 10) return str.substring(0, 10);
    return str;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final balance = auth.rewardBalance;
    final cashValue = (balance / 100).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards & Recycling Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Waste Value Calculator',
            onPressed: _showRecyclingCalculator,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(icon: Icon(Icons.card_giftcard), text: 'Redeem'),
            Tab(icon: const Icon(Icons.confirmation_number_outlined), text: 'My Vouchers (${_myVouchers.length})'),
            const Tab(icon: Icon(Icons.history), text: 'Points Log'),
          ],
        ),
      ),
      body: Column(
        children: [
            // Top Wallet Balance Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wrap (not Row) so the buttons drop to a second line on narrow phones
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.eco, color: Color(0xFFFFD700), size: 16),
                            SizedBox(width: 4),
                            Text('Recycling Rewards Program', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFFD700),
                              backgroundColor: Colors.white12,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: _claimBonus,
                            icon: const Icon(Icons.card_giftcard, size: 15),
                            label: const Text('+50 Pts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white12,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: _showRecyclingCalculator,
                            icon: const Icon(Icons.calculate, size: 16),
                            label: const Text('Calculator', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Total Redeemable Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$balance', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      const Text('PTS', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Cash Value', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text('\$$cashValue', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Recycling Incentive Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tier: ${balance >= 500 ? "Gold Eco-Master" : "Silver Recycler"}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('${balance >= 500 ? "100%" : "${(balance / 500 * 100).toInt()}%"} to Gold', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (balance / 500).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Redeem Catalog
                  _loading
                    ? const LoadingWidget(message: 'Loading rewards catalog...')
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _catalog.length,
                        itemBuilder: (_, i) {
                          final item = _catalog[i];
                          final cost = (item['cost'] as num?)?.toInt() ?? 100;
                          final canAfford = balance >= cost;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: const Color(0xFFE8F5E9),
                                    child: const Icon(Icons.stars, color: Color(0xFFF57F17), size: 28),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text(item['perk'] ?? item['category'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        const SizedBox(height: 6),
                                        Text('$cost points', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: canAfford ? AppTheme.primary : Colors.grey.shade300,
                                      foregroundColor: canAfford ? Colors.white : Colors.grey.shade600,
                                      elevation: canAfford ? 2 : 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      minimumSize: const Size(90, 40), // theme default is full-width, which breaks this Row
                                    ),
                                    onPressed: () => _redeemVoucher(item),
                                    child: Text(canAfford ? 'Redeem' : 'Need ${cost - balance}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                  // Tab 2: My Active Vouchers
                  _loading
                    ? const LoadingWidget(message: 'Loading your vouchers...')
                    : _myVouchers.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.confirmation_number_outlined,
                          title: 'No active vouchers yet',
                          subtitle: 'Redeem your recycling points in the Redeem tab to generate grocery and utility discount passes.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _myVouchers.length,
                          itemBuilder: (_, i) {
                            final v = _myVouchers[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE8F5E9),
                                  child: Icon(Icons.verified, color: AppTheme.success),
                                ),
                                title: Text(v['title'] ?? 'Reward Voucher', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('Code: ${v['code']} • Expires: ${_formatDate(v['expiresAt'])}'),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(60, 32),
                                  ),
                                  onPressed: () => _showVoucherPassDialog(v),
                                  child: const Text('View Pass', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            );
                          },
                        ),

                  // Tab 3: Points Statement Log
                  _loading
                    ? const LoadingWidget(message: 'Loading transactions...')
                    : _txs.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.history,
                          title: 'No transactions yet',
                          subtitle: 'Recycle waste with a collector to earn reward points.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _txs.length,
                          itemBuilder: (_, i) {
                            final tx = _txs[i];
                            final pts = (tx['points'] as num?)?.toInt() ?? 0;
                            final isEarned = pts > 0;
                            final desc = tx['description'] ?? tx['categoryName'] ?? 'Recycling Reward';
                            final date = _formatDate(tx['createdAt']);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isEarned ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                  child: Icon(
                                    isEarned ? Icons.add_task : Icons.redeem,
                                    color: isEarned ? AppTheme.success : AppTheme.error,
                                  ),
                                ),
                                title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                trailing: Text(
                                  '${isEarned ? '+' : ''}$pts pts',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: isEarned ? AppTheme.success : AppTheme.error,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}
