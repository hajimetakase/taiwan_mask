import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TaiwanMaskHomeModel {
  Map<MarkerId, Marker> markers;
  String updatedAtStr;
  TaiwanMaskHomeModel({@required this.markers, @required this.updatedAtStr});
}
