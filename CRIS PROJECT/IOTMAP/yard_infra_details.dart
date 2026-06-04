import 'package:flutter/material.dart';

class YardInfraDetails extends StatefulWidget {
  final Map<String, dynamic> depot;
  YardInfraDetails(this.depot);

  @override
  State<YardInfraDetails> createState() => _YardInfraDetailsState();
}

class _YardInfraDetailsState extends State<YardInfraDetails> {
  TableRow _buildTableRow(String key, String value) {
    return TableRow(children: [
      Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Text(key, style: const TextStyle(fontWeight: FontWeight.bold))),
      Padding(padding: const EdgeInsets.all(8.0), child: Text(value)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    List category = [
      'Freight Yard',
      'Coaching Depot',
      'Workdepot',
      'CTS Station',
      'ROH',
      'SickLine'
    ];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          !category.contains(widget.depot["category"] != null
                  ? widget.depot["category"].toString()
                  : "-")
              ? widget.depot["category"].toString() ==
                      widget.depot["status"].toString()
                  ? Table(
                      border: TableBorder.all(color: Colors.black12),
                      children: [
                        _buildTableRow(
                            "Device Id",
                            widget.depot["org_code"] != null
                                ? widget.depot["org_code"].toString()
                                : "-"),
                        _buildTableRow(
                            "Device Type",
                            widget.depot["org_type"] != null
                                ? widget.depot["org_type"].toString()
                                : "-"),
                        _buildTableRow(
                            "Zone",
                            widget.depot["zone"] != null
                                ? widget.depot["zone"].toString()
                                : "-"),
                        _buildTableRow(
                            "Division",
                            widget.depot["div"] != null
                                ? widget.depot["div"].toString()
                                : "-"),
                        _buildTableRow(
                            "Location Name",
                            widget.depot["name"] != null
                                ? widget.depot["name"].toString()
                                : "-"),
                        _buildTableRow(
                            "Section",
                            widget.depot["state"] != null
                                ? widget.depot["state"].toString()
                                : "-"),
                        _buildTableRow(
                            "Description",
                            widget.depot["district"] != null
                                ? widget.depot["district"].toString()
                                : "-"),
                        _buildTableRow(
                            "Vendor",
                            widget.depot["status"] != null
                                ? widget.depot["status"].toString()
                                : "-"),
                      ],
                    )
                  : Table(
                      border: TableBorder.all(color: Colors.black12),
                      children: [
                        _buildTableRow(
                            "Device Id",
                            widget.depot["org_code"] != null
                                ? widget.depot["org_code"].toString()
                                : "-"),
                        _buildTableRow(
                            "Device Type",
                            widget.depot["category"] != null
                                ? widget.depot["category"].toString()
                                : "-"),
                        _buildTableRow(
                            "Zone",
                            widget.depot["zone"] != null
                                ? widget.depot["zone"].toString()
                                : "-"),
                        _buildTableRow(
                            "Division",
                            widget.depot["div"] != null
                                ? widget.depot["div"].toString()
                                : "-"),
                        _buildTableRow(
                            "Location Name",
                            widget.depot["name"] != null
                                ? widget.depot["name"].toString()
                                : "-"),
                        _buildTableRow(
                            "Section",
                            widget.depot["state"] != null
                                ? widget.depot["state"].toString()
                                : "-"),
                        _buildTableRow(
                            "Description",
                            widget.depot["district"] != null
                                ? widget.depot["district"].toString()
                                : "-"),
                        _buildTableRow(
                            "Vendor",
                            widget.depot["status"] != null
                                ? widget.depot["status"].toString()
                                : "-"),
                      ],
                    )
              : Table(
                  border: TableBorder.all(color: Colors.black12),
                  children: [
                    _buildTableRow(
                        "Category",
                        widget.depot["category"] != null
                            ? widget.depot["category"].toString()
                            : "-"),
                    _buildTableRow(
                        "Zone",
                        widget.depot["zone"] != null
                            ? widget.depot["zone"].toString()
                            : "-"),
                    _buildTableRow(
                        "Division",
                        widget.depot["div"] != null
                            ? widget.depot["div"].toString()
                            : "-"),
                    _buildTableRow(
                        "Station",
                        widget.depot["stn"] != null
                            ? widget.depot["stn"].toString()
                            : "-"),
                    _buildTableRow(
                        "State",
                        widget.depot["state"] != null
                            ? widget.depot["state"].toString()
                            : "-"),
                    _buildTableRow(
                        "District",
                        widget.depot["district"] != null
                            ? widget.depot["district"].toString()
                            : "-"),
                  ],
                ),
        ],
      ),
    );
  }
}
