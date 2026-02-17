# Document Update: Progress

## Document Specification

**progress.md** captures the current shared understanding of where the project stands.
It answers:
- What has been done?
- What is currently in progress?
- What is still pending?
- What key information has been discovered?
- What should not be repeated?

This is a human-readable snapshot of reality that serves as **persistent memory** for future interactions.

## What Goes In Progress
- Completed work (in plain language)
- Current focus or blockers
- Pending steps
- **Key findings and discoveries** - concrete results from tool executions that inform next steps
- Notes that affect what to do next

## What Does NOT Go In Progress
- Original intent (that stays in the plan)
- Long explanations of why decisions were made (that belongs in history)

## Current Progress Document
Project created from template: cost-optimization

## Done
- Scheduled kick-off meeting with Cascade Logistics stakeholders.

## In Progress
- Reviewing the Statement of Work.
- Adding the Cascade Logistics logo to the presentation materials.
- Opening the customer info document for context.

## Key Findings
- Meeting scheduling link generated for "Cascade Logistics - Cost Optimization Kickoff Meeting [vbox-task-1365]" with 1 attendee(s): vmakhnevich@vboxcloud.com.

## Last User Message
Schedule kick-off meeting

## Main Loop Response
- **Action**: call
- **Summary**: Updating the project progress document to reflect that the kickoff meeting has been scheduled.
- **Tool Result**: {
  "success": true,
  "message": "Artifact written successfully",
  "path": "/planning/progress.md",
  "name": "progress.md",
  "contentType": "text/markdown",
  "size": 1306
}

# Document Update: Progress

## Document Specification

**progress.md** captures the current shared understanding of where the project stands.
It answers:
- What has been done?
- What is currently in progress?
- What is still pending?
- What key information has been discovered?
- What should not be repeated?

This is a human-readable snapshot of reality that serves as **persistent memory** for future interactions.

## What Goes In Progress
- Completed work (in plain language)
- Current focus or blockers
- Pending steps
- **Key findings and discoveries** - concrete results from tool executions that inform next steps
- Notes that affect what to do next

## What Does NOT Go In Progress
- Original intent (that stays in the plan)
- Long explanations of why decisions were made (that belongs in history)

## Current Progress Document
Project created from template: cost-optimization

## Done
- Scheduled kick-off meeting with Cascade Logistics stakeholders.

## In Progress
- Reviewing the Statement of Work.
- Adding the Cascade Logistics logo to the presentation materials.
- Opening the customer info document for context.

## Key Findings
- Meeting scheduling link generated for "Cascade Logistics - Cost Optimization Kickoff Meeting [vbox-task-1365]" with 1 attendee(s): vmakhnevich@vboxcloud.com.
- The kick-off meeting has been scheduled.

## Last User Message
Schedule kick-off meeting

## Main Loop Response
- **Action**: call
- **Summary**: Updating the project progress document to reflect that the kickoff meeting has been scheduled.
- **Tool Result**: {
  "success": true,
  "message": "Artifact written successfully",
  "path": "/planning/progress.md",
  "name": "progress.md",
  "contentType": "text/markdown",
  "size": 1306
}

## Instructions

Analyze the main loop response and the tool result. Decide if progress should be updated.

**IMPORTANT**: When tools return useful information, you MUST capture the **relevant findings** in the progress document. This is critical because:
- The raw tool results are NOT preserved between conversations
- Progress.md is the ONLY place where discovered information persists
- Future interactions depend on this captured knowledge

### When to Update

Update progress when:
- A task was completed
- A new task started
- Blockers were identified or resolved
- **Tools returned relevant findings** (capture the key information, not just "searched for X")
  - NOTE: Tool errors, compilation failures, or transient failures should NOT be logged - they are not progress
- The main loop synthesized new information in its response

### When to SKIP

Return `skip` when:
- No tool was called AND no new information was synthesized
- A tool was called but failed with no useful results
- A tool returned an error or failed (tool failures are transient and should NOT be recorded in progress)
- The action was just a status query or acknowledgment with no progress
- Rewriting the document would produce essentially the same content

**Important**: Do NOT rewrite the document with cosmetic changes or rewordings. If the substance hasn't changed, return `skip`.

### How to Capture Findings

BAD (too generic):
```
## Done
- Searched for integration testing tools
```

GOOD (captures actual findings):
```
## Done
- Researched integration testing tools
  - Key options: Selenium, Cypress, Playwright, Puppeteer
  - For CI/CD: Jenkins, GitLab CI, CircleCI
  - For infrastructure: Molecule, ansible-test
```

### Response Format

1. **If a meaningful state change occurred**:
   - Write the NEW complete content for progress.md
   - Use sections as appropriate: ## Done, ## In Progress, ## Pending, ## Key Findings
   - Capture relevant discovered information concretely
   - Return the full new document content

2. **If no meaningful state change occurred** (e.g., tool failed with no useful info):
   - Return exactly: `skip`

**Your response should be EITHER:**
- The word `skip` (if no update needed)
- The complete new progress.md content (if update needed)

Do not include explanations or metadata outside the progress content.
```markdown
# Document Update: Progress

## Document Specification

**progress.md** captures the current shared understanding of where the project stands.
It answers:
- What has been done?
- What is currently in progress?
- What is still pending?
- What key information has been discovered?
- What should not be repeated?

This is a human-readable snapshot of reality that serves as **persistent memory** for future interactions.

## What Goes In Progress
- Completed work (in plain language)
- Current focus or blockers
- Pending steps
- **Key findings and discoveries** - concrete results from tool executions that inform next steps
- Notes that affect what to do next

## What Does NOT Go In Progress
- Original intent (that stays in the plan)
- Long explanations of why decisions were made (that belongs in history)

## Current Progress Document
Project created from template: cost-optimization

## Done
- Scheduled kick-off meeting with Cascade Logistics stakeholders.

## In Progress
- Reviewing the Statement of Work.
- Adding the Cascade Logistics logo to the presentation materials.
- Opening the customer info document for context.

## Key Findings
- Meeting scheduling link generated for "Cascade Logistics - Cost Optimization Kickoff Meeting [vbox-task-1365]" with 1 attendee(s): vmakhnevich@vboxcloud.com.
```