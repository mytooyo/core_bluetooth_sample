import 'dart:async';

import 'package:flutter/services.dart';

class ChatModel {
  final String message;
  final DateTime date;
  final bool isMe;

  ChatModel({required this.message, required this.date, required this.isMe});
}

class ChatStreamController {
  /// データリスト
  final List<ChatModel> list = [];

  final StreamController<List<ChatModel>> _controller =
      StreamController<List<ChatModel>>.broadcast();

  Stream<List<ChatModel>> get stream => _controller.stream;

  final _channel = const MethodChannel('com.example/app');
  final _eventChannel = const EventChannel('com.example/app-event');
  late StreamSubscription _subscription;

  ChatStreamController() {
    _subscription = _eventChannel.receiveBroadcastStream().listen((event) {
      final eventData = event['event'];
      if (eventData == 'onmessage') {
        final data = event['body']!['data'];
        list.add(ChatModel(message: data, date: DateTime.now(), isMe: false));
        _controller.sink.add(list);
      }
    });
  }

  void dispose() {
    _subscription.cancel();
    _controller.sink.close();
    _channel.invokeMethod('stopCentral');
  }

  /// メッセージ送信
  void send(String text) {
    _channel.invokeMethod('send', {'data': text});

    list.add(ChatModel(message: text, date: DateTime.now(), isMe: true));
    _controller.sink.add(list);
  }
}
