/// Bundled mapping from pub.dev package name → the `Info.plist` usage
/// description keys that package is known to require for iOS.
///
/// This is a **living data resource** (per the plan doc) and will grow via
/// community PRs. When adding a plugin, add both the top-level Dart package
/// (`foo`) and its platform-specific counterpart (`foo_ios` or `foo_apple`)
/// so the check works whether the user's `pubspec.lock` pins the top or the
/// platform package.
///
/// Empty list means the plugin is *known* but requires no Info.plist entries
/// simply by being installed — e.g. `permission_handler`, whose actual
/// requirements depend on the `Permission.X` calls in the developer's Dart
/// source (planned for the v1.1 dynamic-scan pass).
const permissionPlugins = <String, List<String>>{
  // Media / camera / photos
  'image_picker': [
    'NSCameraUsageDescription',
    'NSPhotoLibraryUsageDescription',
  ],
  'image_picker_ios': [
    'NSCameraUsageDescription',
    'NSPhotoLibraryUsageDescription',
  ],
  'camera': [
    'NSCameraUsageDescription',
    'NSMicrophoneUsageDescription',
  ],
  'camera_avfoundation': [
    'NSCameraUsageDescription',
    'NSMicrophoneUsageDescription',
  ],
  'photo_manager': ['NSPhotoLibraryUsageDescription'],
  'gallery_saver': ['NSPhotoLibraryAddUsageDescription'],
  'image_gallery_saver': ['NSPhotoLibraryAddUsageDescription'],

  // Location
  'geolocator': ['NSLocationWhenInUseUsageDescription'],
  'geolocator_apple': ['NSLocationWhenInUseUsageDescription'],
  'location': ['NSLocationWhenInUseUsageDescription'],

  // Contacts / calendar / reminders
  'flutter_contacts': ['NSContactsUsageDescription'],
  'contacts_service': ['NSContactsUsageDescription'],
  'device_calendar': ['NSCalendarsUsageDescription'],

  // Bluetooth
  'flutter_blue_plus': ['NSBluetoothAlwaysUsageDescription'],
  'flutter_reactive_ble': ['NSBluetoothAlwaysUsageDescription'],

  // Local network / Bonjour
  'network_info_plus': ['NSLocalNetworkUsageDescription'],

  // Sensors / motion
  'sensors_plus': ['NSMotionUsageDescription'],
  'pedometer': ['NSMotionUsageDescription'],

  // Speech / mic
  'speech_to_text': [
    'NSMicrophoneUsageDescription',
    'NSSpeechRecognitionUsageDescription',
  ],
  'record': ['NSMicrophoneUsageDescription'],
  'flutter_sound': ['NSMicrophoneUsageDescription'],

  // Face ID
  'local_auth': ['NSFaceIDUsageDescription'],

  // NFC
  'nfc_manager': ['NFCReaderUsageDescription'],

  // Dynamic — actual requirements depend on runtime Permission.X calls;
  // v1.1 will add source scanning to resolve these.
  'permission_handler': [],
  'permission_handler_apple': [],
};
