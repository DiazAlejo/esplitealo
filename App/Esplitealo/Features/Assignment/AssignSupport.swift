import EsplitealoDesign
import SwiftUI

extension String {
    /// A catalog string in the environment's locale (`String(localized:)` alone follows the device's), for what is
    /// spoken or announced.
    init(resolving resource: LocalizedStringResource, in locale: Locale) {
        var resource = resource
        resource.locale = locale
        self.init(localized: resource)
    }
}

extension AssignViewModel.Person {
    /// The person's VoiceOver reading: the name and what they have so far.
    func spokenSubtotal(_ formatter: MoneyFormatter) -> String {
        "\(name), \(formatter.spokenString(cents: subtotalCents))"
    }
}

/// A row of small overlapping avatars: who is marked for an item. Past four people the rest is a count.
struct AvatarStack: View {
    let people: [AssignViewModel.Person]
    var size: CGFloat = 24
    private let limit = 4

    var body: some View {
        HStack(spacing: -8) {
            ForEach(people.prefix(limit)) { person in
                PersonAvatar(name: person.name, participantIndex: person.colorIndex, size: size, announcesName: false)
                    .overlay { Circle().strokeBorder(Color.esp.paper, lineWidth: 2) }
            }
            if people.count > limit {
                Text(verbatim: "+\(people.count - limit)")
                    .espText(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.esp.inkSecondary)
                    .padding(.leading, Spacing.sm)
            }
        }
        .accessibilityHidden(true)
    }
}
