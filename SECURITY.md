# Security Policy

## Reporting a Vulnerability

Please report security issues privately to the repository maintainers. Do not
open a public issue for credentials, token exposure, unsafe storage, or
registry access problems.

Include:

- A short description of the issue.
- Steps to reproduce, if practical.
- The affected platform and app version.
- Any relevant logs with secrets removed.

## Credential Storage Notice

Harbor Visible Kit can remember Harbor credentials. In the current
implementation, remembered passwords are stored in local app preferences via
Flutter `shared_preferences`. This is convenient for local desktop use, but it
is not equivalent to encrypted system credential storage.

Users who require stronger protection should leave password remembering
disabled until the app migrates to platform credential storage such as Windows
Credential Manager or macOS Keychain.
