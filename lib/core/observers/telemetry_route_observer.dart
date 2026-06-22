import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';
import '../../services/performance_service.dart';
import '../../services/health_ping_service.dart';

class TelemetryRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  
  void _sendScreenView(PageRoute<dynamic> route) {
    final screenName = route.settings.name;
    if (screenName != null && screenName.isNotEmpty) {
      TelemetryService.instance.trackScreenOpen(screenName);
      HealthPingService.instance.updateScreen(screenName);
      
      final start = DateTime.now();
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          final elapsed = DateTime.now().difference(start).inMilliseconds;
          PerformanceService.instance.logDuration('Screen Load', elapsed, screenName: screenName);
          route.animation?.removeStatusListener(listener);
        }
      }
      route.animation?.addStatusListener(listener);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _sendScreenView(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _sendScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute && route is PageRoute) {
      _sendScreenView(previousRoute);
    }
  }
}
