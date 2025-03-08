import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '保质期提醒',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _items = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _databaseHelper.initDatabase();
    await _initNotifications();
    await _loadItems();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (Theme.of(context).platform == TargetPlatform.android) {
      final bool? granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestPermission();
      if (granted != true) {
        print('通知权限未授予');
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy年MM月dd日').format(date);
  }

  String _getRemainingDays(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    if (difference < 0) {
      return '已过期';
    } else if (difference == 0) {
      return '今天过期';
    } else {
      return '剩余 $difference 天';
    }
  }

  Color _getStatusColor(DateTime expiryDate) {
    final daysRemaining = expiryDate.difference(DateTime.now()).inDays;
    if (daysRemaining < 0) {
      return Colors.red;
    } else if (daysRemaining <= 7) {
      return Colors.orange;
    } else if (daysRemaining <= 30) {
      return Colors.yellow;
    }
    return Colors.green;
  }

  Future<void> _loadItems() async {
    final items = await _databaseHelper.getItems();
    setState(() {
      _items = items;
    });
  }

  Future<void> _addItem(String name, DateTime productionDate, int shelfLifeMonths) async {
    final expiryDate = _calculateExpiryDate(productionDate, shelfLifeMonths);
    await _databaseHelper.insertItem(name, productionDate, shelfLifeMonths);
    await _scheduleNotification(name, expiryDate);
    await _loadItems();
  }

  DateTime _calculateExpiryDate(DateTime productionDate, int shelfLifeMonths) {
    return DateTime(
      productionDate.year + (productionDate.month + shelfLifeMonths - 1) ~/ 12,
      (productionDate.month + shelfLifeMonths - 1) % 12 + 1,
      productionDate.day,
    );
  }

  Future<void> _scheduleNotification(String name, DateTime expiryDate) async {
    final bool? hasPermission = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();

    if (hasPermission != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('通知权限未授予，无法发送提醒')),
      );
      return;
    }

    final notificationTimes = [
      {'days': 30, 'id': 1, 'time': TimeOfDay(hour: 9, minute: 0)},  // 早上9点
      {'days': 15, 'id': 2, 'time': TimeOfDay(hour: 9, minute: 0)},  // 早上9点
      {'days': 7, 'id': 3, 'time': TimeOfDay(hour: 9, minute: 0)},   // 早上9点
      {'days': 3, 'id': 4, 'time': TimeOfDay(hour: 9, minute: 0)},   // 早上9点
      {'days': 1, 'id': 5, 'time': TimeOfDay(hour: 9, minute: 0)},   // 早上9点
    ];

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'expiry_alerts',
      '保质期提醒',
      channelDescription: '商品保质期提醒通知',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    for (var time in notificationTimes) {
      final scheduledDate = expiryDate.subtract(Duration(days: time['days']!));
      if (scheduledDate.isAfter(DateTime.now())) {
        final notificationTime = time['time'] as TimeOfDay;
        final scheduledDateTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          notificationTime.hour,
          notificationTime.minute,
        );

        if (scheduledDateTime.isAfter(DateTime.now())) {
          await flutterLocalNotificationsPlugin.schedule(
            time['id']!,
            '商品即将过期提醒',
            '$name 将在 ${time['days']} 天后过期\n\n'
            '生产日期: ${DateFormat('yyyy年MM月dd日').format(productionDate)}\n'
            '过期日期: ${DateFormat('yyyy年MM月dd日').format(expiryDate)}',
            scheduledDateTime,
            platformChannelSpecifics,
          );
        }
      }
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.access_time),
            title: Text('按过期时间排序'),
            onTap: () {
              _sortItems('expiry');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.sort_by_alpha),
            title: Text('按名称排序'),
            onTap: () {
              _sortItems('name');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _sortItems(String sortBy) {
    setState(() {
      _items.sort((a, b) {
        if (sortBy == 'expiry') {
          final aExpiry = _calculateExpiryDate(
            DateTime.parse(a['productionDate']),
            a['shelfLifeMonths'],
          );
          final bExpiry = _calculateExpiryDate(
            DateTime.parse(b['productionDate']),
            b['shelfLifeMonths'],
          );
          return aExpiry.compareTo(bExpiry);
        } else {
          return a['name'].compareTo(b['name']);
        }
      });
    });
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> item) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除 ${item['name']} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _databaseHelper.deleteItem(item['id']);
              await _loadItems();
            },
            child: Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('保质期提醒'),
        actions: [
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: () => _showStatistics(context),
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '暂无商品，点击右下角按钮添加',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final productionDate = DateTime.parse(item['productionDate']);
                final expiryDate = _calculateExpiryDate(
                  productionDate,
                  item['shelfLifeMonths'],
                );
                final statusColor = _getStatusColor(expiryDate);

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: Container(
                      width: 4,
                      color: statusColor,
                    ),
                    title: Text(
                      item['name'],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('生产日期: ${_formatDate(productionDate)}'),
                        Text('过期日期: ${_formatDate(expiryDate)}'),
                        Text(
                          _getRemainingDays(expiryDate),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _editItem(context, item),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _showDeleteConfirmation(item),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddItemScreen(context),
        label: Text('添加商品'),
        icon: Icon(Icons.add),
      ),
    );
  }

  Future<void> _navigateToAddItemScreen(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddItemScreen()),
    );
    if (result != null) {
      await _addItem(
        result['name'],
        result['productionDate'],
        result['shelfLifeMonths'],
      );
    }
  }

  Future<void> _editItem(BuildContext context, Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemScreen(
          initialName: item['name'],
          initialProductionDate: DateTime.parse(item['productionDate']),
          initialShelfLifeMonths: item['shelfLifeMonths'],
        ),
      ),
    );
    if (result != null) {
      await _databaseHelper.updateItem(
        item['id'],
        result['name'],
        result['productionDate'],
        result['shelfLifeMonths'],
      );
      await _loadItems();
    }
  }

  Future<void> _showStatistics(BuildContext context) async {
    final statistics = await _calculateStatistics();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatisticsScreen(statistics: statistics),
      ),
    );
  }

  Future<Map<String, dynamic>> _calculateStatistics() async {
    final now = DateTime.now();
    int totalItems = _items.length;
    int expiredItems = 0;
    int nearExpiryItems = 0;
    int safeItems = 0;
    double averageShelfLife = 0;
    
    List<Map<String, dynamic>> expiryByMonth = [];
    Map<int, int> monthlyExpiry = {};

    for (var item in _items) {
      final productionDate = DateTime.parse(item['productionDate']);
      final expiryDate = _calculateExpiryDate(
        productionDate,
        item['shelfLifeMonths'],
      );
      
      final daysUntilExpiry = expiryDate.difference(now).inDays;
      
      if (daysUntilExpiry < 0) {
        expiredItems++;
      } else if (daysUntilExpiry <= 30) {
        nearExpiryItems++;
      } else {
        safeItems++;
      }

      averageShelfLife += item['shelfLifeMonths'];

      // 统计每月过期商品数量
      final expiryMonth = DateTime(expiryDate.year, expiryDate.month);
      monthlyExpiry[expiryMonth.millisecondsSinceEpoch] = 
          (monthlyExpiry[expiryMonth.millisecondsSinceEpoch] ?? 0) + 1;
    }

    if (totalItems > 0) {
      averageShelfLife /= totalItems;
    }

    // 将每月过期数据转换为列表
    monthlyExpiry.forEach((timestamp, count) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      expiryByMonth.add({
        'month': '${date.year}年${date.month}月',
        'count': count,
      });
    });

    // 按时间排序
    expiryByMonth.sort((a, b) => a['month'].compareTo(b['month']));

    return {
      'totalItems': totalItems,
      'expiredItems': expiredItems,
      'nearExpiryItems': nearExpiryItems,
      'safeItems': safeItems,
      'averageShelfLife': averageShelfLife,
      'expiryByMonth': expiryByMonth,
    };
  }
}

class AddItemScreen extends StatefulWidget {
  final String? initialName;
  final DateTime? initialProductionDate;
  final int? initialShelfLifeMonths;

  AddItemScreen({
    this.initialName,
    this.initialProductionDate,
    this.initialShelfLifeMonths,
  });

  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late DateTime _productionDate;
  late int _shelfLifeMonths;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _productionDate = widget.initialProductionDate ?? DateTime.now();
    _shelfLifeMonths = widget.initialShelfLifeMonths ?? 1;
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _productionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && pickedDate != _productionDate) {
      setState(() {
        _productionDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialName == null ? '添加商品' : '编辑商品'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '商品名称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入商品名称';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('生产日期', style: TextStyle(fontSize: 16)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today),
                          SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy年MM月dd日').format(_productionDate),
                            style: TextStyle(fontSize: 16),
                          ),
                          Spacer(),
                          TextButton(
                            onPressed: () => _selectDate(context),
                            child: Text('选择日期'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '保质期（月）',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                  suffixText: '个月',
                ),
                initialValue: _shelfLifeMonths.toString(),
                onChanged: (value) {
                  setState(() {
                    _shelfLifeMonths = int.tryParse(value) ?? 1;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入保质期';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return '请输入有效的保质期';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, {
                      'name': _nameController.text,
                      'productionDate': _productionDate,
                      'shelfLifeMonths': _shelfLifeMonths,
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('保存', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class StatisticsScreen extends StatelessWidget {
  final Map<String, dynamic> statistics;

  const StatisticsScreen({Key? key, required this.statistics}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('统计信息'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(context),
            SizedBox(height: 16),
            _buildStatusCard(context),
            SizedBox(height: 16),
            _buildMonthlyExpiryCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '总体统计',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Divider(),
            _buildStatItem(
              context,
              '商品总数',
              '${statistics['totalItems']}',
              Icons.shopping_bag,
            ),
            _buildStatItem(
              context,
              '平均保质期',
              '${statistics['averageShelfLife'].toStringAsFixed(1)} 个月',
              Icons.calendar_today,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '状态分布',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Divider(),
            _buildStatItem(
              context,
              '已过期',
              '${statistics['expiredItems']}',
              Icons.error_outline,
              color: Colors.red,
            ),
            _buildStatItem(
              context,
              '即将过期',
              '${statistics['nearExpiryItems']}',
              Icons.warning_amber_outlined,
              color: Colors.orange,
            ),
            _buildStatItem(
              context,
              '状态良好',
              '${statistics['safeItems']}',
              Icons.check_circle_outline,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyExpiryCard(BuildContext context) {
    final expiryByMonth = statistics['expiryByMonth'] as List<Map<String, dynamic>>;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '月度过期统计',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Divider(),
            if (expiryByMonth.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无数据'),
              )
            else
              ...expiryByMonth.map((data) => Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['month']),
                    Text(
                      '${data['count']} 件商品',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: 8),
          Text(label),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class DatabaseHelper {
  static const _databaseName = 'shelf_life.db';
  static const _databaseVersion = 1;
  static const table = 'items';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnProductionDate = 'production_date';
  static const columnShelfLifeMonths = 'shelf_life_months';

  late Database _database;

  Future<void> initDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnName TEXT NOT NULL,
            $columnProductionDate TEXT NOT NULL,
            $columnShelfLifeMonths INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertItem(String name, DateTime productionDate, int shelfLifeMonths) async {
    return await _database.insert(
      table,
      {
        columnName: name,
        columnProductionDate: productionDate.toIso8601String(),
        columnShelfLifeMonths: shelfLifeMonths,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getItems() async {
    return await _database.query(table);
  }

  Future<int> updateItem(int id, String name, DateTime productionDate, int shelfLifeMonths) async {
    return await _database.update(
      table,
      {
        columnName: name,
        columnProductionDate: productionDate.toIso8601String(),
        columnShelfLifeMonths: shelfLifeMonths,
      },
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteItem(int id) async {
    return await _database.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
} 