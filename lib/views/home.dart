
import 'package:face/data/notifiers.dart';
import 'package:face/views/pages/camera.dart';
import 'package:face/views/pages/edit.dart';
import 'package:face/views/widgets/navigationbar.dart';
import 'package:flutter/material.dart';

class HomeWidget extends StatefulWidget {
  const HomeWidget({super.key});

  @override
  HomeWidgetState createState() => HomeWidgetState();
}

class HomeWidgetState extends State<HomeWidget> {
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    loadFaces().then((faces) {
      facesNotifier.value = faces;
    });
    _pages = [
      CameraPage(),
      EditPage()
    ];
  }

  @override
  void dispose() {
    saveFaces(facesNotifier.value);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Face Recognize"),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              isDarkNotifier.value = !isDarkNotifier.value;
            },
            icon: ValueListenableBuilder(
              valueListenable: isDarkNotifier, 
              builder: (context, bool value, child) => Icon(value ? Icons.light_mode : Icons.dark_mode),
            ),
          )
        ],
      ),

        body: ValueListenableBuilder(
          valueListenable: selectedPageNotifier, 
          builder:(context, value, child) {
            return _pages.elementAt(value);
          },
        ),

        bottomNavigationBar: NavigationBarWidget(),
    );
  }
}