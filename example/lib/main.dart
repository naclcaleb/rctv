import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:rctv/rctv.dart';

//Activity Categories
enum ActivityCategories {
  education,
  recreational,
  social,
  diy,
  charity,
  cooking,
  relaxation,
  music,
  busywork
}

extension Capitalize on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

//Activity data class
class Activity {

  final String activity;
  final ActivityCategories type;
  final int participants;
  final double price;
  final double accessibility;
  final String link;
  final String key;

  Activity.fromJson(Map<String, dynamic> json) 
  : activity = json['activity'],
    type = ActivityCategories.values.byName(json['type']),
    participants = json['participants'],
    price = json['price'] as double,
    accessibility = json['accessibility'] as double,
    link = json['link'],
    key = json['key'];

}

//HTTP Client
final dio = Dio();

class MainViewModel extends ReactiveAggregate {

  final activityCategory = Reactive(ActivityCategories.education);

  late final activity = Reactive.asyncSource<Activity>((currentValue, watch, _) async {
    //Watch the category
    final category = watch(activityCategory);

    //Get the data
    final response = await dio.get('http://bored.api.lewagon.com/api/activity?type=${category.name}');

    //Decode the data with the data classes
    return Activity.fromJson(response.data);

  }, silentLoading: true);

  void setCategory(ActivityCategories newCategory) { activityCategory.set(newCategory); }

  @override
  List<Reactive> get reactiveDisposeList => [
    activity //activityCategory will autoDispose
  ];

}

class ActivityDisplay extends StatelessWidget {

  final Activity activity;

  const ActivityDisplay({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Text(activity.activity, style: Theme.of(context).textTheme.displayLarge, textAlign: TextAlign.center,);
  }
}


class MainPage extends StatelessWidget {

  final MainViewModel viewModel;

  const MainPage({super.key, required this.viewModel });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Ideas'),),
      body: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: ReactiveProvider(
                  viewModel.activityCategory,
                  builder: (context, activityCategory, child) => DropdownButton<ActivityCategories>(
                    items: ActivityCategories.values.map((category) => DropdownMenuItem<ActivityCategories>(
                      value: category,
                      child: Text(category.name.capitalize()),
                    )).toList(), onChanged: (category) {
                      if (category == null) return;
                      viewModel.setCategory(category);
                    },
                    value: activityCategory,
                    icon: const Icon(Icons.arrow_drop_down),
                    iconSize: 16,
                  )
                ),
              ),
              ElevatedButton(onPressed: () => viewModel.activity.refresh(), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white), child: const Text('Refresh'))
            ],
          ),
          Expanded(
            child: ReactiveProvider(
              viewModel.activity,
              builder: (context, activitiesAsyncValue, _) => activitiesAsyncValue.when(
                loading: () => const Center(child: CircularProgressIndicator()), 
                error: (error) => Text(error, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.red),), 
                data: (activity) => Center(child: ActivityDisplay(activity: activity))
              )
            )
          )
        ],
      ),
    );
  }
}


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RCTV Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MainPage(viewModel: MainViewModel(),),
    );
  }
}