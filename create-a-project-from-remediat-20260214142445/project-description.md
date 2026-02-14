# Project Description — Remediation for A. Datum Corporation

## What Is This Project?

This is an **Azure Remediation** project for A. Datum Corporation addressing: **Downscale disks**.
The project generates production-ready remediation scripts, validates fixes, and produces a runbook with step-by-step instructions.

## Project Phases

1. **Discovery** — Retrieve recommendation details and affected resources from vBox
2. **Script Generation** — Generate remediation scripts (PowerShell/Azure CLI) tailored to the affected resources
3. **Validation** — Generate validation scripts to verify remediation was successful
4. **Runbook Completion** — Compile all steps, scripts, and manual actions into a comprehensive runbook
5. **Execution Support** — Guide implementation and track results

## Expected Artifacts

| Artifact | Description |
|----------|-------------|
| **Runbook** (`deliverables/runbook.md`) | Step-by-step remediation guide with scripts and manual steps |
| **Remediation Scripts** | Auto-generated PowerShell/CLI scripts for the affected resources |
| **Validation Scripts** | Scripts to verify remediation was applied successfully |
| **Affected Resources** (`context/affected-resources.json`) | List of Azure resources requiring remediation |

## How to Work With the Agent

You can ask the agent to help with any project task. Here are some examples:

- "Generate the remediation script"
- "Generate manual remediation steps"
- "Change the script language to Azure CLI"
- "Show me the affected resources"
- "Generate validation scripts"
- "What is the current status of the project?"

The agent will update the project plan and progress as work is completed.
