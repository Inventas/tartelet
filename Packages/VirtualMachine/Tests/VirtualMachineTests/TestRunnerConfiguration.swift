import GitHubDomain
import VirtualMachineDomain

struct TestRunnerConfiguration: GitHubActionsRunnerConfiguration {
    var runnerDisableDefaultLabels = false
    var runnerDisableUpdates = true
    var runnerScope = GitHubRunnerScope.organization
    var runnerLabels = "tartelet,$(touch /tmp/should-not-exist),'quoted'"
    var runnerGroup = "Default"
    var runnerName = ""
}
