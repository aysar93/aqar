import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aqar/chat/utils/time_formatter.dart';
import 'admin_chat_screen.dart';

class AdminChatListScreen extends StatefulWidget {

  const AdminChatListScreen({super.key});


  @override
  State<AdminChatListScreen> createState() =>
      _AdminChatListScreenState();

}



class _AdminChatListScreenState
    extends State<AdminChatListScreen> {


  String searchText = "";


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
        title: const Text(
          "المحادثات",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
      ),

      body: Column(

  children: [

    Padding(

      padding:
          const EdgeInsets.all(12),

      child: TextField(

        onChanged: (value){

          setState(() {

            searchText =
                value.trim();

          });

        },


        style:
            const TextStyle(
              color: Colors.white,
            ),


        decoration:
            InputDecoration(

              hintText:
                  "البحث عن مستخدم",


              hintStyle:
                  const TextStyle(
                    color:
                        Colors.white54,
                  ),


              prefixIcon:
                  const Icon(
                    Icons.search,
                    color:
                        Color(0xffD4AF37),
                  ),


              filled:
                  true,


              fillColor:
                  const Color(0xff1E293B),


              border:
                  OutlineInputBorder(

                    borderRadius:
                        BorderRadius.circular(15),

                  ),

            ),

      ),

    ),



    Expanded(

      child: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance
            .collection("chats")
            .orderBy(
              "updatedAt",
              descending: true,
            )
            .snapshots(),

        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }


          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {

            return const Center(
              child: Text(
                "لا توجد محادثات حالياً",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            );
          }


          final chats =
              snapshot.data!.docs;

              final filteredChats =
    chats.where((chat) {

  final data =
      chat.data()
      as Map<String, dynamic>;


  final name =
      data["userName"]
          .toString()
          .toLowerCase();


  final phone =
      data["userPhone"]
          .toString()
          .toLowerCase();


  return name.contains(
        searchText.toLowerCase(),
      ) ||

      phone.contains(
        searchText.toLowerCase(),
      );


}).toList();

filteredChats.sort((a, b) {

  final aData =
      a.data() as Map<String, dynamic>;

  final bData =
      b.data() as Map<String, dynamic>;

  final aUnread =
      (aData["unreadAdmin"] ?? 0) as int;

  final bUnread =
      (bData["unreadAdmin"] ?? 0) as int;

  if (aUnread > 0 && bUnread == 0) {
    return -1;
  }

  if (aUnread == 0 && bUnread > 0) {
    return 1;
  }

  return 0;

});


          return ListView.builder(

            padding:
                const EdgeInsets.all(12),

            itemCount:
    filteredChats.length,


            itemBuilder:
                (context, index) {


              final chat =
    filteredChats[index];


              final data =
                  chat.data()
                  as Map<String,dynamic>;

                  final Timestamp? updatedAt =
    data["updatedAt"] as Timestamp?;

final String lastTime =
    updatedAt != null
        ? TimeFormatter.format(
            updatedAt.toDate(),
          )
        : "";


              final unread =
                  data["unreadAdmin"] ?? 0;

                  final String userName =
    (data["userName"] ?? "").toString();


              return Container(

  margin: const EdgeInsets.only(bottom: 12),

  decoration: BoxDecoration(

    border: unread > 0
        ? const Border(
            right: BorderSide(
              color: Color(0xffD4AF37),
              width: 4,
            ),
          )
        : null,

  ),

  child: Card(

    color: const Color(0xFF1E293B),

    margin: EdgeInsets.zero,

    child: ListTile(

                  leading:
                      CircleAvatar(
                        backgroundColor:
                            const Color(0xFFD4AF37),

                      child: Text(
  userName.isNotEmpty
      ? userName[0]
      : "?",
  style: const TextStyle(
    color: Colors.black,
    fontWeight: FontWeight.bold,
  ),
),
                      ),


                  title:
                      Text(
                        data["userName"] ??
                            "مستخدم",

                        style:
                            const TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                      ),


                  subtitle:
                      Column(

                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          Text(
                            data["userPhone"] ??
                                "",

                            style:
                                const TextStyle(
                                  color:
                                      Colors.white60,
                                ),
                          ),


                          const SizedBox(
                            height: 4,
                          ),


                          Text(
                            data["lastMessage"] ??
                                "",

                            maxLines: 1,

                            overflow:
                                TextOverflow.ellipsis,

                            style:
                                const TextStyle(
                                  color:
                                      Colors.white70,
                                ),
                          ),

                        ],
                      ),



                  trailing: Column(

  mainAxisAlignment:
      MainAxisAlignment.center,

  crossAxisAlignment:
      CrossAxisAlignment.end,

  children: [

    Text(

      lastTime,

      style: const TextStyle(

        color: Colors.white60,

        fontSize: 12,

      ),

    ),

    const SizedBox(height: 6),

    if (unread > 0)

      Container(

        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),

        decoration: const BoxDecoration(

          color: Colors.red,

          borderRadius:
              BorderRadius.all(
                Radius.circular(20),
              ),

        ),

        child: Text(

          unread.toString(),

          style: const TextStyle(

            color: Colors.white,

            fontWeight: FontWeight.bold,

            fontSize: 12,

          ),

        ),

      ),

  ],

),



                  onTap: () {

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder:
                            (_) =>
                                AdminChatScreen(
                                  userId:
                                      chat.id,

                                  chatData:
                                      data,
                                ),

                      ),

                    );

                  },


                                ),

              ),

            );

            },

          );

           },

      ), // نهاية StreamBuilder

    ), // نهاية Expanded


  ], // نهاية children في Column


), // نهاية Column


    );
  }
}