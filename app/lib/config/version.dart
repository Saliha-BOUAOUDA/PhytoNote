/// Version applicative — synchronisée manuellement avec `pubspec.yaml` à
/// chaque bump (cf. skill `phytonote-workflow`).
///
/// On évite `package_info_plus` qui souffre de problèmes Gradle récurrents
/// avec Flutter 3.24 / AGP 8.1 (compileSdkVersion non propagé aux subprojects).
const String kAppVersion = '1.4.0';
const String kAppBuildNumber = '18';
