import SwiftUI

extension View {
    /// "¿Abandonar esta cuenta?": the one place a bill is thrown away on purpose. Nothing happens unless the user taps
    /// the destructive button; `onDiscard` finishes the bill and deletes its draft.
    func discardBillConfirmation(isPresented: Binding<Bool>, onDiscard: @escaping () -> Void) -> some View {
        alert("bill.discard.title", isPresented: isPresented) {
            Button("bill.discard.keep", role: .cancel) {}
            Button("bill.discard", role: .destructive, action: onDiscard)
        } message: {
            Text("bill.discard.message")
        }
    }
}
