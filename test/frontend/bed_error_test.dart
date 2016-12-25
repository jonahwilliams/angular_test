@Tags(const ['aot'])
@TestOn('browser')
import 'dart:async';

import 'package:angular2/angular2.dart';
import 'package:angular_test/angular_test.dart';
import 'package:test/test.dart';

@AngularEntrypoint()
void main() {
  tearDown(() => disposeAnyRunningTest());

  test('should be able to catch errors that occur synchronously', () {
    return CatchSynchronousErrors._runTest();
  });

  test('should be able to catch errors that occur asynchronously', () {
    return CatchAsynchronousErrors._runTest();
  });

  test('should be able to catch errors that occur in the constructor', () {
    return CatchConstructorErrors._runTest();
  });

  test('should be able to catch errors asynchronously in constructor', () {
    return CatchConstructorAsyncErrors._runTest();
  });

  test('should be able to catch errors that occur in `ngOnInit`', () {
    return CatchOnInitErrors._runTest();
  });

  test('should be able to catch errors that occur in change detection', () {
    return CatchInChangeDetection._runTest();
  });
}

@Component(selector: 'test', template: '')
class CatchSynchronousErrors {
  static _runTest() async {
    final fixture = await new NgTestBed<CatchSynchronousErrors>().create();
    expect(
      fixture.update(run: (_) => throw new StateError('Test')),
      throwsInAngular(isStateError),
    );
  }
}

@Component(selector: 'test', template: '')
class CatchAsynchronousErrors {
  static _runTest() async {
    final fixture = await new NgTestBed<CatchAsynchronousErrors>().create();
    expect(
      fixture.update(run: (_) => new Future.error(new StateError('Test'))),
      throwsInAngular(isStateError),
    );
  }
}

@Component(selector: 'test', template: '')
class CatchConstructorErrors {
  static _runTest() async {
    final testBed = new NgTestBed<CatchConstructorErrors>();
    expect(
      testBed.create(),
      throwsInAngular(isStateError),
    );
  }

  CatchConstructorErrors() {
    throw new StateError('Test');
  }
}

@Component(selector: 'test', template: '')
class CatchConstructorAsyncErrors {
  static _runTest() async {
    final testBed = new NgTestBed<CatchConstructorAsyncErrors>();
    expect(
      testBed.create(),
      throwsInAngular(isStateError),
    );
  }

  CatchConstructorAsyncErrors() {
    scheduleMicrotask(() {
      throw new StateError('Test');
    });
  }
}

@Component(selector: 'test', template: '')
class CatchOnInitErrors implements OnInit {
  static _runTest() async {
    final testBed = new NgTestBed<CatchOnInitErrors>();
    expect(
      testBed.create(),
      throwsInAngular(isStateError),
    );
  }

  @override
  void ngOnInit() {
    throw new StateError('Test');
  }
}

@Component(
  selector: 'test',
  template: '<child [trueToError]="value"></child>',
  directives: const [ChildChangeDetectionError],
)
class CatchInChangeDetection {
  static _runTest() async {
    final fixture = await new NgTestBed<CatchInChangeDetection>().create();
    expect(
      fixture.update(run: (c) => c.value = true),
      throwsInAngular(isStateError),
    );
  }

  bool value = false;
}

@Component(selector: 'child', template: '')
class ChildChangeDetectionError {
  @Input()
  set trueToError(bool trueToError) {
    if (trueToError) {
      throw new StateError('Test');
    }
  }
}