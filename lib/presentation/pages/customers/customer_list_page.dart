import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/customer_provider.dart';
import '../../../data/models/customer_model.dart';
import 'customer_detail_page.dart';
import 'customer_form_page.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  String search = "";
  int page = 1;
  bool loadingMore = false;
  bool hasMore = true;
  bool isInitialLoading = true;

  Timer? _debounce;
  final ScrollController _scroll = ScrollController();

  List<Customer> items = [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);

    _scroll.addListener(() async {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120 &&
          !loadingMore &&
          hasMore) {
        await _load();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      page = 1;
      hasMore = true;
      items.clear();
    }

    setState(() => loadingMore = true);

    final repo = ref.read(customerRepositoryProvider);

    try {
      final result = await repo.getCustomers(
        page: page,
        limit: 10,
        search: search,
      );

      setState(() {
        items.addAll(result);
        loadingMore = false;
        isInitialLoading = false;
        hasMore = result.length == 10;
        if (hasMore) page++;
      });
    } catch (e) {
      setState(() {
        loadingMore = false;
        isInitialLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      appBar: AppBar(
        title: const Text("Data Pelanggan"),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: TextStyle(color: Colors.grey.shade900),
              decoration: InputDecoration(
                hintText: "Cari pelanggan…",
                hintStyle: TextStyle(color: Colors.grey.shade500),

                filled: true,
                fillColor: theme.colorScheme.surface,

                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.4,
                  ),
                ),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  search = v;
                  _load(reset: true);
                });
              },
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerFormPage()),
          );

          if (created == true) _load(reset: true);
        },
      ),

      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Text(
                    search.isEmpty
                        ? "Belum ada pelanggan"
                        : "Pelanggan tidak ditemukan",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.separated(
                  controller: _scroll,
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey.shade300, height: 1),
                  itemBuilder: (_, i) {
                    if (i == items.length) {
                      return loadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child:
                                  Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox.shrink();
                    }

                    final p = items[i];
                    return _item(context, p);
                  },
                ),
    );
  }

  Widget _item(BuildContext context, Customer p) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        Icons.person_outline,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        p.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade900,
        ),
      ),
      subtitle: Text(
        p.phone ?? '-',
        style: TextStyle(color: Colors.grey.shade600),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),

      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: p)),
        );

        if (updated == true) {
          _load(reset: true);
        }
      },
    );
  }
}
