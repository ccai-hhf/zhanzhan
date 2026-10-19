KeyboardShortcuts 3.1.0 (772133d9dbe800fdac0473226822994c5c162c58), MIT.

Local Command Line Tools compatibility: expand @Entry into EnvironmentKey + computed accessor; guard preview macros unavailable outside Xcode. No shortcut behavior changes. Source: https://github.com/sindresorhus/KeyboardShortcuts

The localized string helper first checks the signed app's Contents/Resources bundle location, then falls back to SwiftPM's Bundle.module for command-line development. This avoids unsealed bundles in a macOS application root.
