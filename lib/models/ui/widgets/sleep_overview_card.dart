import 'package:flutter/material.dart';
import 'package:tane06_app/theme/app_theme.dart';
import 'hypnogram_painter.dart';

class SleepDetailPage extends StatefulWidget {
  const SleepDetailPage({super.key});

  @override
  State<SleepDetailPage> createState() => _SleepDetailPageState();
}

class _SleepDetailPageState extends State<SleepDetailPage> {
  bool showHR = false;
  bool showSpo2 = false;

  final List<SleepSegment> sampleSleep = const [
    SleepSegment(stage: SleepStage.light, durationMinutes: 30),
    SleepSegment(stage: SleepStage.deep, durationMinutes: 45),
    SleepSegment(stage: SleepStage.light, durationMinutes: 60),
    SleepSegment(stage: SleepStage.rem, durationMinutes: 20),
    SleepSegment(stage: SleepStage.light, durationMinutes: 50),
    SleepSegment(stage: SleepStage.awake, durationMinutes: 5),
    SleepSegment(stage: SleepStage.deep, durationMinutes: 40),
    SleepSegment(stage: SleepStage.light, durationMinutes: 30),
    SleepSegment(stage: SleepStage.rem, durationMinutes: 25),
    SleepSegment(stage: SleepStage.deep, durationMinutes: 30),
  ];

  @override
  Widget build(BuildContext context) {
    const totalSleepMinutes = 538;

    final h = totalSleepMinutes ~/ 60;
    final m = totalSleepMinutes % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sleep Monitoring"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                //-----------------------------------
                // TITLE + SWITCHES
                //-----------------------------------

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Sleep Monitoring",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Row(
                      children: [

                        Switch(
                          value: showHR,
                          onChanged: (v) {
                            setState(() {
                              showHR = v;
                            });
                          },
                        ),

                        const Text("HR"),

                        const SizedBox(width: 10),

                        Switch(
                          value: showSpo2,
                          onChanged: (v) {
                            setState(() {
                              showSpo2 = v;
                            });
                          },
                        ),

                        const Text("SpO₂"),
                      ],
                    ),
                  ],
                ),

                const Divider(),

                //-----------------------------------
                // TOTAL SLEEP
                //-----------------------------------

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Total Sleeping Time : ${h}h ${m}m",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Jul 14, 21:34 - Jul 15, 06:32",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                //-----------------------------------
                // LEGEND
                //-----------------------------------

                const Row(
                  children: [
                    LegendItem(
                      color: Colors.indigo,
                      label: "Deep",
                    ),
                    SizedBox(width: 18),

                    LegendItem(
                      color: Colors.blue,
                      label: "Light",
                    ),
                    SizedBox(width: 18),

                    LegendItem(
                      color: Colors.purple,
                      label: "REM",
                    ),
                    SizedBox(width: 18),

                    LegendItem(
                      color: Colors.orange,
                      label: "Awake",
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                //-----------------------------------
                // HYPNOGRAM
                //-----------------------------------

                Hypnogram(
                  segments: sampleSleep,
                ),

                const SizedBox(height: 30),

                //-----------------------------------
                // DONUT + STATS
                //-----------------------------------

                Row(
                  children: [

                    Expanded(
                      flex: 2,
                      child: SleepDonut(
                        totalMinutes: totalSleepMinutes,
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: Column(
                        children: const [

                          InfoTile(
                            title: "Avg HR",
                            value: "70.7 bpm",
                          ),

                          SizedBox(height: 15),

                          InfoTile(
                            title: "Min HR",
                            value: "61 bpm",
                          ),

                          SizedBox(height: 15),

                          InfoTile(
                            title: "RMSSD",
                            value: "49.4 ms",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

              ],
            ),
          ),
        ),
      ),
    );
  }
}


class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        CircleAvatar(
          radius: 5,
          backgroundColor: color,
        ),

        const SizedBox(width: 5),

        Text(label),
      ],
    );
  }
}



class InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const InfoTile({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [

        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}



class SleepDonut extends StatelessWidget {
  final int totalMinutes;

  const SleepDonut({
    super.key,
    required this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {

    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        children: [

          Positioned.fill(
            child: CustomPaint(
              painter: DonutPainter(),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Text(
                  "${h}h ${m}m",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Text(
                  "Sleep",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class DonutPainter extends CustomPainter {

  @override
  void paint(Canvas canvas, Size size) {

    final rect = Offset.zero & size;

    final backgroundPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      rect.deflate(8),
      0,
      6.28,
      false,
      backgroundPaint,
    );


    final progressPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;


    canvas.drawArc(
      rect.deflate(8),
      -1.57,
      5,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}


class SleepOverviewCard extends StatefulWidget {
  final int? totalMinutes;
  final List<SleepSegment>? segments;

  const SleepOverviewCard({super.key, this.totalMinutes, this.segments});

  @override
  State<SleepOverviewCard> createState() => _SleepOverviewCardState();
}

class _SleepOverviewCardState extends State<SleepOverviewCard> {
  @override
  Widget build(BuildContext context) {
    final sample = widget.segments ?? const [
      SleepSegment(stage: SleepStage.light, durationMinutes: 30),
      SleepSegment(stage: SleepStage.deep, durationMinutes: 45),
      SleepSegment(stage: SleepStage.light, durationMinutes: 60),
      SleepSegment(stage: SleepStage.rem, durationMinutes: 20),
      SleepSegment(stage: SleepStage.light, durationMinutes: 50),
      SleepSegment(stage: SleepStage.awake, durationMinutes: 5),
      SleepSegment(stage: SleepStage.deep, durationMinutes: 40),
    ];

    final total = widget.totalMinutes ?? sample.fold<int>(0, (p, e) => p + e.durationMinutes);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Sleep', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),

            // Hypnogram
            Hypnogram(segments: sample),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${total ~/ 60}h ${total % 60}m',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sleep',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      InfoTile(title: 'Avg HR', value: '70.7 bpm'),
                      SizedBox(height: 8),
                      InfoTile(title: 'Min HR', value: '61 bpm'),
                      SizedBox(height: 8),
                      InfoTile(title: 'RMSSD', value: '49.4 ms'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}