import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // ICON BADGE
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Icon(
                    Icons.point_of_sale,
                    color: Theme.of(context).colorScheme.primary,
                    size: 48,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Kasir Es Teh',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Masuk ke akun Esteh Candi anda',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                const SizedBox(height: 24),
                Card(
                  elevation: 0, // ⛔ tidak ada shadow
                  color: Theme.of(
                    context,
                  ).colorScheme.surface, // atau Colors.white
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      18,
                    ), // masih rounded, tanpa border
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "EMAIL",
                              style: Theme.of(context).textTheme.labelSmall!
                                  .copyWith(letterSpacing: .6),
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              hintText: 'nama@email.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? "Email wajib diisi"
                                : null,
                          ),

                          const SizedBox(height: 20),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "KATA SANDI",
                              style: Theme.of(context).textTheme.labelSmall!
                                  .copyWith(letterSpacing: .6),
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              hintText: 'Kata Sandi',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? "Password wajib diisi"
                                : null,
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: auth.loading
                                          ? null
                                          : (v) => setState(
                                              () => _rememberMe = v ?? false,
                                            ),
                                    ),
                                    const Flexible(
                                      child: Text(
                                        "Ingat saya",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "Lupa Kata Sandi?",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          if (auth.error != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(25, 255, 0, 0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                auth.error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: auth.loading
                                  ? null
                                  : () {
                                      if (_formKey.currentState!.validate()) {
                                        ref
                                            .read(authProvider.notifier)
                                            .login(
                                              _emailCtrl.text.trim(),
                                              _passCtrl.text.trim(),
                                              rememberMe: _rememberMe,
                                            );
                                      }
                                    },
                              child: auth.loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text("Masuk"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  "Tidak punya akun? Hubungi Admin",
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                const SizedBox(height: 16),

                // Chip(
                //   backgroundColor: Colors.grey.shade100,
                //   label: Row(
                //     mainAxisSize: MainAxisSize.min,
                //     children: const [
                //       Icon(Icons.circle, color: Colors.green, size: 10),
                //       SizedBox(width: 8),
                //       Text("Server: APAC-East-1"),
                //     ],
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
