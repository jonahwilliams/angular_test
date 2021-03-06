// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angular_test/src/bin/logging.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

/// Runs all tests using `pub run test` in the specified directory.
///
/// Tests that require AoT code generation proxies through `pub serve`.
main(List<String> args) async {
  initLogging('angular_test.bin.run');

  final parsedArgs = _argParser.parse(args);
  final pubspecFile = new File(p.join(parsedArgs['package'], 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    error('No "pubspec.yaml" found at ${pubspecFile.path}');
    _usage();
  }

  // Run pub serve, and wait for significant messages.
  final pubServeProcess = await Process.start('pub', const ['serve', 'test']);
  pubServeProcess.stdout.map(UTF8.decode).listen((message) async {
    if (message.contains('Serving angular_testing')) {
      log('Using pub serve to generate AoT code for AngularDart...');
    } else if (message.contains('Build completed successfully')) {
      success('Finished AoT compilation. Running tests...');
      await _runTests(
        includeFlags: parsedArgs['run-test-flag'],
        includePlatforms: parsedArgs['platform'],
      );
      log('Shutting down...');
      pubServeProcess.kill();
      exitCode = 0;
    } else {
      log(message);
    }
  });
  pubServeProcess.stderr.map(UTF8.decode).forEach(error);
}

Future<Null> _runTests({
  List<String> includeFlags: const ['aot'],
  List<String> includePlatforms: const ['content-shell'],
}) async {
  final args = ['run', 'test', '--pub-serve=8080'];
  args.addAll(includeFlags.map((f) => '-t $f'));
  args.add('--platform=${includePlatforms.map((p) => p.trim()).join(' ')}');
  final process = await Process.start('pub', args);
  await Future.wait([
    process.stderr.map(UTF8.decode).forEach(error),
    process.stdout.map(UTF8.decode).forEach(log),
  ]);
  if (await process.exitCode != 0) {
    exitCode = 1;
  }
}

void _usage() {
  log(_argParser.usage);
  exitCode = 1;
}

final _argParser = new ArgParser()
  ..addOption(
    'run-test-flag',
    abbr: 't',
    help: 'What flag(s) to include when running "pub run test"',
    valueHelp: ''
        'In order to have a fast test cycle, we only want to run tests '
        'that have AoT required (all the ones created using this '
        'package do).',
    defaultsTo: 'aot',
    allowMultiple: true,
  )
  ..addOption(
    'package',
    help: 'What directory containing a pub package to run tests in',
    valueHelp: p.join('some', 'path', 'to', 'package'),
    defaultsTo: p.current,
  )
  ..addOption(
    'platform',
    abbr: 'p',
    help: 'What platform(s) to pass to pub run test',
    valueHelp: 'Common examples are "content-shell", "dartium", "chrome"',
    // TODO: Detect if content-shell is installed, fall back otherwise.
    defaultsTo: 'content-shell',
    allowMultiple: true,
  );
