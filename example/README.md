# An Example App Demonstrating RCTV's Functionality
This app makes a network request to the Bored API for activity ideas.
A dropdown allows you to select a category for the activity, and a refresh button gives you a new idea.

This uses a regular, non-sourced `Reactive` along with an `asyncSourced` Reactive, composed together seamlessly.

All the logic is in just a few lines:
```dart
final activityCategory = Reactive(ActivityCategories.education);

late final activity = Reactive.asyncSource<Activity>((currentValue, watch, _) async {
    //Watch the category
    final category = watch(activityCategory); //Automatically triggers updates when this changes

    //Get the data
    final response = await dio.get('http://bored.api.lewagon.com/api/activity?type=${category.name}');

    //Decode the data with the data classes
    return Activity.fromJson(response.data);
});

void setCategory(ActivityCategories newCategory) { activityCategory.set(newCategory); } //Uses the `Reactive.set` method
```