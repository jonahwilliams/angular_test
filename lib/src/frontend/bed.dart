// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:angular2/angular2.dart';
import 'package:angular_test/src/bootstrap.dart';
import 'package:angular_test/src/errors.dart';
import 'package:angular_test/src/frontend/fixture.dart';
import 'package:angular_test/src/frontend/stabilizer.dart';

/// Used to determine if there is an actively executing test.
NgTestFixture activeTest;

/// Returns a new [List] merging iterables [a] and [b].
List/*<E>*/ _concat/*<E>*/(Iterable/*<E>*/ a, Iterable/*<E>*/ b) {
  return new List<E>.from(a)..addAll(b);
}

/// If any [NgTestFixture] is currently executing, calls `dispose` on it.
///
/// Returns a future that completes when the test is destroyed.
///
/// This function is meant to be used within the
/// [`tearDown`](https://goo.gl/qT4fxc) function of `package:test`:
/// ```dart
/// tearDown(() => disposeAnyRunningTest());
/// ```
Future<Null> disposeAnyRunningTest() async => activeTest?.dispose();

/// An immutable builder for creating a pre-configured AngularDart application.
///
/// The root component type [T] that is created is essentially the same as a
/// root application component you would create normally with `bootstrap`.
///
/// For a simple test:
/// ```dart
/// group('$HelloWorldComponent', () {
///   tearDown(() => disposeAnyRunningTest());
///
///   test('should render "Hello World"', () async {
///     var bed = new NgTestBed<HelloWorldComponent>();
///     var fixture = await bed.create();
///     expect(fixture.text, contains('Hello World'));
///   });
/// });
/// ```
///
/// New behavior and features can be added in a hierarchy of tests:
/// ```dart
/// group('My tests', () {
///   NgTestBed<HelloWorldComponent> bed;
///   NgTextFixture<HelloWorldComponent> fixture;
///
///   setUp(() => bed = new NgTestBed<HelloWorldComponent>());
///   tearDown(() => disposeAnyRunningTest());
///
///   test('should render "Hello World", () async {
///     fixture = await bed.create();
///     expect(fixture.text, contains('Hello World'));
///   });
///
///   test('should render "Hello World" in all-caps', () async {
///     bed = bed.addProviders(const [
///       const Provider(TextFormatter, useClass: AllCapsTextFormatter),
///     ]);
///     fixture = await bed.create();
///     expect(fixture.text, contains('HELLO WORLD'));
///   });
/// });
/// ```
class NgTestBed<T> {
  static Element _defaultHost() {
    final host = new Element.tag('ng-test-bed');
    document.body.append(host);
    return host;
  }

  static const _lifecycleProviders = const [NgZoneStabilizer];
  static const _lifecycleStabilizers = const [NgZoneStabilizer];

  final Element _host;
  final List _providers;
  final List _stabilizers;

  /// Create a new empty [NgTestBed] that creates a component type [T].
  ///
  /// May optionally specify what DOM element should [host] the component.
  ///
  /// By default, the resulting [NgTestFixture] automatically waits for Angular
  /// to signal completion of change detection - this behavior can vbe disabled
  /// by setting [watchAngularLifecycle] to `false`.
  factory NgTestBed({
    Element host,
    bool watchAngularLifecycle: true,
  }) {
    if (T == dynamic) {
      throw new GenericTypeMissingError();
    }
    return new NgTestBed<T>._(
      host: host,
      providers: watchAngularLifecycle ? _lifecycleProviders : const [],
      stabilizers: watchAngularLifecycle ? _lifecycleStabilizers : const [],
    );
  }

  NgTestBed._({
    Element host,
    Iterable providers,
    Iterable stabilizers,
  })
      : _host = host,
        _providers = providers.toList(),
        _stabilizers = stabilizers.toList();

  /// Returns a new instance of [NgTestBed] with [providers] added.
  NgTestBed<T> addProviders(Iterable providers) {
    return fork(providers: _concat(_providers, providers));
  }

  /// Returns a new instance of [NgTestBed] with [stabilizers] added.
  NgTestBed<T> addStabilizers(Iterable stabilizers) {
    return fork(stabilizers: _concat(_stabilizers, stabilizers));
  }

  /// Creates a new test application with [T] as the root component.
  ///
  /// If [beforeChangeDetection] is set, it is called _before_ any initial
  /// change detection (so you can do initialization of component state that
  /// might be required).
  ///
  /// Returns a future that completes with a fixture around the component.
  Future<NgTestFixture<T>> create({void beforeChangeDetection(T instance)}) {
    // We *purposefully* do not use async/await here - that always adds an
    // additional micro-task - we want this to fail fast without entering an
    // asynchronous event if another test is running.
    void _checkForActiveTest() {
      if (activeTest != null) {
        throw new TestAlreadyRunningError();
      }
    }

    _checkForActiveTest();
    return new Future<NgTestFixture<T>>.sync(() {
      _checkForActiveTest();
      return bootstrapForTest(
        T,
        _host ?? _defaultHost(),
        beforeChangeDetection: beforeChangeDetection,
        addProviders: _concat(_providers, _stabilizers),
      ).then((componentRef) async {
        _checkForActiveTest();
        final allStabilizers = new NgTestStabilizer.all(
          _stabilizers.map/*<NgTestStabilizer>*/((s) {
            return componentRef.injector.get(s);
          }),
        );
        await allStabilizers.stabilize();
        return new NgTestFixture(
          componentRef.injector.get(ApplicationRef),
          componentRef,
          allStabilizers,
        );
      });
    });
  }

  /// Creates a new instance of [NgTestBed].
  ///
  /// Any non-null value overrides the existing properties.
  NgTestBed<T> fork({
    Element host,
    Iterable providers,
    Iterable stabilizers,
  }) {
    return new NgTestBed._(
      host: host ?? _host,
      providers: providers ?? _providers,
      stabilizers: stabilizers ?? _stabilizers,
    );
  }

  /// Returns a new instance of [NgTestBed] with [host] overrode.
  NgTestBed<T> setHost(Element host) => fork(host: host);
}
