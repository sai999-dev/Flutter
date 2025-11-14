// Stub file for web - File is not available on web
// This file provides a minimal stub to satisfy the type checker
// The actual File class from dart:io is never used on web due to kIsWeb checks

import 'dart:async';

// Stub File class for web compilation
// This will never actually be instantiated on web since we check kIsWeb first
class File {
  final String path;
  File(this.path);
  
  Stream<List<int>> openRead([int? start, int? end]) {
    throw UnimplementedError('File operations not available on web');
  }
  
  Future<int> length() {
    throw UnimplementedError('File operations not available on web');
  }
}
