import 'dart:async';
import 'dart:convert';

import 'package:command_chain/command_chain.dart';
import 'package:command_chain_logger/command_chain_logger.dart';
import 'package:command_chain_timeline/command_chain_timeline.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final logger = CommandChainLogger();

void main() {
  CommandChainLogger.enablePrint();
  CommandExecutor.init(observer: logger);
  runApp(const CommandChainExampleApp());
}

class CommandChainExampleApp extends StatelessWidget {
  const CommandChainExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const ShoppingScenarioScreen(),
    );
  }
}

class ShoppingScenarioScreen extends StatefulWidget {
  const ShoppingScenarioScreen({super.key});

  @override
  State<ShoppingScenarioScreen> createState() => ShoppingScenarioScreenState();
}

class ShoppingScenarioScreenState extends State<ShoppingScenarioScreen> {
  final startupExecutor = CommandExecutor<BuildContext>(
    'AppStartup',
    instanceName: 'customer-session',
    isContextAvailable: (context) => context.mounted,
  );
  final productExecutor = CommandExecutor<BuildContext>(
    'ProductScreen',
    instanceName: 'SKU-42',
    isContextAvailable: (context) => context.mounted,
  );
  final cartExecutor = CommandExecutor<BuildContext>(
    'CartScreen',
    instanceName: 'active-cart',
    isContextAvailable: (context) => context.mounted,
    mode: ExecutionMode.queued,
  );
  final checkoutExecutor = CommandExecutor<BuildContext>(
    'CheckoutScreen',
    instanceName: 'order-1042',
    isContextAvailable: (context) => context.mounted,
    mode: ExecutionMode.queued,
  );
  final analyticsExecutor = CommandExecutor<BuildContext>(
    'Analytics',
    instanceName: 'shopping-flow',
    isContextAvailable: (context) => context.mounted,
  );
  bool scenarioRunning = false;

  @override
  void dispose() {
    startupExecutor.cancel();
    productExecutor.cancel();
    cartExecutor.cancel();
    checkoutExecutor.cancel();
    analyticsExecutor.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportsFileImport =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;

    return Scaffold(
      appBar: AppBar(title: const Text('Command Chain Timeline')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Online store scenario',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      scenarioRunning
                          ? 'A customer is opening a product, updating the cart, and checking out.'
                          : 'Run one realistic flow, then inspect its parallel, queued, and failed commands.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: scenarioRunning
                          ? null
                          : () async {
                              logger.clear();
                              setState(() => scenarioRunning = true);

                              await startupExecutor.execute(
                                context,
                                RestoreSessionCommand(userId: 'customer-17'),
                              );
                              if (!context.mounted) return;

                              await Future.wait([
                                productExecutor.execute(
                                  context,
                                  LoadProductCommand(sku: 'SKU-42'),
                                ),
                                productExecutor.execute(
                                  context,
                                  LoadRecommendationsCommand(sku: 'SKU-42'),
                                ),
                                analyticsExecutor.execute(
                                  context,
                                  TrackProductViewCommand(sku: 'SKU-42'),
                                ),
                              ]);
                              if (!context.mounted) return;

                              await Future.wait([
                                cartExecutor.execute(
                                  context,
                                  AddToCartCommand(
                                    cartId: 'cart-17',
                                    sku: 'SKU-42',
                                  ),
                                ),
                                cartExecutor.execute(
                                  context,
                                  SyncCartCommand(cartId: 'cart-17'),
                                ),
                              ]);
                              if (!context.mounted) return;

                              final promoExecution = checkoutExecutor.execute(
                                context,
                                ApplyExpiredPromoCommand(code: 'SUMMER-2025'),
                              );
                              final handledPromoExecution = promoExecution
                                  .then<void>(
                                    (_) {},
                                    onError: (Object _, StackTrace _) {},
                                  );
                              await Future.wait([
                                handledPromoExecution,
                                checkoutExecutor.execute(
                                  context,
                                  SubmitOrderCommand(
                                    orderId: 'order-1042',
                                    sku: 'SKU-42',
                                    amount: 129.90,
                                  ),
                                ),
                                analyticsExecutor.execute(
                                  context,
                                  TrackCheckoutCommand(orderId: 'order-1042'),
                                ),
                              ]);

                              if (context.mounted) {
                                setState(() => scenarioRunning = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Scenario completed: '
                                      '${logger.snapshot.chains.length} chains recorded',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: scenarioRunning
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(
                        scenarioRunning
                            ? 'Running shopping scenario…'
                            : 'Run shopping scenario',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: scenarioRunning || logger.chains.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => CommandTimelineScreen(
                                    snapshot: CommandLogSnapshot.decode(
                                      logger.exportJson(),
                                    ),
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.timeline),
                      label: const Text('Open current timeline'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: scenarioRunning || logger.chains.isEmpty
                          ? null
                          : () async {
                              final json = logger.exportJson(pretty: true);
                              final timestamp = DateTime.now()
                                  .toUtc()
                                  .toIso8601String()
                                  .replaceAll(':', '-');
                              final path = await FileSaver.instance.saveFile(
                                name: 'command-chain-log-$timestamp',
                                bytes: Uint8List.fromList(utf8.encode(json)),
                                fileExtension: 'json',
                                mimeType: MimeType.json,
                              );
                              await Clipboard.setData(
                                ClipboardData(text: json),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'JSON saved and copied to clipboard: $path',
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save and copy JSON'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: scenarioRunning
                          ? null
                          : () async {
                              final clipboard = await Clipboard.getData(
                                'text/plain',
                              );
                              if (!context.mounted) return;
                              final controller = TextEditingController(
                                text: clipboard?.text ?? '',
                              );
                              final source = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Paste command log JSON'),
                                  content: SizedBox(
                                    width: 720,
                                    child: TextField(
                                      controller: controller,
                                      minLines: 12,
                                      maxLines: 24,
                                      decoration: const InputDecoration(
                                        hintText: 'Paste exported JSON here',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pop(controller.text),
                                      child: const Text('Open'),
                                    ),
                                  ],
                                ),
                              );
                              controller.dispose();
                              if (!context.mounted ||
                                  source == null ||
                                  source.trim().isEmpty) {
                                return;
                              }
                              await CommandLogImport.open(
                                context: context,
                                source: source,
                              );
                            },
                      icon: const Icon(Icons.content_paste_go_outlined),
                      label: const Text('Paste JSON and open timeline'),
                    ),
                    if (supportsFileImport) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: scenarioRunning
                            ? null
                            : () async {
                                const jsonTypeGroup = XTypeGroup(
                                  label: 'Command log JSON',
                                  extensions: ['json'],
                                  mimeTypes: ['application/json'],
                                  uniformTypeIdentifiers: ['public.json'],
                                );
                                final file = await openFile(
                                  acceptedTypeGroups: [jsonTypeGroup],
                                );
                                if (file == null) return;
                                final source = await file.readAsString();
                                if (!context.mounted) return;
                                await CommandLogImport.open(
                                  context: context,
                                  source: source,
                                );
                              },
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('Open JSON file'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CommandLogImport {
  static Future<void> open({
    required BuildContext context,
    required String source,
  }) async {
    try {
      final snapshot = CommandLogSnapshot.decode(source);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => CommandTimelineScreen(snapshot: snapshot),
        ),
      );
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid command log: ${error.message}')),
      );
    }
  }
}

class CommandTimelineScreen extends StatelessWidget {
  final CommandLogSnapshot snapshot;

  const CommandTimelineScreen({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Command Timeline')),
      body: SafeArea(child: CommandChainTimeline(snapshot: snapshot)),
    );
  }
}

class RestoreSessionCommand extends Command {
  final String userId;

  RestoreSessionCommand({required this.userId});

  @override
  String get description => 'Restore the signed-in customer session';

  @override
  Map<String, dynamic> get details => {'userId': userId};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return LoadProfileCommand(userId: userId);
  }
}

class LoadProfileCommand extends Command {
  final String userId;

  LoadProfileCommand({required this.userId});

  @override
  String get description => 'Load the customer profile';

  @override
  Map<String, dynamic> get details => {
    'userId': userId,
    'endpoint': '/api/customers/$userId',
  };

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    return null;
  }
}

class LoadProductCommand extends Command {
  final String sku;

  LoadProductCommand({required this.sku});

  @override
  String get description => 'Load product details and inventory';

  @override
  Map<String, dynamic> get details => {
    'sku': sku,
    'endpoint': '/api/products/$sku',
  };

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return LoadReviewsCommand(sku: sku);
  }
}

class LoadReviewsCommand extends Command {
  final String sku;

  LoadReviewsCommand({required this.sku});

  @override
  String get description => 'Load recent customer reviews';

  @override
  Map<String, dynamic> get details => {
    'sku': sku,
    'endpoint': '/api/products/$sku/reviews',
  };

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return PresentProductCommand(sku: sku);
  }
}

class PresentProductCommand extends Command {
  final String sku;

  PresentProductCommand({required this.sku});

  @override
  String get description => 'Present the complete product state';

  @override
  Map<String, dynamic> get details => {'sku': sku, 'available': 7};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 70));
    return null;
  }
}

class LoadRecommendationsCommand extends Command {
  final String sku;

  LoadRecommendationsCommand({required this.sku});

  @override
  String get description => 'Load related products';

  @override
  Map<String, dynamic> get details => {'sku': sku, 'limit': 6};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    return PresentRecommendationsCommand(sku: sku);
  }
}

class PresentRecommendationsCommand extends Command {
  final String sku;

  PresentRecommendationsCommand({required this.sku});

  @override
  String get description => 'Present six related products';

  @override
  Map<String, dynamic> get details => {'sku': sku, 'count': 6};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return null;
  }
}

class TrackProductViewCommand extends Command {
  final String sku;

  TrackProductViewCommand({required this.sku});

  @override
  String get description => 'Track the product view';

  @override
  Map<String, dynamic> get details => {'event': 'product_viewed', 'sku': sku};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return null;
  }
}

class AddToCartCommand extends Command {
  final String cartId;
  final String sku;

  AddToCartCommand({required this.cartId, required this.sku});

  @override
  String get description => 'Add the selected product to the cart';

  @override
  Map<String, dynamic> get details => {'cartId': cartId, 'sku': sku};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return CalculateCartCommand(cartId: cartId);
  }
}

class CalculateCartCommand extends Command {
  final String cartId;

  CalculateCartCommand({required this.cartId});

  @override
  String get description => 'Calculate totals and delivery';

  @override
  Map<String, dynamic> get details => {'cartId': cartId, 'total': 129.90};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 210));
    return SaveCartCommand(cartId: cartId);
  }
}

class SaveCartCommand extends Command {
  final String cartId;

  SaveCartCommand({required this.cartId});

  @override
  String get description => 'Persist the local cart state';

  @override
  Map<String, dynamic> get details => {'cartId': cartId};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 90));
    return null;
  }
}

class SyncCartCommand extends Command {
  final String cartId;

  SyncCartCommand({required this.cartId});

  @override
  String get description => 'Synchronize the cart with the server';

  @override
  Map<String, dynamic> get details => {'cartId': cartId};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 340));
    return PresentCartCommand(cartId: cartId);
  }
}

class PresentCartCommand extends Command {
  final String cartId;

  PresentCartCommand({required this.cartId});

  @override
  String get description => 'Present the synchronized cart';

  @override
  Map<String, dynamic> get details => {'cartId': cartId};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 70));
    return null;
  }
}

class ApplyExpiredPromoCommand extends Command {
  final String code;

  ApplyExpiredPromoCommand({required this.code});

  @override
  String get description => 'Validate the customer promo code';

  @override
  Map<String, dynamic> get details => {'code': code};

  @override
  FutureOr<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    throw StateError('Promo code expired');
  }
}

class SubmitOrderCommand extends Command {
  final String orderId;
  final String sku;
  final double amount;

  SubmitOrderCommand({
    required this.orderId,
    required this.sku,
    required this.amount,
  });

  @override
  String get description => 'Submit the final order';

  @override
  Map<String, dynamic> get details => {
    'orderId': orderId,
    'sku': sku,
    'amount': amount,
  };

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    return ReserveStockCommand(orderId: orderId, amount: amount);
  }
}

class ReserveStockCommand extends Command {
  final String orderId;
  final double amount;

  ReserveStockCommand({required this.orderId, required this.amount});

  @override
  String get description => 'Reserve the purchased item';

  @override
  Map<String, dynamic> get details => {
    'orderId': orderId,
    'warehouse': 'ams-01',
  };

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return AuthorizePaymentCommand(orderId: orderId, amount: amount);
  }
}

class AuthorizePaymentCommand extends Command {
  final String orderId;
  final double amount;

  AuthorizePaymentCommand({required this.orderId, required this.amount});

  @override
  String get description => 'Authorize the card payment';

  @override
  Map<String, dynamic> get details => {
    'orderId': orderId,
    'amount': amount,
    'provider': 'demo-pay',
  };

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    return ConfirmOrderCommand(orderId: orderId);
  }
}

class ConfirmOrderCommand extends Command {
  final String orderId;

  ConfirmOrderCommand({required this.orderId});

  @override
  String get description => 'Confirm the paid order';

  @override
  Map<String, dynamic> get details => {'orderId': orderId};

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return null;
  }
}

class TrackCheckoutCommand extends Command {
  final String orderId;

  TrackCheckoutCommand({required this.orderId});

  @override
  String get description => 'Track the checkout start';

  @override
  Map<String, dynamic> get details => {
    'event': 'checkout_started',
    'orderId': orderId,
  };

  @override
  Future<Command?> execute() async {
    await Future<void>.delayed(const Duration(milliseconds: 70));
    return null;
  }
}
