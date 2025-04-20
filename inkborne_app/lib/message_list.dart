import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inkborne_app/chat.dart';
import 'package:inkborne_app/epub_upload.dart';
import 'package:inkborne_app/message_character.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import 'dart:async';

class MessageList extends StatefulWidget {
  const MessageList({super.key});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  List<MessageCharacter> characters = [];
  List<MessageCharacter> filteredCharacters = [];
  types.User userMe = types.User(id: Uuid().v4());
  TextEditingController searchController = TextEditingController();
  late StreamSubscription<QuerySnapshot> _characterSub;
  Color bgColor = const Color(0xffE7D5BD);

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);

    // Subscribe to Firestore updates
    _characterSub = FirebaseFirestore.instance
        .collection('characters')
        .snapshots()
        .listen((snapshot) {
      final docs = snapshot.docs;

      List<MessageCharacter> loadedCharacters = docs.map((doc) {
        types.User userChar =
            types.User(id: Uuid().v4(), imageUrl: doc['avatar']);
        String file = doc['file'];
        String name = doc['name'];
        String avatar = doc['avatar'];
        var messagesText = doc['messages'];
        List<types.TextMessage> messages = [];

        for (int i = 0; i < messagesText.length; i++) {
          final indexFromOldest = messagesText.length - 1 - i;
          final author = (indexFromOldest % 2 == 0) ? userMe : userChar;
          messages.add(types.TextMessage(
            author: author,
            id: Uuid().v4(),
            text: messagesText[i],
          ));
        }

        return MessageCharacter(name, messages, avatar, file, userChar);
      }).toList();

      setState(() {
        characters = loadedCharacters;
        _applyFilter(); // keep filtering on update
      });
    });
  }

  void _onSearchChanged() {
    setState(() {
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = searchController.text.toLowerCase();
    filteredCharacters = characters
        .where((c) => c.character.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _characterSub.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Message',
                        style: GoogleFonts.zillaSlab(
                            fontWeight: FontWeight.bold, fontSize: 24)),
                    IconButton(
                      style: IconButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) {
                            return EpubUpload();
                          },
                        ));
                      },
                      icon: Icon(Icons.more_vert),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: Colors.black, width: 1),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: searchController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search),
                        hintText: 'Search characters...',
                        border: InputBorder.none,
                        hintStyle: GoogleFonts.lato(fontSize: 15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Friends',
                  style: GoogleFonts.lato(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: filteredCharacters.length,
                  itemBuilder: (context, index) {
                    final character = filteredCharacters[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) {
                              return ChatPage(
                                messages: character.messages,
                                name: character.character,
                                userMe: userMe,
                                bookPath: character.fileName,
                                userChar: character.userChar,
                                avatarFile: character.avatarPath,
                              );
                            },
                          ));
                        },
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 25,
                          child: ClipOval(
                            child: Image.asset(
                              character.avatarPath,
                              fit: BoxFit.cover,
                              width: 50,
                              height: 50,
                            ),
                          ),
                        ),
                        title: Text(
                          character.character,
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                        ),
                        subtitle: character.messages.isNotEmpty
                            ? Text(
                                character.messages[0].text,
                                style: GoogleFonts.lato(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                'No messages yet',
                                style: GoogleFonts.lato(
                                    fontStyle: FontStyle.italic),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
