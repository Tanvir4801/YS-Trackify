class AppFailure {
  const AppFailure({required this.message, this.exception, this.stackTrace});

  final String message;
  final Object? exception;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppFailure(message: $message, exception: $exception)';
}

class Result<T> {
  const Result._({this.data, this.failure});

  final T? data;
  final AppFailure? failure;

  bool get isSuccess => failure == null;
  bool get isFailure => failure != null;

  static Result<T> success<T>(T data) => Result<T>._(data: data);

  static Result<T> err<T>(AppFailure failure) =>
      Result<T>._(failure: failure);
}
