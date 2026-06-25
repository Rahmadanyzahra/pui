// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_child_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    // await FirebaseAuth.instance.signOut();
  }

  // void _selectChild(BuildContext context, Child child) {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) =>
  //           DashboardScreen(child: child, openedFromParentDashboard: true),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    // final user = FirebaseAuth.instance.currentUser;
    // TODO: Integrate backend user session check

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Daftar anak akan tampil di sini setelah integrasi backend. (TODO)',
          style: TextStyle(fontSize: 15, color: Colors.black54),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<bool?>(
            context,
            MaterialPageRoute(builder: (context) => const AddChildScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
