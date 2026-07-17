import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'widgets/property_card.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/filter_bar.dart';

class PropertyManagementScreen extends StatefulWidget {
  const PropertyManagementScreen({super.key});

  @override
  State<PropertyManagementScreen> createState() =>
      _PropertyManagementScreenState();
}

class _PropertyManagementScreenState
    extends State<PropertyManagementScreen> {

  final TextEditingController searchController =
      TextEditingController();

  String search = "";
  String selectedFilter = "الكل";

  @override
Widget build(BuildContext context) {

  return Directionality(

    textDirection: TextDirection.rtl,

    child: Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
        backgroundColor: const Color(0xff0F172A),
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "إدارة العقارات",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [

          Padding(
  padding: const EdgeInsets.all(16),

  child: Column(
    children: [

      SearchBarWidget(
        controller: searchController,

        hintText: "بحث عن عقار...",

        onChanged: (value) {

          setState(() {

            search = value.trim();

          });

        },
      ),


      const SizedBox(height: 12),


      FilterBar(

        selectedFilter: selectedFilter,

        onChanged: (value) {

          setState(() {

            selectedFilter = value;

          });

        },

      ),

    ],
  ),

),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("properties")
                  .orderBy(
                    "createdAt",
                    descending: true,
                  )
                  .snapshots(),
                                builder: (context, snapshot) {

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      snapshot.error.toString(),
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                List<DocumentSnapshot> docs =
                    snapshot.data!.docs;
                    if (selectedFilter != "الكل") {

  docs = docs.where((doc) {

    final data =
        doc.data() as Map<String, dynamic>;


    return data["status"] == selectedFilter;

  }).toList();

}

                if (search.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;

                    final title =
                        (data["title"] ?? "")
                            .toString()
                            .toLowerCase();

                    final city =
                        (data["city"] ?? "")
                            .toString()
                            .toLowerCase();

                    final district =
                        (data["district"] ?? "")
                            .toString()
                            .toLowerCase();

                    final text =
                        search.toLowerCase();

                    return title.contains(text) ||
                        city.contains(text) ||
                        district.contains(text);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "لا توجد عقارات",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  );
                }

                return ListView.builder(
  padding: const EdgeInsets.all(16),

  itemCount: docs.length,

  itemBuilder: (context, index) {

    return PropertyCard(
      document: docs[index],
    );

  },

);

              },
            ),
          ),
        ],
      ),
    ),
  );
}

@override
void dispose() {

  searchController.dispose();

  super.dispose();

}
}