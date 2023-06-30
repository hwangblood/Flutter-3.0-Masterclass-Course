import 'dart:io' show SocketException;

import 'package:dio/dio.dart' show DioException, DioExceptionType;

extension DioExceptionX on DioException {
  /// [SokectException] means the network connection is offline.
  /// when SokectException happens, it should be [DioExceptionType.unknown],
  /// because [DioException] wraps another exception inside of its instance.
  bool get isNoConnectionException =>
      type == DioExceptionType.unknown && error is SocketException;
}
