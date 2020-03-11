import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:location/location.dart';
import 'package:fluster/fluster.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'config.dart';
import 'model/points.dart';
import 'model/mask.dart';
import 'model/shop.dart';
import 'model/shop_map_maker.dart';
import 'model/taiwan_mask_home_model.dart';
import 'repository/mask_api_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'このアプリは台湾政府のマスク在庫APIのデータを30秒ごとに取得しGoogleMaps上に表示するアプリです。',
      home: TaiwanMaskHome(),
    );
  }
}

class TaiwanMaskHome extends StatefulWidget {
  @override
  State<TaiwanMaskHome> createState() => TaiwanMaskHomeState();
}

class TaiwanMaskHomeState extends State<TaiwanMaskHome>
    with SingleTickerProviderStateMixin {
  //TODO service経由
  MaskApiProvider maskApiProvider = MaskApiProvider();
  static final taipeiLat = 25.033964;
  static final taipeiLong = 121.564468;
  static LocationData currentLocation =
      LocationData.fromMap({"latitude": taipeiLat, "longitude": taipeiLong});

  static LocationData myLocation;
  static double currentZoom = 16;
  static final CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(taipeiLat, taipeiLong),
    zoom: currentZoom,
  );

  static Map<String, Shop> _shopMap;
  double mapPixelWidth;
  double mapPixelHeight;
  Fluster<ShopMapMaker> _fluster;
  List<ShopMapMaker> _points = List<ShopMapMaker>();
  CameraPosition _currentPosition;

  final _markers = StreamController<TaiwanMaskHomeModel>();

  Location _locationService = new Location();

  Completer<GoogleMapController> _googleMapController = Completer();

  @override
  void initState() {
    print("initState");
    super.initState();

    _createShopMapMakerPoints().then((value) async {
      await _fetchTaiwanMaskData();
    });

    //デフォルトの位置を現在位置or台北市中心部に
    initLocationState();

    _locationService
        .onLocationChanged()
        .listen((LocationData changedLocation) async {
      setState(() {
        currentLocation = changedLocation;
      });
    });

    //fetchApiDuration毎に定期実行
    Timer.periodic(
        Duration(seconds: fetchApiDuration), (_) => _fetchTaiwanMaskData());
  }

  Future<void> _fetchTaiwanMaskData() async {
    print("_fetchTaiwanMaskApi");
    await _createPoints();
    int zoom = _currentPosition.zoom.round();
    Map<MarkerId, Marker> markers =
        await _createMarkers(_currentPosition.target, zoom);
    //TODO データの正確性向上のためにmarkersと同じ処理で取得したい
    String updatedAtStr = _points.last.updatedAtStr;
    _markers.sink
        .add(TaiwanMaskHomeModel(markers: markers, updatedAtStr: updatedAtStr));

    print("_fetchTaiwanMaskApi should update data length:${markers.length}");
  }

  Future<void> _createCluster() async {
    _fluster = Fluster<ShopMapMaker>(
        minZoom: 0,
        maxZoom: 21,
        radius: 210,
        extent: 512,
        nodeSize: 64,
        points: _points,
        createCluster:
            (BaseCluster cluster, double longitude, double latitude) =>
                ShopMapMaker(
                    latitude: latitude,
                    longitude: longitude,
                    isCluster: true,
                    clusterId: cluster.id,
                    pointsSize: cluster.pointsSize,
                    id: cluster.id.toString(),
                    childMarkerId: cluster.childMarkerId));
  }

  Future _createShopMapMakerPoints() async {
    //薬局・病院のマスターデータ(約6000件・9MB)をロード
    //元データ: https://github.com/kiang/pharmacies/blob/master/json/points.json
    //TODO 定期的に最新のマスターデータを作成
    String loadData = await rootBundle.loadString('assets/points.json');
    Map<String, dynamic> jsonResponse = jsonDecode(loadData);

    //jsonをdartのobject化
    Points points = Points.fromJson(jsonResponse);
    Iterable<Shop> shops = points.features.map((point) {
      String shopId = point.properties.id;
      String name = point.properties.name;
      String address = point.properties.address;
      String phoneNum = point.properties.phone;
      String webAddress = point.properties.website;
      String officeHour = point.properties.available;
      double latitude = point.geometry.coordinates[1];
      double longitude = point.geometry.coordinates[0];
      return Shop(
          id: shopId,
          name: name,
          address: address,
          phoneNum: phoneNum,
          webAddress: webAddress,
          officeHour: officeHour,
          latitude: latitude,
          longitude: longitude);
    });

    //マスターデータのMapをクラス内で参照できるようにする。
    _shopMap = Map.fromIterable(shops, key: (s) => s.id, value: (s) => s);
  }

  Future<void> _createPoints() async {
    //台湾政府のAPIからマスクデータを取得
    List<Mask> maskList = await maskApiProvider.fetchMask();

    //TODO 薬局・病院のマスターデータのnullチェック
    var getShopInfoFromMaskData = (Mask m) {
      Shop shop = (_shopMap ?? const {})[m.shopId] ?? null;
      return shop != null
          ? ShopMapMaker(
              id: m.shopId,
              name: shop.name,
              address: shop.address,
              phoneNum: shop.phoneNum,
              webAddress: shop.webAddress,
              officeHour: shop.officeHour,
              latitude: shop.latitude,
              longitude: shop.longitude,
              maskAdultNum: m.adultNum,
              maskChildNum: m.childNum,
              updatedAtStr: m.updatedAtStr)
          : null;
    };

    //マスクデータと薬局・病院のマスターデータを結合→薬局・病院でのマスク在庫データ作成
    List<ShopMapMaker> shopMapMakers =
        maskList.map((m) => (getShopInfoFromMaskData(m))).toList();
    //今の実装だとList内にnullが入っているのでそれらを削除
    //TODO 薬局・病院のマスターデータのnullチェック
    shopMapMakers.removeWhere((value) => value == null);

    //薬局・病院でのマスク在庫データをクラス内で参照できるようにする。
    _points = shopMapMakers;

    //マスク在庫データをもとにクラスターデータを作成
    _createCluster();
  }

  Future<Map<MarkerId, Marker>> _createMarkers(
      LatLng location, int zoom) async {
    LatLng northeast = _calculateLatLon(mapPixelWidth, 0);
    LatLng southwest = _calculateLatLon(0, mapPixelHeight);
    var bounds = [
      southwest.longitude,
      southwest.latitude,
      northeast.longitude,
      northeast.latitude
    ];

    List<ShopMapMaker> clusters = _fluster.clusters(bounds, zoom);
    Map<MarkerId, Marker> markers = Map();
    print("${clusters.length}");

    for (ShopMapMaker feature in clusters) {
      final Uint8List markerIcon = await _getBytesFromCanvas(feature);
      BitmapDescriptor bitmapDescriptor =
          BitmapDescriptor.fromBytes(markerIcon);
      //Google MapのMarker作成
      Marker marker = Marker(
          markerId: MarkerId(feature.markerId),
          position: LatLng(feature.latitude, feature.longitude),
          icon: bitmapDescriptor,
          infoWindow: InfoWindow(title: feature.name),
          onTap: () {
            //TODO fix ライブラリの仕様?でクラスタ内のノード数が1のときfeature.pointsSizeがnullで返ってくる
            if (feature.pointsSize == 1 || feature.pointsSize == null) {
              _settingModalBottomSheet(context, feature);
            } else {
              //GoogleMap()のonTapが呼ばれる
            }
          });

      //ここで ${feature.updatedAtStr}を取ろうとしてもクラスタのsize=1でなければnullになる
      markers.putIfAbsent(MarkerId(feature.markerId), () => marker);
    }
    return markers;
  }

  Future<Uint8List> _getBytesFromCanvas(ShopMapMaker feature) async {
    Color color = Colors.blue[300];
    String text = "1";
    int size = 150;

    if (feature.pointsSize != null) {
      text = feature.pointsSize.toString();
      if (feature.pointsSize >= 100) {
        color = Colors.blue[400];
        size = 180;
      } else if (feature.pointsSize >= 10) {
        color = Colors.blue[400];
        size = 170;
      } else if (feature.pointsSize >= 2) {
        color = Colors.blue[400];
        size = 160;
      }
    } else {
      if (feature.maskChildNum > 100 && feature.maskAdultNum > 10) {
        color = Colors.red[300];
      } else if (feature.maskChildNum > 10 && feature.maskAdultNum > 1) {
        color = Colors.yellow[500];
      } else if (feature.maskChildNum + feature.maskAdultNum > 1) {
        color = Colors.yellow[300];
      } else {
        color = Colors.black26;
      }
    }

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint2 = Paint()..color = Colors.white;
    final Paint paint1 = Paint()..color = color;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 3.0, paint2);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 3.3, paint1);
    TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
          fontSize: size / 4, color: Colors.black, fontWeight: FontWeight.bold),
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset(size / 2 - painter.width / 2, size / 2 - painter.height / 2),
    );

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data.buffer.asUint8List();
  }

  LatLng _calculateLatLon(x, y) {
    double parallelMultiplier =
        math.cos(_currentPosition.target.latitude * math.pi / 180);
    double degreesPerPixelX = 360 / math.pow(2, _currentPosition.zoom + 8);
    double degreesPerPixelY =
        360 / math.pow(2, _currentPosition.zoom + 8) * parallelMultiplier;
    var lat = _currentPosition.target.latitude -
        degreesPerPixelY * (y - mapPixelHeight / 2);
    var lng = _currentPosition.target.longitude +
        degreesPerPixelX * (x - mapPixelWidth / 2);
    LatLng latLng = LatLng(lat, lng);
    return latLng;
  }

  void _onCameraMove(CameraPosition cameraPosition) {
    setState(() {
      _currentPosition = cameraPosition;
    });
  }

  void _onTap(LatLng target) {
    _googleMapController.future.then((controller) {
      controller.animateCamera(
          CameraUpdate.newLatLng(LatLng(target.latitude, target.longitude)));
    });
  }

  @override
  Widget build(BuildContext context) {
    print("####let build###");
    final Size size = MediaQuery.of(context).size;
    final double ratio = MediaQuery.of(context).devicePixelRatio;
    mapPixelWidth = size.width * ratio;
    mapPixelHeight = size.height * ratio;
    return new Scaffold(
      appBar: AppBar(title: Text(appName)),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              child: Text(
                appName,
                style: Theme.of(context).primaryTextTheme.title,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),
            AboutListTile(
              child: Text("このアプリについて"),
            ),
          ],
        ),
      ),
      body: Container(
        child: StreamBuilder<TaiwanMaskHomeModel>(
          stream: _markers.stream,
          builder: (_, AsyncSnapshot<TaiwanMaskHomeModel> snapshot) {
            print("snapshot has data? ${snapshot.hasData} ${timestamp()}");
            if (snapshot.hasData) {
              print("updatedAt ${snapshot.data.updatedAtStr}");
              return AnimatedSwitcher(
                  key: ValueKey(snapshot.data.updatedAtStr),
//                  transitionBuilder: (child, animation) {
//                    return SlideTransition(child: child,
//                      position: _animationController
//                          .drive(CurveTween(curve: Curves.easeInOut))
//                          .drive(
//                        Tween<Offset>(
//                          begin: Offset.zero,
//                          end: const Offset(0, -1),
//                        ),
//                      ),
//                    );
//                  },
                  //TODO animation時に目が疲れないようにする。多分左から右へゆっくりslideする感じが良さそう。
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity:
                          animation.drive(CurveTween(curve: Interval(10, 100))),
                      child: child,
                    );
                  },
                  duration: Duration(seconds: 10),
                  child: Stack(children: <Widget>[
                    GoogleMap(
                      initialCameraPosition: _kInitialPosition,
                      mapType: MapType.normal,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      rotateGesturesEnabled: false,
                      onCameraMove: _onCameraMove,
                      onTap: _onTap,
                      onMapCreated: (GoogleMapController controller) {
                        _googleMapController.complete(controller);
                      },
                      gestureRecognizers:
                          <Factory<OneSequenceGestureRecognizer>>[
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      ].toSet(),
                      markers: Set<Marker>.of(snapshot.data.markers.values),
                    ),
                    Container(
                        margin: EdgeInsets.all(5.0),
                        child: Text(
                          "最終更新日時(台湾時間): ${snapshot.data.updatedAtStr}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey,
                          ),
                        ))
                  ]));
            } else {
              return Stack(children: <Widget>[
                GoogleMap(
                  initialCameraPosition: _kInitialPosition,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  rotateGesturesEnabled: false,
                  onCameraMove: _onCameraMove,
                  onTap: _onTap,
                  onMapCreated: (GoogleMapController controller) {
                    _googleMapController.complete(controller);
                  },
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  ].toSet(),
                ),
                CircularProgressIndicator()
              ]);
            }
          },
        ),
      ),
    );
  }

  void initLocationState() async {
    try {
      myLocation = await _locationService.getLocation();
    } on PlatformException catch (e) {
      myLocation = LocationData.fromMap(
          {"latitude": taipeiLat, "longitude": taipeiLong});
    }
  }

  static void _settingModalBottomSheet(
      BuildContext context, ShopMapMaker shopMapMaker) {
    print("_settingModalBottomSheet");
    print("_settingModalBottomSheet shopMapMaker: ${shopMapMaker}");
    print("_settingModalBottomSheet shopMapMaker id: ${shopMapMaker.id}");
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Material(
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: new BorderRadius.only(
                      topLeft: new Radius.circular(15.0),
                      topRight: new Radius.circular(15.0))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  //TODO デザインをカッコよくする
                  Expanded(
                      child: Text(
                          "大人用マスク在庫数: ${shopMapMaker.maskAdultNum.toString()}")),
                  Expanded(
                      child: Text(
                          "子供用マスク在庫数: ${shopMapMaker.maskChildNum.toString()}")),
                  Expanded(child: Text("店名: ${shopMapMaker.name}")),
                  Expanded(child: Text("住所: ${shopMapMaker.address}")),
                  Expanded(child: Text("電話番号: ${shopMapMaker.phoneNum}")),
                  Expanded(child: Text("店舗ID: ${shopMapMaker.id}")),
                ],
              ));
        });
  }
}

String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
