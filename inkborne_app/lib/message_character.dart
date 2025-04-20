import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class MessageCharacter {
  String character;
  String avatarPath;
  List<types.TextMessage> messages;
  String fileName;
  types.User userChar;

  MessageCharacter(this.character, this.messages, this.avatarPath,
      this.fileName, this.userChar);
}
