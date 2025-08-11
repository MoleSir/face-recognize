
import 'package:face/data/notifiers.dart';
import 'package:flutter/material.dart';

class NavigationBarWidget extends StatelessWidget {
  const NavigationBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedPageNotifier, 
      builder: (context, int selectedPage, child) {
        return NavigationBar(
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.camera), 
              label: "Camera",
            ),
            NavigationDestination(
              icon: Icon(Icons.edit), 
              label: "Edit",
            ),
          ],
        
          onDestinationSelected: (int value) {
            selectedPageNotifier.value = value;
          },

          selectedIndex: selectedPage,
        );
      });
  }
}