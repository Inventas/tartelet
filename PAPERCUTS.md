# Papercuts

## Multiple Tart run options are passed as one argument

This is existing upstream behavior in `Packages/VirtualMachine/Sources/VirtualMachineData/Tart.swift`.

- **Impact:** A single `TARTELET_RUN_OPTIONS` flag works, but a string containing several flags is passed to Tart as one CLI argument. Those flags cannot be combined as expected.
- **Reproduction:** Set `TARTELET_RUN_OPTIONS` to `--no-graphics --dir=extra:/path/to/folder`, then start a job VM. The current command builder appends that entire string once.
- **Evidence:** Confirmed from the command builder; this combined command was not run against a live VM during the multi-account change.
- **Follow-up:** Define and document an argument-list format, parse it without shell evaluation, and test single and multiple options.
