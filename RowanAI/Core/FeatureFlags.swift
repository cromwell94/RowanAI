import Foundation

// Compile-time feature flags. Set false to hide a feature from the UI for v1.0
// while leaving the underlying implementation in place for re-enablement.
enum FeatureFlags {
    // Cyrano Live (Pro+ earpiece) is gated off for v1.0 App Store submission —
    // the live audio path has not been validated end-to-end against a stranger's
    // device. Re-enable in v1.0.1 once tested.
    static let cyranoLiveEnabled = false
}
