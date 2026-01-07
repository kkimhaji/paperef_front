import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/paper_provider.dart';
import '../providers/auth_provider.dart';
import 'paper_detail_screen.dart';
import 'create_paper_screen.dart';

class PapersListScreen extends StatefulWidget {
  const PapersListScreen({super.key});

  @override
  State<PapersListScreen> createState() => _PapersListScreenState();
}

class _PapersListScreenState extends State<PapersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaperProvider>().fetchPapers();
      context.read<PaperProvider>().fetchHashtags();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paperef'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PaperProvider>().fetchPapers();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 해시태그 필터
          Consumer<PaperProvider>(
            builder: (context, paperProvider, _) {
              if (paperProvider.hashtags.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: paperProvider.selectedHashtag == null,
                      onSelected: (_) {
                        paperProvider.clearFilter();
                      },
                    ),
                    const SizedBox(width: 8),
                    ...paperProvider.hashtags.map((hashtag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('#$hashtag'),
                          selected: paperProvider.selectedHashtag == hashtag,
                          onSelected: (_) {
                            paperProvider.fetchPapers(hashtag: hashtag);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          // 논문 목록
          Expanded(
            child: Consumer<PaperProvider>(
              builder: (context, paperProvider, _) {
                if (paperProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (paperProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${paperProvider.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            paperProvider.fetchPapers();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (paperProvider.papers.isEmpty) {
                  return const Center(
                    child: Text('No papers found. Create your first paper!'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: paperProvider.papers.length,
                  itemBuilder: (context, index) {
                    final paper = paperProvider.papers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PaperDetailScreen(paperId: paper.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paper.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (paper.summary != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  paper.summary!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: paper.hashtags.map((hashtag) {
                                  return Chip(
                                    label: Text('#${hashtag.name}'),
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreatePaperScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
