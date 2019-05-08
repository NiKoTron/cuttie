import 'dart:ui';

abstract class Bloc {
  ///Close controllers here
  void dispose();
  void lifeCycleStateChanged(AppLifecycleState state) {}
}
