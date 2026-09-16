import Foundation

public enum RunnerStartupScript {
    public static func make(
        runnerURL: URL,
        downloadURL: URL,
        token: String,
        name: String,
        configuration: GitHubActionsRunnerConfiguration
    ) -> String {
        let arguments =
            [
                "--url", runnerURL.absoluteString, "--unattended", "--ephemeral", "--labels",
                configuration.runnerLabels,
                "--name", name, "--runnergroup", configuration.runnerGroup, "--work", "_work", "--token", token
            ] + (configuration.runnerDisableUpdates ? ["--disableupdate"] : [])
            + (configuration.runnerDisableDefaultLabels ? ["--no-default-labels"] : [])
        return """
            #!/bin/zsh
            set -euo pipefail
            umask 077
            trap 'sudo shutdown -h now' EXIT
            cd "$HOME"
            mkdir -p "$HOME/.tartelet"
            JOB_STARTED_FILE="$HOME/.tartelet/job-started"
            rm -f "$JOB_STARTED_FILE"

            # Release capacity if a queued job is cancelled or another runner takes it.
            # Once a job starts, it may run for as long as GitHub permits.
            (
              sleep 300
              if [ ! -f "$JOB_STARTED_FILE" ]; then
                sudo shutdown -h now
              fi
            ) &

            curl --fail --location --retry 3 --connect-timeout 20 --max-time 180 \\
              --output actions-runner.tar.gz \(quote(downloadURL.absoluteString))
            mkdir -p "$HOME/actions-runner"
            tar xzf actions-runner.tar.gz --directory "$HOME/actions-runner"
            cat > "$HOME/.tartelet/job-started.sh" <<'TARTELET_JOB_HOOK'
            #!/bin/zsh
            set -e
            touch "$HOME/.tartelet/job-started"
            if [ -f "$HOME/.tartelet/pre-run.sh" ]; then
              "$HOME/.tartelet/pre-run.sh"
            fi
            TARTELET_JOB_HOOK
            chmod +x "$HOME/.tartelet/job-started.sh"
            cd "$HOME/actions-runner"
            export ACTIONS_RUNNER_HOOK_JOB_STARTED="$HOME/.tartelet/job-started.sh"
            echo "ACTIONS_RUNNER_HOOK_JOB_STARTED=$HOME/.tartelet/job-started.sh" >> .env
            if [ -f "$HOME/.tartelet/post-run.sh" ]; then
              export ACTIONS_RUNNER_HOOK_JOB_COMPLETED="$HOME/.tartelet/post-run.sh"
              echo "ACTIONS_RUNNER_HOOK_JOB_COMPLETED=$HOME/.tartelet/post-run.sh" >> .env
            fi
            ./config.sh \(arguments.map(quote).joined(separator: " "))
            ./run.sh
            """
    }

    public static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
