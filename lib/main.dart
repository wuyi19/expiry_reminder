import 'package:flutter/material.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import 'package:sqflite/sqflite.dart'; 
import 'package:path/path.dart'; 
import 'package:intl/intl.dart'; 

// 假设 DatabaseHelper 类的定义
class DatabaseHelper {
  static const _databaseName = 'expiry_reminder.db';
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
        return db.execute(
          'CREATE TABLE $table ($columnId INTEGER PRIMARY KEY, $columnName TEXT, $columnProductionDate TEXT, $columnShelfLifeMonths INTEGER)',
        );
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
}

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
    await _scheduleNotification(name, expiryDate, productionDate); 
    await _loadItems(); 
  } 

  DateTime _calculateExpiryDate(DateTime productionDate, int shelfLifeMonths) { 
    return DateTime( 
      productionDate.year + (productionDate.month + shelfLifeMonths - 1) ~/ 12, 
      (productionDate.month + shelfLifeMonths - 1) % 12 + 1, 
      productionDate.day, 
    ); 
  } 

  Future<void> _scheduleNotification(String name, DateTime expiryDate, DateTime productionDate) async { 
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
      {'days': 30, 'id': 1, 'time': TimeOfDay(hour: 9, minute: 0)},  
      {'days': 15, 'id': 2, 'time': TimeOfDay(hour: 9, minute: 0)},  
      {'days': 7, 'id': 3, 'time': TimeOfDay(hour: 9, minute: 0)},   
      {'days': 3, 'id': 4, 'time': TimeOfDay(hour: 9, minute: 0)},   
      {'days': 1, 'id': 5, 'time': TimeOfDay(hour: 9, minute: 0)},   
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
            '生产日期: ${_formatDate(productionDate)}\n' 
            '过期日期: ${_formatDate(expiryDate)}', 
            scheduledDateTime, 
            platformChannelSpecifics, 
            androidAllowWhileIdle: true,
          ); 
        } 
      } 
    } 
  }
}
