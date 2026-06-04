import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';
import 'package:flutter_map_marker_popup/extension_api.dart';
import 'package:get/get.dart';

// import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
// import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:roams/modules/IOTMAP/painting.dart';
import 'package:roams/modules/IOTMAP/yard_infra_details.dart';
import 'package:roams/modules/already_device_reg/already_device_reg_controller/already_device_reg_controller.dart';
import 'package:roams/modules/global_widgets/footer_widget.dart';

import '../../network_services/models/user_info.dart';
import '../../utils/constants.dart';
import '../../utils/dprint.dart';
import '../../utils/storage/storage.dart';
import '../../utils/theme/app_colors.dart';
import '../global_widgets/header_widget.dart';

class IndiaRailwayDepotsMap extends StatefulWidget {
  @override
  _IndiaRailwayDepotsMapState createState() => _IndiaRailwayDepotsMapState();
}

class _IndiaRailwayDepotsMapState extends State<IndiaRailwayDepotsMap>
    with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  late MapController _mapController;
  double _currentZoom = 5.0;
  List<Map<String, dynamic>> depots = [];
  bool _isLoading = true;

  // String token =
  //     '''eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJvcmdzbG5vIjoiUkIiLCJkZXBvdCI6bnVsbCwibGV2ZWwiOiJCT0FSRCIsInVzZXJfbmFtZSI6ImNtbXVzZXJyYiIsImhyRW1wbG95ZWVJZCI6bnVsbCwiYXBwQ29kZSI6IiIsImF1dGhvcml0aWVzIjpbIjIyIiwiQ09BQ0hNSVRSQV9VU0VSIiwiQ01NX1VTRVIiLCI1MDAwMCIsIjkiLCJGTU1fVVNFUiIsIjY0IiwiMjEiXSwiY2xpZW50X2lkIjoiY21tIiwidG9rZW4iOiIiLCJkaXZpc2lvbiI6bnVsbCwiZmlyc3ROYW1lIjoiUkIgVVNFUiIsInpvbmUiOm51bGwsInNjb3BlIjpbImNtbSIsInJlYWQiLCJ3cml0ZSJdLCJzZXNJZCI6IiIsIlNTT1VpZCI6IiIsImxvY2F0aW9uIjoiUkIiLCJocm1zSWQiOiJYVExFSUkiLCJleHAiOjE3Njg4MDIwMjQsImRlcGFydG1lbnQiOiJNRUNIIiwid29ya2NlbnRlcmlkIjpudWxsLCJ1c2VyIjoiY21tdXNlcnJiIiwianRpIjoiN2QwNTI4YjAtOWI2ZS00NWZkLThiYTgtNmQ2Y2EzOGY0OGU2IiwiaG9tZXBhZ2UiOm51bGx9.hXQeDBFhzKTX2bHjIcV8ZBSlnQZgveY1MDqgybAoFRqP0d2D-JApQ2yRbud6BOMSIZapVz5k85K-_4f5U4vgQq4jgs9SIxcADrL8rcF3jXY6BkmmDzjwFs7rnw4FTD2RZNxx335pImQ_r2Di0iNV819EdNA5fE8RhO5RvROOvkTgYalRLs4W_VKkQJeyKxIhIlSaAG_8kIKOtbH0ZxeN7x1-uPCdOF9xhKMk793lgywSRPKBylBG_jvqXfYd_iifMLh8DN2zVDbly3UmKoWz4yJIS3qlPGeRtRFkwjWqfAb7jh-2sWxJxbV0NPiSsEL3p5V5mp_8k8XaNzDQAfYAAQ''';
  String token = '${Storage.getValue(Constants.token)}';
  bool isExpanded = true;
  bool isExpanded1 = true;
  bool isExpanded2 = true;

  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];

  void _searchDepot(String query) {
    if (query.isEmpty) {
      searchResults.clear();
      setState(() {});
      return;
    }

    searchResults = depots
        .where((depot) => depot['name']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();

    // If only one match, zoom to it automatically

    final depot = searchResults.first;
    _mapController.move(
        LatLng(depot['lat'], depot['lng']), 12); // Adjust zoom level as needed

    setState(() {});
  }

  // Map<String, bool> filters = {
  //   "Freight Yard": false,
  //   "Coaching Depot": false,
  //   "Workdepot": false,
  //   "CTS Station": true,
  //   "CTS Station(Proposed)": false,
  //   "Watering Point": false,
  //   "Weigh Bridge": false,
  //   "Tippler": false,
  //   "OMRS": false,
  // };

  Map<String, bool> filters = {};
  Map<String, String> categoryCodeMapping = {};
  Map<String, Color> categoryColors = {};
  Map<String, String> categoryTypeUsed = {};

  // Map<String, String> categoryCodeMapping = {
  //   "YD": "Freight Yard",
  //   "CD": "Coaching Depot",
  //   "WS": "Workdepot",
  //   "CT": "CTS Station",
  //   "CTO": "CTS Station(Proposed)",
  //   "WP": "Watering Point",
  //   "WB": "Weigh Bridge",
  //   "UT": "Tippler",
  //   "OM": "OMRS",
  // };

  // Map<String, Color> categoryColors = {
  //   "Freight Yard": Colors.red,
  //   "Coaching Depot": Colors.orange,
  //   "Workdepot": Colors.blue,
  //   "CTS Station": Colors.brown,
  //   "CTS Station(Proposed)": Colors.indigo,
  //   "Watering Point": Colors.pink,
  //   "Weigh Bridge": Colors.deepPurple,
  //   "Tippler": Colors.black,
  //   "OMRS": Colors.cyan,
  // };

  Color generateColor(String input) {
    final hash = input.hashCode;

    final hue = (hash & 0xFFFF) % 360;

    final saturation = 0.6 + ((hash >> 8) & 0xFF) / 255 * 0.3;
    final lightness = 0.35 + ((hash >> 16) & 0xFF) / 255 * 0.1;

    return HSLColor.fromAHSL(
      1.0,
      hue.toDouble(),
      saturation.clamp(0.6, 0.9),
      lightness.clamp(0.35, 0.45),
    ).toColor();
  }

  final GeoJsonParser zoneParser = GeoJsonParser();
  List<Polyline> trackPolylines = [];
  List<Map<String, dynamic>> trackFeatures = [];

  Future<void> _loadGeoJson() async {
    // Zones
    final zoneData = await rootBundle.loadString('assets/railway_zone.json');
    final zoneJson = jsonDecode(zoneData);

    // Clear old polygons
    zoneParser.polygons.clear();

    // Manually parse features
    for (var feature in zoneJson["features"]) {
      final zoneName = feature["properties"]["Code"] ?? "Unknown";
      final geometry = feature["geometry"];
      final type = geometry["type"];

      if (type == "Polygon") {
        for (var coords in geometry["coordinates"]) {
          final points = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
          zoneParser.polygons.add(
            Polygon(
              points: points,
              label: zoneName, // attach name here
            ),
          );
        }
      } else if (type == "MultiPolygon") {
        for (var polygon in geometry["coordinates"]) {
          for (var coords in polygon) {
            final points =
                coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
            zoneParser.polygons.add(
              Polygon(
                points: points,
                label: zoneName,
              ),
            );
          }
        }
      }
    }

    // Load tracks
    final trackData =
        await rootBundle.loadString('assets/railway_track_cris.json');
    final trackJson = jsonDecode(trackData);

    trackPolylines.clear();
    trackFeatures.clear();

    for (var feature in trackJson["features"]) {
      final geometry = feature["geometry"];
      final type = geometry["type"];
      final tmsSection = feature["properties"]["route"] ?? "Unknown";

      List<List<LatLng>> lines = [];

      if (type == "LineString") {
        final coords = geometry["coordinates"] as List;
        final points = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
        lines.add(points);
      } else if (type == "MultiLineString") {
        final coords = geometry["coordinates"] as List;
        for (var line in coords) {
          final points = line.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
          lines.add(points);
        }
      }

      for (var points in lines) {
        trackPolylines.add(Polyline(
          points: points,
          color: Colors.black,
          strokeWidth: 2.0,
        ));
        trackFeatures.add({
          "points": points,
          "tmssection": tmsSection,
        });
      }
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true); // Blinking effect

    _blinkAnimation =
        Tween<double>(begin: 1.0, end: 0.2).animate(_blinkController);
    _mapController = MapController();

    deviceList().then((val) {
      setState(() {
        devices = val;
        bool isDone = false;

        for (var i = 0; i < devices.length; i++) {
          String categoryName = devices[i]['device_name'];
          if (i == 0) {
            filters[categoryName] = true;
          } else {
            filters[categoryName] = false;
          }
          categoryCodeMapping[categoryName] = categoryName;
          categoryColors[categoryName] = generateColor(categoryName);
          categoryCount[categoryName] = "0";
          categoryTypeUsed[categoryName] = 'D';
        }

        filters["Freight Yard"] = false;
        categoryCodeMapping["YD"] = "Freight Yard";
        categoryColors["Freight Yard"] = generateColor("Freight Yard");
        categoryCount["Freight Yard"] = "0";
        categoryTypeUsed["Freight Yard"] = 'L';

        filters["Coaching Depot"] = false;
        categoryCodeMapping["CD"] = "Coaching Depot";
        categoryColors["Coaching Depot"] = generateColor("Coaching Depot");
        categoryCount["Coaching Depot"] = "0";
        categoryTypeUsed["Coaching Depot"] = 'L';

        filters["Workdepot"] = false;
        categoryCodeMapping["WS"] = "Workdepot";
        categoryColors["Workdepot"] = generateColor("Workdepot");
        categoryCount["Workdepot"] = "0";
        categoryTypeUsed["Workdepot"] = 'L';

        filters["CTS Station"] = false;
        categoryCodeMapping["CT"] = "CTS Station";
        categoryColors["CTS Station"] = generateColor("CTS Station");
        categoryCount["CTS Station"] = "0";
        categoryTypeUsed["CTS Station"] = 'L';

        filters["ROH"] = false;
        categoryCodeMapping["RH"] = "ROH";
        categoryColors["ROH"] = generateColor("ROH");
        categoryCount["ROH"] = "0";
        categoryTypeUsed["ROH"] = 'L';

        filters["SickLine"] = false;
        categoryCodeMapping["SL"] = "SickLine";
        categoryColors["ROH"] = generateColor("SickLine");
        categoryCount["SickLine"] = "0";
        categoryTypeUsed["SickLine"] = 'L';
        if (!isDone) {
          isDone = true;
          vendorList().then((vendor) {
            devices = vendor;

            for (var i = 0; i < devices.length; i++) {
              String categoryName = devices[i]['vendor_name'];

              filters[categoryName] = false;

              categoryCodeMapping[categoryName] = categoryName;
              categoryColors[categoryName] = generateColor(categoryName);
              categoryCount[categoryName] = "0";
              categoryTypeUsed[categoryName] = 'V';
            }
          });
        }
      });
    });
    fetchDepotData();
    zoneList().then((value) {
      setState(() {
        zone = value;
        zone.insert(0, {"orgCode": "ALL", "orgSlno": "ALL"});
        selectedZone = "ALL";
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMobile(context)) {
        setState(() {
          isExpanded = false;
        });
      }
    });
  }

  String selectedMapLayer = 'default';

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Future<List> zoneList() async {
    var response = await http.get(
        Uri.parse(
            "${Constants.baseUrl}nodeJsAPI/FmmOrgMs?filter[where][orgType]=HQ&filter[where][prntOrgSlno]=RB&filter[where][validFlag]=Y"),
        headers: {"x-auth-token": "$token"});
    List dataPoh = [];
    if (response.statusCode == 200) {
      var resBody = json.decode(response.body);
      if (resBody != null) dataPoh = resBody;
      return dataPoh;
    } else {
      return [];
    }
  }

  Future<List> deviceList() async {
    var response = await http.get(
        Uri.parse(
            "${Constants.iotBaseUrl}rolling_stock/filter-data/map_device_type_master"),
        headers: {"Authorization": "Bearer $token"});
    List dataPoh = [];
    if (response.statusCode == 200) {
      var resBody = json.decode(response.body);
      if (resBody != null) dataPoh = resBody;
      return dataPoh;
    } else {
      return [];
    }
  }

  Future<List> vendorList() async {
    var response = await http.get(
        Uri.parse(
            "${Constants.iotBaseUrl}rolling_stock/filter-data/map_vendor_name"),
        headers: {"Authorization": "Bearer $token"});
    List dataPoh = [];
    if (response.statusCode == 200) {
      var resBody = json.decode(response.body);
      if (resBody != null) dataPoh = resBody;
      return dataPoh;
    } else {
      return [];
    }
  }

  String returnPointsCount(String type) {
    if (selectedZone == "ALL" || selectedZone == null) {
      return categoryCount[type]?.toString() ?? "0";
    }

    final count = depots.where((depot) {
      final matchesZone =
          depot['zone'].toString().toUpperCase() == selectedZone!.toUpperCase();
      if (!matchesZone) return false;
      return depot['category'] == type;
    }).length;

    return count.toString();
  }

  String? selectedZone;
  List zone = [];
  List devices = [];

  // String yardCount = "0";
  // String workdepotCount = "0";
  // String coachingCount = "0";
  // String ctsCount = "0";
  // String ctsExistingCount = "0";
  // String ctsNotExistingCount = "0";
  // String wateringCount = "0";
  // String weighBridgeCount = "0";
  // String tipplerCount = "0";
  // String omrsCount = "0";
  Map<String, dynamic> categoryCount = {};

  Future<void> fetchDepotData() async {
    await Future.delayed(const Duration(seconds: 3));

    String apiUrl1 = "${Constants.iotBaseUrl}rolling_stock/iot-devices-map/";

    const String apiUrl11 =
        "https://roams.cris.org.in/nodeJsAPI/EdrishtiProcesses/fmmOrgMGisCoord?orgType=YD";
    const String apiUrl2 =
        "https://wise.cris.org.in/wiseapi/edrishti-workdepot-infras/work_depot_infra";

    const String apiUrl3 =
        "https://roams.cris.org.in/nodeJsAPI/EdrishtiProcesses/edrishtiCtsGis?orgType=CT";

    const String apiUrl4 =
        "https://roams.cris.org.in/nodeJsAPI/EdrishtiProcesses/edrishtiCoachingDepotGis?orgType=CD";

    String apiUrl5 = "${Constants.baseUrlForRoh}fmmOrg/fmm-org-details";

    try {
      final response11 = await http
          .get(Uri.parse(apiUrl11), headers: {"x-auth-token": "$token"});
      final response2 = await http.get(Uri.parse(apiUrl2));

      final response3 = await http
          .get(Uri.parse(apiUrl3), headers: {"x-auth-token": "$token"});

      final response4 = await http
          .get(Uri.parse(apiUrl4), headers: {"x-auth-token": "$token"});

      final response5 = await http
          .get(Uri.parse(apiUrl5), headers: {"Authorization": "Bearer $token"});

      List<dynamic> jsonDataLocation = [];
      if (response11.statusCode == 200 && response2.statusCode == 200) {
        List<dynamic> jsonData1 = json.decode(response11.body);
        List<dynamic> jsonData2 = json.decode(response2.body);
        List<dynamic> jsonData3 = json.decode(response3.body);
        List<dynamic> jsonData4 = json.decode(response4.body);
        List<dynamic> jsonData5 = json.decode(response5.body);

        jsonDataLocation = [
          ...jsonData4,
          ...jsonData2,
          ...jsonData3,
          ...jsonData1,
          ...jsonData5
        ];
      }

      final response1 = await http
          .get(Uri.parse(apiUrl1), headers: {"Authorization": "Bearer $token"});

      if (response1.statusCode == 200) {
        List<dynamic> jsonData1 = json.decode(response1.body);

        List<dynamic> jsonData = [...jsonData1];

        setState(() {
          depots = jsonData
              .map((depot) {
                String category = categoryCodeMapping[depot["org_type"]] ?? "";
                categoryCount[category] =
                    ((int.tryParse(categoryCount[category].toString()) ?? 0) +
                            1)
                        .toString();
                return {
                  "name": depot["org_desc"],
                  "lat": double.tryParse(depot["lat"].toString()) ?? 0.0,
                  "lng": double.tryParse(depot["lng"].toString()) ?? 0.0,
                  "category": category,
                  "district": depot["district_name"] ?? "",
                  "state": depot["state_name"] ?? "",
                  "zone": depot["hq"] ?? "",
                  "div": depot["div"] ?? "",
                  "stn": depot["hq"] ?? "",
                  "status": depot["status"] ?? "",
                  "org_code": depot["org_code"]?.toString() ?? "",
                  "org_type": depot["org_type"] ?? ""
                };
              })
              .whereType<Map<String, dynamic>>()
              .toList();

          List<Map<String, dynamic>> depots111 = jsonData
              .map((depot) {
                String category = categoryCodeMapping[depot["status"]] ?? "";
                categoryCount[category] =
                    ((int.tryParse(categoryCount[category].toString()) ?? 0) +
                            1)
                        .toString();
                return {
                  "name": depot["org_desc"],
                  "lat": double.tryParse(depot["lat"].toString()) ?? 0.0,
                  "lng": double.tryParse(depot["lng"].toString()) ?? 0.0,
                  "category": category,
                  "district": depot["district_name"] ?? "",
                  "state": depot["state_name"] ?? "",
                  "zone": depot["hq"] ?? "",
                  "div": depot["div"] ?? "",
                  "stn": depot["hq"] ?? "",
                  "status": depot["status"] ?? "",
                  "org_code": depot["org_code"]?.toString() ?? "",
                  "org_type": depot["org_type"] ?? ""
                };
              })
              .whereType<Map<String, dynamic>>()
              .toList();
          List<Map<String, dynamic>> depots11 = jsonDataLocation
              .map((depot) {
                String category = categoryCodeMapping[depot["org_type"]] ?? "";
                categoryCount[category] =
                    ((int.tryParse(categoryCount[category].toString()) ?? 0) +
                            1)
                        .toString();

                String? coords = depot["gis_coord"];
                if (coords != null && coords.isNotEmpty && category != "") {
                  coords = coords.replaceAll("(", "").replaceAll(")", "");
                  List<String> latLng = coords.split(",");
                  if (latLng.length < 2 || latLng.contains("null")) return null;
                  return {
                    "name": depot["org_desc"],
                    "lat": double.tryParse(depot["org_type"] == "YD" ||
                                depot["org_type"] == "RH" ||
                                depot["org_type"] == "SL"
                            ? latLng[1].trim()
                            : latLng[0].trim()) ??
                        0.0,
                    "lng": double.tryParse(depot["org_type"] == "YD" ||
                                depot["org_type"] == "RH" ||
                                depot["org_type"] == "SL"
                            ? latLng[0].trim()
                            : latLng[1].trim()) ??
                        0.0,
                    "category": (depot["org_type"] == "CT" &&
                            depot["status"] != "EXISTING")
                        ? "CTS Station(Proposed)"
                        : category,
                    "district": depot["org_type"] == "YD" ||
                            depot["org_type"] == "RH" ||
                            depot["org_type"] == "SL" ||
                            depot["org_type"] == "CT" ||
                            depot["org_type"] == "CD"
                        ? depot["district_name"]
                        : depot["lgd_district_name"],
                    "state": depot["org_type"] == "YD" ||
                            depot["org_type"] == "RH" ||
                            depot["org_type"] == "SL" ||
                            depot["org_type"] == "CT" ||
                            depot["org_type"] == "CD"
                        ? depot["state_name"]
                        : depot["lgd_state_name"],
                    "zone": depot["hq"],
                    "div": depot["div"],
                    "stn": depot["stn"],
                    "status": depot["status"],
                    "org_type": depot["org_type"]
                  };
                }
                return null;
              })
              .whereType<Map<String, dynamic>>()
              .toList();
          depots = [...depots, ...depots11, ...depots111];
          _isLoading = false;
        });
      } else {
        showError("Failed to fetch data.");
      }
    } catch (e) {
      showError("Error fetching data: $e");
    }
  }

  final PopupController popupController = PopupController();

  void _showDepotDetails(BuildContext context, Map<String, dynamic> depot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(depot["name"],
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: YardInfraDetails(depot),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    setState(() => _isLoading = false);
  }

  void toggleFilter(String category) {
    setState(() {
      filters.forEach((key, value) {
        if (key == category) {
          if (value) {
            filters[category] = false;
          } else {
            filters[category] = true;
          }
        }
      });
    });
  }

  String? selectedDepotName;

  final Map<String, Color> zoneColors = {};

  Color _getRandomColor() {
    final random = Random();
    return Color.fromARGB(
      255, // full opacity
      random.nextInt(200) + 30,
      random.nextInt(200) + 30,
      random.nextInt(200) + 30,
    );
  }

  LatLng _getPolygonCentroid(List<LatLng> points) {
    double lat = 0, lng = 0;
    for (var p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  UserInfo? getStoredUserInfo() {
    var data = Storage.getValue(Constants.userInfo);

    if (data is String) {
      try {
        var decodedData = jsonDecode(data);
        return UserInfo.fromJson(decodedData);
      } catch (e) {
        dprint("Error decoding UserInfo: $e");
      }
    } else if (data is Map<String, dynamic>) {
      return UserInfo.fromMap(data);
    }

    return null;
  }

  bool isMobile(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white.withOpacity(0.85),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: HeaderWidget(
          showLeading: true,
          user: getStoredUserInfo()?.firstname ?? '',
          zone: getStoredUserInfo()?.level ?? '',
          depot: getStoredUserInfo()?.location ?? '',
          division: getStoredUserInfo()?.department ?? '',
          department: '',
          backCallback: () {
            Get.back();
          },
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(23.5937, 82.9629),
                initialZoom: _currentZoom,
                onPositionChanged: (position, hasGesture) {
                  setState(() {
                    _currentZoom = position.zoom ?? _currentZoom;
                  });
                },
              ),
              children: [
                TileLayer(
                  // tileProvider: CachedNetworkTileProvider(),
                  tileSize: 256,

                  wmsOptions: WMSTileLayerOptions(
                    baseUrl:
                        'https://bhuvan-ras1.nrsc.gov.in/SatServices/service?',
                    layers: const ['bhuvan_awifs2021,bhuvan_vector'],
                    format: 'image/png',
                    transparent: true,
                    version: '1.1.1',
                    crs:
                        const Epsg3857(), // Must match SRS from GetCapabilities
                  ),
                  tileProvider: NetworkTileProvider(),
                  minZoom: 2,
                  maxZoom: 25,
                ),
                PolygonLayer(
                  polygons: zoneParser.polygons.map((p) {
                    final zoneName = p.label ?? 'Unknown';

                    // ensure we have a non-null Color to use (and reuse)
                    final fill =
                        zoneColors.putIfAbsent(zoneName, _getRandomColor);

                    return Polygon(
                      points: p.points,
                      isFilled: true,
                      color: fill.withOpacity(0.6), // 👈 unique fill color
                      borderColor: Colors.black,
                      borderStrokeWidth: 1.2,
                    );
                  }).toList(),
                ),
                PolylineLayer(
                  polylines: trackPolylines,
                  polylineCulling: true,
                ),
                MarkerLayer(
                  markers: zoneParser.polygons.map((polygon) {
                    final zoneName = polygon.label ?? "Unknown";
                    final center = _getPolygonCentroid(polygon.points);

                    return Marker(
                      point: center,
                      width: 120,
                      height: 40,
                      child: Text(
                        zoneName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: depots
                      .where((depot) {
                        if (depot["category"] == "CTS Station(Proposed)") {
                          return false;
                        } else if (filters[depot["category"]]! &&
                            (selectedZone == "ALL" ||
                                (depot['zone'].toString().toUpperCase() ==
                                    selectedZone!.toUpperCase()))) {
                          return true;
                        } else {
                          return false;
                        }
                      })
                      .map(
                        (depot) => Marker(
                            point: LatLng(depot["lat"], depot["lng"]),
                            width: 80, // adjust width for label
                            height: 60, // adjust height for label + marker
                            child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedDepotName = depot['name'];
                                  });
                                  _showDepotDetails(context, depot);
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Depot Name Label
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 2,
                                              offset: Offset(0, 1))
                                        ],
                                      ),
                                      child: Text(
                                        depot['name'],
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Marker (Circle + Triangle)
                                    Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        // Triangle (Tail)
                                        Positioned(
                                          bottom: 0,
                                          child: CustomPaint(
                                            size: const Size(20, 10),
                                            painter: TrianglePainter(
                                                color: categoryColors[
                                                        depot["category"]] ??
                                                    Colors.grey),
                                          ),
                                        ),
                                        // Circle (Head)
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: categoryColors[
                                                    depot["category"]] ??
                                                Colors.grey,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ))),
                      )
                      .toList(),
                ),
              ],
            ),
          Positioned(
            top: 10,
            left: 10,
            //  right: 1000, // leave space for zone filter
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4)
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _searchDepot,
                decoration: const InputDecoration(
                  hintText: "Search...",
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
              ),
            ),
          ),

          Positioned(
            top: 10,
            right: 10,
            child: Container(
              // width: 250,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 5)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Filter Zone",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  DropdownButton<String>(
                    value: selectedZone,
                    hint: const Text("Filter Zone"),
                    underline: const SizedBox(),
                    onChanged: (String? newZone) {
                      setState(() {
                        selectedZone = newZone;
                        // _filterMarkersByZone(newZone);
                      });
                    },
                    items: zone.map((item) {
                      return DropdownMenuItem(
                        value: item['orgSlno'].toString(),
                        child: Text(item['orgSlno']),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          /// Zoom Controls
          Positioned(
            bottom: 10,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  backgroundColor: AppColors.gradient1,
                  onPressed: () {
                    _mapController.move(
                        _mapController.center, _currentZoom + 0.5);
                    setState(() => _currentZoom += 0.5);
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  backgroundColor: AppColors.gradient1,
                  onPressed: () {
                    _mapController.move(
                        _mapController.center, _currentZoom - 0.5);
                    setState(() => _currentZoom -= 0.5);
                  },
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
              ],
            ),
          ),

          /// Filter Box for device types
          if (!_isLoading)
            Positioned(
              top: 100,
              right: 10,
              child: Container(
                width: isExpanded ? 280 : 120,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 5)
                  ],
                ),
                child: Column(
                  children: [
                    // Collapse/Expand Toggle
                    GestureDetector(
                        onTap: () {
                          setState(() {
                            isExpanded = !isExpanded;
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Filter",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isExpanded = !isExpanded;
                                });
                              },
                              child: Row(
                                children: [
                                  Text(
                                    isExpanded ? "Hide" : "More",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )),
                    const SizedBox(height: 8),

                    // Animated filter list
                    AnimatedCrossFade(
                      crossFadeState: isExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 300),

                      // Expanded scrollable view
                      firstChild: SizedBox(
                        height: isMobile(context)
                            ? 350
                            : 450, // set max scroll height
                        child: SingleChildScrollView(
                          child: Column(children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                "Device Type",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Divider(height: 1, thickness: 0.8),
                            ...filters.keys
                                .where((category) =>
                                    category != "CTS Station(Proposed)" &&
                                    categoryTypeUsed[category] == 'D')
                                .map(
                                  (category) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: categoryColors[category],
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            returnPointsCount(category),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Switch(
                                          activeColor: categoryColors[category],
                                          value: filters[category]!,
                                          onChanged: (val) =>
                                              toggleFilter(category),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                "Vendor Type",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Divider(height: 1, thickness: 0.8),
                            ...filters.keys
                                .where((category) =>
                                    categoryTypeUsed[category] == 'V')
                                .map(
                                  (category) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: categoryColors[category],
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            returnPointsCount(category),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Switch(
                                          activeColor: categoryColors[category],
                                          value: filters[category]!,
                                          onChanged: (val) =>
                                              toggleFilter(category),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                "Locations",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Divider(height: 1, thickness: 0.8),
                            ...filters.keys
                                .where((category) =>
                                    categoryTypeUsed[category] == 'L')
                                .map(
                                  (category) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: categoryColors[category],
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            returnPointsCount(category),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Switch(
                                          activeColor: categoryColors[category],
                                          value: filters[category]!,
                                          onChanged: (val) =>
                                              toggleFilter(category),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ]),
                        ),
                      ),

                      // Collapsed view
                      secondChild: SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

          if (selectedDepotName != null)
            Positioned(
              top: 70,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 5)
                    ]),
                child: Text(selectedDepotName!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const FooterWidget(),
    );
  }
}
