import 'package:flutter/material.dart';

import 'chat_stream.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  bool enabled = false;

  final streamController = ChatStreamController();

  @override
  void dispose() {
    streamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHAT'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              child: Container(
                color: Colors.transparent,
                child: StreamBuilder<List<ChatModel>>(
                  initialData: const [],
                  stream: streamController.stream,
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return const Center(
                        child: Text('No Message'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 8,
                      ),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final chat = snapshot.data![index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: messageContainer(chat),
                        );
                      },
                    );
                  },
                ),
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _textField),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _sendButton,
                ),
              ],
            ),
          ),
          Container(
            height: MediaQuery.of(context).padding.bottom,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget get _textField {
    return TextFormField(
      controller: textController,
      focusNode: focusNode,
      minLines: 1,
      maxLines: 4,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        hintText: 'Aa',
        hintStyle: Theme.of(context).textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: Theme.of(context).textTheme.bodyMedium,
      onChanged: (value) {
        setState(() {
          enabled = value.isNotEmpty;
        });
      },
    );
  }

  Widget get _sendButton {
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: enabled
            ? () {
                streamController.send(textController.text);
                textController.clear();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.4,
            child: Icon(
              Icons.send_rounded,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget messageContainer(ChatModel chat) {
    Widget c = Flexible(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: chat.isMe
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
        ),
        child: Text(
          chat.message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: chat.isMe ? Colors.white : null,
              ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment:
          chat.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [c],
    );
  }
}
