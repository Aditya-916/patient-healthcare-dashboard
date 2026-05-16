import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

final supabase = Supabase.instance.client;

class FamilyDashboard extends StatefulWidget {
  const FamilyDashboard({super.key});

  @override
  State<FamilyDashboard> createState() =>
      _FamilyDashboardState();
}

class _FamilyDashboardState
    extends State<FamilyDashboard> {
  bool loading = true;

  int? patientId;

  // =========================
  // VITALS
  // =========================

  List<FlSpot> oxygenData = [];
  List<FlSpot> bpData = [];
  List<FlSpot> sugarData = [];

  // =========================
  // NOTES
  // =========================

  List<Map<String, dynamic>> doctorNotes = [];

  // =========================
  // RESPONSES
  // =========================

  List<Map<String, dynamic>> responses = [];

  // =========================
  // CONTROLLERS
  // =========================

  final queryController =
      TextEditingController();

  RealtimeChannel? responseChannel;

  @override
  void initState() {
    super.initState();

    initializeDashboard();
  }

  // =========================
  // INITIALIZE
  // =========================

  Future<void> initializeDashboard() async {
    await fetchPatientId();

    if (patientId != null) {
      await fetchVitals();
      await fetchDoctorNotes();
      await fetchResponses();

      listenToResponses();
    }

    setState(() {
      loading = false;
    });
  }

  // =========================
  // FETCH PATIENT ID
  // =========================

  Future<void> fetchPatientId() async {
    try {
      final user =
          supabase.auth.currentUser;

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user!.id)
          .single();

      patientId =
          response['patient_id'];
    } catch (e) {
      print("Patient ID Error: $e");
    }
  }

  // =========================
  // REALTIME RESPONSES
  // =========================

  void listenToResponses() {
    responseChannel =
        supabase.channel(
      'query_responses_channel',
    );

    responseChannel!
        .onPostgresChanges(
          event:
              PostgresChangeEvent.insert,
          schema: 'public',
          table: 'query_responses',

          callback: (payload) {
            fetchResponses();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    responseChannel?.unsubscribe();

    queryController.dispose();

    super.dispose();
  }

  // =========================
  // FETCH VITALS
  // =========================

  Future<void> fetchVitals() async {
    try {
      final response = await supabase
          .from('vitals')
          .select()
          .eq(
            'patient_id',
            patientId!,
          )
          .order('id');

      List<FlSpot> oxygen = [];
      List<FlSpot> bp = [];
      List<FlSpot> sugar = [];

      for (int i = 0;
          i < response.length;
          i++) {
        final row = response[i];

        oxygen.add(
          FlSpot(
            i.toDouble(),
            (row['oxygen'] as num)
                .toDouble(),
          ),
        );

        bp.add(
          FlSpot(
            i.toDouble(),
            (row['bp'] as num)
                .toDouble(),
          ),
        );

        sugar.add(
          FlSpot(
            i.toDouble(),
            (row['sugar'] as num)
                .toDouble(),
          ),
        );
      }

      setState(() {
        oxygenData = oxygen;
        bpData = bp;
        sugarData = sugar;
      });
    } catch (e) {
      print("Vitals Error: $e");
    }
  }

  // =========================
  // FETCH DOCTOR NOTES
  // =========================

  Future<void> fetchDoctorNotes() async {
    try {
      final response = await supabase
          .from('doctor_notes')
          .select()
          .eq(
            'patient_id',
            patientId!,
          )
          .order('id');

      setState(() {
        doctorNotes =
            List<Map<String, dynamic>>
                .from(response);
      });
    } catch (e) {
      print("Notes Error: $e");
    }
  }

  // =========================
  // FETCH RESPONSES
  // =========================

  Future<void> fetchResponses() async {
    try {
      final response = await supabase
          .from('query_responses')
          .select()
          .eq(
            'patient_id',
            patientId!,
          )
          .order('id');

      setState(() {
        responses =
            List<Map<String, dynamic>>
                .from(response);
      });
    } catch (e) {
      print("Responses Error: $e");
    }
  }

  // =========================
  // SUBMIT QUERY
  // =========================

  Future<void> submitQuery() async {
    final query =
        queryController.text.trim();

    if (query.isEmpty) return;

    try {
      await supabase
          .from('family_queries')
          .insert({
        'query': query,
        'patient_id': patientId,
      });

      queryController.clear();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Query submitted"),
        ),
      );
    } catch (e) {
      print("Query Error: $e");
    }
  }

  // =========================
  // LEVEL LOGIC
  // =========================

  int getLevel(
    String type,
    double value,
  ) {
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
    if (level == 2) {
      return Colors.red;
    }

    if (level == 1) {
      return Colors.orange;
    }

    return Colors.green;
  }

  // =========================
  // GRAPH SEGMENTS
  // =========================

  List<LineChartBarData> buildSegments(
    List<FlSpot> data,
    String type,
  ) {
    List<LineChartBarData> segments =
        [];

    for (int i = 0;
        i < data.length - 1;
        i++) {
      final start = data[i];
      final end = data[i + 1];

      int level = getLevel(
        type,
        end.y,
      );

      segments.add(
        LineChartBarData(
          spots: [start, end],
          isCurved: true,
          color: levelColor(level),
          barWidth: 5,

          dotData: FlDotData(
            show: true,
          ),
        ),
      );
    }

    return segments;
  }

  // =========================
  // GRAPH UI
  // =========================

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
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style: const TextStyle(
            fontSize: 22,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 230,

          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: data.isEmpty
                  ? 0
                  : data.length - 1,

              gridData: FlGridData(
                show: true,
              ),

              borderData: FlBorderData(
                show: true,
              ),

              titlesData: FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles:
                      SideTitles(
                    showTitles: false,
                  ),
                ),

                rightTitles:
                    AxisTitles(
                  sideTitles:
                      SideTitles(
                    showTitles: false,
                  ),
                ),

                leftTitles:
                    AxisTitles(
                  sideTitles:
                      SideTitles(
                    showTitles: true,
                    reservedSize: 35,

                    getTitlesWidget:
                        (value, meta) {
                      for (var v
                          in yValues) {
                        if ((value - v)
                                .abs() <
                            1) {
                          return Text(
                            v.toInt()
                                .toString(),

                            style:
                                const TextStyle(
                              fontSize:
                                  10,
                            ),
                          );
                        }
                      }

                      return const Text(
                          '');
                    },
                  ),
                ),

                bottomTitles:
                    AxisTitles(
                  sideTitles:
                      SideTitles(
                    showTitles: true,
                    interval: 1,

                    getTitlesWidget:
                        (value, meta) {
                      final labels = [
                        "6 AM",
                        "9 AM",
                        "12 PM",
                        "3 PM",
                        "6 PM",
                      ];

                      if (value
                                  .toInt() >=
                              0 &&
                          value.toInt() <
                              labels.length) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(
                            top: 8,
                          ),

                          child: Text(
                            labels[value
                                .toInt()],

                            style:
                                const TextStyle(
                              fontSize:
                                  10,
                            ),
                          ),
                        );
                      }

                      return const Text(
                          '');
                    },
                  ),
                ),
              ),

              lineBarsData:
                  buildSegments(
                data,
                type,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // MAIN UI
  // =========================

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Family Dashboard",
        ),

        actions: [
          IconButton(
            icon:
                const Icon(Icons.logout),

            onPressed: () async {
              await supabase.auth
                  .signOut();

              if (!context.mounted) {
                return;
              }

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(16),

        child: SingleChildScrollView(
          child: Column(
            children: [
              buildGraph(
                "Oxygen (SpO2 %)",
                oxygenData,
                "oxygen",
              ),

              const SizedBox(height: 30),

              buildGraph(
                "Blood Pressure (mmHg)",
                bpData,
                "bp",
              ),

              const SizedBox(height: 30),

              buildGraph(
                "Sugar Level (mg/dL)",
                sugarData,
                "sugar",
              ),

              const SizedBox(height: 40),

              const Align(
                alignment:
                    Alignment.centerLeft,

                child: Text(
                  "Doctor Notes",

                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              ...doctorNotes.map((note) {
                return Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),

                    child: Text(
                      note['note'] ?? '',
                    ),
                  ),
                );
              }),

              const SizedBox(height: 40),

              const Align(
                alignment:
                    Alignment.centerLeft,

                child: Text(
                  "Doctor Responses",

                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              ...responses.map((response) {
                return Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),

                    child: Text(
                      response['response'] ??
                          '',
                    ),
                  ),
                );
              }),

              const SizedBox(height: 40),

              TextField(
                controller:
                    queryController,

                maxLines: 3,

                decoration:
                    const InputDecoration(
                  hintText:
                      "Ask doctor a question...",
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              ElevatedButton(
                onPressed:
                    submitQuery,

                child: const Text(
                  "Submit Query",
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}