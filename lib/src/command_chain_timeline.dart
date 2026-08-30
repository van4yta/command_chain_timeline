import 'dart:math' as math;

import 'package:command_chain/command_chain.dart';
import 'package:command_chain_logger/command_chain_logger.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'command_chain_timeline_localization.dart';

const double commandTimelineViewportSegmentExtent = 320;

class CommandChainTimeline extends StatefulWidget {
  final CommandLogSnapshot snapshot;
  final double? initialPixelsPerMillisecond;
  final CommandChainTimelineLocale locale;

  const CommandChainTimeline({
    super.key,
    required this.snapshot,
    this.initialPixelsPerMillisecond,
    this.locale = CommandChainTimelineLocale.en,
  });

  @override
  State<CommandChainTimeline> createState() => CommandChainTimelineState();
}

class CommandChainTimelineState extends State<CommandChainTimeline> {
  final ScrollController axisHorizontalController = ScrollController();
  final ScrollController timelineHorizontalController = ScrollController();
  final ScrollController labelsVerticalController = ScrollController();
  final ScrollController timelineVerticalController = ScrollController();
  final ValueNotifier<int> horizontalViewportSegment = ValueNotifier(0);
  final ValueNotifier<int> verticalViewportSegment = ValueNotifier(0);
  String? selectedChainId;
  String? selectedCommandId;
  double? pixelsPerMillisecond;
  bool syncingHorizontal = false;
  bool syncingVertical = false;

  @override
  void initState() {
    super.initState();
    pixelsPerMillisecond = widget.initialPixelsPerMillisecond?.clamp(
      0.00005,
      20,
    );

    axisHorizontalController.addListener(() {
      if (syncingHorizontal ||
          !axisHorizontalController.hasClients ||
          !timelineHorizontalController.hasClients) {
        return;
      }
      syncingHorizontal = true;
      timelineHorizontalController.jumpTo(
        axisHorizontalController.positions.last.pixels.clamp(
          0,
          timelineHorizontalController.positions.last.maxScrollExtent,
        ),
      );
      syncingHorizontal = false;
    });
    timelineHorizontalController.addListener(() {
      if (syncingHorizontal ||
          !timelineHorizontalController.hasClients ||
          !axisHorizontalController.hasClients) {
        return;
      }
      syncingHorizontal = true;
      axisHorizontalController.jumpTo(
        timelineHorizontalController.positions.last.pixels.clamp(
          0,
          axisHorizontalController.positions.last.maxScrollExtent,
        ),
      );
      final segment =
          (timelineHorizontalController.positions.last.pixels /
                  commandTimelineViewportSegmentExtent)
              .floor();
      if (horizontalViewportSegment.value != segment) {
        horizontalViewportSegment.value = segment;
      }
      syncingHorizontal = false;
    });
    labelsVerticalController.addListener(() {
      if (syncingVertical ||
          !labelsVerticalController.hasClients ||
          !timelineVerticalController.hasClients) {
        return;
      }
      syncingVertical = true;
      timelineVerticalController.jumpTo(
        labelsVerticalController.positions.last.pixels.clamp(
          0,
          timelineVerticalController.positions.last.maxScrollExtent,
        ),
      );
      final segment =
          (labelsVerticalController.positions.last.pixels /
                  commandTimelineViewportSegmentExtent)
              .floor();
      if (verticalViewportSegment.value != segment) {
        verticalViewportSegment.value = segment;
      }
      syncingVertical = false;
    });
    timelineVerticalController.addListener(() {
      if (syncingVertical ||
          !timelineVerticalController.hasClients ||
          !labelsVerticalController.hasClients) {
        return;
      }
      syncingVertical = true;
      labelsVerticalController.jumpTo(
        timelineVerticalController.positions.last.pixels.clamp(
          0,
          labelsVerticalController.positions.last.maxScrollExtent,
        ),
      );
      final segment =
          (timelineVerticalController.positions.last.pixels /
                  commandTimelineViewportSegmentExtent)
              .floor();
      if (verticalViewportSegment.value != segment) {
        verticalViewportSegment.value = segment;
      }
      syncingVertical = false;
    });
  }

  @override
  void didUpdateWidget(covariant CommandChainTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPixelsPerMillisecond !=
        widget.initialPixelsPerMillisecond) {
      pixelsPerMillisecond = widget.initialPixelsPerMillisecond?.clamp(
        0.00005,
        20,
      );
    }
  }

  @override
  void dispose() {
    axisHorizontalController.dispose();
    timelineHorizontalController.dispose();
    labelsVerticalController.dispose();
    timelineVerticalController.dispose();
    horizontalViewportSegment.dispose();
    verticalViewportSegment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    if (snapshot.chains.isEmpty) {
      return Center(
        child: Text(
          CommandChainTimelineLocalization.empty(widget.locale),
          key: const ValueKey('command-timeline-empty'),
        ),
      );
    }

    final now = snapshot.generatedAt;
    final chains = [...snapshot.chains]
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final chainsByExecutor = <String, List<ChainLogEntry>>{};
    for (final chain in chains) {
      chainsByExecutor.putIfAbsent(chain.executorId, () => []).add(chain);
    }

    const laneHeight = 48.0;
    const rowPadding = 4.0;
    double currentTop = 0;
    final executorRows =
        <
          ({
            String executorId,
            String executorName,
            String? instanceName,
            List<({ChainLogEntry chain, int lane})> placements,
            int laneCount,
            double top,
            double height,
          })
        >[];

    for (final entry in chainsByExecutor.entries) {
      final executorChains = [...entry.value]
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      final laneEnds = <DateTime>[];
      final placements = <({ChainLogEntry chain, int lane})>[];
      for (final chain in executorChains) {
        final chainEnd = chain.endTime;
        int lane = -1;
        for (int index = 0; index < laneEnds.length; index++) {
          if (!chain.scheduledTime.isBefore(laneEnds[index])) {
            lane = index;
            break;
          }
        }
        if (lane == -1) {
          lane = laneEnds.length;
          laneEnds.add(chainEnd);
        } else {
          laneEnds[lane] = chainEnd;
        }
        placements.add((chain: chain, lane: lane));
      }
      final laneCount = math.max(1, laneEnds.length);
      final height = laneCount * laneHeight + rowPadding * 2;
      executorRows.add((
        executorId: entry.key,
        executorName: executorChains.first.executorName,
        instanceName: executorChains.first.instanceName,
        placements: placements,
        laneCount: laneCount,
        top: currentTop,
        height: height,
      ));
      currentTop += height;
    }

    DateTime globalStart = chains.first.scheduledTime;
    DateTime globalEnd = chains.first.endTime;
    for (final chain in chains) {
      if (chain.scheduledTime.isBefore(globalStart)) {
        globalStart = chain.scheduledTime;
      }
      final chainEnd = chain.endTime;
      if (chainEnd.isAfter(globalEnd)) globalEnd = chainEnd;
    }
    if (!globalEnd.isAfter(globalStart)) {
      globalEnd = globalStart.add(const Duration(milliseconds: 1));
    }
    final totalMilliseconds = math.max(
      1,
      globalEnd.difference(globalStart).inMilliseconds,
    );

    ChainLogEntry? selectedChain;
    CommandLogEntry? selectedCommand;
    for (final chain in snapshot.chains) {
      if (chain.chainId == selectedChainId) selectedChain = chain;
      for (final command in chain.commands) {
        if (command.commandId == selectedCommandId) {
          selectedChain = chain;
          selectedCommand = command;
        }
      }
    }

    const labelWidth = 220.0;
    const axisHeight = 42.0;
    final rowsHeight = currentTop;

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final detailsWidth =
            selectedChain == null || outerConstraints.maxWidth < 1000
            ? 0.0
            : 340.0;
        final availableTimelineWidth = math.max(
          320.0,
          outerConstraints.maxWidth - labelWidth - detailsWidth,
        );
        final fittedPixelsPerMillisecond = math.max(
          0.00005,
          (availableTimelineWidth - 80) / totalMilliseconds,
        );
        final scale = pixelsPerMillisecond ?? fittedPixelsPerMillisecond;
        final timelineWidth = math.max(
          availableTimelineWidth,
          totalMilliseconds * scale + 80,
        );
        final desiredTickMilliseconds = 100 / scale;
        final magnitude = math
            .pow(10, (math.log(desiredTickMilliseconds) / math.ln10).floor())
            .toDouble();
        final normalizedTick = desiredTickMilliseconds / magnitude;
        final tickFactor = normalizedTick <= 1
            ? 1
            : normalizedTick <= 2
            ? 2
            : normalizedTick <= 5
            ? 5
            : 10;
        final tickMilliseconds = math.max(1, (tickFactor * magnitude).round());
        final tickCount = (totalMilliseconds / tickMilliseconds).ceil();
        final tickSpacing = tickMilliseconds * scale;
        final canvasChains = <CommandTimelineCanvasChain>[];
        for (final row in executorRows) {
          for (final placement in row.placements) {
            final laneTop = row.top + rowPadding + placement.lane * laneHeight;
            final scheduledLeft =
                placement.chain.scheduledTime
                    .difference(globalStart)
                    .inMicroseconds /
                1000 *
                scale;
            final startedLeft =
                placement.chain.startTime
                    .difference(globalStart)
                    .inMicroseconds /
                1000 *
                scale;
            final commandGeometries = <CommandTimelineCanvasCommand>[];
            for (final command in placement.chain.commands) {
              final left =
                  command.startTime.difference(globalStart).inMicroseconds /
                  1000 *
                  scale;
              final width = math.max<double>(
                8,
                command.durationAt(now).inMicroseconds / 1000 * scale,
              );
              commandGeometries.add(
                CommandTimelineCanvasCommand(
                  chain: placement.chain,
                  command: command,
                  rect: Rect.fromLTWH(left, laneTop + 10, width, 32),
                ),
              );
            }
            final chainEndLeft =
                placement.chain.endTime.difference(globalStart).inMicroseconds /
                1000 *
                scale;
            double commandsRight = scheduledLeft + 18;
            for (final commandGeometry in commandGeometries) {
              if (commandGeometry.rect.right > commandsRight) {
                commandsRight = commandGeometry.rect.right;
              }
            }
            canvasChains.add(
              CommandTimelineCanvasChain(
                chain: placement.chain,
                laneTop: laneTop,
                scheduledLeft: scheduledLeft,
                startedLeft: startedLeft,
                bounds: Rect.fromLTRB(
                  scheduledLeft,
                  laneTop,
                  math.max(chainEndLeft, commandsRight),
                  laneTop + laneHeight,
                ),
                commands: commandGeometries,
              ),
            );
          }
        }

        final timeline = Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      CommandChainTimelineLocalization.summary(
                        widget.locale,
                        snapshot.chains.length,
                        executorRows.length,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('command-timeline-zoom-out'),
                    tooltip: CommandChainTimelineLocalization.zoomOut(
                      widget.locale,
                    ),
                    onPressed: scale <= 0.00005
                        ? null
                        : () {
                            setState(() {
                              pixelsPerMillisecond = (scale / 1.5).clamp(
                                0.00005,
                                20,
                              );
                            });
                          },
                    icon: const Icon(Icons.remove),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 72),
                    child: Text(
                      scale >= 0.01
                          ? '${scale.toStringAsFixed(2)} px/ms'
                          : '${scale.toStringAsFixed(5)} px/ms',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('command-timeline-zoom-in'),
                    tooltip: CommandChainTimelineLocalization.zoomIn(
                      widget.locale,
                    ),
                    onPressed: scale >= 20
                        ? null
                        : () {
                            setState(() {
                              pixelsPerMillisecond = (scale * 1.5).clamp(
                                0.00005,
                                20,
                              );
                            });
                          },
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    key: const ValueKey('command-timeline-fit'),
                    tooltip: CommandChainTimelineLocalization.fit(
                      widget.locale,
                    ),
                    onPressed: () {
                      setState(() => pixelsPerMillisecond = null);
                      if (timelineHorizontalController.hasClients) {
                        timelineHorizontalController.jumpTo(0);
                      }
                    },
                    icon: const Icon(Icons.fit_screen),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Column(
                      children: [
                        Container(
                          height: axisHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            border: Border(
                              right: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                              bottom: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Executor',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, labelConstraints) {
                              return SingleChildScrollView(
                                controller: labelsVerticalController,
                                child: SizedBox(
                                  height: rowsHeight,
                                  child: AnimatedBuilder(
                                    animation: verticalViewportSegment,
                                    builder: (context, child) {
                                      final segmentTop =
                                          verticalViewportSegment.value *
                                          commandTimelineViewportSegmentExtent;
                                      final visibleTop = math.max<double>(
                                        0,
                                        segmentTop -
                                            commandTimelineViewportSegmentExtent,
                                      );
                                      final visibleBottom =
                                          segmentTop +
                                          labelConstraints.maxHeight +
                                          commandTimelineViewportSegmentExtent *
                                              2;
                                      return Stack(
                                        children: [
                                          for (
                                            int index = 0;
                                            index < executorRows.length;
                                            index++
                                          )
                                            if (executorRows[index].top +
                                                        executorRows[index]
                                                            .height >=
                                                    visibleTop - 80 &&
                                                executorRows[index].top <=
                                                    visibleBottom + 80)
                                              Positioned(
                                                left: 0,
                                                right: 0,
                                                top: executorRows[index].top,
                                                height:
                                                    executorRows[index].height,
                                                child: Container(
                                                  key: ValueKey(
                                                    'executor-row-${executorRows[index].executorId}',
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: index.isEven
                                                        ? Theme.of(
                                                            context,
                                                          ).colorScheme.surface
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .surfaceContainerLowest,
                                                    border: Border(
                                                      right: BorderSide(
                                                        color: Theme.of(
                                                          context,
                                                        ).dividerColor,
                                                      ),
                                                      bottom: BorderSide(
                                                        color: Theme.of(
                                                          context,
                                                        ).dividerColor,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        '${executorRows[index].executorName}'
                                                        '${executorRows[index].instanceName == null ? '' : ' · ${executorRows[index].instanceName}'}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        CommandChainTimelineLocalization.rowSummary(
                                                          widget.locale,
                                                          executorRows[index]
                                                              .placements
                                                              .length,
                                                          executorRows[index]
                                                              .laneCount,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: axisHeight,
                          child: SingleChildScrollView(
                            controller: axisHorizontalController,
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: SizedBox(
                              width: timelineWidth,
                              height: axisHeight,
                              child: AnimatedBuilder(
                                animation: horizontalViewportSegment,
                                builder: (context, child) {
                                  final segmentLeft =
                                      horizontalViewportSegment.value *
                                      commandTimelineViewportSegmentExtent;
                                  final visibleLeft = math.max<double>(
                                    0,
                                    segmentLeft -
                                        commandTimelineViewportSegmentExtent,
                                  );
                                  int firstTick =
                                      ((visibleLeft - 88) / tickSpacing)
                                          .floor();
                                  int lastTick =
                                      ((visibleLeft +
                                                  availableTimelineWidth +
                                                  commandTimelineViewportSegmentExtent *
                                                      2 +
                                                  88) /
                                              tickSpacing)
                                          .ceil();
                                  if (firstTick < 0) firstTick = 0;
                                  if (lastTick > tickCount) {
                                    lastTick = tickCount;
                                  }
                                  return Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ColoredBox(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainer,
                                        ),
                                      ),
                                      for (
                                        int index = firstTick;
                                        index <= lastTick;
                                        index++
                                      )
                                        Positioned(
                                          left: index * tickSpacing,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 1,
                                            color: Theme.of(
                                              context,
                                            ).dividerColor,
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                              top: 5,
                                            ),
                                            child: SizedBox(
                                              width: 88,
                                              child: Text(
                                                index * tickMilliseconds < 1000
                                                    ? '${index * tickMilliseconds}ms'
                                                    : '${(index * tickMilliseconds / 1000).toStringAsFixed(index * tickMilliseconds % 1000 == 0 ? 0 : 1)}s',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelSmall,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                fit: StackFit.expand,
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  SingleChildScrollView(
                                    controller: timelineHorizontalController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: timelineWidth,
                                      height: constraints.maxHeight,
                                      child: Scrollbar(
                                        controller: timelineVerticalController,
                                        thumbVisibility:
                                            rowsHeight > constraints.maxHeight,
                                        child: SingleChildScrollView(
                                          controller:
                                              timelineVerticalController,
                                          child: SizedBox(
                                            width: timelineWidth,
                                            height: rowsHeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    right: 12,
                                    child: CommandTimelineCanvasView(
                                      chains: canvasChains,
                                      rowTops: [
                                        for (final row in executorRows) row.top,
                                      ],
                                      rowHeights: [
                                        for (final row in executorRows)
                                          row.height,
                                      ],
                                      tickSpacing: tickSpacing,
                                      contentWidth: timelineWidth,
                                      contentHeight: rowsHeight,
                                      horizontalController:
                                          timelineHorizontalController,
                                      verticalController:
                                          timelineVerticalController,
                                      selectedChainId: selectedChainId,
                                      selectedCommandId: selectedCommandId,
                                      now: now,
                                      evenRowColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      oddRowColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLowest,
                                      dividerColor: Theme.of(
                                        context,
                                      ).dividerColor,
                                      commandOutlineColor: Colors.white
                                          .withValues(alpha: 0.5),
                                      selectedOutlineColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      connectorColor: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                      hoverCardColor: Theme.of(
                                        context,
                                      ).colorScheme.inverseSurface,
                                      hoverTextColor: Theme.of(
                                        context,
                                      ).colorScheme.onInverseSurface,
                                      locale: widget.locale,
                                      onSelected: (chain, command) {
                                        setState(() {
                                          selectedChainId = chain.chainId;
                                          selectedCommandId =
                                              command?.commandId;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final details = selectedChain == null
            ? null
            : CommandTimelineDetailsPanel(
                chain: selectedChain,
                command: selectedCommand,
                now: now,
                locale: widget.locale,
                onClose: () {
                  setState(() {
                    selectedChainId = null;
                    selectedCommandId = null;
                  });
                },
              );

        final showDetailsAtSide = outerConstraints.maxWidth >= 1000;
        return Flex(
          direction: showDetailsAtSide ? Axis.horizontal : Axis.vertical,
          children: [
            Expanded(child: timeline),
            if (details != null)
              SizedBox(
                width: showDetailsAtSide ? 340 : null,
                height: showDetailsAtSide ? null : 260,
                child: details,
              ),
          ],
        );
      },
    );
  }
}

typedef CommandTimelineSelectionCallback =
    void Function(ChainLogEntry chain, CommandLogEntry? command);

class CommandTimelineCanvasCommand {
  final ChainLogEntry chain;
  final CommandLogEntry command;
  final Rect rect;

  const CommandTimelineCanvasCommand({
    required this.chain,
    required this.command,
    required this.rect,
  });
}

class CommandTimelineCanvasChain {
  final ChainLogEntry chain;
  final double laneTop;
  final double scheduledLeft;
  final double startedLeft;
  final Rect bounds;
  final List<CommandTimelineCanvasCommand> commands;

  const CommandTimelineCanvasChain({
    required this.chain,
    required this.laneTop,
    required this.scheduledLeft,
    required this.startedLeft,
    required this.bounds,
    required this.commands,
  });
}

class CommandTimelineCanvasView extends StatefulWidget {
  final List<CommandTimelineCanvasChain> chains;
  final List<double> rowTops;
  final List<double> rowHeights;
  final double tickSpacing;
  final double contentWidth;
  final double contentHeight;
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final String? selectedChainId;
  final String? selectedCommandId;
  final DateTime now;
  final Color evenRowColor;
  final Color oddRowColor;
  final Color dividerColor;
  final Color commandOutlineColor;
  final Color selectedOutlineColor;
  final Color connectorColor;
  final Color hoverCardColor;
  final Color hoverTextColor;
  final CommandChainTimelineLocale locale;
  final CommandTimelineSelectionCallback onSelected;

  const CommandTimelineCanvasView({
    super.key,
    required this.chains,
    required this.rowTops,
    required this.rowHeights,
    required this.tickSpacing,
    required this.contentWidth,
    required this.contentHeight,
    required this.horizontalController,
    required this.verticalController,
    required this.selectedChainId,
    required this.selectedCommandId,
    required this.now,
    required this.evenRowColor,
    required this.oddRowColor,
    required this.dividerColor,
    required this.commandOutlineColor,
    required this.selectedOutlineColor,
    required this.connectorColor,
    required this.hoverCardColor,
    required this.hoverTextColor,
    required this.locale,
    required this.onSelected,
  });

  @override
  State<CommandTimelineCanvasView> createState() =>
      CommandTimelineCanvasViewState();
}

class CommandTimelineCanvasViewState extends State<CommandTimelineCanvasView> {
  final ValueNotifier<CommandTimelineCanvasCommand?> hoveredCommand =
      ValueNotifier(null);
  final ValueNotifier<CommandTimelineCanvasChain?> hoveredEmptyChain =
      ValueNotifier(null);

  @override
  void didUpdateWidget(covariant CommandTimelineCanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    hoveredCommand.value = null;
    hoveredEmptyChain.value = null;
  }

  @override
  void dispose() {
    hoveredCommand.dispose();
    hoveredEmptyChain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        if (widget.horizontalController.hasClients &&
            event.scrollDelta.dx != 0) {
          final position = widget.horizontalController.positions.last;
          widget.horizontalController.jumpTo(
            (position.pixels + event.scrollDelta.dx).clamp(
              0,
              position.maxScrollExtent,
            ),
          );
        }
        if (widget.verticalController.hasClients && event.scrollDelta.dy != 0) {
          final position = widget.verticalController.positions.last;
          widget.verticalController.jumpTo(
            (position.pixels + event.scrollDelta.dy).clamp(
              0,
              position.maxScrollExtent,
            ),
          );
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onExit: (_) {
          hoveredCommand.value = null;
          hoveredEmptyChain.value = null;
        },
        onHover: (event) {
          final horizontalOffset = widget.horizontalController.hasClients
              ? widget.horizontalController.positions.last.pixels
              : 0.0;
          final verticalOffset = widget.verticalController.hasClients
              ? widget.verticalController.positions.last.pixels
              : 0.0;
          final contentPosition =
              event.localPosition + Offset(horizontalOffset, verticalOffset);
          CommandTimelineCanvasCommand? commandHit;
          CommandTimelineCanvasChain? emptyChainHit;
          for (final chain in widget.chains.reversed) {
            if (!chain.bounds.inflate(8).contains(contentPosition)) {
              continue;
            }
            for (final command in chain.commands.reversed) {
              if (command.rect.inflate(3).contains(contentPosition)) {
                commandHit = command;
                break;
              }
            }
            if (commandHit == null && chain.commands.isEmpty) {
              final emptyRect = Rect.fromLTWH(
                chain.scheduledLeft,
                chain.laneTop + 10,
                22,
                32,
              );
              if (emptyRect.contains(contentPosition)) {
                emptyChainHit = chain;
              }
            }
            if (commandHit != null || emptyChainHit != null) break;
          }
          if (hoveredCommand.value?.command.commandId !=
              commandHit?.command.commandId) {
            hoveredCommand.value = commandHit;
          }
          if (hoveredEmptyChain.value?.chain.chainId !=
              emptyChainHit?.chain.chainId) {
            hoveredEmptyChain.value = emptyChainHit;
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            if (widget.horizontalController.hasClients &&
                details.delta.dx != 0) {
              final position = widget.horizontalController.positions.last;
              widget.horizontalController.jumpTo(
                (position.pixels - details.delta.dx).clamp(
                  0,
                  position.maxScrollExtent,
                ),
              );
            }
            if (widget.verticalController.hasClients && details.delta.dy != 0) {
              final position = widget.verticalController.positions.last;
              widget.verticalController.jumpTo(
                (position.pixels - details.delta.dy).clamp(
                  0,
                  position.maxScrollExtent,
                ),
              );
            }
          },
          onTapUp: (details) {
            final horizontalOffset = widget.horizontalController.hasClients
                ? widget.horizontalController.positions.last.pixels
                : 0.0;
            final verticalOffset = widget.verticalController.hasClients
                ? widget.verticalController.positions.last.pixels
                : 0.0;
            final contentPosition =
                details.localPosition +
                Offset(horizontalOffset, verticalOffset);
            for (final chain in widget.chains.reversed) {
              if (!chain.bounds.inflate(8).contains(contentPosition)) {
                continue;
              }
              CommandTimelineCanvasCommand? commandHit;
              for (final command in chain.commands.reversed) {
                if (command.rect.inflate(3).contains(contentPosition)) {
                  commandHit = command;
                  break;
                }
              }
              if (commandHit != null) {
                widget.onSelected(commandHit.chain, commandHit.command);
                return;
              }
              if (chain.commands.isEmpty &&
                  Rect.fromLTWH(
                    chain.scheduledLeft,
                    chain.laneTop + 10,
                    22,
                    32,
                  ).contains(contentPosition)) {
                widget.onSelected(chain.chain, null);
                return;
              }
            }
          },
          child: CustomPaint(
            painter: CommandTimelineCommandsPainter(
              chains: widget.chains,
              rowTops: widget.rowTops,
              rowHeights: widget.rowHeights,
              tickSpacing: widget.tickSpacing,
              contentWidth: widget.contentWidth,
              contentHeight: widget.contentHeight,
              horizontalController: widget.horizontalController,
              verticalController: widget.verticalController,
              selectedChainId: widget.selectedChainId,
              selectedCommandId: widget.selectedCommandId,
              now: widget.now,
              evenRowColor: widget.evenRowColor,
              oddRowColor: widget.oddRowColor,
              dividerColor: widget.dividerColor,
              commandOutlineColor: widget.commandOutlineColor,
              selectedOutlineColor: widget.selectedOutlineColor,
              connectorColor: widget.connectorColor,
              hoverCardColor: widget.hoverCardColor,
              hoverTextColor: widget.hoverTextColor,
              locale: widget.locale,
              hoveredCommand: hoveredCommand,
              hoveredEmptyChain: hoveredEmptyChain,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class CommandTimelineCommandsPainter extends CustomPainter {
  final List<CommandTimelineCanvasChain> chains;
  final List<double> rowTops;
  final List<double> rowHeights;
  final double tickSpacing;
  final double contentWidth;
  final double contentHeight;
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final String? selectedChainId;
  final String? selectedCommandId;
  final DateTime now;
  final Color evenRowColor;
  final Color oddRowColor;
  final Color dividerColor;
  final Color commandOutlineColor;
  final Color selectedOutlineColor;
  final Color connectorColor;
  final Color hoverCardColor;
  final Color hoverTextColor;
  final CommandChainTimelineLocale locale;
  final ValueNotifier<CommandTimelineCanvasCommand?> hoveredCommand;
  final ValueNotifier<CommandTimelineCanvasChain?> hoveredEmptyChain;

  CommandTimelineCommandsPainter({
    required this.chains,
    required this.rowTops,
    required this.rowHeights,
    required this.tickSpacing,
    required this.contentWidth,
    required this.contentHeight,
    required this.horizontalController,
    required this.verticalController,
    required this.selectedChainId,
    required this.selectedCommandId,
    required this.now,
    required this.evenRowColor,
    required this.oddRowColor,
    required this.dividerColor,
    required this.commandOutlineColor,
    required this.selectedOutlineColor,
    required this.connectorColor,
    required this.hoverCardColor,
    required this.hoverTextColor,
    required this.locale,
    required this.hoveredCommand,
    required this.hoveredEmptyChain,
  }) : super(
         repaint: Listenable.merge([
           horizontalController,
           verticalController,
           hoveredCommand,
           hoveredEmptyChain,
         ]),
       );

  @override
  void paint(Canvas canvas, Size size) {
    final rawHorizontalOffset = horizontalController.hasClients
        ? horizontalController.positions.last.pixels
        : 0.0;
    final rawVerticalOffset = verticalController.hasClients
        ? verticalController.positions.last.pixels
        : 0.0;
    final horizontalOffset = rawHorizontalOffset
        .clamp(0, math.max(0, contentWidth - size.width))
        .toDouble();
    final verticalOffset = rawVerticalOffset
        .clamp(0, math.max(0, contentHeight - size.height))
        .toDouble();
    final visibleBounds = Rect.fromLTWH(
      horizontalOffset,
      verticalOffset,
      math.min(size.width, contentWidth - horizontalOffset),
      math.min(size.height, contentHeight - verticalOffset),
    );
    final paintBounds = visibleBounds.inflate(24);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-horizontalOffset, -verticalOffset);

    for (int index = 0; index < rowTops.length; index++) {
      if (rowTops[index] + rowHeights[index] < visibleBounds.top ||
          rowTops[index] > visibleBounds.bottom) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTWH(
          visibleBounds.left,
          rowTops[index],
          visibleBounds.width,
          rowHeights[index],
        ),
        Paint()..color = index.isEven ? evenRowColor : oddRowColor,
      );
      canvas.drawLine(
        Offset(visibleBounds.left, rowTops[index] + rowHeights[index]),
        Offset(visibleBounds.right, rowTops[index] + rowHeights[index]),
        Paint()..color = dividerColor,
      );
    }
    final gridPaint = Paint()..color = dividerColor.withValues(alpha: 0.45);
    int firstTick = (visibleBounds.left / tickSpacing).floor();
    int lastTick = (visibleBounds.right / tickSpacing).ceil();
    if (firstTick < 0) firstTick = 0;
    for (int index = firstTick; index <= lastTick; index++) {
      final position = index * tickSpacing;
      canvas.drawLine(
        Offset(position, visibleBounds.top),
        Offset(position, visibleBounds.bottom),
        gridPaint,
      );
    }
    final connectorPaint = Paint()
      ..color = connectorColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final chainGeometry in chains) {
      if (!chainGeometry.bounds.overlaps(paintBounds)) continue;

      if (chainGeometry.chain.mode == ExecutionMode.queued.name &&
          chainGeometry.startedLeft > chainGeometry.scheduledLeft) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              chainGeometry.scheduledLeft,
              chainGeometry.laneTop + 3,
              math.max<double>(
                2,
                chainGeometry.startedLeft - chainGeometry.scheduledLeft,
              ),
              4,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = Colors.blueGrey,
        );
      }

      for (int index = 1; index < chainGeometry.commands.length; index++) {
        final commandRect = chainGeometry.commands[index].rect;
        final arrowEnd = commandRect.left - 3;
        final arrowStart = math.max(0.0, arrowEnd - 13);
        final arrowY = commandRect.center.dy;
        canvas.drawLine(
          Offset(arrowStart, arrowY),
          Offset(arrowEnd, arrowY),
          connectorPaint,
        );
        canvas.drawLine(
          Offset(arrowEnd - 4, arrowY - 3),
          Offset(arrowEnd, arrowY),
          connectorPaint,
        );
        canvas.drawLine(
          Offset(arrowEnd - 4, arrowY + 3),
          Offset(arrowEnd, arrowY),
          connectorPaint,
        );
      }

      for (final commandGeometry in chainGeometry.commands) {
        if (!commandGeometry.rect.overlaps(paintBounds)) continue;
        final chainHash = chainGeometry.chain.chainId.hashCode.abs();
        final color = switch (commandGeometry.command.status) {
          CommandResultStatus.failed => Colors.red.shade700,
          CommandResultStatus.completed =>
            chainGeometry.chain.status == ChainResultStatus.cancelled
                ? Colors.orange
                : Color.fromARGB(
                    255,
                    70 + chainHash % 100,
                    90 + chainHash % 80,
                    150 + chainHash % 80,
                  ),
        };
        final commandRRect = RRect.fromRectAndRadius(
          commandGeometry.rect,
          const Radius.circular(5),
        );
        canvas.drawRRect(commandRRect, Paint()..color = color);
        final selected = selectedCommandId == commandGeometry.command.commandId;
        canvas.drawRRect(
          commandRRect,
          Paint()
            ..color = selected ? selectedOutlineColor : commandOutlineColor
            ..strokeWidth = selected ? 2 : 1
            ..style = PaintingStyle.stroke,
        );
        if (commandGeometry.rect.width >= 34) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: commandGeometry.command.commandName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            maxLines: 1,
            ellipsis: '…',
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: commandGeometry.rect.width - 10);
          textPainter.paint(
            canvas,
            Offset(
              commandGeometry.rect.left + 5,
              commandGeometry.rect.top +
                  (commandGeometry.rect.height - textPainter.height) / 2,
            ),
          );
        }
      }

      if (chainGeometry.commands.isEmpty) {
        final center = Offset(
          chainGeometry.scheduledLeft + 9,
          chainGeometry.laneTop + 26,
        );
        final color = switch (chainGeometry.chain.status) {
          ChainResultStatus.failed => Colors.red,
          ChainResultStatus.cancelled => Colors.orange,
          ChainResultStatus.completed => Colors.blueGrey,
        };
        canvas.drawCircle(center, 8, Paint()..color = color);
        if (selectedChainId == chainGeometry.chain.chainId &&
            selectedCommandId == null) {
          canvas.drawCircle(
            center,
            10,
            Paint()
              ..color = selectedOutlineColor
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke,
          );
        }
        canvas.drawLine(
          Offset(center.dx - 3, center.dy),
          Offset(center.dx + 3, center.dy),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5,
        );
      }
    }

    final hovered = hoveredCommand.value;
    final hoveredChain = hoveredEmptyChain.value;
    Rect? hoveredRect;
    String? title;
    String? duration;
    String? description;
    if (hovered != null) {
      hoveredRect = hovered.rect;
      title = hovered.command.commandName;
      duration = '${hovered.command.durationAt(now).inMicroseconds / 1000}ms';
      description =
          hovered.command.description ??
          CommandChainTimelineLocalization.commandStatus(
            locale,
            hovered.command.status,
          );
    } else if (hoveredChain != null) {
      hoveredRect = Rect.fromLTWH(
        hoveredChain.scheduledLeft,
        hoveredChain.laneTop + 10,
        22,
        32,
      );
      title = CommandChainTimelineLocalization.chainTitle(
        locale,
        hoveredChain.chain.chainId,
      );
      duration =
          '${hoveredChain.chain.durationAt(now).inMicroseconds / 1000}ms';
      description = CommandChainTimelineLocalization.chainStatus(
        locale,
        hoveredChain.chain.status,
      );
    }
    if (hoveredRect != null && title != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hoveredRect, const Radius.circular(5)),
        Paint()
          ..color = selectedOutlineColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      const cardWidth = 240.0;
      const cardHeight = 72.0;
      double cardLeft = hoveredRect.right + 8;
      if (cardLeft + cardWidth > visibleBounds.right - 8) {
        cardLeft = hoveredRect.left - cardWidth - 8;
      }
      cardLeft = cardLeft.clamp(
        visibleBounds.left + 8,
        math.max(visibleBounds.left + 8, visibleBounds.right - cardWidth - 8),
      );
      final cardTop = hoveredRect.top
          .clamp(
            visibleBounds.top + 8,
            math.max(
              visibleBounds.top + 8,
              visibleBounds.bottom - cardHeight - 8,
            ),
          )
          .toDouble();
      final cardRect = Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cardRect, const Radius.circular(7)),
        Paint()..color = hoverCardColor,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          style: TextStyle(color: hoverTextColor, fontSize: 11, height: 1.35),
          children: [
            TextSpan(
              text: '$title\n',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: '$duration\n$description'),
          ],
        ),
        maxLines: 3,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cardWidth - 16);
      textPainter.paint(canvas, Offset(cardLeft + 8, cardTop + 7));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CommandTimelineCommandsPainter oldDelegate) {
    return oldDelegate.chains != chains ||
        oldDelegate.rowTops != rowTops ||
        oldDelegate.rowHeights != rowHeights ||
        oldDelegate.tickSpacing != tickSpacing ||
        oldDelegate.contentWidth != contentWidth ||
        oldDelegate.contentHeight != contentHeight ||
        oldDelegate.selectedChainId != selectedChainId ||
        oldDelegate.selectedCommandId != selectedCommandId ||
        oldDelegate.now != now ||
        oldDelegate.evenRowColor != evenRowColor ||
        oldDelegate.oddRowColor != oddRowColor ||
        oldDelegate.dividerColor != dividerColor ||
        oldDelegate.commandOutlineColor != commandOutlineColor ||
        oldDelegate.selectedOutlineColor != selectedOutlineColor ||
        oldDelegate.connectorColor != connectorColor ||
        oldDelegate.hoverCardColor != hoverCardColor ||
        oldDelegate.hoverTextColor != hoverTextColor ||
        oldDelegate.locale != locale;
  }
}

class CommandTimelineDetailsPanel extends StatelessWidget {
  final ChainLogEntry chain;
  final CommandLogEntry? command;
  final DateTime now;
  final CommandChainTimelineLocale locale;
  final VoidCallback onClose;

  const CommandTimelineDetailsPanel({
    super.key,
    required this.chain,
    required this.command,
    required this.now,
    required this.locale,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final failure = command?.failure ?? chain.failure;
    return Material(
      key: const ValueKey('command-timeline-details'),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(
              command?.commandName ??
                  CommandChainTimelineLocalization.chainTitle(
                    locale,
                    chain.chainId,
                  ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              command == null
                  ? CommandChainTimelineLocalization.chainStatus(
                      locale,
                      chain.status,
                    )
                  : CommandChainTimelineLocalization.commandStatus(
                      locale,
                      command!.status,
                    ),
            ),
            trailing: IconButton(
              tooltip: CommandChainTimelineLocalization.close(locale),
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectionArea(
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodySmall,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.executor)}: '
                        '${chain.executorName}',
                      ),
                      Text(
                        '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.executorId)}: '
                        '${chain.executorId}',
                      ),
                      if (chain.instanceName != null)
                        Text(
                          '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.instance)}: '
                          '${chain.instanceName}',
                        ),
                      Text(
                        '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.chainId)}: '
                        '${chain.chainId}',
                      ),
                      Text(
                        '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.mode)}: '
                        '${chain.mode}',
                      ),
                      Text(
                        '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.scheduled)}: '
                        '${chain.scheduledTime.toLocal().toIso8601String()}',
                      ),
                      Text(
                        '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.started)}: '
                        '${chain.startTime.toLocal().toIso8601String()}',
                      ),
                      Text(
                        '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.queue)}: '
                        '${chain.queueDuration.inMicroseconds / 1000}ms',
                      ),
                      Text(
                        '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.chainDuration)}: '
                        '${chain.durationAt(now).inMicroseconds / 1000}ms',
                      ),
                      if (chain.terminationReason != null)
                        Text(
                          '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.reason)}: '
                          '${CommandChainTimelineLocalization.terminationReason(locale, chain.terminationReason!)}',
                        ),
                      if (command != null) ...[
                        const Divider(),
                        Text(
                          '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.commandId)}: '
                          '${command!.commandId}',
                        ),
                        Text(
                          '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.commandIndex)}: '
                          '${command!.commandIndex}',
                        ),
                        Text(
                          '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.started)}: '
                          '${command!.startTime.toLocal().toIso8601String()}',
                        ),
                        Text(
                          '${CommandChainTimelineLocalization.label(locale, CommandChainTimelineLabel.duration)}: '
                          '${command!.durationAt(now).inMicroseconds / 1000}ms',
                        ),
                        if (command!.description != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            command!.description!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (command!.details != null &&
                            command!.details!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            CommandChainTimelineLocalization.label(
                              locale,
                              CommandChainTimelineLabel.details,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          for (final entry in command!.details!.entries)
                            Text('${entry.key}: ${entry.value}'),
                        ],
                      ],
                      if (failure != null) ...[
                        const Divider(),
                        Text(
                          '${failure.type}: ${failure.message}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(failure.stackTrace),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
