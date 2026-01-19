# Codex Reference: Prompting Claude Opus 4.5

When user requests a task for Claude Opus 4.5, generate prompts following these rules.

---

## Opus Profile

- Model: `claude-opus-4-5-20250514`
- Cost: Higher tier (use for complex tasks only)
- Context: 200K tokens
- Strengths: Deepest reasoning, maximum capability, complex multi-domain synthesis, frontier performance
- Best for: Tasks where Sonnet insufficient, critical accuracy requirements, complex creative work, multi-domain expertise

---

## Core Principle

Opus performs best with rich, comprehensive prompts. More context = better output.

Unlike Codex (minimal prompts), Opus needs:
- Detailed role definitions
- Full context and background
- Explicit reasoning requests
- Structured output specifications

---

## Always Include: Parallel Agent Directive

Every prompt to Opus MUST include:

```
<parallel_execution>
Spin up multiple temporary agents to work in parallel on independent subtasks.
For complex analysis: assign each agent a different perspective or domain.
For research: parallelize across sources or themes.
Synthesize all agent outputs into unified response.
</parallel_execution>

<deep_reasoning>
Think through this problem thoroughly in <thinking> tags.
Consider multiple approaches before selecting the best.
Verify reasoning and check for errors before finalizing.
</deep_reasoning>
```

---

## Prompt Structure for Opus

```
<system>
You are a [specific role] with [years/level] of experience in [domain].
You specialize in [specific skills]. You prioritize [key values: accuracy, thoroughness, etc.].

<parallel_execution>
Spin up multiple temporary agents to work in parallel.
Assign focused scopes. Synthesize results.
</parallel_execution>
</system>

<user>
## Context
[Full background - why this matters, who uses it, what decision it informs]

## Task
[Clear, specific description]

## Requirements
- [Detailed requirement 1]
- [Detailed requirement 2]
- [Detailed requirement 3]

## Constraints
[Any limitations, must-haves, must-avoids]

## Examples (if applicable)
[Show desired format/style with 2-3 examples]

## Output Format
[Exact structure: sections, length, tone, tags for parsing]

---

Think through your approach in <thinking> tags, then provide your response in <response> tags.
</user>
```

---

## Key Rules for Opus Prompts

1. **Define role precisely** - "Senior architect with 15 years in distributed systems" not just "developer"
2. **Provide full context** - Why it matters, who uses it, what decision it informs
3. **Request chain-of-thought** - Use `<thinking>` tags for complex reasoning
4. **Be explicit about everything** - Format, tone, length, structure
5. **Include examples** - 2-3 examples significantly improve output quality
6. **Explain constraints** - Opus uses constraints intelligently

---

## Chain-of-Thought Levels

**Basic:**
```
Think step by step before responding.
```

**Guided:**
```
Before answering, consider:
1. [What to analyze first]
2. [What factors to weigh]
3. [What tradeoffs exist]
Then provide your response.
```

**Structured (Best for Opus):**
```
Think through your approach in <thinking> tags:
1. Understand the core problem
2. Identify key constraints
3. Consider 3 approaches
4. Evaluate tradeoffs
5. Select best approach

Then provide your response in <response> tags.
```

---

## XML Structure Pattern

Use XML for both input organization and output parsing:

**Input:**
```
<context>
[Background information]
</context>

<requirements>
- Requirement 1
- Requirement 2
</requirements>

<examples>
[Desired output examples]
</examples>

<task>
[What to do]
</task>
```

**Output request:**
```
Structure your response as:
<analysis>[Your analysis]</analysis>
<recommendation>[Your recommendation]</recommendation>
<implementation>[Implementation details]</implementation>
```

---

## Templates

### Deep Analysis
```
<system>
You are a senior analyst with 20 years experience in [domain].
You excel at finding non-obvious insights and presenting nuanced findings.

<parallel_execution>
Spin up agents: one per analysis angle. Synthesize into comprehensive report.
</parallel_execution>
</system>

<user>
## Context
[Full background - stakeholders, decisions this informs, constraints]

## Subject
[What to analyze]

## Analysis Dimensions
- [Dimension 1 with specific questions]
- [Dimension 2 with specific questions]
- [Dimension 3 with specific questions]

## Output Format
<thinking>[Your reasoning process]</thinking>
<analysis>
  <summary>[Executive summary - 3 sentences]</summary>
  <findings>[Detailed findings by dimension]</findings>
  <risks>[Identified risks]</risks>
  <recommendations>[Prioritized recommendations with rationale]</recommendations>
</analysis>
</user>
```

### Complex Decision
```
<system>
You are a strategic advisor with expertise in [domain].
You evaluate options rigorously and present clear recommendations.

<parallel_execution>
Spin up one agent per option to analyze deeply. Compare in synthesis.
</parallel_execution>
</system>

<user>
## Decision Context
[What decision, why it matters, who decides]

## Options
- Option A: [Full description]
- Option B: [Full description]
- Option C: [Full description]

## Evaluation Criteria
- [Criterion 1]: Weight [X]
- [Criterion 2]: Weight [Y]
- [Criterion 3]: Weight [Z]

## Output Format
<thinking>[Evaluation reasoning]</thinking>
<comparison>
  [Option-by-option analysis against criteria]
</comparison>
<recommendation>
  [Clear recommendation with supporting rationale]
</recommendation>
</user>
```

### Expert Synthesis
```
<system>
You are a research director synthesizing complex information across domains.

<parallel_execution>
Spin up agents: one per source document or theme. Cross-reference findings.
</parallel_execution>
</system>

<user>
## Research Question
[What needs to be understood]

## Sources
[Documents, data, or information to synthesize]

## Synthesis Requirements
- Identify consensus findings (3+ sources agree)
- Flag contradictions with source attribution
- Note gaps in coverage
- Propose resolution for conflicts

## Output Format
<thinking>[Synthesis reasoning]</thinking>
<synthesis>
  <consensus>[Agreed findings with citations]</consensus>
  <conflicts>[Disagreements with analysis]</conflicts>
  <gaps>[Missing information]</gaps>
  <conclusion>[Answer to research question with confidence level]</conclusion>
</synthesis>
</user>
```

---

## Iteration Strategy

If first response insufficient:

```
What weaknesses or gaps exist in this response?
```

Then:
```
Address [specific weakness]. Strengthen [specific area].
Make [section] more [detailed/concise/technical].
```

Finally:
```
Verify this meets all original requirements:
- [Requirement 1]
- [Requirement 2]
```

---

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Vague role | Specific expertise + years |
| Missing context | Full background + purpose |
| "Keep it short" | "Limit to 200 words" |
| "Be professional" | "Formal tone, no contractions, address reader directly" |
| Skip reasoning request | Include `<thinking>` tags |
| Generic examples | Domain-specific examples |

---

## Transform User Request

When user says: "Analyze whether we should migrate to microservices"

Generate:
```
<system>
You are a principal software architect with 20 years experience in system design and migrations.
You have led 10+ monolith-to-microservices transitions.

<parallel_execution>
Spin up parallel agents:
- Agent 1: Analyze current architecture strengths/weaknesses
- Agent 2: Evaluate microservices benefits for this case
- Agent 3: Assess risks and migration complexity
- Agent 4: Research industry case studies
Synthesize into comprehensive recommendation.
</parallel_execution>
</system>

<user>
## Context
[Include user's codebase details, team size, business constraints]

## Decision
Should we migrate from monolith to microservices?

## Evaluation Criteria
- Development velocity impact
- Operational complexity
- Cost (infrastructure + team)
- Risk profile
- Timeline to value

## Current State
[User's architecture details]

## Output Format
<thinking>
[Deep analysis of tradeoffs]
</thinking>

<analysis>
  <current_state_assessment>[Honest evaluation]</current_state_assessment>
  <microservices_fit>[How well it fits this case]</microservices_fit>
  <migration_complexity>[Realistic assessment]</migration_complexity>
  <alternatives>[Other options considered]</alternatives>
</analysis>

<recommendation>
  [Clear yes/no/conditional with detailed rationale]
  [If yes: phased approach]
  [If no: what to do instead]
</recommendation>
</user>
```
