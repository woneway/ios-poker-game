import SwiftUI

extension View {
    /// A compatibility wrapper for `onChange` that:
    /// - uses the iOS 17+ `onChange` overload (old/new parameters) to avoid deprecation warnings
    /// - falls back to the legacy `onChange(of:perform:)` on iOS 16 and earlier
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            // iOS 16 及更早：使用旧签名（iOS 17 才 deprecated）
            onChange(of: value, perform: action)
        }
    }
}

