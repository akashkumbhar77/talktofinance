import 'package:equatable/equatable.dart';

class SetupState extends Equatable {
  final bool prefsLoaded;

  final String gpuUrl;
  final String gpuSha256;
  final String cpuUrl;
  final String cpuSha256;

  final bool wifiOnlyDownloads;
  final String selectedTier; // 'gpu' | 'cpu'

  final String status;
  final bool isDownloading;
  final int? downloadProgress; // 0-100

  const SetupState({
    required this.prefsLoaded,
    required this.gpuUrl,
    required this.gpuSha256,
    required this.cpuUrl,
    required this.cpuSha256,
    required this.wifiOnlyDownloads,
    required this.selectedTier,
    required this.status,
    required this.isDownloading,
    required this.downloadProgress,
  });

  factory SetupState.initial() => const SetupState(
        prefsLoaded: false,
        gpuUrl: '',
        gpuSha256: '',
        cpuUrl: '',
        cpuSha256: '',
        wifiOnlyDownloads: true,
        selectedTier: 'gpu',
        status: 'Not loaded.',
        isDownloading: false,
        downloadProgress: null,
      );

  SetupState copyWith({
    bool? prefsLoaded,
    String? gpuUrl,
    String? gpuSha256,
    String? cpuUrl,
    String? cpuSha256,
    bool? wifiOnlyDownloads,
    String? selectedTier,
    String? status,
    bool? isDownloading,
    int? downloadProgress,
  }) {
    return SetupState(
      prefsLoaded: prefsLoaded ?? this.prefsLoaded,
      gpuUrl: gpuUrl ?? this.gpuUrl,
      gpuSha256: gpuSha256 ?? this.gpuSha256,
      cpuUrl: cpuUrl ?? this.cpuUrl,
      cpuSha256: cpuSha256 ?? this.cpuSha256,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      selectedTier: selectedTier ?? this.selectedTier,
      status: status ?? this.status,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }

  @override
  List<Object?> get props => [
        prefsLoaded,
        gpuUrl,
        gpuSha256,
        cpuUrl,
        cpuSha256,
        wifiOnlyDownloads,
        selectedTier,
        status,
        isDownloading,
        downloadProgress,
      ];
}

