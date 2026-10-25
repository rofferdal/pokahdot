# Switching GitHub Pages to manual deployment

Use this guide only when the project owner explicitly asks to replace the
default automatic deployment policy. The repository normally builds and
deploys every successful push to `main`.

Manual mode should always deploy the latest commit on `main`. It must not ask
an operator to paste an arbitrary commit SHA or silently deploy another
branch.

## Switch the workflow to manual mode

1. Start from an up-to-date `main` branch and create a branch for the workflow
   and documentation change.
2. In `.github/workflows/deploy-web.yml`, replace the trigger:

   ```yaml
   on:
     push:
       branches: [main]
   ```

   with:

   ```yaml
   on:
     workflow_dispatch:
   ```

3. Keep the workflow input-free. The operator is selecting when to deploy,
   not which revision to deploy.
4. Make checkout explicitly use the latest `main` revision:

   ```yaml
   - name: Check out latest main commit
     uses: actions/checkout@v6
     with:
       ref: main
       fetch-depth: 0
       persist-credentials: false
   ```

5. Replace the push-specific provenance step with this manual-mode check:

   ```yaml
   - name: Record deployment provenance
     shell: bash
     env:
       WORKFLOW_REF: ${{ github.ref }}
     run: |
       set -euo pipefail
       test "$WORKFLOW_REF" = "refs/heads/main" || {
         echo "Run Deploy Web release from the main branch." >&2
         exit 1
       }
       deployed_sha="$(git rev-parse HEAD)"
       test "$deployed_sha" = "$(git rev-parse origin/main)"
       test -z "$(git status --porcelain)"

       {
         echo "### Web deployment"
         echo "- Commit SHA: \`$deployed_sha\`"
         echo "- Provenance: manual dispatch of the latest \`main\` commit"
       } >> "$GITHUB_STEP_SUMMARY"
   ```

6. Leave the build, `release-candidate-gate`, Web export, Pages artifact, and
   deploy jobs unchanged.
7. Update `docs/OPTIONAL_WEB_SETUP.md`, `docs/ARCHITECTURE.md`,
   `docs/GUI_VISUAL_TESTING.md`, `README.md`, and the affected documentation
   indexes in the same commit. Manual mode must never be introduced as an
   undocumented workflow-only change.
8. Validate the workflow and documentation, review the diff, merge the change
   to `main`, and confirm that the merge does not start a Pages deployment.

## Deploy the latest commit on main

1. Confirm that the commit to test is already the latest commit on `main`.
2. Open the repository on GitHub and select **Actions**.
3. Select **Deploy Web release**.
4. Select **Run workflow**.
5. Choose `main` in the branch selector and select **Run workflow** again.
6. Wait for both the build and deploy jobs to succeed.
7. Open the run summary and record its full commit SHA and deployed URL.
8. Open the deployed URL in a private/incognito browser session and verify
   startup plus the browser console before collecting evidence.

If the **Run workflow** button is missing, confirm that the
`workflow_dispatch` version of the workflow exists on the repository's
default branch and that the current user has write access.

## GitHub environment settings

The workflow uses the `github-pages` environment. A required-reviewer rule in
**Settings > Environments > github-pages** makes a manual run wait for a second
approval. Add such a rule only when the project owner explicitly requests
approval-gated deployment, and document that additional policy in
`docs/OPTIONAL_WEB_SETUP.md`.

## Restore automatic deployment

Reverse the trigger change so `.github/workflows/deploy-web.yml` again uses:

```yaml
on:
  push:
    branches: [main]
```

Restore checkout and provenance to use `github.sha`, update all deployment
documentation in the same commit, and remove any GitHub environment approval
rule that would pause pushes. After merging, confirm that the merge commit
automatically starts **Deploy Web release**.
