/// System checks and flags.
library;

import 'dart:io' as io;

/// Aggregated check for desktop vs. mobile.
///
/// Core does not have check like this one by default.
bool get isDesktop =>
    io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS;
