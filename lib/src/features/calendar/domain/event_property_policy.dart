import '../../../providers/busy_provider.dart';

// Shared presentation/conversion values. Applying these to an existing draft
// is reserved for explicit field edits or the repository's destination policy.
String eventShowAsForProvider(String? value, BusyProvider provider) {
  if (provider == BusyProvider.microsoft) {
    return switch (value) {
      'free' || 'tentative' || 'busy' || 'oof' || 'workingElsewhere' => value!,
      'transparent' => 'free',
      _ => 'busy',
    };
  }
  return switch (value) {
    'opaque' || 'transparent' => value!,
    'free' => 'transparent',
    _ => 'opaque',
  };
}

String eventVisibilityForProvider(String? value, BusyProvider provider) {
  if (provider == BusyProvider.microsoft) {
    return switch (value) {
      'normal' || 'personal' || 'private' || 'confidential' => value!,
      _ => 'normal',
    };
  }
  return switch (value) {
    'default' || 'public' || 'private' || 'confidential' => value!,
    'personal' => 'private',
    _ => 'default',
  };
}
