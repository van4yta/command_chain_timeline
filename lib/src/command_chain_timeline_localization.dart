import 'package:command_chain/command_chain.dart';

enum CommandChainTimelineLocale { en, ru }

/// Pure localization helpers for text displayed by the timeline.
class CommandChainTimelineLocalization {
  static String plural(int count, String one, String few, String many) {
    final lastTwoDigits = count % 100;
    final lastDigit = count % 10;
    if (lastTwoDigits >= 11 && lastTwoDigits <= 14) return many;
    if (lastDigit == 1) return one;
    if (lastDigit >= 2 && lastDigit <= 4) return few;
    return many;
  }

  static String empty(CommandChainTimelineLocale locale) {
    return switch (locale) {
      CommandChainTimelineLocale.en => 'No command data',
      CommandChainTimelineLocale.ru => 'Нет данных о командах',
    };
  }

  static String summary(
    CommandChainTimelineLocale locale,
    int chainCount,
    int executorCount,
  ) {
    if (locale == CommandChainTimelineLocale.en) {
      return '$chainCount ${chainCount == 1 ? 'chain' : 'chains'} · '
          '$executorCount ${executorCount == 1 ? 'executor' : 'executors'}';
    }
    return '$chainCount ${plural(chainCount, 'цепочка', 'цепочки', 'цепочек')} · '
        '$executorCount ${plural(executorCount, 'исполнитель', 'исполнителя', 'исполнителей')}';
  }

  static String rowSummary(
    CommandChainTimelineLocale locale,
    int chainCount,
    int laneCount,
  ) {
    if (locale == CommandChainTimelineLocale.en) {
      return '$chainCount ${chainCount == 1 ? 'chain' : 'chains'} · '
          '$laneCount ${laneCount == 1 ? 'lane' : 'lanes'}';
    }
    return '$chainCount ${plural(chainCount, 'цепочка', 'цепочки', 'цепочек')} · '
        '$laneCount ${plural(laneCount, 'поддорожка', 'поддорожки', 'поддорожек')}';
  }

  static String zoomOut(CommandChainTimelineLocale locale) => switch (locale) {
    CommandChainTimelineLocale.en => 'Zoom out',
    CommandChainTimelineLocale.ru => 'Отдалить',
  };

  static String zoomIn(CommandChainTimelineLocale locale) => switch (locale) {
    CommandChainTimelineLocale.en => 'Zoom in',
    CommandChainTimelineLocale.ru => 'Приблизить',
  };

  static String fit(CommandChainTimelineLocale locale) => switch (locale) {
    CommandChainTimelineLocale.en => 'Fit timeline',
    CommandChainTimelineLocale.ru => 'Показать всё',
  };

  static String close(CommandChainTimelineLocale locale) => switch (locale) {
    CommandChainTimelineLocale.en => 'Close',
    CommandChainTimelineLocale.ru => 'Закрыть',
  };

  static String chainTitle(CommandChainTimelineLocale locale, String chainId) =>
      switch (locale) {
        CommandChainTimelineLocale.en => 'Chain $chainId',
        CommandChainTimelineLocale.ru => 'Цепочка $chainId',
      };

  static String chainStatus(
    CommandChainTimelineLocale locale,
    ChainResultStatus status,
  ) {
    if (locale == CommandChainTimelineLocale.en) return status.name;
    return switch (status) {
      ChainResultStatus.completed => 'завершено',
      ChainResultStatus.cancelled => 'отменено',
      ChainResultStatus.failed => 'ошибка',
    };
  }

  static String commandStatus(
    CommandChainTimelineLocale locale,
    CommandResultStatus status,
  ) {
    if (locale == CommandChainTimelineLocale.en) return status.name;
    return switch (status) {
      CommandResultStatus.completed => 'завершено',
      CommandResultStatus.failed => 'ошибка',
    };
  }

  static String terminationReason(
    CommandChainTimelineLocale locale,
    String reason,
  ) {
    if (locale == CommandChainTimelineLocale.en) return reason;
    return switch (reason) {
      'contextUnavailable' => 'контекст больше недоступен',
      'executorCancelled' => 'executor отменён',
      'maxCommandsExceeded' => 'превышен лимит команд',
      'commandFailed' => 'ошибка команды',
      _ => reason,
    };
  }

  static String label(
    CommandChainTimelineLocale locale,
    CommandChainTimelineLabel label,
  ) {
    return switch ((locale, label)) {
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.executor) =>
        'Executor',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.executorId) =>
        'Executor ID',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.instance) =>
        'Instance',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.chainId) =>
        'Chain ID',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.mode) => 'Mode',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.scheduled) =>
        'Scheduled',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.started) =>
        'Started',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.queue) =>
        'Queue',
      (
        CommandChainTimelineLocale.en,
        CommandChainTimelineLabel.chainDuration,
      ) =>
        'Chain duration',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.reason) =>
        'Reason',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.commandId) =>
        'Command ID',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.commandIndex) =>
        'Index',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.duration) =>
        'Duration',
      (CommandChainTimelineLocale.en, CommandChainTimelineLabel.details) =>
        'Details',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.executor) =>
        'Executor',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.executorId) =>
        'ID executor',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.instance) =>
        'Экземпляр',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.chainId) =>
        'ID цепочки',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.mode) =>
        'Режим',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.scheduled) =>
        'Запланировано',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.started) =>
        'Запущено',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.queue) =>
        'Ожидание',
      (
        CommandChainTimelineLocale.ru,
        CommandChainTimelineLabel.chainDuration,
      ) =>
        'Длительность цепочки',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.reason) =>
        'Причина',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.commandId) =>
        'ID команды',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.commandIndex) =>
        'Индекс',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.duration) =>
        'Длительность',
      (CommandChainTimelineLocale.ru, CommandChainTimelineLabel.details) =>
        'Детали',
    };
  }
}

enum CommandChainTimelineLabel {
  executor,
  executorId,
  instance,
  chainId,
  mode,
  scheduled,
  started,
  queue,
  chainDuration,
  reason,
  commandId,
  commandIndex,
  duration,
  details,
}
