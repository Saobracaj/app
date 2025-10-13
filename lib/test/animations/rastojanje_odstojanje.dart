import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/auto.dart';
import 'package:saobracaj/test/animations/road.dart';

class RastojanjeOndsojanje extends StatelessWidget {
  const RastojanjeOndsojanje({super.key});



  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      // padding: EdgeInsets.all(16),
      child: ClipRRect(
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.grey.shade800)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10,),
                SizedBox(height: 40, child: AnimatedAutoWidget(color: Colors.blue)),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    children: [
                      Text('🔼'),
                      Text('Растојање', style: TextStyle(color: Colors.white),),
                      Text('🔽'),
                    ],
                  ),
                ),
                Row(
                  children: [
                    SizedBox(height: 40, child: AnimatedAutoWidget(color: Colors.red)),
                    Text('◀️ Одстојање ▶️', style: TextStyle(color: Colors.white)),
                    SizedBox(height: 40, child: AnimatedAutoWidget(color: Colors.yellow))
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
