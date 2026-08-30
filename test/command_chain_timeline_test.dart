import 'package:command_chain/command_chain.dart';
import 'package:command_chain_logger/command_chain_logger.dart';
import 'package:command_chain_timeline/command_chain_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localizes English and Russian summaries', () {
    expect(
      CommandChainTimelineLocalization.summary(
        CommandChainTimelineLocale.en,
        2,
        1,
      ),
      '2 chains · 1 executor',
    );
    expect(
      CommandChainTimelineLocalization.rowSummary(
        CommandChainTimelineLocale.ru,
        21,
        2,
      ),
      '21 цепочка · 2 поддорожки',
    );
    expect(
      CommandChainTimelineLocalization.terminationReason(
        CommandChainTimelineLocale.ru,
        'maxCommandsExceeded',
      ),
      'превышен лимит команд',
    );
  });

  testWidgets('renders the empty snapshot state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandChainTimeline(snapshot: CommandLogSnapshot.empty()),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('command-timeline-empty')),
      findsOneWidget,
    );
    expect(find.text('No command data'), findsOneWidget);
  });

  testWidgets('renders the Russian empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandChainTimeline(
            snapshot: CommandLogSnapshot.empty(),
            locale: CommandChainTimelineLocale.ru,
          ),
        ),
      ),
    );

    expect(find.text('Нет данных о командах'), findsOneWidget);
  });

  testWidgets('renders an imported snapshot independently', (tester) async {
    final startTime = DateTime.utc(2026, 1, 1, 12);
    final snapshot = CommandLogSnapshot.decode(
      CommandLogSnapshot(
        generatedAt: startTime.add(const Duration(seconds: 1)),
        chains: [
          CommandChainReport(
            executorId: 'executor-1',
            executorName: 'ProductScreen',
            instanceName: 'product-42',
            chainId: 'chain-1',
            mode: ExecutionMode.queued.name,
            scheduledTime: startTime,
            startTime: startTime,
            endTime: startTime.add(const Duration(milliseconds: 120)),
            totalDuration: const Duration(milliseconds: 120),
            status: ChainResultStatus.completed,
            terminationReason: null,
            failure: null,
            commands: [
              CommandReport(
                commandId: 'command-1',
                commandIndex: 0,
                commandName: 'LoadProduct',
                startTime: startTime,
                duration: const Duration(milliseconds: 120),
                status: CommandResultStatus.completed,
                description: 'Timeline details',
                details: const {'answer': 42},
                failure: null,
              ),
            ],
          ),
        ],
      ).encode(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 700,
            child: CommandChainTimeline(snapshot: snapshot),
          ),
        ),
      ),
    );

    expect(find.textContaining('ProductScreen'), findsOneWidget);
    expect(find.textContaining('product-42'), findsOneWidget);
    expect(find.byType(CommandChainTimeline), findsOneWidget);
  });

  testWidgets('localizes the details panel', (tester) async {
    final startTime = DateTime.utc(2026, 1, 1, 12);
    final chain = CommandChainReport(
      executorId: 'executor-1',
      executorName: 'ProductScreen',
      instanceName: null,
      chainId: 'chain-1',
      mode: ExecutionMode.queued.name,
      scheduledTime: startTime,
      startTime: startTime,
      endTime: startTime.add(const Duration(milliseconds: 120)),
      totalDuration: const Duration(milliseconds: 120),
      status: ChainResultStatus.completed,
      terminationReason: null,
      failure: null,
      commands: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommandTimelineDetailsPanel(
            chain: chain,
            command: null,
            now: startTime.add(const Duration(milliseconds: 120)),
            locale: CommandChainTimelineLocale.ru,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('Цепочка chain-1'), findsOneWidget);
    expect(find.text('завершено'), findsOneWidget);
    expect(find.text('Режим: queued'), findsOneWidget);
    expect(find.byTooltip('Закрыть'), findsOneWidget);
  });
}
