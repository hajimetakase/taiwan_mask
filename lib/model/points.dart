// To parse this JSON data, do
//
//     final points = pointsFromJson(jsonString);
//https://app.quicktype.io/ を使い自動生成

import 'dart:convert';

Points pointsFromJson(String str) => Points.fromJson(json.decode(str));

String pointsToJson(Points data) => json.encode(data.toJson());

class Points {
  String type;
  List<Feature> features;

  Points({
    this.type,
    this.features,
  });

  factory Points.fromJson(Map<String, dynamic> json) => Points(
    type: json["type"],
    features: List<Feature>.from(json["features"].map((x) => Feature.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "features": List<dynamic>.from(features.map((x) => x.toJson())),
  };
}

class Feature {
  String type;
  Properties properties;
  Geometry geometry;

  Feature({
    this.type,
    this.properties,
    this.geometry,
  });

  factory Feature.fromJson(Map<String, dynamic> json) => Feature(
    type: json["type"],
    properties: Properties.fromJson(json["properties"]),
    geometry: Geometry.fromJson(json["geometry"]),
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "properties": properties.toJson(),
    "geometry": geometry.toJson(),
  };
}

class Geometry {
  String type;
  List<double> coordinates;

  Geometry({
    this.type,
    this.coordinates,
  });

  factory Geometry.fromJson(Map<String, dynamic> json) => Geometry(
    type: json["type"],
    coordinates: List<double>.from(json["coordinates"].map((x) => x.toDouble())),
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "coordinates": List<dynamic>.from(coordinates.map((x) => x)),
  };
}

class Properties {
  String id;
  String name;
  String phone;
  String address;
  int maskAdult;
  int maskChild;
  String updated;
  String available;
  String note;
  String customNote;
  String website;
  String county;
  String town;
  String cunli;
  String servicePeriods;

  Properties({
    this.id,
    this.name,
    this.phone,
    this.address,
    this.maskAdult,
    this.maskChild,
    this.updated,
    this.available,
    this.note,
    this.customNote,
    this.website,
    this.county,
    this.town,
    this.cunli,
    this.servicePeriods,
  });

  factory Properties.fromJson(Map<String, dynamic> json) => Properties(
    id: json["id"],
    name: json["name"],
    phone: json["phone"],
    address: json["address"],
    maskAdult: json["mask_adult"],
    maskChild: json["mask_child"],
    updated: json["updated"],
    available: json["available"],
    note: json["note"],
    customNote: json["custom_note"],
    website: json["website"],
    county: json["county"],
    town: json["town"],
    cunli: json["cunli"],
    servicePeriods: json["service_periods"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "phone": phone,
    "address": address,
    "mask_adult": maskAdult,
    "mask_child": maskChild,
    "updated": updated,
    "available": available,
    "note": note,
    "custom_note": customNote,
    "website": website,
    "county": county,
    "town": town,
    "cunli": cunli,
    "service_periods": servicePeriods,
  };
}
