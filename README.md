# Golden AMI Payload - Packer Script Standard

This repository contains Packer payload scripts used to build Golden AMIs. Packer is the orchestration engine, and this repository contains no orchestration logic.

Each script is a self-contained, idempotent payload unit that:
- Installs or validates a single component
- Is safe to run multiple times
- Produces deterministic evidence
- Signals success or failure via a file-based contract
- Receives input only through environment variables

For the full contract, environment variables, and local test harness usage, see `Docs/README.md`.
