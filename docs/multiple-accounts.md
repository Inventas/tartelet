# Multiple GitHub accounts

The Inventas fork uses one Tartelet app and one shared pool of up to two macOS VMs. Add organization and personal account profiles in **Settings → GitHub**. No separate macOS users are needed.

## Configure an account

1. Create a GitHub App and install it on the account that will use the runners.
2. Give the app access to the repositories that Tartelet should monitor.
3. Grant these permissions:

   | Account type | Required permissions |
   | --- | --- |
   | Organization | Repository **Actions: read**, **Metadata: read**; Organization **Self-hosted runners: read and write** |
   | Personal account | Repository **Actions: read**, **Metadata: read**, **Administration: read and write** |

4. Select **Add Account…** in Tartelet. Enter the account name and numeric App ID, then select the app's RSA private key (`.pem`).
5. Optionally enter a comma-separated list of repository names, without the owner. An empty list monitors all active repositories available to that installation. A repository filter limits queue discovery; it does not change a GitHub organization runner group's access policy.
6. For an organization, optionally select an existing runner group by name. Use GitHub's runner-group settings to control which repositories can use the group. Personal accounts register a runner with the specific repository that has a queued job.
7. Select the shared base VM and SSH credentials under **Virtual Machine**. Set the maximum number of machines to one or two. Configure the shared labels under **Runner**.
8. Start Tartelet from the menu bar. The GitHub Accounts page shows scheduler status and API or cleanup errors. Stop the fleet before editing account profiles.

Select an account row to open its settings in a modal. Use **Save** to apply changes, **Cancel** to discard them, or **Remove Account…** to remove the account. The modal remains available while the fleet runs, but changes are locked. The **Enabled** and **Disabled** labels show the saved scheduling setting; they do not confirm GitHub authentication.

A separate GitHub App can be used for each profile. One app can also be installed on several accounts if its installation policy permits that. Each profile has separate Keychain entries, including a separate private-key tag. Private keys are never stored in profile preferences or copied to a VM. Only a short-lived runner registration token is sent to the job VM.

Use matching labels in your workflow, for example:

```yaml
jobs:
  build:
    runs-on: [self-hosted, macOS, ARM64, tartelet]
    steps:
      - run: xcodebuild -version
```

Jobs must have at least one runner label. Every requested label must match the shared runner configuration. Default labels are `self-hosted`, `macOS`, and `ARM64`, unless disabled in Settings. If a workflow selects a runner group, the profile must use that group and the workflow must also specify matching labels.

## Scheduling and VM lifecycle

- Tartelet checks the queue when started and then 30 seconds after each scan completes. It scans both queued and running workflows to find queued downstream and matrix jobs. Repositories, workflow runs, and jobs are paginated.
- It selects jobs in turns between profiles. If only one account needs capacity, that account can use both slots. It does not interrupt a running job to give its slot to another account.
- Each selected job creates a fresh clone of the shared base VM. Organization profiles register organization runners; personal profiles register repository runners.
- GitHub makes the final job assignment. Queue discovery does not reserve a job in GitHub. Another eligible job in the same runner scope may be assigned to the runner, or another host may take the queued job first.
- Runner setup is limited to five minutes. A guest that has not started a job within five minutes of running its setup script shuts down. Once a job starts, this idle timeout does not limit its duration. Existing `.tartelet/pre-run.sh` and `.tartelet/post-run.sh` hooks remain supported.
- After one job, the guest shuts down. Tartelet deletes the clone and removes any remaining registration with its unique runner name. A slot stays reserved until cleanup succeeds. Cleanup failures are shown in Settings and retried; restore GitHub access or resolve the reported Tart error if cleanup cannot finish.
- **Stop** lets current jobs finish and stops new allocations. **Quit** cancels the job VMs and waits for cleanup before the app exits.
- Each profile gets a cache directory at `$TART_HOME/cache/accounts/<profile UUID>` (or `~/.tart/cache/accounts/<profile UUID>`). Removing a profile leaves its cache files intact. Directories supplied manually through `TARTELET_RUN_OPTIONS` are outside this separation.

API failures in one account do not stop checks for the other accounts. Installation tokens are reused for up to 45 minutes. Queue API rate-limit responses pause that account until the reset time or `Retry-After` interval. Limit the monitored repositories for large installations: polling many repositories can consume the GitHub API allowance quickly. No webhook server is required.

## Existing installations

The first launch imports the previous single-account configuration if no profile list exists and its credentials are accessible in Keychain. The import preserves the old key and settings. Removing all profiles does not trigger another import. Organization runner-group settings are imported; runner names are now generated per VM to avoid collisions across accounts and hosts.

Existing apps need **Repository Actions: read** and repository access for queue discovery. Approve that permission change in GitHub before starting the scheduler.

A build signed by a different developer team may not be able to read the original app's Keychain entries. Re-enter those credentials in the new build. The development build described below has a separate bundle identifier and preferences, so it does not import production preferences automatically.

## Build and validate

Requirements: Apple Silicon, macOS 14 or later, Xcode, XcodeGen, and Tart for actual VM jobs. Install XcodeGen with `brew install xcodegen`, or point `XCODEGEN` at an existing executable.

```sh
./script/build_and_run.sh
./script/build_and_run.sh --verify
swift test --package-path Packages/GitHub
swift test --package-path Packages/VirtualMachine
swift test --package-path Packages/Shell
swift test --package-path Packages/Settings
```

The script generates the Xcode project, builds an ad-hoc signed development app, and launches it. `--verify` disables automatic VM startup for that launch and checks that the app process exists. `--build-only` builds without launching. The development bundle identifier is `dk.shape.Tartelet.Development`; its preferences are separate from the standard app.

For a build with your developer team, set `TARTELET_DEVELOPMENT_TEAM`. Set `TARTELET_BUNDLE_ID` if a different bundle identifier is required. Keychain access uses the signed app's default access group rather than a hardcoded upstream team ID. The Codex Run action calls the same script.

The tests use generated test keys, simulated GitHub responses, and fake VM lifecycles. They do not register real runners or start Tart VMs. A live acceptance check requires installed GitHub Apps and a prepared base VM: queue jobs in two accounts, verify at most two VMs run, confirm each runner's scope, then confirm both clones and runner registrations are removed.
