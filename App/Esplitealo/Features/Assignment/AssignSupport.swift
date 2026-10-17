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

    /// The avatars are laid out one by one, not with a `ForEach`: `ViewThatFits` measures this stack on SwiftUI's async
    /// renderer, which calls a `ForEach` content closure off the main actor and traps its isolation check.
    var body: some View {
        HStack(spacing: -8) {
            avatar(0)
            avatar(1)
            avatar(2)
            avatar(3)
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

    @ViewBuilder
    private func avatar(_ index: Int) -> some View {
        if index < min(people.count, limit) {
            let person = people[index]
            PersonAvatar(name: person.name, participantIndex: person.colorIndex, size: size, announcesName: false)
                .overlay { Circle().strokeBorder(Color.esp.paper, lineWidth: 2) }
        }
    }
}
