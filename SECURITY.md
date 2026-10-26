# Security policy

## Reporting a vulnerability

Please use GitHub Security Advisories for vulnerabilities that could expose credentials, cross an app capability boundary, execute a tool without user authorization, or disclose private task data. Do not place secrets, installation identifiers, or exploit details in a public issue.

## Trust boundaries

- Provider credentials use iOS Keychain and never enter tool results, logs, exports, telemetry, or repository files.
- Browser, HTTPS, workspace writes, JavaScript, and memory have independent user-facing capability switches.
- File access is restricted to the application workspace and validates canonical paths.
- The model HTTPS tool accepts public HTTPS hosts with request, response, and timeout bounds.
- The built-in browser uses a nonpersistent profile separate from the persistent ChatGPT Web website session.
- Remote provider catalogs are data only and cannot install executable code or add a native protocol adapter.
- Tool results, browser content, remote configuration, files, and memory are untrusted input.
- Audit, event, task, and diagnostic records stay in protected local storage unless the user exports them.

The iOS project contains no cross-app Accessibility automation, root access, or arbitrary shell command surface.
