# Publishing Guide

This repository is configured for GitHub-driven releases. Treat GitHub Actions as the release authority and PyPI as the final distribution step.

## Release Order

Do releases in this order:

1. make sure all GitHub Actions build jobs are green
2. confirm the generated wheels and source distribution look correct in GitHub artifacts
3. confirm the GitHub Release step works correctly
4. only then enable or use PyPI publishing

Do not treat PyPI as the first validation step. If GitHub builds are failing, fix CI first and keep PyPI publishing disabled or unconfigured until the workflow is stable.

## PyPI Trusted Publishing Setup

This repository is configured for PyPI Trusted Publishing through GitHub Actions.

The workflow already has the required OIDC permission in [build.yml](/home/ubuntu/dev/pjsua2-python/.github/workflows/build.yml), so you do not need to store a long-lived PyPI API token if you use the recommended setup.

### Recommended approach

Use this sequence:

1. get GitHub Actions builds working reliably
2. configure Trusted Publishing on PyPI
3. push a new release tag
4. let GitHub Actions publish automatically after the build, package check, and GitHub Release steps succeed

### Step 1: Create a PyPI account

1. go to https://pypi.org/account/register/
2. verify your email address
3. enable two-factor authentication on PyPI
4. log in

### Step 2: Configure Trusted Publishing on PyPI

Open:

- https://pypi.org/manage/account/publishing/

Add a new pending publisher with these values:

- PyPI project name: pjsua2-python
- Owner: srthorat
- Repository name: pjsua2-python
- Workflow name: build.yml
- Environment name: leave empty unless you intentionally use a GitHub Environment for releases

This tells PyPI that only this GitHub repository and this workflow may publish the pjsua2-python project.

### Step 3: Verify GitHub before enabling release publishing

Before you depend on PyPI publishing, check the GitHub side first:

1. the Build Wheels workflow completes successfully for all platforms
2. the package-check job builds the sdist and passes twine check
3. the github-release job creates a GitHub Release and uploads all expected files
4. release artifacts include platform wheels, source tarball, and SHA256SUMS.txt

If any of those steps fail, do not proceed to PyPI publishing yet.

### Step 4: Publish a release

When GitHub Actions is working correctly:

1. bump [pjsua2/_version.py](/home/ubuntu/dev/pjsua2-python/pjsua2/_version.py) if needed
2. push the commit to main
3. create a matching tag such as v2.15.2
4. push the tag

Example:

```bash
git tag v2.15.2
git push origin v2.15.2
```

The release workflow will then:

1. build all platform wheels
2. build and validate the source distribution
3. create the GitHub Release
4. publish to PyPI if Trusted Publishing is configured correctly

### Step 5: Verify the published package

After a successful publish:

1. open https://pypi.org/project/pjsua2-python/
2. confirm the new version is listed
3. confirm wheels exist for the expected platforms
4. confirm the source distribution is present

## TestPyPI First

If you want a safer dry run, configure TestPyPI before real PyPI.

1. create an account at https://test.pypi.org/account/register/
2. open https://test.pypi.org/manage/account/publishing/
3. add the same pending publisher values:
   - project: pjsua2-python
   - owner: srthorat
   - repository: pjsua2-python
   - workflow: build.yml

If you later want a separate TestPyPI workflow, add one explicitly rather than mixing test and production publishing in the same release path.

## Common Publish Failures

Common causes of PyPI publish failures:

1. Trusted Publishing values do not match the repository exactly
2. the project name on PyPI does not match pjsua2-python
3. the version already exists on PyPI
4. one or more platform build jobs failed earlier in the workflow
5. GitHub Release packaging failed before the PyPI step
6. Trusted Publishing was configured after the tag run had already started

## Temporary Recommendation

Because the current builds are still failing, keep the focus on GitHub Actions until the workflow is green end to end.

Recommended immediate order:

1. fix all GitHub build failures
2. confirm release artifacts are correct on GitHub
3. configure Trusted Publishing on PyPI
4. publish with a fresh version tag