import 'package:flutter/material.dart';

class LearnPage extends StatefulWidget {
  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Learn',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 20),
          Text(
            'Your learning materials will appear here',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // Add learning functionality here
            },
            child: Text('Create Learn Item'),
          ),
        ],
      ),
    );
  }
}