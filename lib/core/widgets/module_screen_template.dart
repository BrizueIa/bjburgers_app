import 'package:flutter/material.dart';

class ModuleScreenTemplate extends StatelessWidget {
  const ModuleScreenTemplate({
    super.key,
    required this.title,
    required this.description,
    required this.highlights,
    this.trailing,
  });

  final String title;
  final String description;
  final List<String> highlights;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1200
        ? 3
        : width >= 700
        ? 2
        : 1;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(description),
                      if (trailing != null) ...[
                        const SizedBox(height: 20),
                        trailing!,
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: highlights.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: width >= 700 ? 1.5 : 2.4,
                ),
                itemBuilder: (context, index) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(highlights[index])),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
