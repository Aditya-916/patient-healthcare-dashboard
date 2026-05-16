import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

final supabase = Supabase.instance.client;

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  bool loading = true;

  List<Map<String, dynamic>> patients = [];
  int? selectedPatientId;

  List<FlSpot> oxygenData = [];
  List<FlSpot> bpData = [];
  List<FlSpot> sugarData = [];

  List<Map<String, dynamic>> familyQueries = [];
  List<Map<String, dynamic>> alerts = [];

  final noteController = TextEditingController();

  RealtimeChannel? queryChannel;

  @override
  void initState() {
    super.initState();
    fetchPatients();
    listenToFamilyQueries();
  }

  void listenToFamilyQueries() {
    queryChannel = supabase.channel('family_queries_channel');

    queryChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'family_queries',
          callback: (payload) {
            fetchQueries();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    queryChannel?.unsubscribe();
    noteController.dispose();
    super.dispose();
  }

  Future<void> fetchPatients() async {
    try {
      final response = await supabase.from('patients').select();

      patients = List<Map<String, dynamic>>.from(response);

      if (patients.isNotEmpty) {
        selectedPatientId = patients.first['id'];

        await fetchVitals();
        await fetchQueries();
        await fetchAlerts();
      }

      setState(() {
        loading = false;
      });
    } catch (e) {
      print("Patients Error: $e");

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> fetchVitals() async {
    if (selectedPatientId == null) return;

    try {
      final response = await supabase
          .from('vitals')
          .select()
          .eq('patient_id', selectedPatientId!)
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

      
        oxygenData = oxygen;
        bpData = bp;
        sugarData = sugar;
      await generateAlerts();

      setState(() {});
      
    } catch (e) {
      print("Vitals Error: $e");
    }
  }

  Future<void> fetchQueries() async {
    if (selectedPatientId == null) return;

    try {
      final response = await supabase
          .from('family_queries')
          .select()
          .eq('patient_id', selectedPatientId!)
          .order('id');

      setState(() {
        familyQueries = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("Query Error: $e");
    }
  }

  Future<void> fetchAlerts() async {
    if (selectedPatientId == null) return;

    try {
      final response = await supabase
          .from('alerts')
          .select()
          .eq('patient_id', selectedPatientId!)
          .order('created_at', ascending: false);

      setState(() {
        alerts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print("Alerts Error: $e");
    }
  }

  Future<void> createAlert({
    required String type,
    required double value,
    required String severity,
    required String message,
  }) async {
    try {
      await supabase.from('alerts').insert({
        'patient_id': selectedPatientId,
        'type': type,
        'value': value,
        'severity': severity,
        'message': message,
      });
    } catch (e) {
      print("Create Alert Error: $e");
    }
  }

  Future<void> generateAlerts() async {
    if (oxygenData.isEmpty || bpData.isEmpty || sugarData.isEmpty) {
      return;
    }

    final oxygen = oxygenData.last.y;
    final bp = bpData.last.y;
    final sugar = sugarData.last.y;

    if (oxygen < 92) {
      await createAlert(
        type: "Oxygen",
        value: oxygen,
        severity: "Critical",
        message: "Oxygen level critically low",
      );
    }

    if (bp > 140) {
      await createAlert(
        type: "Blood Pressure",
        value: bp,
        severity: "Warning",
        message: "Blood pressure elevated",
      );
    }

    if (sugar > 250) {
      await createAlert(
        type: "Sugar",
        value: sugar,
        severity: "Critical",
        message: "Sugar level dangerously high",
      );
    }

    await fetchAlerts();
  }

  Future<void> saveDoctorNote() async {
    final note = noteController.text.trim();

    if (note.isEmpty || selectedPatientId == null) return;

    try {
      await supabase.from('doctor_notes').insert({
        'note': note,
        'patient_id': selectedPatientId,
      });

      noteController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Doctor note saved"),
        ),
      );
    } catch (e) {
      print("Doctor Note Error: $e");
    }
  }

  Future<void> respondToQuery(
    int queryId,
    String response,
  ) async {
    if (selectedPatientId == null) return;

    try {
      await supabase.from('query_responses').insert({
        'query_id': queryId,
        'response': response,
        'patient_id': selectedPatientId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Response submitted"),
        ),
      );
    } catch (e) {
      print("Response Error: $e");
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
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: data.isEmpty ? 0 : data.length - 1,
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    getTitlesWidget: (value, meta) {
                      for (var v in yValues) {
                        if ((value - v).abs() < 1) {
                          return Text(
                            v.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
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
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final labels = [
                        "6 AM",
                        "9 AM",
                        "12 PM",
                        "3 PM",
                        "6 PM",
                      ];

                      if (value.toInt() >= 0 &&
                          value.toInt() < labels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }

                      return const Text('');
                    },
                  ),
                ),
              ),
              lineBarsData: buildSegments(data, type),
            ),
          ),
        ),
      ],
    );
  }

  Widget vitalCard(
    String title,
    String value,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget buildAlertsSection() {
    if (alerts.isEmpty) return const SizedBox();

    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Active Alerts",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 15),
        ...alerts.map((alert) {
          final severity = alert['severity'];

          Color color = Colors.orange;

          if (severity == "Critical") {
            color = Colors.red;
          }

          return Card(
            color: color.withOpacity(0.2),
            child: ListTile(
              title: Text(
                alert['message'] ?? '',
              ),
              subtitle: Text(
                "${alert['type']} • ${alert['value']}",
              ),
              trailing: Text(
                severity ?? '',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 30),
      ],
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
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();

              if (!context.mounted) return;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButton<int>(
                value: selectedPatientId,
                isExpanded: true,
                hint: const Text("Select Patient"),
                items: patients.map((patient) {
                  return DropdownMenuItem<int>(
                    value: patient['id'],
                    child: Text(patient['name']),
                  );
                }).toList(),
                onChanged: (value) async {
                  setState(() {
                    selectedPatientId = value;
                    alerts = [];
                    oxygenData = [];
                    bpData = [];
                    sugarData = [];
                    familyQueries = [];
                  });

                  await fetchVitals();
                  await fetchQueries();
                  await fetchAlerts();
                },
              ),
              const SizedBox(height: 30),
              buildAlertsSection(),
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
              const SizedBox(height: 30),
              if (oxygenData.isNotEmpty)
                vitalCard(
                  "Current Oxygen",
                  "${oxygenData.last.y.toStringAsFixed(0)} %",
                ),
              if (bpData.isNotEmpty)
                vitalCard(
                  "Current Blood Pressure",
                  "${bpData.last.y.toStringAsFixed(0)} mmHg",
                ),
              if (sugarData.isNotEmpty)
                vitalCard(
                  "Current Sugar",
                  "${sugarData.last.y.toStringAsFixed(0)} mg/dL",
                ),
              const SizedBox(height: 30),
              TextField(
                controller: noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Doctor observations...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: saveDoctorNote,
                child: const Text("Save Doctor Note"),
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
              const SizedBox(height: 20),
              ...familyQueries.map((query) {
                final responseController = TextEditingController();

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          query['query'] ?? '',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: responseController,
                          decoration: const InputDecoration(
                            hintText: "Respond to family...",
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            respondToQuery(
                              query['id'],
                              responseController.text,
                            );
                          },
                          child: const Text("Send Response"),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}