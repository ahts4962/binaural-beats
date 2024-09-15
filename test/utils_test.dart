import 'package:binaural_beats/utils.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Debouncer', () {
    test('run', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        int x = 0;
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 50));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 150));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 600));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 600));
        expect(x, 2);
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 50));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 200));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 300));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 600));
        expect(x, 3);
      });
    });

    test('run (100 ms)', () {
      fakeAsync((async) {
        final debouncer = Debouncer(milliseconds: 100);
        int x = 0;
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 50));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 150));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 600));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 600));
        expect(x, 3);
      });
    });

    test('flush', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        int x = 0;
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 50));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 150));
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 600));
        debouncer.run(() => x++);
        expect(x, 1);
        debouncer.flush();
        expect(x, 2);
      });
    });

    test('runAsync', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        int a = 0;
        int x = 0;
        Future<void> action() async {
          a++;
          await Future.delayed(const Duration(seconds: 1));
          x++;
        }

        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 50));
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 150));
        expect(a, 0);
        expect(x, 0);
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 600));
        expect(a, 1);
        expect(x, 0);
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 600));
        expect(a, 2);
        expect(x, 0);
        async.elapse(const Duration(milliseconds: 400));
        expect(x, 1);
        expect(debouncer.future, completes);
        async.elapse(const Duration(seconds: 600));
        expect(a, 2);
        expect(x, 2);
      });
    });

    test('runAsync (100 ms)', () {
      fakeAsync((async) {
        final debouncer = Debouncer(milliseconds: 100);
        int a = 0;
        int x = 0;
        Future<void> action() async {
          a++;
          await Future.delayed(const Duration(seconds: 1));
          x++;
        }

        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 50));
        expect(a, 0);
        expect(x, 0);
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 150));
        expect(a, 1);
        expect(x, 0);
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 600));
        expect(a, 2);
        expect(x, 0);
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 600));
        expect(a, 3);
        expect(x, 2);
        expect(debouncer.future, completes);
        async.elapse(const Duration(milliseconds: 600));
        expect(a, 3);
        expect(x, 3);
      });
    });

    test('flush (async)', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        int a = 0;
        int x = 0;
        Future<void> action() async {
          a++;
          await Future.delayed(const Duration(seconds: 1));
          x++;
        }

        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 50));
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 150));
        expect(a, 0);
        expect(x, 0);
        debouncer.flush();
        expect(a, 1);
        expect(x, 0);
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 600));
        expect(a, 2);
        expect(x, 0);
        debouncer.runAsync(action);
        expect(a, 2);
        expect(x, 0);
        debouncer.flush();
        expect(a, 3);
        expect(x, 0);
        async.elapse(const Duration(milliseconds: 500));
        expect(x, 1);
        async.elapse(const Duration(milliseconds: 450));
        expect(x, 2);
        expect(debouncer.future, completes);
        async.elapse(const Duration(milliseconds: 100));
        expect(a, 3);
        expect(x, 3);
      });
    });

    test('mixed (run and runAsync)', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        int a = 0;
        int x = 0;
        Future<void> action() async {
          a++;
          await Future.delayed(const Duration(seconds: 1));
          x++;
        }

        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 50));
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 150));
        expect(a, 0);
        expect(x, 0);
        debouncer.run(() => x++);
        async.elapse(const Duration(milliseconds: 600));
        expect(a, 0);
        expect(x, 1);
        debouncer.runAsync(action);
        async.elapse(const Duration(milliseconds: 600));
        expect(a, 1);
        expect(x, 1);
        expect(debouncer.future, completes);
        async.elapse(const Duration(milliseconds: 1000));
        expect(a, 1);
        expect(x, 2);
      });
    });
  });
}
