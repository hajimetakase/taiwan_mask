import 'package:flutter/material.dart';
import 'package:fluster/fluster.dart';

class ShopMapMaker extends Clusterable {
  String id;
  String name;
  String address;
  String phoneNum;
  String webAddress;
  String officeHour;
  String note;
  double latitude;
  double longitude;
  int maskAdultNum;
  int maskChildNum;
  String updatedAtStr;

  ShopMapMaker({
    @required this.id,
    @required this.name,
    this.address,
    this.phoneNum,
    this.webAddress,
    this.officeHour,
    this.note,
    @required this.latitude,
    @required this.longitude,
    @required this.maskAdultNum,
    @required this.maskChildNum,
    @required this.updatedAtStr,
    isCluster = false,
    clusterId,
    pointsSize,
    childMarkerId,
  }) : super(
    markerId: id,
    latitude: latitude,
    longitude: longitude,
    isCluster: isCluster,
    clusterId: clusterId,
    pointsSize: pointsSize,
    childMarkerId: childMarkerId,
  );
}
