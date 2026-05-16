import 'package:flutter/material.dart';
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

  Map<String, dynamic>? latestVitals;

  List<dynamic> doctorResponses = [];

  final TextEditingController queryController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    fetchLatestVitals();
    fetchDoctorResponses();
  }

  Future<void> fetchLatestVitals() async {
    try {
      final response = await supabase
          .from('vitals')
          .select()
          .order('id', ascending: false)
          .limit(1)
          .single();

      setState(() {
        latestVitals = response;
        loading = false;
      });
    } catch (e) {
      print(e);

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> fetchDoctorResponses() async {
    try {
      final response = await supabase
          .from('query_responses')
          .select()
          .order('id', ascending: false);

      setState(() {
        doctorResponses = response;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> sendQuery() async {
    final query = queryController.text.trim();

    if (query.isEmpty) return;

    try {
      await supabase.from('family_queries').insert({
        'query': query,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Query sent"),
        ),
      );

      queryController.clear();
    } catch (e) {
      print(e);
    }
  }

  String getStatus(String type, double value) {
    if (type == "oxygen") {
      if (value < 92) return "Critical";
      if (value < 95) return "Observation";
      return "Stable";
    }

    if (type == "bp") {
      if (value > 140) return "Critical";
      if (value > 120) return "Observation";
      return "Stable";
    }

    if (type == "sugar") {
      if (value > 250) return "Critical";
      if (value > 140) return "Observation";
      return "Stable";
    }

    return "Stable";
  }

  Color statusColor(String status) {
    if (status == "Critical") return Colors.red;

    if (status == "Observation") {
      return Colors.orange;
    }

    return Colors.green;
  }

  Widget statusCard(
    String title,
    String status,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 10,
      ),

      child: ListTile(
        title: Text(title),

        trailing: Text(
          status,
          style: TextStyle(
            color: statusColor(status),
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

    if (latestVitals == null) {
      return const Scaffold(
        body: Center(
          child: Text("No vitals found"),
        ),
      );
    }

    final oxygen =
        (latestVitals!['oxygen'] as num).toDouble();

    final bp =
        (latestVitals!['bp'] as num).toDouble();

    final sugar =
        (latestVitals!['sugar'] as num).toDouble();

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
              statusCard(
                "Oxygen",
                getStatus("oxygen", oxygen),
              ),

              statusCard(
                "Blood Pressure",
                getStatus("bp", bp),
              ),

              statusCard(
                "Sugar Level",
                getStatus("sugar", sugar),
              ),

              const SizedBox(height: 30),

              const Align(
                alignment: Alignment.centerLeft,

                child: Text(
                  "Ask Doctor",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: queryController,
                maxLines: 4,

                decoration: InputDecoration(
                  hintText:
                      "Ask a non-emergency question...",

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
                  onPressed: sendQuery,

                  child: const Text(
                    "Send Query",
                  ),
                ),
              ),

              const SizedBox(height: 40),

              const Align(
                alignment: Alignment.centerLeft,

                child: Text(
                  "Doctor Responses",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              ListView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),

                itemCount: doctorResponses.length,

                itemBuilder: (context, index) {
                  final response =
                      doctorResponses[index];

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
                          const Text(
                            "Doctor Response",
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            response['response'],
                            style: const TextStyle(
                              fontSize: 16,
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