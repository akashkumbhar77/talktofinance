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
          wifiOnlyDownloads: true,
        ),
      ],
    );
  });
}

