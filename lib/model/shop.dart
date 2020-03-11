import 'package:flutter/material.dart';

class Shop {
  String id;
  String name;
  String address;
  String phoneNum;
  String webAddress;
  String officeHour;
  String note;
  double latitude;
  double longitude;

  Shop(
      {@required this.id,
      @required this.name,
      this.address,
      this.phoneNum,
      this.webAddress,
      this.officeHour,
      this.note,
      @required this.latitude,
      @required this.longitude});
}
