# Welcome to the RCTV (ReaCTiVe) package!

`rctv` is a lightweight solution for abstracting away state management in Flutter. 

## Features

At the heart of the `rctv` package is the `Reactive` class - this provides a simple ChangeNotifier wrapper around any data value, which can then be consumed by the `ReactiveProvider` or `ReactiveListenerWidget` widgets.

I personally believe Flutter state management can generally be much simpler than most people think. In the `rctv` library, reactivity is designed to come from two main sources:
1. Data model classes, such as `User` can be cached in a `ReactiveManager`, will turn them into `Reactive` objects.
2. Page ViewModels - these should inherit from `ReactiveAggregate`, and define particular `Reactive` properties to which the appropriate segments of the page UI will respond. 

Both of these cases are dead simple to set up, and wherever you want to use a reactive value you can simply access it through a `ReactiveProvider` widget. 

This library supports both `Reactive` and `ReactiveStream` objects, which behave similarly but are designed to give you a bit more control over how you prefer to write state data.

## Getting started

To install, run `flutter pub add rctv`. 

## Usage

```dart

class CounterPageViewModel extends ReactiveAggregate {

    final counter = Reactive(0);

    void increment() {
        counter.set(counter.value + 1);
    }

    @override
    void dispose() {
        disposeReactives([ counter ]);
    }

}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {

  final viewModel = CounterPageViewModel();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RCTV Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
            title: Text('Counter demo'),
        ),
        body: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                    Text(
                    'You have pushed the button this many times:',
                    ),
                    ReactiveProvider(
                        viewModel.counter,
                        builder: (context, value) => Text('$value', style: Theme.of(context).textTheme.display1)
                    ),
                ],
            ),
        ),
        floatingActionButton: FloatingActionButton(
            onPressed: viewModel.increment,
            tooltip: 'Increment',
            child: Icon(Icons.add),
        )
      )
    );
  }
}

```

## Additional information

Another important class included in this package is the `Loadable`, a further wrapper for `Reactive` that provides a scaffold for asynchronous request handling. 