import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() =>
      _DoctorDashboardState();
}

class _DoctorDashboardState
    extends State<DoctorDashboard> {
  bool loading = true;

  final TextEditingController doctorController =
      TextEditingController();

  final TextEditingController responseController =
      TextEditingController();

  List<dynamic> familyQueries = [];

  List<FlSpot> oxygenData = [];
  List<FlSpot> bpData = [];
  List<FlSpot> sugarData = [];

  @override
  void initState() {
    super.initState();

    fetchVitals();
    fetchFamilyQueries();
  }

  Future<void> fetchVitals() async {
    try {
      final response = await supabase
          .from('vitals')
          .select()
          .order('id');

      List<FlSpot> oxygen = [];
      List<FlSpot> bp = [];
      List<FlSpot> sugar = [];

      for (int i = 0; i < response.length; i++) {
        final row = response[i];

        oxygen.add(
          FlSpot(
            i.toDouble(),
            (row['oxygen'] as num).toDouble(),
          ),
        );

        bp.add(
          FlSpot(
            i.toDouble(),
            (row['bp'] as num).toDouble(),
          ),
        );

        sugar.add(
          FlSpot(
            i.toDouble(),
            (row['sugar'] as num).toDouble(),
          ),
        );
      }

      setState(() {
        oxygenData = oxygen;
        bpData = bp;
        sugarData = sugar;
        loading = false;
      });
    } catch (e) {
      print(e);

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> fetchFamilyQueries() async {
    try {
      final response = await supabase
          .from('family_queries')
          .select()
          .order('id', ascending: false);

      setState(() {
        familyQueries = response;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> saveDoctorNote() async {
    final note = doctorController.text.trim();

    if (note.isEmpty) return;

    try {
      await supabase.from('doctor_notes').insert({
        'note': note,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Doctor note saved"),
        ),
      );

      doctorController.clear();
    } catch (e) {
      print(e);
    }
  }

  Future<void> sendResponse(int queryId) async {
    final responseText = responseController.text.trim();

    if (responseText.isEmpty) return;

    try {
      await supabase.from('query_responses').insert({
        'query_id': queryId,
        'response': responseText,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Response sent"),
        ),
      );

      responseController.clear();
    } catch (e) {
      print(e);
    }
  }

  int getLevel(String type, double value) {
    if (type == "oxygen") {
      if (value < 92) return 2;
      if (value < 95) return 1;
      return 0;
    }

    if (type == "bp") {
      if (value > 140) return 2;
      if (value > 120) return 1;
      return 0;
    }

    if (type == "sugar") {
      if (value > 250) return 2;
      if (value > 140) return 1;
      return 0;
    }

    return 0;
  }

  Color levelColor(int level) {
    if (level == 2) return Colors.red;
    if (level == 1) return Colors.orange;
    return Colors.green;
  }

  List<LineChartBarData> buildSegments(
    List<FlSpot> data,
    String type,
  ) {
    List<LineChartBarData> segments = [];

    for (int i = 0; i < data.length - 1; i++) {
      final start = data[i];
      final end = data[i + 1];

      int level = getLevel(type, end.y);

      segments.add(
        LineChartBarData(
          spots: [start, end],
          isCurved: true,
          color: levelColor(level),
          barWidth: 5,
          dotData: FlDotData(show: true),
        ),
      );
    }

    return segments;
  }

  Widget buildGraph(
    String title,
    List<FlSpot> data,
    String type,
  ) {
    List<double> yValues = [];

    if (type == "oxygen") {
      yValues = [90, 95, 100];
    } else if (type == "bp") {
      yValues = [100, 120, 140];
    } else {
      yValues = [100, 150, 200, 250];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          height: 220,

          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 4,

              gridData: FlGridData(show: true),

              borderData: FlBorderData(show: true),

              titlesData: FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: false),
                ),

                rightTitles: AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: false),
                ),

                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,

                    getTitlesWidget:
                        (value, meta) {
                      for (var v in yValues) {
                        if ((value - v).abs() < 1) {
                          return Text(
                            v.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                            ),
                          );
                        }
                      }

                      return const Text('');
                    },
                  ),
                ),

                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,

                    getTitlesWidget:
                        (value, meta) {
                      final labels = [
                        "6 AM",
                        "9 AM",
                        "12 PM",
                        "3 PM",
                        "6 PM",
                      ];

                      if (value.toInt() >= 0 &&
                          value.toInt() <
                              labels.length) {
                        return Text(
                          labels[value.toInt()],
                          style: const TextStyle(
                            fontSize: 10,
                          ),
                        );
                      }

                      return const Text('');
                    },
                  ),
                ),
              ),

              lineBarsData:
                  buildSegments(data, type),
            ),
          ),
        ),
      ],
    );
  }

  Widget vitalCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 10,
      ),

      child: ListTile(
        title: Text(title),

        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Doctor Dashboard",
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: SingleChildScrollView(
          child: Column(
            children: [
              buildGraph(
                "Oxygen (SpO2 %)",
                oxygenData,
                "oxygen",
              ),

              const SizedBox(height: 25),

              buildGraph(
                "Blood Pressure (mmHg)",
                bpData,
                "bp",
              ),

              const SizedBox(height: 25),

              buildGraph(
                "Sugar Level (mg/dL)",
                sugarData,
                "sugar",
              ),

              const SizedBox(height: 30),

              vitalCard(
                "Current Oxygen",
                "${oxygenData.last.y.toStringAsFixed(0)} %",
              ),

              vitalCard(
                "Current BP",
                "${bpData.last.y.toStringAsFixed(0)} mmHg",
              ),

              vitalCard(
                "Current Sugar",
                "${sugarData.last.y.toStringAsFixed(0)} mg/dL",
              ),

              const SizedBox(height: 30),

              TextField(
                controller: doctorController,
                maxLines: 4,

                decoration: InputDecoration(
                  hintText:
                      "Doctor observations...",

                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,

                child: ElevatedButton(
                  onPressed: saveDoctorNote,

                  child: const Text(
                    "Save Doctor Note",
                  ),
                ),
              ),

              const SizedBox(height: 40),

              const Align(
                alignment: Alignment.centerLeft,

                child: Text(
                  "Family Queries",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              ListView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),

                itemCount: familyQueries.length,

                itemBuilder: (context, index) {
                  final query = familyQueries[index];

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(
                      vertical: 10,
                    ),

                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            query['query'],
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextField(
                            controller:
                                responseController,

                            decoration:
                                InputDecoration(
                              hintText:
                                  "Type response...",

                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          SizedBox(
                            width:
                                double.infinity,

                            child: ElevatedButton(
                              onPressed: () {
                                sendResponse(
                                  query['id'],
                                );
                              },

                              child: const Text(
                                "Send Response",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}