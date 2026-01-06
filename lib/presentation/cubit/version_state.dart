import 'package:equatable/equatable.dart';

abstract class VersionState extends Equatable {
  const VersionState();

  @override
  List<Object?> get props => [];
}

class VersionInitial extends VersionState {}

class VersionLoading extends VersionState {}

class VersionLatest extends VersionState {}

class VersionOutdated extends VersionState {
  final String currentVersion;
  final String latestVersion;
  final bool isForceUpdate;
  final String? storeUrl;

  const VersionOutdated({
    required this.currentVersion,
    required this.latestVersion,
    required this.isForceUpdate,
    this.storeUrl,
  });

  @override
  List<Object?> get props => [
    currentVersion,
    latestVersion,
    isForceUpdate,
    storeUrl,
  ];
}

class VersionError extends VersionState {
  final String message;

  const VersionError(this.message);

  @override
  List<Object?> get props => [message];
}
