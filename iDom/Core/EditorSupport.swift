import SwiftUI

struct StorageErrorBanner: View {
    var body: some View {
        Label("Dati non leggibili: gli originali sono conservati. Le modifiche sono bloccate.", systemImage: "exclamationmark.triangle")
            .font(.callout).foregroundStyle(.red)
    }
}

extension View {
    func storageAlert(_ issue: Binding<AppIssue?>) -> some View {
        alert("Attenzione", isPresented: Binding(get: { issue.wrappedValue != nil }, set: { if !$0 { issue.wrappedValue = nil } })) {
            Button("OK", role: .cancel) { issue.wrappedValue = nil }
        } message: { Text(issue.wrappedValue?.message ?? "") }
    }
}
