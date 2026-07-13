// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mobile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BridgeAuthentication {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeAuthentication);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeAuthentication()';
}


}

/// @nodoc
class $BridgeAuthenticationCopyWith<$Res>  {
$BridgeAuthenticationCopyWith(BridgeAuthentication _, $Res Function(BridgeAuthentication) __);
}


/// Adds pattern-matching-related methods to [BridgeAuthentication].
extension BridgeAuthenticationPatterns on BridgeAuthentication {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BridgeAuthentication_Password value)?  password,TResult Function( BridgeAuthentication_PrivateKey value)?  privateKey,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BridgeAuthentication_Password() when password != null:
return password(_that);case BridgeAuthentication_PrivateKey() when privateKey != null:
return privateKey(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BridgeAuthentication_Password value)  password,required TResult Function( BridgeAuthentication_PrivateKey value)  privateKey,}){
final _that = this;
switch (_that) {
case BridgeAuthentication_Password():
return password(_that);case BridgeAuthentication_PrivateKey():
return privateKey(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BridgeAuthentication_Password value)?  password,TResult? Function( BridgeAuthentication_PrivateKey value)?  privateKey,}){
final _that = this;
switch (_that) {
case BridgeAuthentication_Password() when password != null:
return password(_that);case BridgeAuthentication_PrivateKey() when privateKey != null:
return privateKey(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String password)?  password,TResult Function( String pem,  String? passphrase)?  privateKey,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BridgeAuthentication_Password() when password != null:
return password(_that.password);case BridgeAuthentication_PrivateKey() when privateKey != null:
return privateKey(_that.pem,_that.passphrase);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String password)  password,required TResult Function( String pem,  String? passphrase)  privateKey,}) {final _that = this;
switch (_that) {
case BridgeAuthentication_Password():
return password(_that.password);case BridgeAuthentication_PrivateKey():
return privateKey(_that.pem,_that.passphrase);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String password)?  password,TResult? Function( String pem,  String? passphrase)?  privateKey,}) {final _that = this;
switch (_that) {
case BridgeAuthentication_Password() when password != null:
return password(_that.password);case BridgeAuthentication_PrivateKey() when privateKey != null:
return privateKey(_that.pem,_that.passphrase);case _:
  return null;

}
}

}

/// @nodoc


class BridgeAuthentication_Password extends BridgeAuthentication {
  const BridgeAuthentication_Password({required this.password}): super._();
  

 final  String password;

/// Create a copy of BridgeAuthentication
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeAuthentication_PasswordCopyWith<BridgeAuthentication_Password> get copyWith => _$BridgeAuthentication_PasswordCopyWithImpl<BridgeAuthentication_Password>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeAuthentication_Password&&(identical(other.password, password) || other.password == password));
}


@override
int get hashCode => Object.hash(runtimeType,password);

@override
String toString() {
  return 'BridgeAuthentication.password(password: $password)';
}


}

/// @nodoc
abstract mixin class $BridgeAuthentication_PasswordCopyWith<$Res> implements $BridgeAuthenticationCopyWith<$Res> {
  factory $BridgeAuthentication_PasswordCopyWith(BridgeAuthentication_Password value, $Res Function(BridgeAuthentication_Password) _then) = _$BridgeAuthentication_PasswordCopyWithImpl;
@useResult
$Res call({
 String password
});




}
/// @nodoc
class _$BridgeAuthentication_PasswordCopyWithImpl<$Res>
    implements $BridgeAuthentication_PasswordCopyWith<$Res> {
  _$BridgeAuthentication_PasswordCopyWithImpl(this._self, this._then);

  final BridgeAuthentication_Password _self;
  final $Res Function(BridgeAuthentication_Password) _then;

/// Create a copy of BridgeAuthentication
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? password = null,}) {
  return _then(BridgeAuthentication_Password(
password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class BridgeAuthentication_PrivateKey extends BridgeAuthentication {
  const BridgeAuthentication_PrivateKey({required this.pem, this.passphrase}): super._();
  

 final  String pem;
 final  String? passphrase;

/// Create a copy of BridgeAuthentication
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeAuthentication_PrivateKeyCopyWith<BridgeAuthentication_PrivateKey> get copyWith => _$BridgeAuthentication_PrivateKeyCopyWithImpl<BridgeAuthentication_PrivateKey>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeAuthentication_PrivateKey&&(identical(other.pem, pem) || other.pem == pem)&&(identical(other.passphrase, passphrase) || other.passphrase == passphrase));
}


@override
int get hashCode => Object.hash(runtimeType,pem,passphrase);

@override
String toString() {
  return 'BridgeAuthentication.privateKey(pem: $pem, passphrase: $passphrase)';
}


}

/// @nodoc
abstract mixin class $BridgeAuthentication_PrivateKeyCopyWith<$Res> implements $BridgeAuthenticationCopyWith<$Res> {
  factory $BridgeAuthentication_PrivateKeyCopyWith(BridgeAuthentication_PrivateKey value, $Res Function(BridgeAuthentication_PrivateKey) _then) = _$BridgeAuthentication_PrivateKeyCopyWithImpl;
@useResult
$Res call({
 String pem, String? passphrase
});




}
/// @nodoc
class _$BridgeAuthentication_PrivateKeyCopyWithImpl<$Res>
    implements $BridgeAuthentication_PrivateKeyCopyWith<$Res> {
  _$BridgeAuthentication_PrivateKeyCopyWithImpl(this._self, this._then);

  final BridgeAuthentication_PrivateKey _self;
  final $Res Function(BridgeAuthentication_PrivateKey) _then;

/// Create a copy of BridgeAuthentication
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pem = null,Object? passphrase = freezed,}) {
  return _then(BridgeAuthentication_PrivateKey(
pem: null == pem ? _self.pem : pem // ignore: cast_nullable_to_non_nullable
as String,passphrase: freezed == passphrase ? _self.passphrase : passphrase // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$BridgeTerminalEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeTerminalEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeTerminalEvent()';
}


}

/// @nodoc
class $BridgeTerminalEventCopyWith<$Res>  {
$BridgeTerminalEventCopyWith(BridgeTerminalEvent _, $Res Function(BridgeTerminalEvent) __);
}


/// Adds pattern-matching-related methods to [BridgeTerminalEvent].
extension BridgeTerminalEventPatterns on BridgeTerminalEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BridgeTerminalEvent_Stdout value)?  stdout,TResult Function( BridgeTerminalEvent_Stderr value)?  stderr,TResult Function( BridgeTerminalEvent_Exit value)?  exit,TResult Function( BridgeTerminalEvent_Closed value)?  closed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BridgeTerminalEvent_Stdout() when stdout != null:
return stdout(_that);case BridgeTerminalEvent_Stderr() when stderr != null:
return stderr(_that);case BridgeTerminalEvent_Exit() when exit != null:
return exit(_that);case BridgeTerminalEvent_Closed() when closed != null:
return closed(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BridgeTerminalEvent_Stdout value)  stdout,required TResult Function( BridgeTerminalEvent_Stderr value)  stderr,required TResult Function( BridgeTerminalEvent_Exit value)  exit,required TResult Function( BridgeTerminalEvent_Closed value)  closed,}){
final _that = this;
switch (_that) {
case BridgeTerminalEvent_Stdout():
return stdout(_that);case BridgeTerminalEvent_Stderr():
return stderr(_that);case BridgeTerminalEvent_Exit():
return exit(_that);case BridgeTerminalEvent_Closed():
return closed(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BridgeTerminalEvent_Stdout value)?  stdout,TResult? Function( BridgeTerminalEvent_Stderr value)?  stderr,TResult? Function( BridgeTerminalEvent_Exit value)?  exit,TResult? Function( BridgeTerminalEvent_Closed value)?  closed,}){
final _that = this;
switch (_that) {
case BridgeTerminalEvent_Stdout() when stdout != null:
return stdout(_that);case BridgeTerminalEvent_Stderr() when stderr != null:
return stderr(_that);case BridgeTerminalEvent_Exit() when exit != null:
return exit(_that);case BridgeTerminalEvent_Closed() when closed != null:
return closed(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Uint8List bytes)?  stdout,TResult Function( Uint8List bytes)?  stderr,TResult Function( int status)?  exit,TResult Function()?  closed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BridgeTerminalEvent_Stdout() when stdout != null:
return stdout(_that.bytes);case BridgeTerminalEvent_Stderr() when stderr != null:
return stderr(_that.bytes);case BridgeTerminalEvent_Exit() when exit != null:
return exit(_that.status);case BridgeTerminalEvent_Closed() when closed != null:
return closed();case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Uint8List bytes)  stdout,required TResult Function( Uint8List bytes)  stderr,required TResult Function( int status)  exit,required TResult Function()  closed,}) {final _that = this;
switch (_that) {
case BridgeTerminalEvent_Stdout():
return stdout(_that.bytes);case BridgeTerminalEvent_Stderr():
return stderr(_that.bytes);case BridgeTerminalEvent_Exit():
return exit(_that.status);case BridgeTerminalEvent_Closed():
return closed();}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Uint8List bytes)?  stdout,TResult? Function( Uint8List bytes)?  stderr,TResult? Function( int status)?  exit,TResult? Function()?  closed,}) {final _that = this;
switch (_that) {
case BridgeTerminalEvent_Stdout() when stdout != null:
return stdout(_that.bytes);case BridgeTerminalEvent_Stderr() when stderr != null:
return stderr(_that.bytes);case BridgeTerminalEvent_Exit() when exit != null:
return exit(_that.status);case BridgeTerminalEvent_Closed() when closed != null:
return closed();case _:
  return null;

}
}

}

/// @nodoc


class BridgeTerminalEvent_Stdout extends BridgeTerminalEvent {
  const BridgeTerminalEvent_Stdout({required this.bytes}): super._();
  

 final  Uint8List bytes;

/// Create a copy of BridgeTerminalEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeTerminalEvent_StdoutCopyWith<BridgeTerminalEvent_Stdout> get copyWith => _$BridgeTerminalEvent_StdoutCopyWithImpl<BridgeTerminalEvent_Stdout>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeTerminalEvent_Stdout&&const DeepCollectionEquality().equals(other.bytes, bytes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(bytes));

@override
String toString() {
  return 'BridgeTerminalEvent.stdout(bytes: $bytes)';
}


}

/// @nodoc
abstract mixin class $BridgeTerminalEvent_StdoutCopyWith<$Res> implements $BridgeTerminalEventCopyWith<$Res> {
  factory $BridgeTerminalEvent_StdoutCopyWith(BridgeTerminalEvent_Stdout value, $Res Function(BridgeTerminalEvent_Stdout) _then) = _$BridgeTerminalEvent_StdoutCopyWithImpl;
@useResult
$Res call({
 Uint8List bytes
});




}
/// @nodoc
class _$BridgeTerminalEvent_StdoutCopyWithImpl<$Res>
    implements $BridgeTerminalEvent_StdoutCopyWith<$Res> {
  _$BridgeTerminalEvent_StdoutCopyWithImpl(this._self, this._then);

  final BridgeTerminalEvent_Stdout _self;
  final $Res Function(BridgeTerminalEvent_Stdout) _then;

/// Create a copy of BridgeTerminalEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bytes = null,}) {
  return _then(BridgeTerminalEvent_Stdout(
bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}


}

/// @nodoc


class BridgeTerminalEvent_Stderr extends BridgeTerminalEvent {
  const BridgeTerminalEvent_Stderr({required this.bytes}): super._();
  

 final  Uint8List bytes;

/// Create a copy of BridgeTerminalEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeTerminalEvent_StderrCopyWith<BridgeTerminalEvent_Stderr> get copyWith => _$BridgeTerminalEvent_StderrCopyWithImpl<BridgeTerminalEvent_Stderr>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeTerminalEvent_Stderr&&const DeepCollectionEquality().equals(other.bytes, bytes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(bytes));

@override
String toString() {
  return 'BridgeTerminalEvent.stderr(bytes: $bytes)';
}


}

/// @nodoc
abstract mixin class $BridgeTerminalEvent_StderrCopyWith<$Res> implements $BridgeTerminalEventCopyWith<$Res> {
  factory $BridgeTerminalEvent_StderrCopyWith(BridgeTerminalEvent_Stderr value, $Res Function(BridgeTerminalEvent_Stderr) _then) = _$BridgeTerminalEvent_StderrCopyWithImpl;
@useResult
$Res call({
 Uint8List bytes
});




}
/// @nodoc
class _$BridgeTerminalEvent_StderrCopyWithImpl<$Res>
    implements $BridgeTerminalEvent_StderrCopyWith<$Res> {
  _$BridgeTerminalEvent_StderrCopyWithImpl(this._self, this._then);

  final BridgeTerminalEvent_Stderr _self;
  final $Res Function(BridgeTerminalEvent_Stderr) _then;

/// Create a copy of BridgeTerminalEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bytes = null,}) {
  return _then(BridgeTerminalEvent_Stderr(
bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}


}

/// @nodoc


class BridgeTerminalEvent_Exit extends BridgeTerminalEvent {
  const BridgeTerminalEvent_Exit({required this.status}): super._();
  

 final  int status;

/// Create a copy of BridgeTerminalEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeTerminalEvent_ExitCopyWith<BridgeTerminalEvent_Exit> get copyWith => _$BridgeTerminalEvent_ExitCopyWithImpl<BridgeTerminalEvent_Exit>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeTerminalEvent_Exit&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,status);

@override
String toString() {
  return 'BridgeTerminalEvent.exit(status: $status)';
}


}

/// @nodoc
abstract mixin class $BridgeTerminalEvent_ExitCopyWith<$Res> implements $BridgeTerminalEventCopyWith<$Res> {
  factory $BridgeTerminalEvent_ExitCopyWith(BridgeTerminalEvent_Exit value, $Res Function(BridgeTerminalEvent_Exit) _then) = _$BridgeTerminalEvent_ExitCopyWithImpl;
@useResult
$Res call({
 int status
});




}
/// @nodoc
class _$BridgeTerminalEvent_ExitCopyWithImpl<$Res>
    implements $BridgeTerminalEvent_ExitCopyWith<$Res> {
  _$BridgeTerminalEvent_ExitCopyWithImpl(this._self, this._then);

  final BridgeTerminalEvent_Exit _self;
  final $Res Function(BridgeTerminalEvent_Exit) _then;

/// Create a copy of BridgeTerminalEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? status = null,}) {
  return _then(BridgeTerminalEvent_Exit(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class BridgeTerminalEvent_Closed extends BridgeTerminalEvent {
  const BridgeTerminalEvent_Closed(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeTerminalEvent_Closed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeTerminalEvent.closed()';
}


}




// dart format on
