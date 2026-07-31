import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutBloc extends Bloc<AboutEvent, String?> {
  AboutBloc() : super(null) {
    on<AboutEventInit>(_init);
    add(AboutEventInit());
  }

  Future<void> _init(AboutEventInit event, Emitter<String?> emit) async {
    emit(null);
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String appName = packageInfo.appName;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;

    final res = '$appName, version $version\n\nBuild $buildNumber\n\n';
    emit(res);
  }
}

sealed class AboutEvent {}

class AboutEventInit extends AboutEvent {}
