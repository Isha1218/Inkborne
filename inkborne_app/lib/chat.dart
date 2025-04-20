import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ChatPage extends StatefulWidget {
  const ChatPage(
      {super.key,
      required this.messages,
      required this.name,
      required this.userMe,
      required this.userChar,
      required this.bookPath,
      required this.avatarFile});

  final List<types.TextMessage> messages;
  final String name;
  final types.User userMe;
  final String bookPath;
  final types.User userChar;
  final String avatarFile;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shadowColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        backgroundColor: const Color(0xffE7D5BD),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage(widget.avatarFile),
            ),
            const SizedBox(width: 20),
            Text(
              widget.name,
              style: GoogleFonts.lato(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Chat(
        timeFormat: DateFormat.jm(),
        showUserAvatars: true,
        customBottomWidget: _buildCustomInput(),
        messages: widget.messages,
        onSendPressed: _handleSendPressed,
        user: widget.userMe,
        scrollPhysics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        bubbleBuilder: _bubbleBuilder,
        theme: DefaultChatTheme(
            inputPadding: EdgeInsets.all(0),
            inputMargin: EdgeInsets.only(bottom: 20, left: 20, right: 20),
            inputContainerDecoration: BoxDecoration(
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(10),
              color: Color(0xffE7D5BD),
              boxShadow: [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(4, 4),
                ),
              ],
            ),
            messageInsetsVertical: 12,
            backgroundColor: Color(0xffE7D5BD),
            receivedMessageBodyTextStyle: TextStyle(
              color: neutral0,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            sentMessageBodyTextStyle: TextStyle(
              color: neutral0,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            dateDividerTextStyle: TextStyle(color: Colors.black54)),
      ),
    );
  }

  Widget _bubbleBuilder(
    Widget child, {
    required types.Message message,
    required bool nextMessageInGroup,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: message.author == widget.userMe
                ? Radius.circular(10)
                : Radius.circular(0),
            bottomRight: message.author == widget.userMe
                ? Radius.circular(0)
                : Radius.circular(10)),
        color: message.author == widget.userMe
            ? Color(0xffE7D5BD)
            : Color.fromARGB(255, 232, 202, 169),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCustomInput() {
    final controller = TextEditingController();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xffE7D5BD),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              offset: const Offset(4, 4),
            ),
          ],
          border: Border.all(color: Colors.black),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                textInputAction: TextInputAction.done,
                maxLines: null,
                controller: controller,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  if (value.trim().isEmpty) return;
                  final message = types.PartialText(text: value.trim());
                  _handleSendPressed(message);
                  controller.clear();
                },
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;

                final message = types.PartialText(text: text);
                _handleSendPressed(message);
                controller.clear();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.send,
                  size: 22,
                  color: Colors.black,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: widget.userMe,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: UniqueKey().toString(),
      text: message.text,
    );
    _addMessage(textMessage);
  }

  void _addMessage(types.TextMessage message) async {
    final docRef =
        FirebaseFirestore.instance.collection('characters').doc(widget.name);
    final snapshot = await docRef.get();
    List<dynamic> currentMessages = snapshot.data()?['messages'] ?? [];
    currentMessages.insert(0, message.text);
    await docRef.update({
      'messages': currentMessages,
    });
    setState(() {
      widget.messages.insert(0, message);
    });
    getCharacterResponse(message.text);
  }

  Future<void> getCharacterResponse(String userInput) async {
    final url = Uri.parse('http://192.168.0.23:5000/get_response');
    try {
      final response = await http.post(url, body: {
        'message': userInput,
        'name': widget.name,
        'fileName': widget.bookPath
      });
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String charResponse = data['response'];
        setState(() {
          widget.messages.insert(
              0,
              types.TextMessage(
                  author: widget.userChar,
                  id: Uuid().v4(),
                  text: charResponse));
        });
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Couldn\'t connect to Flask server: $e');
    }
  }
}
