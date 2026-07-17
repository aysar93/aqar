import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SelectLocation extends StatefulWidget {
  const SelectLocation({super.key});

  @override
  State<SelectLocation> createState() => _SelectLocationState();
}

class _SelectLocationState extends State<SelectLocation> {
  LatLng? selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("اختيار الموقع"),
        backgroundColor: const Color(0xff0D47A1),
      ),

      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(33.4372, 43.2860),
          zoom: 12,
        ),

        onTap: (position) {
          setState(() {
            selected = position;
          });
        },

        markers: selected == null
            ? {}
            : {
                Marker(
                  markerId: const MarkerId("selected"),
                  position: selected!,
                )
              },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff0D47A1),
        child: const Icon(Icons.check),
        onPressed: () {
          if (selected != null) {
            Navigator.pop(context, selected);
          }
        },
      ),
    );
  }
}