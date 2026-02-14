import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuidesPage extends StatefulWidget {
  const GuidesPage({Key? key}) : super(key: key);

  @override
  State<GuidesPage> createState() => _GuidesPageState();
}

class _GuidesPageState extends State<GuidesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  final List<List<Color>> _backgroundGradients = [
    [Color(0xFF0BA360), Color(0xFF3CBA92)], // Do’s
    [Color(0xFFCB2D3E), Color(0xFFEF473A)], // Don’ts
    [Color(0xFF1E3C72), Color(0xFF2A5298)], // Raw
  ];

  final List<Color> _indicatorColors = [
    Colors.greenAccent,
    Colors.redAccent,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> getHistoryStream() {
    return FirebaseFirestore.instance
        .collection('directives')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ================== SAFE TEXT CLEANER ==================
  // Only removes extra spaces & multiple blank lines
  // DOES NOT remove symbols or change formatting

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\n\s*\n'), '\n') // Remove multiple blank lines
        .replaceAll(RegExp(r'[ \t]+'), ' ')   // Remove extra spaces
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Hero(
          tag: "historyTitle",
          child: Text(
            "History",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: "Do’s"),
                  Tab(text: "Don’ts"),
                  Tab(text: "Raw Text"),
                ],
              ),
              const SizedBox(height: 6),
              _SlidingIndicator(
                controller: _tabController,
                color: _indicatorColors[_currentIndex],
              ),
            ],
          ),
        ),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _backgroundGradients[_currentIndex],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: getHistoryStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                );
              }

              var docs = snapshot.data!.docs;

              return Column(
                children: [
                  _buildStatsHeader(docs),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(docs, type: "dos"),
                        _buildList(docs, type: "donts"),
                        _buildList(docs, type: "raw"),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ================== STATS HEADER ==================

  Widget _buildStatsHeader(List<QueryDocumentSnapshot> docs) {
    int totalDos = 0;
    int totalDonts = 0;

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;

      List<dynamic> dosList = (data['dos'] as List<dynamic>?) ?? [];
      List<dynamic> dontsList = (data['donts'] as List<dynamic>?) ?? [];

      totalDos += dosList.length;
      totalDonts += dontsList.length;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _animatedCounter("Do’s", totalDos),
          _animatedCounter("Don’ts", totalDonts),
          _animatedCounter("Docs", docs.length),
        ],
      ),
    );
  }

  Widget _animatedCounter(String title, int value) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 800),
          builder: (context, double val, child) {
            return Text(
              val.toInt().toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  // ================== LIST ==================

  Widget _buildList(List<QueryDocumentSnapshot> docs,
      {required String type}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        var doc = docs[index];
        var data = doc.data() as Map<String, dynamic>;

        return Dismissible(
          key: Key(doc.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            FirebaseFirestore.instance
                .collection('directives')
                .doc(doc.id)
                .delete();
          },
          child: TweenAnimationBuilder(
            duration: Duration(milliseconds: 300 + (index * 100)),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, val, child) {
              return Opacity(
                opacity: val,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - val)),
                  child: child,
                ),
              );
            },
            child: _buildCard(data, type),
          ),
        );
      },
    );
  }

  Widget _buildCard(Map<String, dynamic> data, String type) {
    if (type == "raw") {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
            )
          ],
        ),
        child: Text(
          _cleanText(data['rawText'] ?? ""),
          style: const TextStyle(
            color: Colors.black87,
            height: 1.6,
          ),
        ),
      );
    }

    List items = data[type] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map<Widget>(
              (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  type == "dos"
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _cleanText(e.toString()),
                    style:
                    const TextStyle(color: Colors.white),
                  ),
                )
              ],
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}

// ================== SLIDING INDICATOR ==================

class _SlidingIndicator extends StatelessWidget {
  final TabController controller;
  final Color color;

  const _SlidingIndicator({
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width / 3;

    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, child) {
        return Stack(
          children: [
            Container(
              height: 4,
              margin:
              const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Positioned(
              left: 16 +
                  (width *
                      (controller.animation?.value ??
                          controller.index)),
              child: AnimatedContainer(
                duration:
                const Duration(milliseconds: 300),
                width: width - 32 / 3,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                  BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 12,
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
