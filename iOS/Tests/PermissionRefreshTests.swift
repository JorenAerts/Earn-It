import Permissions
import Testing

@MainActor struct PermissionRefreshTests {
    @Test(.timeLimit(.minutes(1))) func refreshFillsStatuses() async {
        let center = PermissionCenter()
        await center.refresh()
        #expect(center.statuses.count == PermissionKind.allCases.count)
    }
}
