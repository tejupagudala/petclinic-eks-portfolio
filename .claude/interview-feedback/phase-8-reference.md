# Phase 8 — AIOps Service + Streamlit UI (COMPLETE REFERENCE)

**Window:** May 5+ 2026
**Final Average Score:** **8.3/10** across **5 hostile interview questions** (TIED with Phase 7 for project HIGH 🏆)
**Status:** ✅ Locked — interview-viable at $120-165K band
**Written in simple language for future memory refresh**

---

## 📑 Table of Contents

1. [Phase 8 Vocabulary (Plain English)](#vocabulary)
2. [The Story (Why / What / Fails / Wins)](#the-story)
3. [Architecture Decisions Explained](#architecture-decisions)
4. [The 8-Layer Flow Walkthrough](#flow-walkthrough)
5. [Code Walkthrough — The 7 Key Components](#code-walkthrough)
6. [Foundation Concepts](#foundation-concepts)
7. [5 Hostile Q&A (Drilled — Summaries)](#hostile-qa)
8. [Power Phrases & Secret Weapons](#power-phrases)
9. [Memory Tricks (Mnemonics + Anchors)](#memory-tricks)
10. [Common Mistakes to Avoid](#common-mistakes)
11. [Cheat Card](#cheat-card)

---

<a name="vocabulary"></a>
## 1. Phase 8 Vocabulary (Plain English)

### Big Picture

| Term | Plain English |
|---|---|
| **AIOps** | "AI-driven IT Operations" — using LLMs to read logs/metrics and explain incidents |
| **LLM** | "Large Language Model" — like Claude, the brain that reads text and produces text |
| **AWS Bedrock** | AWS's service that gives you access to multiple LLMs (Claude, Llama, Titan) through ONE API |
| **Foundation model** | The pre-trained LLM you use — Claude, Llama, Titan, etc. |
| **Prompt engineering** | Writing instructions to the LLM in a way that guides it to give good answers |
| **Hallucination** | When the LLM invents facts that aren't in the input — dangerous |
| **Grounding** | Forcing the LLM to use ONLY what you supplied, not its training memory |
| **Probable root cause** | The LLM's best guess at WHY an incident is happening |

### Bedrock API Concepts

| Term | Plain English |
|---|---|
| **Converse API** | The NEW Bedrock API — same call shape works for any model. The clean way. |
| **InvokeModel API** | The OLD Bedrock API — each model needs its own JSON format. Messy. |
| **Model ID** | Identifier like `anthropic.claude-3-haiku-20240307-v1:0` |
| **Temperature** | Knob from 0 to 1 — 0 = robotic/deterministic, 1 = creative/random |
| **Max tokens** | Cap on how long the LLM's response can be |
| **Token** | Roughly a word (or part of a word). LLMs charge per token. |
| **Context window** | How much text the LLM can read at once. Claude Haiku: 200K tokens. |
| **System prompt** | The instructions you give the LLM at the start ("You are an AIOps assistant…") |
| **User prompt** | The actual question or data |
| **Streaming** | Getting the response one word at a time (vs waiting for the whole answer) |

### Spring Boot / Java Concepts

| Term | Plain English |
|---|---|
| **Spring Boot** | Java framework for building services quickly with sensible defaults |
| **REST endpoint** | URL that accepts HTTP requests (POST /query) |
| **Controller** | Class that handles HTTP requests, validates them, forwards to a service |
| **Service** | Class with the business logic |
| **DTO (Data Transfer Object)** | Plain Java class representing a JSON shape |
| **`@RestController`** | Spring annotation marking a class as an HTTP handler |
| **`@PostMapping`** | Annotation saying "this method handles HTTP POST" |
| **`@Valid`** | Annotation triggering automatic validation of the request body |
| **`@RequestBody`** | Annotation saying "convert JSON body to a Java object" |
| **`@Component`** | Annotation telling Spring to manage this class as a bean |
| **Dependency Injection** | Spring hands you the things you need — you don't create them yourself |
| **Interface** | A "shape" that says WHAT methods exist without saying HOW |
| **Implementation** | A class with actual code that fulfills the interface's shape |

### Tools You Used

| Term | Plain English |
|---|---|
| **Fabric8** | Java library for talking to the Kubernetes API |
| **AWS SDK v2** | The Java library for calling AWS services like CloudWatch and Bedrock |
| **Spring RestClient** | Modern HTTP client built into Spring (replaces RestTemplate) |
| **HikariCP** | Spring Boot's default database connection pool |
| **Streamlit** | Python framework for building data/ML web apps in 80 lines |
| **Bean Validation** | Spring's automatic validation system (@NotBlank, @Min, @Max) |

### Failure-Handling Concepts

| Term | Plain English |
|---|---|
| **Graceful degradation** | When something breaks, the system keeps working with reduced capability |
| **Marker string** | Specific text in evidence that signals "this source failed" |
| **Failure-classification ladder** | If/else chain mapping which sources failed to which response template |
| **Confidence level** | "low" or "medium" — tells the user how much to trust the answer |
| **Bedrock override** | The pattern where Bedrock writes the root cause, classifier writes the metadata |
| **Status enum** | Cleaner alternative to marker strings — type-safe failure states |

### Design Patterns

| Term | Plain English |
|---|---|
| **Strategy pattern** | Multiple classes with the same shape, swappable at runtime |
| **Adapter pattern** | Wrapping an external library to fit your internal contract |
| **Thin controller** | A controller with no business logic — just receives and forwards |
| **SOLID principles** | Five rules for clean object-oriented design |
| **Single Responsibility (S)** | Each class has ONE reason to change |
| **Open/Closed (O)** | Open to extension (add new), closed to modification (don't edit existing) |
| **Interface Segregation (I)** | Small interfaces with few methods, not fat ones with many |
| **Dependency Inversion (D)** | Depend on interfaces, not concrete classes |

### Production Vocabulary

| Term | Plain English |
|---|---|
| **MVP** | "Minimum Viable Product" — the smallest working version |
| **MECE** | "Mutually Exclusive, Collectively Exhaustive" — no overlap, complete coverage |
| **Resilience4j** | Java library for retry, circuit breaker, rate limiting |
| **Circuit breaker** | Fast-fail pattern — stops calling a broken dependency for a while |
| **Micrometer** | Spring Boot's metrics library — sends data to CloudWatch/Prometheus |
| **Structured logging** | JSON-formatted logs you can query/filter |
| **SLO** | "Service Level Objective" — measurable quality target (99.5% uptime) |
| **RAG** | "Retrieval-Augmented Generation" — LLM gets historical context to reason from |
| **Bedrock Guardrails** | AWS service for content filtering and hallucination defense |
| **Prompt caching** | Bedrock feature to reuse cached prompt prefixes (saves money) |

---

<a name="the-story"></a>
## 2. The Story (Why / What / Fails / Wins)

### Why Phase 8 Existed

After Phase 7, you had all the data plumbing — logs in CloudWatch, metrics in Container Insights, Pod Identity auth wired, Access Entries for cluster access. **But none of it actually HELPED engineers debug incidents.** They still had to read logs manually, correlate timestamps, jump between Grafana and CloudWatch and kubectl. Phase 8 answered the question: *"Can an AI assistant read all my telemetry and tell me what's wrong in plain English?"*

The goal: **reduce incident triage time from hours to seconds**.

### What You Built

Two pieces working together:
1. **`spring-petclinic-aiops-service`** — a Spring Boot microservice that:
   - Accepts natural-language questions via `POST /query`
   - Gathers evidence from Kubernetes, CloudWatch, and Prometheus
   - Sends evidence + question to AWS Bedrock for synthesis
   - Returns a structured 6-field response (root cause, evidence, confidence, fix, unknowns)

2. **`app/python-UI/aiops-assistant/app.py`** — an 80-line Streamlit Python UI that:
   - Lets engineers type questions in a browser
   - Shows results in 6 visual sections
   - Talks to the Spring Boot backend via HTTP POST

### The Fails (Honest Gaps)

| Gap | Why it exists | Production fix |
|---|---|---|
| Sequential adapter calls | Easier to write; 10-second latency | `CompletableFuture.allOf` (5s) |
| No retry/circuit breaker | Out of portfolio scope | Resilience4j |
| String-based marker matching | Quick to ship, fragile | Status enum on EvidenceSection |
| Default Spring logging | Lazy default | Structured JSON with query_id |
| No metrics on the AIOps service itself | Recursive meta-problem skipped | Micrometer + CloudWatch alarms |
| Only Claude Haiku | No fallback chain | Haiku → Llama → template |
| No hallucination detection | Trust the prompt alone | Bedrock Guardrails |
| No RAG / historical context | Single-shot reasoning | Vector store + Knowledge Base |
| No auth on /query | Out of portfolio scope | JWT at ingress |
| No streaming | Wait-for-all UX | converseStream + SSE |
| No conversation memory | Single-shot use case | sessionId + Redis |
| No prompt caching | Cost negligible at portfolio scale | cachePoint blocks |

### The Wins

By end of Phase 8:
- ✅ Spring Boot service with 7 components (controller + orchestrator + 3 adapters + Bedrock + DTOs)
- ✅ Strategy pattern with interface/impl split — testable, swappable
- ✅ Bedrock Converse API with constrained prompt and 6 anti-hallucination guards
- ✅ 11-case failure-classification ladder for graceful degradation
- ✅ Streamlit UI rendering 6 structured response fields
- ✅ Pod Identity auth chain from Phase 7 wired in
- ✅ Cost ~$0.0006 per query with Claude Haiku
- ✅ The killer insight: "AI tools that lie about broken telemetry destroy trust"

---

<a name="architecture-decisions"></a>
## 3. Architecture Decisions Explained

### Decision 1: Spring Boot Service (Not Python)

**Choice:** Java + Spring Boot for the AIOps Service.
**Why:** Petclinic's existing services are all Spring Boot — consistent language, shared parent POM, deploys via same CI/CD pipeline. Adding a Python service would mean a second deployment pipeline.
**Tradeoff:** Python has richer ML/AI library ecosystem (LangChain, LangGraph). Java AWS SDK for Bedrock is well-supported but less idiomatic than Python equivalents.
**When to flip:** If you start using LangChain-specific features (advanced agentic patterns, multi-step tool use), Python wins.

### Decision 2: Streamlit UI (Not React)

**Choice:** 80-line Streamlit app for the UI.
**Why:** Engineers are the users; UX polish doesn't matter. Building React would mean 500+ lines + build pipeline + state management.
**Tradeoff:** Streamlit doesn't scale to consumer-facing UX, has weak auth integrations, lacks mobile responsiveness.
**When to flip:** If exposing to non-engineers, switch to React or Angular.

### Decision 3: Interface + Implementation Split (Strategy Pattern)

**Choice:** Three interfaces (`ServiceHealthAdapter`, `LogsAdapter`, `MetricsAdapter`) each with one implementation.
**Why:** Testability (fake adapters in 3 lines), swappability (CloudWatch → Splunk = one new class), separation of concerns (each adapter has one job).
**Tradeoff:** 6 files instead of 3. Slightly more code.
**When to flip:** Never — this is correct production-pattern at any scale.

### Decision 4: Sequential Adapter Calls (Honest Portfolio Shortcut)

**Choice:** Adapters run one after another, not in parallel.
**Why:** Simpler code; portfolio scope.
**Tradeoff:** Latency is sum of 3 calls (~10s) instead of max of 3 calls (~5s).
**When to flip:** Day 1 of production — `CompletableFuture.allOf` cuts latency in half.

### Decision 5: Bedrock Converse API (Not InvokeModel)

**Choice:** Converse API for LLM calls.
**Why:** Provider-agnostic — same call shape for Claude, Llama, Titan. Switching models is config, not code.
**Tradeoff:** Slightly newer API; some legacy examples online use InvokeModel.
**When to flip:** Never — Converse is AWS's recommended path.

### Decision 6: Temperature 0.3

**Choice:** Temperature 0.3 for Bedrock calls.
**Why:** Deterministic-leaning for diagnostic debuggability. Same evidence → nearly-same root cause. Not zero because perfectly mechanical feels robotic; not higher because creative root causes are dangerous in production observability.
**Tradeoff:** Less variety in phrasing.
**When to flip:** Stick with it — proven good for structured summarization tasks.

### Decision 7: 6-Constraint Anti-Hallucination Prompt

**Choice:** Constrained system prompt with role priming, grounding, anti-hallucination, honesty enforcement, observability-vs-bug guard, format constraint.
**Why:** LLMs hallucinate without constraints. The "do not confuse missing observability with application bug" line addresses a specific failure mode no other prompt addresses.
**Tradeoff:** Longer prompt = slightly higher input token cost.
**When to flip:** Never — these constraints are minimum table-stakes for production AI.

### Decision 8: 6-Field Structured Response (DTO)

**Choice:** `AiopsQueryResponse` has 6 explicit fields — probable root cause, evidence, impacted services, recommended fix, confidence, unknowns.
**Why:** Strict typing means the API contract is enforced at compile time. Matches what the UI renders.
**Tradeoff:** More verbose than free-text responses.
**When to flip:** Never — structured output is critical for downstream consumers (UI, future API consumers).

### Decision 9: Failure-Classification Ladder (11 Cases)

**Choice:** If/else ladder maps combinations of adapter failures to response templates.
**Why:** Defensive design — service answers gracefully even with partial telemetry. Each case has appropriate confidence + recommended fix.
**Tradeoff:** Long if/else block (production fix: state machine or strategy table).
**When to flip:** When you have 20+ cases — extract to a configuration-driven dispatcher.

### Decision 10: Bedrock Override Pattern

**Choice:** Classifier ladder sets initial root cause, then Bedrock's response OVERWRITES it. Classifier still wins on confidence + fix + unknowns.
**Why:** Layered design — Bedrock writes the human-readable diagnosis; classifier writes the metadata. Each does what it's good at.
**Tradeoff:** Subtle code pattern that could confuse new contributors. Worth a comment.
**When to flip:** Never — this is the right division of labor.

---

<a name="flow-walkthrough"></a>
## 4. The 8-Layer Flow Walkthrough

```
USER CLICKS "ANALYZE" IN STREAMLIT
         │
         ▼ Layer 1
┌────────────────────────────────────┐
│  Streamlit UI (Python, 80 lines)   │
│  Reads BACKEND_URL env var         │
└──────────────┬─────────────────────┘
               │
               │ HTTP POST /query
               │ JSON: { question, service, namespace, timeRangeMinutes }
               ▼ Layer 2
┌────────────────────────────────────┐
│  Spring framework receives request │
│  Deserialize to AiopsQueryRequest  │
│  @Valid triggers Bean Validation:  │
│    - @NotBlank on question         │
│    - @Min(1) @Max(1440) on time    │
│  Fail → HTTP 400 automatic         │
└──────────────┬─────────────────────┘
               │
               ▼ Layer 3
┌────────────────────────────────────┐
│  AiopsQueryController (THIN)        │
│  One line: forward to service       │
└──────────────┬─────────────────────┘
               │
               ▼ Layer 4
┌────────────────────────────────────┐
│  AiopsQueryService (THE BRAIN)      │
│  Calls 3 adapters SEQUENTIALLY      │
└──────┬──────────┬──────────┬───────┘
       │          │          │
       ▼          ▼          ▼ Layer 5
┌──────────┐ ┌─────────┐ ┌────────────┐
│Kubernetes│ │CloudWatch│ │Prometheus  │
│Service   │ │Logs      │ │Metrics     │
│Health    │ │Adapter   │ │Adapter     │
│Adapter   │ │          │ │            │
│(Fabric8) │ │(AWS SDK) │ │(RestClient)│
└────┬─────┘ └────┬────┘ └─────┬──────┘
     │            │             │
     │ Each returns EvidenceSection (never throws!)
     │            │             │
     └────────────┴─────────────┘
                  │
                  ▼ Layer 6
┌────────────────────────────────────┐
│  Aggregate evidence → List<String> │
│  Failure-classification ladder:    │
│    - 6 marker strings checked      │
│    - 11 response templates         │
│    - Sets confidence, fix, unknowns│
└──────────────┬─────────────────────┘
               │
               ▼ Layer 7
┌────────────────────────────────────┐
│  BedrockReasoningService            │
│  Builds constrained prompt:         │
│    - 6 anti-hallucination guards    │
│    - Question + evidence            │
│  Calls Bedrock Converse API:        │
│    - Claude Haiku                   │
│    - Temperature 0.3                │
│  Returns root cause sentence        │
│  Bedrock response OVERRIDES         │
│  classifier's rootCause             │
└──────────────┬─────────────────────┘
               │
               ▼ Layer 8
┌────────────────────────────────────┐
│  Build AiopsQueryResponse (6 fields)│
│  - probableRootCause (Bedrock)      │
│  - evidenceCollected (flattened)    │
│  - impactedServices                 │
│  - recommendedFix (classifier)      │
│  - confidence (classifier)          │
│  - unknowns (classifier)            │
│  Return HTTP 200 + JSON body        │
└──────────────┬─────────────────────┘
               │
               ▼
       STREAMLIT RENDERS
       6 visual sections
```

---

<a name="code-walkthrough"></a>
## 5. Code Walkthrough — The 7 Key Components

### Component 1: `AiopsQueryController.java` (29 lines)
**What:** REST endpoint receiver.
**The plain-English job:** A waiter — takes the order, hands to the kitchen, brings back the result.
```java
@RestController
@RequestMapping(path = "/", produces = MediaType.APPLICATION_JSON_VALUE)
public class AiopsQueryController {
    private final AiopsQueryService aiopsQueryService;

    @PostMapping(path = "/query", consumes = MediaType.APPLICATION_JSON_VALUE)
    public AiopsQueryResponse query(@Valid @RequestBody AiopsQueryRequest request) {
        return aiopsQueryService.query(request);   // ← one line, forward to brain
    }
}
```
**Memory anchor:** *"Thin controller — receives, validates, forwards. ONE LINE of business logic."*

### Component 2: `AiopsQueryService.java` (237 lines, the BRAIN)
**What:** Orchestrator. Calls 3 adapters, aggregates evidence, runs classification ladder, invokes Bedrock.
**The plain-English job:** A chef — takes ingredients from suppliers (adapters), tastes for problems (classification), gets a head chef's opinion (Bedrock), plates it (response).
**The 5 steps:**
1. Call 3 adapters sequentially → 3 EvidenceSections
2. Flatten all observations into one List<String>
3. Detect failures by marker strings → 6 boolean flags
4. Run if/else ladder → 11 cases → set confidence + fix + unknowns
5. Call Bedrock for root cause sentence → OVERRIDES classifier's rootCause
**Memory anchor:** *"The brain. Bedrock writes the headline; classifier writes the support."*

### Component 3: `BedrockReasoningService.java` (92 lines)
**What:** AWS Bedrock caller. Builds constrained prompt, invokes Converse API.
**The plain-English job:** The expert consultant — gets the question + evidence, returns a one-sentence diagnosis.
**The constrained prompt (the 6 commandments):**
1. "You are an AIOps incident assistant" — role priming
2. "Use only the supplied evidence" — grounding
3. "Do not invent facts" — anti-hallucination
4. "If telemetry is unavailable, say that clearly" — honesty enforcement
5. **"Do not confuse missing observability data with an application bug"** — KILLER LINE
6. "Return one concise probable root cause sentence" — format constraint
**Memory anchor:** *"6 prompt commandments. Temperature 0.3. Converse API."*

### Component 4: `KubernetesServiceHealthAdapter.java` (176 lines)
**What:** Talks to K8s API via Fabric8 client.
**The plain-English job:** The K8s reporter — asks Kubernetes about deployment status, ready replicas, pod restart counts.
**Two paths:**
- Specific service requested → look up that deployment + label-matched pods
- No service → list all deployments in namespace
**Failure mode:** Try/catch returns *"Failed to query Kubernetes service health."* as observation. NEVER throws.
**Memory anchor:** *"Fabric8 client. Auto-detects in-cluster vs kubeconfig auth."*

### Component 5: `CloudWatchLogsAdapter.java` (105 lines)
**What:** Talks to AWS CloudWatch Logs via AWS SDK v2.
**The plain-English job:** The log fetcher — pulls recent log events from the application log group, filters by service name in message text.
**The query:** `FilterLogEvents` against `/aws/containerinsights/<cluster>/application` with 100-event limit.
**Failure mode:** Try/catch returns *"Failed to query CloudWatch Logs."* as observation. NEVER throws.
**Memory anchor:** *"AWS SDK v2. 100 events fetched, 20 matched, 240-char truncation."*

### Component 6: `PrometheusMetricsAdapter.java` (101 lines)
**What:** Talks to in-cluster Prometheus via Spring RestClient.
**The plain-English job:** The metrics fetcher — queries 3 industry-standard metrics for the service.
**The 3 PromQL queries:**
- 5xx error rate
- p95 latency (`histogram_quantile`)
- Request rate
**Failure mode:** Try/catch returns *"Failed to query Prometheus metrics."* as observation. NEVER throws.
**Honest gap:** PromQL injection — string concatenation of `serviceName` (production fix: input validation).
**Memory anchor:** *"RestClient (not WebClient). 3 PromQL queries. Same metrics as Phase 5 canary."*

### Component 7: DTOs — `AiopsQueryRequest`, `AiopsQueryResponse`, `EvidenceSection`

**`AiopsQueryRequest` (input):**
- `@NotBlank String question` — required
- `String service` — optional
- `String namespace` — optional, defaults to "petclinic"
- `@Min(1) @Max(1440) Integer timeRangeMinutes = 30`

**`AiopsQueryResponse` (output, the 6 fields):**
1. `probableRootCause` — Bedrock's sentence
2. `evidenceCollected` — flat list of observations
3. `impactedServices` — derived from health evidence
4. `recommendedFix` — from classifier
5. `confidence` — "low" / "medium"
6. `unknowns` — transparent gaps

**`EvidenceSection` (intermediate):**
- `source` — "kubernetes" / "cloudwatch" / "prometheus"
- `observations` — list of text observations
**Memory anchor:** *"6-field response. Source-tagged evidence. Strict typing."*

---

<a name="foundation-concepts"></a>
## 6. Foundation Concepts

### Concept 1: Failures Become Evidence, Not Exceptions
Adapters NEVER throw. Every error gets caught and converted into a text observation. The orchestrator reads ALL observations uniformly — some describe data, some describe failures.
**Why it matters:** No exception handling spaghetti in the orchestrator. Uniform processing.

### Concept 2: The Bedrock Override Pattern
Bedrock writes the `probableRootCause` sentence; the classifier writes the metadata (`confidence`, `recommendedFix`, `unknowns`). Each does what it's good at.
**Why it matters:** Layered design — diagnosis is LLM-natural; metadata is deterministic-logic-natural.

### Concept 3: Constrained Prompting Prevents Hallucination
The 6-commandment prompt grounds Bedrock to supplied evidence. Especially the "do not confuse missing observability with application bug" line.
**Why it matters:** Without constraints, LLMs hallucinate confidently — the worst failure mode for production observability.

### Concept 4: Strategy Pattern via Interfaces
Three interfaces, three implementations. The orchestrator depends on shapes, not concrete classes. Tests use fakes; future iterations swap impls.
**Why it matters:** Testability + swappability — two of the biggest production wins.

### Concept 5: Graceful Degradation Over Crash-and-Burn
When CloudWatch is down, the user sees "Failed to query CloudWatch" as evidence with appropriate confidence. The system keeps working with partial data.
**Why it matters:** Production observability that crashes on dependency failure is worse than no observability at all.

### Concept 6: Provider-Agnostic LLM API (Converse)
Same call shape for Claude, Llama, Titan. Switching models is config, not code.
**Why it matters:** Future-proofing. Model fallback chains. A/B testing.

### Concept 7: Meta Observability
Your AIOps monitors other services. Production needs the same observability primitives applied to AIOps itself — metrics, structured logs, alarms.
**Why it matters:** A monitoring tool that's a black box becomes the failure nobody can debug.

### Concept 8: Honest Failure Communication > Wrong Confidence
The user must KNOW when telemetry is broken. Hiding it (returning "looks healthy") destroys trust permanently.
**Why it matters:** Once engineers see one wrong-confidently diagnosis, they stop trusting the tool. Whole tool becomes useless.

---

<a name="hostile-qa"></a>
## 7. 5 Hostile Q&A (Drilled — Summaries)

Full Q&As with ideal answers, memory tips, and 5 follow-ups each live in **[phase-8-qa.md](phase-8-qa.md)**.

| Q | Question | Score | Key insight |
|---|----------|-------|-------------|
| **Q1** | End-to-end flow | **8.0** | 8 layers; thin controller; 3 adapters; Bedrock with constraints; 6-field DTO |
| **Q2** | Why 3 adapters + interface split | **8.5** | Strategy pattern; WHAT vs HOW; testability + swappability + SRP |
| **Q3** | Bedrock integration deep-dive | **8.0** (R2) | Converse over InvokeModel; temp 0.3; 6 prompt commandments; graceful failure |
| **Q4** | Partial telemetry failure handling | **8.5** | Failures become evidence; 6 marker strings; 11-case ladder; Bedrock override |
| **Q5** | Production gaps + prioritization | **8.5** | MECE 3-category framework; tiered Week 1/Month 1/Quarter 1; 80/20 framing |

**Phase 8 Final Average: 8.3/10 — TIED FOR PROJECT HIGH** 🏆

---

<a name="power-phrases"></a>
## 8. Power Phrases & Secret Weapons

### Architecture
- *"Thin controller — receives, validates, forwards. One line of business logic."*
- *"The orchestrator is the brain. Bedrock writes the headline; classifier writes the support."*
- *"Three adapters behind Strategy interfaces — swap implementations without changing orchestrator."*

### LLM Integration
- *"Converse API is provider-agnostic — same call shape for Claude, Llama, Titan."*
- *"Temperature 0.3 — deterministic-leaning for diagnostic debuggability."*
- *"Six prompt constraints, each addresses a specific LLM failure mode."*
- *"The killer line: 'Do not confuse missing observability with application bug.'"*

### Failure Handling
- *"Failures become evidence, not exceptions."*
- *"Six marker strings, eleven response templates."*
- *"Bedrock writes the diagnosis; classifier writes the metadata."*
- *"AI-driven observability tools that lie about broken telemetry destroy trust faster than no tool at all."*

### Production Synthesis
- *"My AIOps monitors other services. Who monitors mine?"*
- *"Three categories — performance & reliability, meta observability, LLM operational maturity."*
- *"Tier by cost-of-not-fixing, not by what's cool to build."*
- *"80% of production value comes from standard production patterns, not AI-specific work."*

### Cost / Auth
- *"$0.0006 per query with Haiku — rounding error against incident analysis value."*
- *"Pod Identity from Phase 7 scopes bedrock:Converse to the model ARN — least privilege."*

---

<a name="memory-tricks"></a>
## 9. Memory Tricks (Mnemonics + Anchors)

### Memory Trick 1: The 8 Layers as a Phone Call
Imagine calling tech support:
1. **You dial** (Streamlit UI)
2. **Phone network routes the call** (HTTP POST)
3. **Receptionist screens the call** (Spring validation)
4. **Front desk forwards to the right person** (Controller)
5. **Specialist takes the call** (Service/Orchestrator)
6. **Specialist gathers info from 3 sources** (3 adapters)
7. **Specialist consults the expert** (Bedrock)
8. **Specialist gives you the answer in structured form** (Response DTO)

### Memory Trick 2: The 6 Prompt Commandments (RGAHHF)
- **R**ole — "You are an AIOps incident assistant"
- **G**rounding — "Use only the supplied evidence"
- **A**nti-hallucination — "Do not invent facts"
- **H**onesty — "If telemetry is unavailable, say that clearly"
- **H**ardest one — "Do not confuse missing observability with application bug"
- **F**ormat — "Return one concise probable root cause sentence"

Anchor: *"Real Good AIOps Has Honest Format"* (RGAHHF)

### Memory Trick 3: The 11 Failure Cases (3-3-3-Special-OK)
- **3** — All 3 sources failed
- **3** — 2 of 3 sources failed (3 sub-cases by pair)
- **3** — 1 of 3 sources failed (3 sub-cases by which)
- **Special** — Deployment missing / no logs found / no metrics data
- **OK** — Everything worked

Anchor: *"Three-Three-Three-Special-OK ladder."*

### Memory Trick 4: The MECE 3-Category Production Framework (PML)
- **P**erformance & reliability
- **M**eta observability
- **L**LM operational maturity

Anchor: *"PML — Production Maturity Layers."*

### Memory Trick 5: The Tiered Prioritization (WMQD)
- **W**eek 1: parallelization, timeouts, metrics, structured logs
- **M**onth 1: Resilience4j, alarms, auth
- **Q**uarter 1: RAG, Guardrails, model fallback
- **D**eferred: prompt caching, streaming, memory, high confidence

Anchor: *"WMQD — Week Month Quarter Deferred."*

### Memory Trick 6: WHAT vs HOW (the interface/impl mental model)
- **WHAT** = interface (the shape, the contract)
- **HOW** = implementation (the actual SDK logic)
- *"Adapters have HOW. Interfaces have WHAT. Orchestrator depends on WHAT."*

### Memory Trick 7: The Bedrock Override Sentence
> *"Bedrock writes the headline; classifier writes the support."*
- **Headline** = `probableRootCause` (Bedrock)
- **Support** = `confidence` + `recommendedFix` + `unknowns` (classifier)

### Memory Trick 8: The Killer One-Liner Library
Three quotes to memorize VERBATIM for closing answers:
1. *"Failures become evidence, not exceptions."* (Q4 anchor)
2. *"AI-driven observability tools that lie about broken telemetry destroy trust faster than no tool at all."* (Q4 closer)
3. *"My AIOps monitors other services. Who monitors mine?"* (Q5 anchor)

### Memory Trick 9: Cost Anchors
- **$0.0006/query** with Claude Haiku (Q3)
- **~$18/month** at 1000 queries/day base
- **+$80/month** for RAG (biggest production add)
- **~$7/month** for all other production adds combined

### Memory Trick 10: Latency Anchors
- **~10 seconds** total today (sequential)
- **~5 seconds** with `CompletableFuture.allOf` (parallel)
- **~1 second** with streaming first token
- **30 seconds** AWS SDK default timeout (the pathological wait you fix with Resilience4j)

---

<a name="common-mistakes"></a>
## 10. Common Mistakes to Avoid

| Mistake | Why it hurts |
|---|---|
| Saying "AI replaces human debugging" | Wrong — AI assists, doesn't replace; LLMs hallucinate |
| Saying "I use Bedrock for everything" | Vague — name Claude Haiku specifically + Converse API |
| Forgetting to name Converse vs InvokeModel | Misses a senior signal |
| Saying "temperature 0" | Wrong — yours is 0.3 (deterministic-leaning, not robotic) |
| Saying "parallel adapters" | Wrong — yours are SEQUENTIAL today (production gap) |
| Saying "Streamlit is production-ready" | Wrong — engineers-only; React for end users |
| Forgetting the 6 prompt constraints | Misses anti-hallucination depth signal |
| Saying "the LLM does everything" | Misses the layered design — classifier writes metadata |
| Confusing "low" vs "medium" confidence | Low = adapter failed; medium = data absent |
| Forgetting the marker-string-matching gap | Misses the honest production gap |
| Saying "no failure handling needed" | Wrong — defensive design is the whole point |
| Saying "I'd just add more prompts" | Misses the structured architecture |
| Confusing Strategy vs Adapter pattern | Your classes are technically BOTH |
| Saying "high confidence" | Wrong — your code caps at "medium" (honest gap) |

---

<a name="cheat-card"></a>
## 11. Cheat Card (One-Page Summary)

### Phase 8 in 30 Seconds
A Spring Boot service that gathers evidence from Kubernetes, CloudWatch, and Prometheus, sends it to AWS Bedrock with a constrained prompt, and returns a structured diagnosis. Streamlit UI for engineers. Built on Phase 7's plumbing.

### The 8 Layers
Streamlit → POST /query → Spring validation → Controller → Service → 3 Adapters → Bedrock → AiopsQueryResponse → render

### The 6 Prompt Commandments (RGAHHF)
Role / Grounding / Anti-hallucination / Honesty / Hardest line / Format

### The 6 Marker Strings
3 × "Failed to query X" + Deployment-not-found + No-log-events + Prometheus-no-data

### The 11-Case Ladder Shape
3 (all failed) — 3 (2 failed pairs) — 3 (1 failed) — Special (deployment, no data) — OK (all worked)

### The Bedrock Override Pattern
- **Bedrock writes:** `probableRootCause` (the headline)
- **Classifier writes:** `confidence` + `recommendedFix` + `unknowns` (the support)

### The 6-Field Response
1. probableRootCause
2. evidenceCollected
3. impactedServices
4. recommendedFix
5. confidence
6. unknowns

### Production Prioritization (WMQD)
- **Week 1:** parallel adapters / timeouts / Micrometer / JSON logs
- **Month 1:** Resilience4j / CloudWatch alarms / JWT auth
- **Quarter 1:** RAG / Bedrock Guardrails / model fallback
- **Deferred:** prompt caching / streaming / memory / high confidence

### Key Numbers
| Metric | Value |
|---|---|
| Latency today (sequential) | ~10s |
| Latency with parallel | ~5s |
| Cost per query (Haiku) | $0.0006 |
| Cost at 1000 q/day | ~$18/month |
| Temperature | 0.3 |
| Claude Haiku context window | 200K tokens |
| Total request budget (production) | 30s |

### Score Targets
| Question | Target |
|---|---|
| End-to-end flow | 8+ |
| Why 3 adapters + interface split | 8.5+ |
| Bedrock integration | 8.5+ |
| Partial telemetry failures | 9+ (your strongest material) |
| Production gaps | 9+ (your strongest material) |

### The 3 Killer One-Liners to Memorize VERBATIM
1. *"Failures become evidence, not exceptions."*
2. *"AI-driven observability tools that lie about broken telemetry destroy trust faster than no tool at all."*
3. *"My AIOps monitors other services. Who monitors mine?"*

---

## Phase 8 — COMPLETE ✅

**Average score across 5 questions: 8.3/10 — TIED WITH PHASE 7 FOR HIGHEST PHASE EVER.**

Combined with Phase 7's 8.3 average, the AIOps Foundation + Service stack is your **strongest interview material**. Lead with what scores highest.

Next: **Cross-phase mock interview round** + **Gap-handling narrative (4-yr gap)**.
