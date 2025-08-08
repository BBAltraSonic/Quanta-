import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class DaySeparator extends StatelessWidget {
  final DateTime date;

  const DaySeparator({Key? key, required this.date}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: kDefaultPadding / 2),
      alignment: Alignment.center,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kCardColor, // Using kCardColor for a subtle dark background
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          DateFormat('EEE, h:mm a').format(date), // e.g., "Wed, 11:46 AM"
          style: TextStyle(color: kLightTextColor, fontSize: 12),
        ),
      ),
    );
  }
}
