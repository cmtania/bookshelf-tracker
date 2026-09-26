import SwiftUI

/// A text field that only accepts whole numbers. Letters, symbols and pasted text are stripped
/// as you type; that matters on iPad keyboards and hardware keyboards, where `.numberPad`
/// doesn't stop other keys. Digits from any script (e.g. Arabic-Indic) are converted to 0–9.
struct NumberField: View {
    let title: String
    @Binding var value: Int?
    var maxDigits = 5

    @State private var text = ""

    init(_ title: String, value: Binding<Int?>, maxDigits: Int = 5) {
        self.title = title
        self._value = value
        self.maxDigits = maxDigits
    }

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.numberPad)
            .onAppear {
                text = value.map(String.init) ?? ""
            }
            .onChange(of: text) { _, newText in
                let digits = newText
                    .compactMap(\.wholeNumberValue)
                    .prefix(maxDigits)
                    .map(String.init)
                    .joined()
                if digits != newText {
                    text = digits
                }
                value = Int(digits)
            }
            .onChange(of: value) { _, newValue in
                // Keep the text in sync when the value is changed from outside (e.g. on load).
                if Int(text) != newValue {
                    text = newValue.map(String.init) ?? ""
                }
            }
    }
}
