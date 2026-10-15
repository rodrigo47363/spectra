// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env.dart';

// **************************************************************************
// EnviedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// generated_from: .env
final class _Env {
  static const List<int> _enviedkeylastFmApiKey = <int>[
    1094113388,
    3661238345,
  ];

  static const List<int> _envieddatalastFmApiKey = <int>[
    1094113358,
    3661238379,
  ];

  static final String lastFmApiKey = String.fromCharCodes(List<int>.generate(
    _envieddatalastFmApiKey.length,
    (int i) => i,
    growable: false,
  ).map((int i) => _envieddatalastFmApiKey[i] ^ _enviedkeylastFmApiKey[i]));

  static const List<int> _enviedkeylastFmApiSecret = <int>[
    1005750334,
    367842125,
  ];

  static const List<int> _envieddatalastFmApiSecret = <int>[
    1005750300,
    367842159,
  ];

  static final String lastFmApiSecret = String.fromCharCodes(List<int>.generate(
    _envieddatalastFmApiSecret.length,
    (int i) => i,
    growable: false,
  ).map(
      (int i) => _envieddatalastFmApiSecret[i] ^ _enviedkeylastFmApiSecret[i]));

  static final int _enviedkey_hideDonations = 2025244358;

  static final int _hideDonations = _enviedkey_hideDonations ^ 2025244358;

  static const List<int> _enviedkey_enableUpdateChecker = <int>[1551853044];

  static const List<int> _envieddata_enableUpdateChecker = <int>[1551852996];

  static final String _enableUpdateChecker = String.fromCharCodes(
      List<int>.generate(
    _envieddata_enableUpdateChecker.length,
    (int i) => i,
    growable: false,
  ).map((int i) =>
          _envieddata_enableUpdateChecker[i] ^
          _enviedkey_enableUpdateChecker[i]));

  static const List<int> _enviedkey_releaseChannel = <int>[
    872924612,
    4192114187,
    54597949,
    3531298542,
    4000030091,
    1998242313,
  ];

  static const List<int> _envieddata_releaseChannel = <int>[
    872924599,
    4192114303,
    54597980,
    3531298444,
    4000030183,
    1998242412,
  ];

  static final String _releaseChannel = String.fromCharCodes(List<int>.generate(
    _envieddata_releaseChannel.length,
    (int i) => i,
    growable: false,
  ).map(
      (int i) => _envieddata_releaseChannel[i] ^ _enviedkey_releaseChannel[i]));
}
