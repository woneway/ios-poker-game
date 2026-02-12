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
            _onChangeLegacy(of: value, perform: action)
        }
    }

    @available(iOS, introduced: 13.0, obsoleted: 17.0)
    private func _onChangeLegacy<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        onChange(of: value, perform: action)
    }
}

