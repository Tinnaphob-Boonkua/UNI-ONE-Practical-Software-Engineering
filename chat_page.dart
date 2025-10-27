import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Simulated users — replace with anything you like
  // final String currentUserId = "dean";
  // final String otherUserId = "secretary";

  final String currentUserId = "secretary";
  final String otherUserId = "dean";

  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create consistent chat ID for both users
  late final List<String> chatId = [currentUserId, otherUserId]..sort();
  late final String combinedChatId = chatId.join('_');

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final messageData = {
      'text': text,
      'senderId': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    // Add message to subcollection
    await _firestore
        .collection('chats')
        .doc(combinedChatId)
        .collection('messages')
        .add(messageData);

    // Update chat summary
    await _firestore.collection('chats').doc(combinedChatId).set({
      'participants': [currentUserId, otherUserId],
      'lastMessage': text,
      'lastAt': FieldValue.serverTimestamp(),
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${otherUserId[0].toUpperCase()}${otherUserId.substring(1)} Chat",
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(combinedChatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data =
                        messages[index].data()! as Map<String, dynamic>;
                    final isMine = data['senderId'] == currentUserId;

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Colors.blueAccent.shade100
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data['text'] ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class ChatPage extends StatefulWidget {
//   const ChatPage({super.key});
//   @override
//   State<ChatPage> createState() => _ChatPageState();
// }

// class _ChatPageState extends State<ChatPage> {
//   final msgCtrl = TextEditingController();
//   final user = FirebaseAuth.instance.currentUser!;
//   late final String otherUserId; // set this for your test
//   late final String chatId;

//   @override
//   void initState() {
//     super.initState();
//     // For your first test, hardcode the other role:
//     // If you log in as dean, chat with secretary (replace with real UID from Firebase console)
//     // Later, you'll fetch this by role or a picker.
//     otherUserId = 'SECRETARY_USER_UID_HERE'; 
//     final a = user.uid.compareTo(otherUserId) <= 0 ? user.uid : otherUserId;
//     final b = user.uid.compareTo(otherUserId) <= 0 ? otherUserId : user.uid;
//     chatId = '${a}_$b';
//   }

//   Future<void> sendMessage() async {
//     final text = msgCtrl.text.trim();
//     if (text.isEmpty) return;
//     final ref = FirebaseFirestore.instance
//         .collection('chats').doc(chatId)
//         .collection('messages').doc();

//     await ref.set({
//       'id': ref.id,
//       'text': text,
//       'senderId': user.uid,
//       'createdAt': FieldValue.serverTimestamp(),
//       'readBy': [user.uid],
//     });

//     msgCtrl.clear();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final msgsQuery = FirebaseFirestore.instance
//         .collection('chats').doc(chatId)
//         .collection('messages')
//         .orderBy('createdAt', descending: true);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dean ↔ Secretary'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () => FirebaseAuth.instance.signOut(),
//             tooltip: 'Sign out',
//           )
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: msgsQuery.snapshots(),
//               builder: (context, snap) {
//                 if (!snap.hasData) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//                 final docs = snap.data!.docs;
//                 return ListView.builder(
//                   reverse: true,
//                   itemCount: docs.length,
//                   itemBuilder: (_, i) {
//                     final m = docs[i].data() as Map<String, dynamic>;
//                     final isMe = m['senderId'] == user.uid;
//                     return Align(
//                       alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
//                       child: Container(
//                         margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
//                         padding: const EdgeInsets.all(12),
//                         constraints: const BoxConstraints(maxWidth: 300),
//                         decoration: BoxDecoration(
//                           color: isMe ? Colors.blue.withOpacity(.15) : Colors.grey.withOpacity(.2),
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                         child: Text(m['text'] ?? ''),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: TextField(
//                       controller: msgCtrl,
//                       decoration: const InputDecoration(
//                         hintText: 'Type a message…',
//                         border: OutlineInputBorder(),
//                         isDense: true,
//                       ),
//                       onSubmitted: (_) => sendMessage(),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   FilledButton(
//                     onPressed: sendMessage,
//                     child: const Icon(Icons.send),
//                   )
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
