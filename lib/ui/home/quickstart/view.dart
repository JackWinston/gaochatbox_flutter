import 'package:flutter/cupertino.dart';

class QuickStartPage extends StatefulWidget {
  const QuickStartPage({super.key});

  @override
  _QuickStartPageState createState() => _QuickStartPageState();
}

class _QuickStartPageState extends State<QuickStartPage> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('快捷开始'));
  }
}
