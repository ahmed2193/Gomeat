import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:gomeat/Theme/nativeTheme.dart';
import 'package:gomeat/l10n/l10n.dart';
import 'package:gomeat/models/businessLayer/global.dart' as global;
import 'package:gomeat/models/localNotificationModel.dart';
import 'package:gomeat/provider/local_provider.dart';
import 'package:gomeat/screens/splashScreen.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'networking/my_http_overrides.dart';

late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  HttpOverrides.global = new MyHttpOverrides();
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(Phoenix(child: MyApp()));
}

AndroidNotificationChannel channel = const AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Channel Description',
  importance: Importance.high,
);
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.

  print('Handling a background message ${message.messageId}');
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => new MyAppState();
}

class MyAppState extends State<MyApp> {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);
  final String routeName = "main";

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (context) => LocaleProvider(),
        builder: (context, child) {
          final provider = Provider.of<LocaleProvider>(context);
          return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Vegakart',
              navigatorObservers: <NavigatorObserver>[observer],
              theme: nativeTheme(
                  isDarkModeEnable:
                      global.isDarkModeEnable), //ThemeData.dark(), //

              locale: provider.locale,
              supportedLocales: L10n.all,
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              home: SplashScreen(
                a: analytics,
                o: observer,
              ));
        },
      );

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false, // Required to display a heads up notification
      badge: true,
      sound: true,
    );
    var initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        LocalNotification _notificationModel =
            LocalNotification.fromJson(message.data);
        global.localNotificationModel = _notificationModel;
        setState(() {
          global.isChatNotTapped = false;
        });

        print('Got a message whilst in the foreground!');
        print('${message.data['0']}');
        print('Message data: ${message.data}');

        Future<String> _downloadAndSaveFile(String url, String fileName) async {
          final Directory directory = await getApplicationDocumentsDirectory();
          final String filePath = '${directory.path}/$fileName';
          final http.Response response = await http.get(Uri.parse(url));
          final File file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          return filePath;
        }

        if (Platform.isAndroid) {
          final String bigPicturePath = await _downloadAndSaveFile(
              message.notification!.android!.imageUrl != null
                  ? message.notification!.android!.imageUrl!
                  : 'https://picsum.photos/200/300',
              'bigPicture');

          final BigPictureStyleInformation bigPictureStyleInformation =
              BigPictureStyleInformation(
            FilePathAndroidBitmap(bigPicturePath),
          );
          final AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(channel.id, channel.name,
                  channelDescription: channel.description,
                  icon: '@mipmap/ic_notification',
                  styleInformation: bigPictureStyleInformation);
          final AndroidNotificationDetails androidPlatformChannelSpecifics2 =
              AndroidNotificationDetails(channel.id, channel.name,
                  channelDescription: channel.description,
                  icon: '@mipmap/ic_notification',
                  styleInformation:
                      BigTextStyleInformation(message.notification!.body!)
                  // styleInformation:   message.notification.android.imageUrl != null  ? bigPictureStyleInformation : BigPictureStyleInformation
                  );
          final NotificationDetails platformChannelSpecifics =
              NotificationDetails(
                  android: message.notification!.android!.imageUrl != null
                      ? androidPlatformChannelSpecifics
                      : androidPlatformChannelSpecifics2);

          flutterLocalNotificationsPlugin.show(1, message.notification!.title,
              message.notification!.body, platformChannelSpecifics);
        } else if (Platform.isIOS) {
          final String bigPicturePath = await _downloadAndSaveFile(
              message.notification!.apple!.imageUrl != null
                  ? message.notification!.apple!.imageUrl!
                  : 'https://picsum.photos/200/300',
              'bigPicture.jpg');
          final DarwinNotificationDetails iOSPlatformChannelSpecifics =
              DarwinNotificationDetails(
                  attachments: <DarwinNotificationAttachment>[
                DarwinNotificationAttachment(bigPicturePath)
              ]);
          final DarwinNotificationDetails iOSPlatformChannelSpecifics2 =
              DarwinNotificationDetails(badgeNumber: 1);
          final NotificationDetails notificationDetails = NotificationDetails(
            iOS: message.notification!.apple!.imageUrl != null
                ? iOSPlatformChannelSpecifics
                : iOSPlatformChannelSpecifics2,
          );
          await flutterLocalNotificationsPlugin.show(
              1,
              message.notification!.title,
              message.notification!.body,
              notificationDetails);
        }

        print('Message also contained a notification: ${message.notification}');
      } catch (e) {
        print('Exception - main.dart - onMessage.listen(): ' + e.toString());
      }
    });
  }
}
// 9915103389