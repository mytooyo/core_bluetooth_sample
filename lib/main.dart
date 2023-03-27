import 'dart:async';

import 'package:app/chat_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFe9edf0),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _channel = const MethodChannel('com.example/app');
  final _eventChannel = const EventChannel('com.example/app-event');

  late StreamSubscription _subscription;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    // 画面起動時にアドバタイズを開始する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _channel.invokeMethod('startAdvertising');
    });

    _subscription = _eventChannel.receiveBroadcastStream().listen((event) {
      final eventData = event['event'];
      if (eventData == 'connected') {
        setState(() {
          loading = false;
        });
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChatView()),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bluetooth Chat',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'You can connect to another device via Bluetooth\nfor text chatting.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () {
                      setState(() {
                        loading = false;
                      });
                      _channel.invokeMethod('startCentral');
                    },
              child: const Text('START CHAT'),
            ),
            const SizedBox(height: 60),
            SizedBox(
              height: 40,
              child: loading
                  ? const CircularProgressIndicator()
                  : const SizedBox(),
            )
          ],
        ),
      ),
    );
  }
}
