# Security policy

This project runs a local HTTP inference server and parses large model files. Bind the server to loopback unless you have independently configured authentication and network isolation. Model files are untrusted input; obtain them from the documented upstream repositories and verify SHA-256 before loading.

Do not include tokens, credentials, private prompts, or personal paths in public bug reports. For a suspected vulnerability, use GitHub's private vulnerability reporting feature for this repository. Ordinary reproducible correctness or performance defects can use GitHub Issues.

