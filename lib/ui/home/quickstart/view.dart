import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'logic.dart';

class QuickStartPage extends StatefulWidget {
  const QuickStartPage({super.key});

  @override
  _QuickStartPageState createState() => _QuickStartPageState();
}

class _QuickStartPageState extends State<QuickStartPage> {
  final QuickStartLogic logic = Get.put(QuickStartLogic());

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuickStartLogic>(
      builder: (logic) {
        return const Center(child: Text('快捷开始'));
      },
    );
  }
}
