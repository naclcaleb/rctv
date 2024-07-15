import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:rctv/core/reactive.dart';
import 'package:rctv/providers/reactive_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _counter = Reactive<int>(0);
  final _counter2 = Reactive<int>(0);

  void _incrementCounter() {
    _counter.set(_counter.read() + 1);
  }

  void _incrementSecondCounter() {
    _counter2.set(_counter2.read() + 1);
  }

  final theStream = Stream.fromIterable([1, 2, 3]);

  late final newAsyncSumCounter = Reactive.asyncSource<int>((currentValue, watch, read) async {
    final counter1 = watch(_counter);
    final future = await watch.future(builder: () => Future.delayed(const Duration(seconds: 2), () => 2 + counter1));
    final counter2 = watch(_counter2);
    return counter2 + future;
  });


  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: ReactiveProvider(
        newAsyncSumCounter,
        builder: (context, value, _) {
           
          return value.when( 
            loading: () => CircularProgressIndicator(),
            error: (error) => Text(error),
            data: (value) => Center(
              // Center is a layout widget. It takes a single child and positions it
              // in the middle of the parent.
              child: Column(
                // Column is also a layout widget. It takes a list of children and
                // arranges them vertically. By default, it sizes itself to fit its
                // children horizontally, and tries to be as tall as its parent.
                //
                // Column has various properties to control how it sizes itself and
                // how it positions its children. Here we use mainAxisAlignment to
                // center the children vertically; the main axis here is the vertical
                // axis because Columns are vertical (the cross axis would be
                // horizontal).
                //
                // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
                // action in the IDE, or press "p" in the console), to see the
                // wireframe for each widget.
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text(
                    'You have pushed the button this many times:',
                  ),
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  FloatingActionButton(onPressed: _incrementSecondCounter, child: Text('Increment Instant Counter'),)
                  
                ],
              ),
            )
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add, size: 20,),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
