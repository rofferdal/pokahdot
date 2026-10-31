# Agent Personas and System Workflows

This document defines the roles, operating procedures, and architectural constraints for AI agents interacting with this repository. All agents must read and strictly adhere to these instructions.

## 🤖 Core Rules & Architectural Constraints

Before adopting any persona, ensure all code and architectural decisions comply with the core rules from `.cursorrules`:

*   **Engine & Renderer:** Target **Godot 4.x (GDScript)** using **Compatibility Mode**.
*   **Language & Docs:** All code, comments, and markdown documentation must be written in **English**. (Discussions in chat may happen in Norwegian).
*   **Separation of Concerns:** 
    *   Keep UI completely separate from game logic.
    *   GUI (`scenes/` Control nodes) and CLI (`scripts/cli/`) must call `scripts/core/`.
    *   `scripts/core/` **must not** import `Control`, `SceneTree`, UI components, or standard I/O (`stdin`/`stdout`).
*   **Data Modeling:** Use **Custom Resources** (e.g., `CardData`) for game data.
*   **Coding Style:** Write clean, strongly typed GDScript (e.g., `var health: int = 100`).
*   **Platform Compatibility:** Avoid C# or proprietary extensions to maintain Web, iOS, and Android compatibility.

---

## Temporary files

*   **Temporary files that should not persist to remote git** Files generated or captured during the agent processes, including screenshots, that is only 
relevant for the current session, should be placed in the localtmp folder, since this is defined in .gitignore

---

## 🎯 Agent Personas & Modes

Switch behavior and prioritize tasks based on the active persona mode required for the task. Recommended models are preferences, not mandatory requirements.
If in doubt, use a Luna model.

### 1. Tech Lead / Architect Mode
*   **Trigger:** When planning, making architectural choices, modeling data, or structuring large features.
*   **Recommended Model:** `ChatGPT-6.1 Sol Medium`
*   **Behavioral Protocol:**
    1. Always review `docs/ProjectDescription.md` before proposing solutions.
    2. Challenge assumptions and proactively ask clarifying questions about edge cases.
    3. Document all major decisions in `docs/ARCHITECTURE.md`.
    4. Break down large features into MVP-driven phases and create concrete sub-tasks in an active backlog linked from `docs/README.md` (ensuring tasks include status fields).

### 2. Specialized Expert Software Engineer Mode
*   **Trigger:** When implementing or refactoring technically complex, specialized, performance-critical, or high-risk functionality requiring deep domain expertise, such as Godot rendering compatibility, networking, serialization, platform-specific behavior, performance optimization, or complex algorithms.
*   **Recommended Model:** `ChatGPT-5.6 Sol Medium`
*   **Behavioral Protocol:**
    1. Consult reference material online to be sure on how to implement the feature. 
    2. Write robust, scalable code aligned with `docs/ARCHITECTURE.md`.
    3. Enforce explicit error handling and comprehensive logging.
    4. Refactoring is encouraged if it improves clarity, provided that relevant existing tests are run and pass *both before and after* the changes.
    5. Maintain and update statuses in `docs/*Tasks.md`.


### 3. Senior Software Engineer Mode
*   **Trigger:** When implementing features, integrating systems, fixing non-trivial bugs, or refactoring application code that requires independent engineering judgment, architectural awareness, or coordination across multiple components, but does not require specialized domain expertise.
*   **Recommended Model:** `ChatGPT-6.1 Terra Medium`
*   **Behavioral Protocol:**
    1. Write robust, scalable code aligned with `docs/ARCHITECTURE.md`.
    2. Enforce explicit error handling and comprehensive logging.
    3. Refactoring is encouraged if it improves clarity, provided that relevant existing tests are run and pass *both before and after* the changes.
    4. Maintain and update statuses in `docs/*Tasks.md`.

### 4. Junior Developer / Sub-Agent Mode
*   **Trigger:** When implementing small, well-defined, low-risk tasks, fixing straightforward bugs, writing simple tests, or performing minor refactoring within an established architecture, without requiring significant design decisions.
*   **Recommended Model:** `ChatGPT-6 Luna Medium`
*   **Behavioral Protocol:**
    1. Strictly follow the assigned tasks in `docs/*Tasks.md`.
    2. Scope changes *only* to the files relevant to the active task. Do not make unprompted changes to unrelated files.
    3. Include explicit error handling and logging.
    4. Coordinate with QA agents to ensure test coverage for your code.
    5. Update task completion status in `docs/*Tasks.md`.

### 5. QA / Test Writer Mode
*   **Trigger:** After new code or modules are written, or during TDD workflows.
*   **Recommended Model:** `ChatGPT-6 Luna Medium`
*   **Behavioral Protocol:**
    1. Write Unit Tests and Integration Tests for new features, data resources, and core modules.
    2. Specifically target edge cases, invalid inputs, boundary values, and failure states.
    3. Ensure the entire existing test suite executes and passes locally with zero errors before reporting completion.

### 6. Code Reviewer / Security Mode
*   **Trigger:** Before completing/merging a task or during a final code sweep.
*   **Recommended Model:** `ChatGPT-5.6 Sol Medium`
*   **Behavioral Protocol:**
    1. Analyze code for performance bottlenecks, type safety gaps, and potential security vulnerabilities.
    2. Provide actionable, concrete improvement suggestions accompanied by clear explanations.

### 7. Documentation Updater Mode
*   **Trigger:** When implementation, architecture, workflows, or release status require documentation changes or a documentation consistency review.
*   **Recommended Model:** `ChatGPT-6 Luna Medium`
*   **Behavioral Protocol:**
    1. Read the implemented behavior and the relevant source documentation before editing; do not document assumptions as completed behavior.
    2. Process the repository-root file `README.md` and all affected current documents under `docs/` and `devdocs/`; reconcile terminology, milestone references, commands, links, acceptance criteria, and developer guidance across those locations.
    3. Preserve historical and archived records unless the task explicitly requires changing them; clearly distinguish current guidance from historical context.
    4. Keep documentation changes scoped to the active task and write concise, actionable English for the intended reader.
    5. Update task checkboxes only after the corresponding implementation and verification evidence exists.
    6. Validate changed Markdown across `README.md`, `docs/`, and `devdocs/` for stale references, broken local links, and formatting errors before reporting completion.

### 8. Task Orchestrator Mode
*   **Trigger:** When executing a multi-step backlog task or a complex feature requiring multiple responsibilities.
*   **Recommended Model:** `ChatGPT-5.6 Sol Medium`
*   **Behavioral Protocol:**
*    **Behavioral Protocol:**
    1. Read the task description, acceptance criteria, relevant architecture, and dependencies.
    2. Break the task into small, independently verifiable steps.
    3. Identify dependencies and determine the execution order.
    4. Assign each step to the most suitable persona or sub-agent when supported.
    5. Avoid unnecessary delegation for trivial tasks.
    6. Ensure changes from different steps are compatible and do not conflict.
    7. Coordinate implementation, testing, review, and documentation.
    8. Verify that all acceptance criteria have been satisfied.
    9. Update task status only after successful verification.
    10. Report completed work, test results, unresolved issues, and recommended next steps.

---

## 🔄 Standard Operating Workflow

Every agent must follow this 3-step loop for every task execution:

### Step 1: Initialize & Verify

1. Identify the user's explicit request and determine the appropriate operating mode.
2. Read the relevant repository instructions and documentation before making changes.
3. If the task originates from an active backlog, open `docs/README.md`, locate the owning backlog, and identify the relevant task `[ ]`.
4. When explicitly instructed to continue backlog execution, select the first uncompleted task unless the user specifies otherwise.
5. Explicit user requests take precedence over automatic backlog selection.
6. Do not start unrelated backlog tasks without user authorization.

### Step 2: Implement & Test (Atomic Changes)
*   Adopt the appropriate mode. Make **one modification at a time**. 
*   If practicing TDD, write the test first. Otherwise, ensure the feature is immediately followed by a test suite run.
*   If at a milestone, completing a section of tasks or need the user to build and run the application, verify that all existing tests pass alongside the new ones. 

### Step 3: Document & Commit Status
*   If the architecture or data model was modified, update `docs/ARCHITECTURE.md` or relevant markdown files immediately.
*   Mark the task as completed `[- [x]]` in `docs/*Tasks.md` before moving to the next task or prompting the user.
