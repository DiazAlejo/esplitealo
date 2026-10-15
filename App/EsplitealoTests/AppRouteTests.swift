import EsplitealoCore
import Testing
@testable import Esplitealo

@MainActor
struct AppRouteTests {
    @Test func theFlowHasSixScreensInOrder() {
        #expect(AppRoute.allCases == [.home, .capture, .review, .people, .mark, .totals])
    }

    @Test func eachScreenKnowsItsNeighbours() {
        #expect(AppRoute.home.next == .capture)
        #expect(AppRoute.capture.next == .review)
        #expect(AppRoute.review.next == .people)
        #expect(AppRoute.people.next == .mark)
        #expect(AppRoute.mark.next == .totals)
        #expect(AppRoute.totals.next == nil)

        #expect(AppRoute.home.previous == nil)
        #expect(AppRoute.capture.previous == .home)
        #expect(AppRoute.totals.previous == .mark)
    }

    @Test func stepNumbersMatchTheMockups() {
        // "Paso n de 5": capture and processing are step 1, home has none.
        #expect(AppRoute.allCases.map(\.step) == [nil, 1, 2, 3, 4, 5])
    }

    @Test func routesHaveStableIdentifiersForUITests() {
        #expect(AppRoute.allCases.map(\.accessibilityIdentifier) == [
            "screen.home", "screen.capture", "screen.review", "screen.people", "screen.mark", "screen.totals",
        ])
    }

    @Test func everyScreenHasATitleKeyInTheCatalog() {
        #expect(AppRoute.allCases.map(\.titleKey) == [
            "home.scan", "capture.title", "review.title", "people.title", "assign.title", "totals.title",
        ])
    }

    // MARK: Resuming a saved bill

    @Test func aBillWithoutPeopleResumesAtTheReceipt() {
        #expect(AppRoute.path(resuming: SampleBill.scanned()) == [.review])
    }

    @Test func aBillWithPeopleAndLooseItemsResumesAtMarking() {
        #expect(AppRoute.path(resuming: SampleBill.midway()) == [.review, .people, .mark])
    }

    @Test func aFullyMarkedBillResumesAtTheTotals() {
        #expect(AppRoute.path(resuming: SampleBill.complete()) == [.review, .people, .mark, .totals])
    }
}

@MainActor
struct AppRouterTests {
    @Test func startsAtHome() {
        let router = AppRouter()
        #expect(router.path.isEmpty)
        #expect(router.current == .home)
    }

    @Test func advancingWalksTheWholeFlow() {
        let router = AppRouter()
        for expected in [AppRoute.capture, .review, .people, .mark, .totals] {
            router.advance()
            #expect(router.current == expected)
        }
        router.advance()
        #expect(router.current == .totals)
        #expect(router.path == [.capture, .review, .people, .mark, .totals])
    }

    @Test func backGoesToThePreviousScreen() {
        let router = AppRouter()
        router.show([.capture, .review])
        router.back()
        #expect(router.current == .capture)
        router.back()
        #expect(router.current == .home)
        router.back()
        #expect(router.current == .home)
    }

    @Test func pushingTheCurrentScreenAgainDoesNothing() {
        let router = AppRouter()
        router.push(.capture)
        router.push(.capture)
        #expect(router.path == [.capture])
    }

    @Test func pushingHomeReturnsToTheRoot() {
        let router = AppRouter()
        router.show([.capture, .review])
        router.push(.home)
        #expect(router.path.isEmpty)
    }

    @Test func popToRootClearsThePath() {
        let router = AppRouter()
        router.show([.capture, .review, .people])
        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    @Test func showDropsHomeFromThePath() {
        let router = AppRouter()
        router.show([.home, .capture])
        #expect(router.path == [.capture])
    }
}
