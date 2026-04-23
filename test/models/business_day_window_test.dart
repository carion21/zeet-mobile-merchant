import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/models/business_day_window.dart';

void main() {
  group('BusinessDayWindow.fromJson', () {
    test('parses cutoff_hour + start/end ISO UTC and converts to local', () {
      final bd = BusinessDayWindow.fromJson(<String, dynamic>{
        'cutoff_hour': 4,
        'start': '2026-04-23T04:00:00.000Z',
        'end': '2026-04-24T04:00:00.000Z',
      });

      expect(bd.cutoffHour, 4);
      expect(bd.start.isUtc, isFalse);
      expect(bd.end.isUtc, isFalse);
      // [start, end[ = fenetre de 24h pile.
      expect(bd.end.difference(bd.start), const Duration(days: 1));
    });

    test('supports a different cutoff (boulangerie matinale 03h)', () {
      final bd = BusinessDayWindow.fromJson(<String, dynamic>{
        'cutoff_hour': 3,
        'start': '2026-04-23T03:00:00.000Z',
        'end': '2026-04-24T03:00:00.000Z',
      });
      expect(bd.cutoffHour, 3);
    });

    test('tolerates num instead of int on cutoff_hour', () {
      final bd = BusinessDayWindow.fromJson(<String, dynamic>{
        'cutoff_hour': 4.0,
        'start': '2026-04-23T04:00:00.000Z',
        'end': '2026-04-24T04:00:00.000Z',
      });
      expect(bd.cutoffHour, 4);
    });
  });

  group('BusinessDayWindow.fallback', () {
    test('before today cutoff → window started yesterday', () {
      final now = DateTime(2026, 4, 23, 2, 15); // 02h15, avant cutoff 4h
      final bd = BusinessDayWindow.fallback(now: now);

      expect(bd.cutoffHour, 4);
      expect(bd.start, DateTime(2026, 4, 22, 4));
      expect(bd.end, DateTime(2026, 4, 23, 4));
      expect(bd.isExpired(now: now), isFalse);
    });

    test('after today cutoff → window started today', () {
      final now = DateTime(2026, 4, 23, 14, 30);
      final bd = BusinessDayWindow.fallback(now: now);

      expect(bd.start, DateTime(2026, 4, 23, 4));
      expect(bd.end, DateTime(2026, 4, 24, 4));
    });

    test('honors custom cutoffHour', () {
      final now = DateTime(2026, 4, 23, 5, 0);
      final bd = BusinessDayWindow.fallback(now: now, cutoffHour: 3);
      expect(bd.cutoffHour, 3);
      expect(bd.start, DateTime(2026, 4, 23, 3));
    });
  });

  group('timeUntilNextReset', () {
    test('returns positive duration before end', () {
      final bd = BusinessDayWindow(
        cutoffHour: 4,
        start: DateTime(2026, 4, 23, 4),
        end: DateTime(2026, 4, 24, 4),
      );
      final remaining =
          bd.timeUntilNextReset(now: DateTime(2026, 4, 23, 14, 30));
      expect(remaining, const Duration(hours: 13, minutes: 30));
    });

    test('returns negative duration when cutoff is crossed', () {
      final bd = BusinessDayWindow(
        cutoffHour: 4,
        start: DateTime(2026, 4, 23, 4),
        end: DateTime(2026, 4, 24, 4),
      );
      final remaining =
          bd.timeUntilNextReset(now: DateTime(2026, 4, 24, 4, 5));
      expect(remaining.isNegative, isTrue);
    });
  });

  group('isExpired', () {
    test('false before end', () {
      final bd = BusinessDayWindow(
        cutoffHour: 4,
        start: DateTime(2026, 4, 23, 4),
        end: DateTime(2026, 4, 24, 4),
      );
      expect(bd.isExpired(now: DateTime(2026, 4, 24, 3, 59)), isFalse);
    });

    test('true at and after end (end is exclusive)', () {
      final bd = BusinessDayWindow(
        cutoffHour: 4,
        start: DateTime(2026, 4, 23, 4),
        end: DateTime(2026, 4, 24, 4),
      );
      expect(bd.isExpired(now: DateTime(2026, 4, 24, 4)), isTrue);
      expect(bd.isExpired(now: DateTime(2026, 4, 24, 4, 1)), isTrue);
    });
  });
}
