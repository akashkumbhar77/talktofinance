class DownloadCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class DownloadCancelled implements Exception {
  @override
  String toString() => 'Download cancelled';
}

