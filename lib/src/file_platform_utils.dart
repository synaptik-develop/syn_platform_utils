/// File and directory management.
library;

import 'dart:developer';
import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;

io.Directory? _systemDirectory;

/// Get a path for a root directory for application and agent files.
Future<io.Directory> get appDirectory => _getSystemDirectory();

/// Return path to directory for storing packages
/// If packages directory doesn't exist, creates it
Future<io.Directory> get packagesDirectory => systemDirectoryFor('packages');

Future<io.Directory> get downloadDirectory => systemDirectoryFor('download');

/// Returns the directory for storing files
/// that are in the process of being downloaded
Future<io.Directory> get tempDownloadDirectory => checkDirAndCreateIfNecessary(
  p.join(io.Directory.systemTemp.absolute.path, 'temp_download'),
);

/// Get a path for database.
Future<io.Directory> get databaseDirectory => systemDirectoryFor('database');

/// Get a path for a logs\crash reports\etc.
Future<io.Directory> get logDirectory => systemDirectoryFor('AppLogs');

Future<io.Directory> systemDirectoryFor(String directoryName) =>
    _getSystemDirectory().then(
      (value) =>
          checkDirAndCreateIfNecessary(p.join(value.path, directoryName)),
    );

Future<io.Directory> directoryForPackagesFiles(String package) =>
    packagesDirectory.then(
      (packagesDirectory) => checkDirAndCreateIfNecessary(
        p.join(packagesDirectory.path, package, 'Apk'),
        recursive: true,
      ),
    );

/// Return the root directory for application
///
/// - Windows - {SYS_DISK}:\ProgramData.
/// - IOS\MacOS\Linux - Uses [pp.getLibraryDirectory].
/// If we catch a crash return current directory
Future<io.Directory> _getSystemDirectory() {
  if (_systemDirectory != null) {
    return Future<io.Directory>.value(_systemDirectory);
  }
  Future<io.Directory> systemDirectory;
  switch (io.Platform.operatingSystem) {
    case 'macos':
    case 'ios':
      systemDirectory = pp.getLibraryDirectory().then(
        (value) => checkDirAndCreateIfNecessary(value.path),
      );
    case 'android':
      systemDirectory = pp.getExternalStorageDirectory().then((value) {
        if (value == null) {
          throw const FormatException('Filesystem is not available for app');
        }
        return checkDirAndCreateIfNecessary(value.path);
      });
    case 'windows':
      systemDirectory = pp
          .getApplicationDocumentsDirectory()
          .then<io.Directory>((value) {
            final sysDisk = value.path.split(':').first;
            final path = p.normalize('$sysDisk:\\ProgramData');

            return checkDirAndCreateIfNecessary(path);
          })
          .catchError(
            (Object error, StackTrace stackTrace) =>
                Future<io.Directory>.error('Unavailable'),
          );
    default:
      systemDirectory = checkDirAndCreateIfNecessary(io.Directory.current.path);
  }
  return systemDirectory.catchError(
    (Object error, StackTrace stackTrace) =>
        checkDirAndCreateIfNecessary(io.Directory.current.path),
  );
}

/// Check if [io.Directory] exist and try to create if not.
///
/// Only two usage during init, so do not use *static* here.
Future<io.Directory> checkDirAndCreateIfNecessary(
  String path, {
  bool recursive = false,
}) {
  final dir = io.Directory(path);
  return dir.existsSync()
      ? Future.value(dir)
      : dir.create(recursive: recursive);
}

/// Rename file
Future<io.File> renameFile({
  required io.File file,
  required String fileName,
  required String targetDirectory,
}) {
  log('[RENAME FILE]: ${file.path}');
  final targetName = p.join(targetDirectory, p.basename(fileName));
  // Prefer using rename for moving file
  return file.rename(targetName).catchError((Object error) async {
    log('[RENAME FILE]: $error}');
    // But in some cases,
    // for example if rename operation throws Cross-device link error
    // uses copy operation and then deletes temp file
    if (error is io.FileSystemException && error.osError?.errorCode == 18) {
      final newFile = await file.copy(targetName);
      await file.delete();
      return newFile;
    }
    // Ignore because at this moment we can guarantee that
    // the error has error type
    // ignore: only_throw_errors
    throw error;
  });
}
