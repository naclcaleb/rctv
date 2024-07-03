import 'dart:io';

//Designed for use with get_it - currently ONLY works on mobile
AbstractClass prodAndTestPair<AbstractClass>({required AbstractClass prod, required AbstractClass test}) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return test;
  } 
  return prod;
}

AbstractClass Function() lazyProdAndTestPair<AbstractClass>({required AbstractClass Function() prod, required AbstractClass Function() test}) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return test;
  } 
  return prod;
}