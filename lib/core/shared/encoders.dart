import 'dart:convert';

/// Convert a string to base64 encoded
///
/// base64.encode(utf8.encode('abcdef'));
///
/// stringToBase64.encode('abcdef');
final stringToBase64 = utf8.fuse(base64);
