// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'miscellaneous_app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MiscellaneousAppSettingsState {
  bool get showTooltips => throw _privateConstructorUsedError;

  /// Create a copy of MiscellaneousAppSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MiscellaneousAppSettingsStateCopyWith<MiscellaneousAppSettingsState>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MiscellaneousAppSettingsStateCopyWith<$Res> {
  factory $MiscellaneousAppSettingsStateCopyWith(
          MiscellaneousAppSettingsState value,
          $Res Function(MiscellaneousAppSettingsState) then) =
      _$MiscellaneousAppSettingsStateCopyWithImpl<$Res,
          MiscellaneousAppSettingsState>;
  @useResult
  $Res call({bool showTooltips});
}

/// @nodoc
class _$MiscellaneousAppSettingsStateCopyWithImpl<$Res,
        $Val extends MiscellaneousAppSettingsState>
    implements $MiscellaneousAppSettingsStateCopyWith<$Res> {
  _$MiscellaneousAppSettingsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MiscellaneousAppSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? showTooltips = null,
  }) {
    return _then(_value.copyWith(
      showTooltips: null == showTooltips
          ? _value.showTooltips
          : showTooltips // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MiscellaneousAppSettingsStateImplCopyWith<$Res>
    implements $MiscellaneousAppSettingsStateCopyWith<$Res> {
  factory _$$MiscellaneousAppSettingsStateImplCopyWith(
          _$MiscellaneousAppSettingsStateImpl value,
          $Res Function(_$MiscellaneousAppSettingsStateImpl) then) =
      __$$MiscellaneousAppSettingsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool showTooltips});
}

/// @nodoc
class __$$MiscellaneousAppSettingsStateImplCopyWithImpl<$Res>
    extends _$MiscellaneousAppSettingsStateCopyWithImpl<$Res,
        _$MiscellaneousAppSettingsStateImpl>
    implements _$$MiscellaneousAppSettingsStateImplCopyWith<$Res> {
  __$$MiscellaneousAppSettingsStateImplCopyWithImpl(
      _$MiscellaneousAppSettingsStateImpl _value,
      $Res Function(_$MiscellaneousAppSettingsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of MiscellaneousAppSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? showTooltips = null,
  }) {
    return _then(_$MiscellaneousAppSettingsStateImpl(
      showTooltips: null == showTooltips
          ? _value.showTooltips
          : showTooltips // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$MiscellaneousAppSettingsStateImpl
    implements _MiscellaneousAppSettingsState {
  const _$MiscellaneousAppSettingsStateImpl({required this.showTooltips});

  @override
  final bool showTooltips;

  @override
  String toString() {
    return 'MiscellaneousAppSettingsState(showTooltips: $showTooltips)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MiscellaneousAppSettingsStateImpl &&
            (identical(other.showTooltips, showTooltips) ||
                other.showTooltips == showTooltips));
  }

  @override
  int get hashCode => Object.hash(runtimeType, showTooltips);

  /// Create a copy of MiscellaneousAppSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MiscellaneousAppSettingsStateImplCopyWith<
          _$MiscellaneousAppSettingsStateImpl>
      get copyWith => __$$MiscellaneousAppSettingsStateImplCopyWithImpl<
          _$MiscellaneousAppSettingsStateImpl>(this, _$identity);
}

abstract class _MiscellaneousAppSettingsState
    implements MiscellaneousAppSettingsState {
  const factory _MiscellaneousAppSettingsState(
      {required final bool showTooltips}) = _$MiscellaneousAppSettingsStateImpl;

  @override
  bool get showTooltips;

  /// Create a copy of MiscellaneousAppSettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MiscellaneousAppSettingsStateImplCopyWith<
          _$MiscellaneousAppSettingsStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
