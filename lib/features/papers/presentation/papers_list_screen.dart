import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/paper_provider.dart';
import '../../authentication/providers/auth_provider.dart';
import 'paper_detail_screen.dart';
import 'create_paper_screen.dart';
import 'edit_paper_screen.dart';

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

  Future<void> _refreshPapers() async {
    await context.read<PaperProvider>().fetchPapers();
    await context.read<PaperProvider>().fetchHashtags();
  }

  Future<void> _navigateToEdit(int paperId) async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // 전체 데이터 가져오기 (content 포함)
    final paper = await context.read<PaperProvider>().fetchPaper(paperId);

    if (mounted) {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      if (paper != null) {
        // Paper 객체 전달
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EditPaperScreen(paper: paper), // 전체 Paper 객체 전달
          ),
        );

        if (result == true) {
          _refreshPapers();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load paper details')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paperef'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPapers,
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
                          onPressed: _refreshPapers,
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

                return RefreshIndicator(
                  onRefresh: _refreshPapers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: paperProvider.papers.length,
                    itemBuilder: (context, index) {
                      final paper = paperProvider.papers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () async {
                            final result =
                                await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PaperDetailScreen(paperId: paper.id),
                              ),
                            );

                            if (result == true) {
                              _refreshPapers();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        paper.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          await _navigateToEdit(paper.id);
                                        } else if (value == 'delete') {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Paper'),
                                              content: const Text(
                                                  'Are you sure you want to delete this paper?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.red),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true && mounted) {
                                            await paperProvider
                                                .deletePaper(paper.id);
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  size: 20, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (paper.summary != null &&
                                    paper.summary!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    paper.summary!,
                                    maxLines: 2,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  ),
                                ],
                                if (paper.hashtags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: paper.hashtags.map((hashtag) {
                                      return Text(
                                        '#${hashtag.name}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const CreatePaperScreen(),
            ),
          );

          if (result == true) {
            _refreshPapers();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
