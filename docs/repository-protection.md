# GitHub integration policy

The active repository ruleset `21994586` applies to the default `master` branch.
It requires a pull request and the `quality` check from GitHub Actions
(integration ID `15368`) with strict up-to-date enforcement. Branch deletion,
force pushes, and unresolved review threads are prohibited. No bypass actors
are configured.

Read back both the ruleset and the effective branch rules after configuration:

```sh
gh api repos/neoenox/selfcheck/rulesets/21994586
gh api repos/neoenox/selfcheck/rules/branches/master
```

The checked-in workflow is not itself proof of enforced settings. A PR with
pending or failing `quality` must remain blocked, and a successful check must
refer to the current candidate. Do not add the post-merge release tasks as
pre-merge checks or use administrative bypass to satisfy this gate.

This integration policy is separate from the physical camera/JAN/OCR acceptance
in Issue #1. Passing CI does not claim that device acceptance is complete.
