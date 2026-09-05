import SwiftUI

struct iDomModule: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
}

enum ModuleCatalog {
    static let modules: [iDomModule] = [
        .init(id: "pc", title: "PC Remote", subtitle: "Controlla il tuo computer", symbol: "desktopcomputer", tint: .blue),
        .init(id: "network", title: "Rete", subtitle: "Stato e diagnostica", symbol: "wifi", tint: .green),
        .init(id: "copy", title: "Quick Copy", subtitle: "Testi sempre pronti", symbol: "doc.on.doc", tint: .indigo),
        .init(id: "parking", title: "Parcheggio", subtitle: "Ritrova la tua auto", symbol: "car.fill", tint: .orange),
        .init(id: "deadlines", title: "Scadenze", subtitle: "Documenti e promemoria", symbol: "calendar.badge.clock", tint: .red)
    ]
}
