import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skilloper_app/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('executes action after delay', () {
      FakeAsync().run((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        var executed = false;

        debouncer.run(() => executed = true);

        // Before delay, should not execute
        expect(executed, isFalse);

        // After delay, should execute
        async.elapse(const Duration(milliseconds: 300));
        expect(executed, isTrue);

        debouncer.dispose();
      });
    });

    test('rapid calls only execute once', () {
      FakeAsync().run((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        var executionCount = 0;

        // Call multiple times rapidly
        debouncer.run(() => executionCount++);
        async.elapse(const Duration(milliseconds: 100));
        debouncer.run(() => executionCount++);
        async.elapse(const Duration(milliseconds: 100));
        debouncer.run(() => executionCount++);

        // Still should not have executed
        expect(executionCount, 0);

        // After full delay from last call
        async.elapse(const Duration(milliseconds: 300));
        expect(executionCount, 1);

        debouncer.dispose();
      });
    });

    test('cancel prevents execution', () {
      FakeAsync().run((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        var executed = false;

        debouncer.run(() => executed = true);
        async.elapse(const Duration(milliseconds: 150));

        // Cancel before delay completes
        debouncer.cancel();

        // Wait past the original delay
        async.elapse(const Duration(milliseconds: 300));
        expect(executed, isFalse);

        debouncer.dispose();
      });
    });

    test('dispose prevents execution', () {
      FakeAsync().run((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        var executed = false;

        debouncer.run(() => executed = true);
        debouncer.dispose();

        async.elapse(const Duration(milliseconds: 500));
        expect(executed, isFalse);
      });
    });

    test('can run again after previous action completes', () {
      FakeAsync().run((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        var executionCount = 0;

        debouncer.run(() => executionCount++);
        async.elapse(const Duration(milliseconds: 300));
        expect(executionCount, 1);

        debouncer.run(() => executionCount++);
        async.elapse(const Duration(milliseconds: 300));
        expect(executionCount, 2);

        debouncer.dispose();
      });
    });

    test('uses custom delay', () {
      FakeAsync().run((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 500));
        var executed = false;

        debouncer.run(() => executed = true);

        // Default 300ms should not trigger
        async.elapse(const Duration(milliseconds: 300));
        expect(executed, isFalse);

        // At 500ms should trigger
        async.elapse(const Duration(milliseconds: 200));
        expect(executed, isTrue);

        debouncer.dispose();
      });
    });
  });
}
