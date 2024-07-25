import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rctv/providers/multi_reactive_provider.dart';
import 'package:rctv/rctv.dart';

void main() {
  testWidgets('MultiProvider works', (tester) async {
    final intReactive = Reactive<int>(0);
    final stringReactive = Reactive<String>('Hi');

    await tester.pumpWidget(MaterialApp(title: 'Provider Test', home: Scaffold(body: MultiReactiveProvider([
      InheritedReactive<int>(intReactive),
      InheritedReactive<String>(stringReactive)
    ], builder: (context, _) {
      return Container(child: Builder(
        builder: (context) {
          final stringValue = InheritedReactive.of<String>(context);
          final intValue = InheritedReactive.of<int>(context);
          stdout.writeln(stringValue);
          stdout.writeln(intValue.toString());
          return Text(stringValue);
        }
      ));
    }))));

    intReactive.set(2);

    final stringValue = find.text('Hi');
    expect(stringValue, findsOneWidget); 
  });
}