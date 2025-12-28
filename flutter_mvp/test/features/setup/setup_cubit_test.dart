import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvp/features/setup/setup_cubit.dart';
import 'package:flutter_mvp/features/setup/setup_state.dart';

import '../../helpers/mocks.dart';

void main() {
  group('SetupCubit', () {
    test('initial state', () {
      final cubit = SetupCubit(settings: MockSettingsRepo(), runtime: MockGemmaRuntime());
      expect(cubit.state, SetupState.initial());
      cubit.close();
    });

    blocTest<SetupCubit, SetupState>(
      'init loads preferences',
      build: () {
        final settings = MockSettingsRepo();
        when(() => settings.getTierGpuUrl()).thenAnswer((_) async => 'gpu-url');
        when(() => settings.getTierGpuSha256()).thenAnswer((_) async => 'gpu-sha');
        when(() => settings.getTierCpuUrl()).thenAnswer((_) async => 'cpu-url');
        when(() => settings.getTierCpuSha256()).thenAnswer((_) async => 'cpu-sha');
        when(() => settings.getSelectedTier()).thenAnswer((_) async => 'gpu');
        when(() => settings.getUseMockExtractor()).thenAnswer((_) async => true);
        when(() => settings.getWifiOnlyDownloads()).thenAnswer((_) async => true);
        return SetupCubit(settings: settings, runtime: MockGemmaRuntime());
      },
      act: (cubit) => cubit.init(),
      expect: () => [
        SetupState.initial().copyWith(
          prefsLoaded: true,
          gpuUrl: 'gpu-url',
          gpuSha256: 'gpu-sha',
          cpuUrl: 'cpu-url',
          cpuSha256: 'cpu-sha',
          selectedTier: 'gpu',
          useMockExtractor: true,
          wifiOnlyDownloads: true,
        ),
      ],
    );

    blocTest<SetupCubit, SetupState>(
      'downloadAndLoad is a no-op when mock extractor is enabled',
      build: () {
        final settings = MockSettingsRepo();
        return SetupCubit(settings: settings, runtime: MockGemmaRuntime());
      },
      seed: () => SetupState.initial().copyWith(useMockExtractor: true, isDownloading: false),
      act: (cubit) => cubit.downloadAndLoad(),
      expect: () => [
        SetupState.initial().copyWith(
          useMockExtractor: true,
          isDownloading: false,
          status: 'Mock extractor enabled (Gemma disabled).',
        ),
      ],
    );
  });
}

