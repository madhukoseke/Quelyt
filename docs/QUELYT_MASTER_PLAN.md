QUELYT

Explore your data. Locally.

Status: Product & Architecture Discovery
Product: Quelyt
Initial Platform: macOS
Architecture Principle: Local-first
Primary Interface: Desktop
Primary Capability: AI-native data exploration

⸻

1. Vision

Quelyt is a local-first AI data workspace.

The fundamental idea is simple:

Connect data. Ask questions. Understand what is happening.

Quelyt should allow someone to:

* create a local database
* connect an existing database
* open local datasets
* inspect schemas
* browse data
* write SQL
* profile datasets
* visualize results
* ask questions in natural language
* let AI investigate data through multiple queries
* understand relationships between tables
* preserve useful semantic context
* optionally perform AI inference entirely locally

The initial product targets macOS.

The basic local experience should require:

* no account
* no cloud backend
* no Docker
* no external database installation where avoidable
* no telemetry
* no mandatory AI subscription
* no mandatory API key

Cloud services may be optionally supported.

⸻

2. North Star

The ideal first experience:

Download Quelyt
      ↓
Open Quelyt
      ↓
Drop sales.parquet
      ↓
Dataset opens immediately
      ↓
Ask:
"Why did revenue decline in August?"
      ↓
Quelyt investigates
      ↓
Runs SQL
      ↓
Runs follow-up SQL
      ↓
Identifies contributing dimensions
      ↓
Creates visualization
      ↓
Explains findings
      ↓
User can inspect every query/action

Target:

Useful insight from a local dataset in under one minute.

⸻

3. Product Thesis

Traditional database clients are optimized around:

Human
 ↓
SQL
 ↓
Database

AI database tools increasingly provide:

Human
 ↓
Natural language
 ↓
LLM
 ↓
SQL
 ↓
Database

Quelyt should eventually provide something richer:

                USER
                  │
                  ▼
           QUELYT AGENT
                  │
          ┌───────┼───────┐
          ▼       ▼       ▼
       Context  Memory   Tools
          │       │       │
          └───────┼───────┘
                  ▼
         SCHEMA INTELLIGENCE
                  │
          ┌───────┼────────┐
          ▼       ▼        ▼
       SQL      Graph    Semantics
          │
          ▼
          DATA SOURCES

Quelyt should become capable of understanding:

* what data exists
* where it lives
* how tables relate
* what columns mean
* how metrics are defined
* which queries have worked before
* what terminology the user uses
* which operations are safe
* what additional investigation is necessary

The differentiator should not simply be:

AI writes SQL.

That capability is becoming commoditized.

The deeper thesis is:

Quelyt builds persistent intelligence around your data and makes that intelligence available to humans and agents.

⸻

4. Long-Term Architecture Thesis

Potential future position:

PostgreSQL ─┐
MySQL ──────┤
DuckDB ─────┤
SQLite ─────┤
Snowflake ──┤
BigQuery ───┤
Databricks ─┤
CSV ────────┤
Parquet ────┤
JSON ───────┤
Excel ──────┤
Files ──────┘
            │
            ▼
    ┌──────────────────┐
    │      QUELYT      │
    │                  │
    │ Query Engine     │
    │ Schema Graph     │
    │ Semantic Layer   │
    │ Context Engine   │
    │ Memory           │
    │ Agent Runtime    │
    │ Permission Layer │
    └────────┬─────────┘
             │
      ┌──────┼───────┐
      ▼      ▼       ▼
     Human  AI Chat  MCP
                    Agents

Quelyt could eventually become:

the local intelligence and permission layer between data and AI agents.

This is a hypothesis, not a predetermined architecture.

⸻

5. Target Users

Investigate these groups.

Primary Candidates

Data Engineers

Need:

* SQL
* multiple databases
* schema exploration
* profiling
* troubleshooting
* transformations
* local data
* AI assistance

Analytics Engineers

Need:

* SQL
* relationships
* metrics
* lineage
* transformations
* semantic context

Data Analysts

Need:

* exploration
* charts
* natural language
* profiling
* SQL assistance

AI Engineers

Need:

* datasets
* embeddings
* retrieval
* agent tools
* MCP
* local models

Developers

Need:

* database inspection
* local PostgreSQL
* SQLite
* logs
* SQL
* debugging

Founders / Indie Developers

Need:

* simple analytics
* local development database
* product-data investigation
* AI assistance

Determine the strongest initial wedge.

Do not attempt to serve everyone in v1.

⸻

6. Competitive Landscape

Continuously research relevant products.

Examples include:

* TablePlus
* DataGrip
* DBeaver
* Beekeeper Studio
* Postico
* Sequel Ace
* pgAdmin
* Supabase Studio
* DuckDB
* MotherDuck
* Hex
* Mode
* Metabase
* Evidence
* Datasette
* dbt
* JupyterLab
* Observable
* Ollama
* LM Studio
* Open WebUI
* AnythingLLM

Also continuously identify newer:

* AI database clients
* text-to-SQL products
* agentic analytics tools
* MCP database tools
* local-first database clients

For each meaningful competitor investigate:

* positioning
* architecture
* target user
* supported databases
* local capabilities
* AI architecture
* privacy
* semantic/context system
* MCP
* pricing
* UX
* weaknesses
* what users complain about
* what Quelyt could uniquely do

Maintain:

docs/research/competitive-landscape.md

⸻

7. Product Principles

7.1 Local First

Meaningful functionality must work locally.

Prefer:

Mac
 ↓
Quelyt
 ↓
Local engines
 ↓
Local data
 ↓
Local AI

Cloud should enhance Quelyt, not be required for Quelyt to exist.

⸻

7.2 Private by Default

Local mode:

* data remains local
* schema remains local
* chat remains local
* embeddings remain local
* AI inference remains local
* logs remain local

Cloud AI should be explicit.

⸻

7.3 Inspectable AI

Every database operation performed by AI should be inspectable.

Expose:

* selected tables
* retrieved schema
* generated SQL
* executed SQL
* execution time
* rows examined where available
* follow-up operations
* charts generated
* errors

Do not create an opaque “magic chatbot.”

⸻

7.4 Safe AI

AI should start with minimum database privileges.

Default:

Read Mode

Potential modes:

Ask

Generate SQL but do not execute.

Read

Allow:

* SELECT
* DESCRIBE
* EXPLAIN
* metadata queries

Write With Approval

Potential:

* INSERT
* UPDATE
* DELETE
* DDL

Require explicit approval.

Agent

Advanced scoped autonomy.

⸻

7.5 Fast

Quelyt should feel like a desktop developer tool.

Avoid unnecessary server round trips.

Exploit local execution.

⸻

7.6 Native Feeling

Even if the implementation uses web technologies, the application should behave like a high-quality macOS application.

Influences:

* Linear
* Raycast
* Arc
* TablePlus
* modern Apple applications

Avoid generic admin-dashboard aesthetics.

⸻

7.7 Progressive Complexity

Simple things should be simple.

Advanced capabilities should reveal themselves progressively.

Opening a CSV should not require understanding:

* warehouses
* catalogs
* semantic models
* agents
* embeddings

⸻

8. Desktop Architecture Investigation

Do not prematurely choose a framework.

Evaluate:

Swift + SwiftUI

Investigate:

* performance
* native UX
* AppKit interoperability
* SQL editor support
* database libraries
* process management
* AI runtime integration
* development velocity

Tauri

Investigate:

* Tauri 2
* Rust
* React
* TypeScript
* process management
* bundle size
* updater
* signing
* native APIs
* performance

Electron

Investigate:

* Monaco
* Node ecosystem
* database libraries
* memory
* packaging
* mature desktop tooling

Others

Where warranted:

* Flutter
* Qt
* AppKit
* hybrid architectures

Produce:

ADR-001-desktop-framework.md

⸻

9. Local Data Engine

DuckDB is the leading hypothesis.

Validate rather than assume.

Investigate:

* embedding DuckDB
* CSV
* Parquet
* JSON
* Excel pathways
* Iceberg
* extensions
* concurrency
* memory
* performance
* database files
* vector extensions
* spatial extensions
* extension security
* packaging
* licensing

Critical UX:

Open file.parquet
      ↓
Immediately queryable

Potential:

SELECT *
FROM 'sales.parquet';

Quelyt should make this capability accessible without requiring users to understand DuckDB first.

Produce:

ADR-002-analytical-engine.md

⸻

10. Application Metadata

Evaluate SQLite for:

* settings
* workspaces
* connections metadata
* chat history
* query history
* cached schema
* AI memory
* saved queries
* chart definitions
* semantic definitions
* local job metadata

Sensitive credentials should NOT simply be stored in SQLite.

Use macOS Keychain where appropriate.

Produce:

ADR-003-app-metadata.md

⸻

11. Local PostgreSQL

One of the most interesting product capabilities:

New
 ↓
PostgreSQL
 ↓
Create

No Homebrew.

No Docker.

No terminal.

Investigate:

* bundling PostgreSQL binaries
* initdb
* pg_ctl
* local data directories
* dynamic ports
* lifecycle
* versioning
* migration
* backup
* crash recovery
* logs
* Apple Silicon
* Intel if supported
* signing
* notarization
* licenses
* application sandboxing

Prototype this.

Experiment:

experiments/local-postgres/

Measure:

* packaged size
* initialization time
* startup time
* shutdown behavior
* upgrade complexity
* reliability

Produce:

ADR-004-local-postgres.md

Do not include local PostgreSQL in MVP solely because it is technically impressive.

Validate user value.

⸻

12. Connector Architecture

Design a connector interface.

Conceptually:

Connector
│
├── connect()
├── disconnect()
├── testConnection()
├── catalogs()
├── schemas()
├── tables()
├── describeTable()
├── sampleRows()
├── execute()
├── explain()
├── cancel()
└── capabilities()

Capabilities may differ between databases.

Potential future connectors:

P0/P1 candidates

* DuckDB
* SQLite
* PostgreSQL

Later

* MySQL
* MariaDB
* SQL Server
* ClickHouse
* Snowflake
* BigQuery
* Redshift
* Databricks
* Athena
* Trino
* Oracle

Do not implement all initially.

Create a clean abstraction without designing an enormous generic framework.

⸻

13. File Sources

Treat files as first-class data.

Support candidates:

* CSV
* TSV
* JSON
* JSONL
* Parquet
* Excel
* Avro

Investigate:

Open file

versus:

Import file

These should be different concepts.

Example:

Parquet may not need importing.

CSV could potentially be queried directly or imported into DuckDB depending on workflow.

Support directories where useful:

/events/*.parquet

Potential future:

~/Quelyt/Data/

as a local analytical workspace.

⸻

14. Dataset Profiling

One-click:

Profile Dataset

Calculate:

* rows
* columns
* types
* null %
* distinct count
* uniqueness
* min/max
* quantiles
* common values
* distributions
* date ranges
* duplicates
* potential IDs
* candidate relationships
* anomalies

AI can summarize deterministic profiling results.

Important:

Prefer database computation for statistics rather than asking LLMs to infer them from samples.

⸻

15. SQL Workspace

Build an excellent SQL environment.

Potential features:

* tabs
* syntax highlighting
* schema autocomplete
* formatting
* linting
* multiple statements
* result grid
* pagination
* query timing
* query cancellation
* history
* saved queries
* snippets
* EXPLAIN
* keyboard shortcuts

AI actions:

* Explain
* Fix
* Optimize
* Generate
* Comment
* Convert Dialect
* Explain Plan
* Generate Tests

Do not let AI degrade the core SQL experience.

Quelyt should remain useful with AI disabled.

⸻

16. Data Explorer

Potential navigation:

Connections
Local
 ├─ DuckDB
 ├─ SQLite
 └─ PostgreSQL
Remote
 ├─ Production
 └─ Analytics

Database:

Database
│
├── Schemas
│
├── Tables
│
├── Views
│
└── Functions

Table:

Data
Structure
Relationships
Profile
SQL
AI

⸻

17. Talk to Data

This is a core feature.

Avoid simplistic:

question
 ↓
LLM
 ↓
SQL

Investigate an agentic approach.

Example:

User
 ↓
"What caused revenue to decline?"
 ↓
Intent
 ↓
Schema Retrieval
 ↓
Candidate Tables
 ↓
Relationship Resolution
 ↓
Exploratory Query
 ↓
Results
 ↓
Hypothesis
 ↓
Follow-up Query
 ↓
Analysis
 ↓
Visualization
 ↓
Explanation

The agent should be able to make multiple constrained tool calls.

⸻

18. Agent Tools

Potential tools:

list_connections
list_databases
list_schemas
search_schema
describe_table
sample_table
find_relationships
profile_table
profile_column
execute_read_query
explain_query
analyze_plan
create_chart
compare_periods
calculate_metric
find_anomalies
export_results

Write operations should use separate permission boundaries.

Do not expose a generic unrestricted shell/database tool to the agent.

⸻

19. Agent Trace

Show meaningful actions.

Example:

Investigating revenue decline
✓ Found revenue-related columns
✓ Selected orders and customers
✓ Identified customer_id relationship
✓ Compared July vs August
✓ Investigated regions
✓ West region declined 18%
✓ Investigated product categories
✓ Created revenue trend
6 queries • 1.4s database time

Allow expansion.

Expanded state may show SQL and results.

Do not expose private chain-of-thought.

Expose actions, evidence and useful summaries.

⸻

20. Schema Intelligence

Enterprise databases can contain thousands of tables.

Do NOT send the entire schema to the model.

Build/research a schema intelligence layer.

Store/index:

* database
* catalog
* schema
* table
* column
* type
* primary keys
* foreign keys
* indexes
* descriptions
* statistics
* relationships
* semantic labels
* historical usage

Potential retrieval:

Question
 ↓
Lexical Retrieval
 ↓
Semantic Retrieval
 ↓
Candidate Tables
 ↓
Graph Expansion
 ↓
Column Ranking
 ↓
Context

⸻

21. Schema Retrieval Experiment

Create synthetic databases of increasing complexity:

* 10 tables
* 100 tables
* 1,000 tables
* potentially 5,000 tables

Create realistic questions.

Compare:

A. entire schema

B. lexical search

C. BM25

D. embeddings

E. graph traversal

F. hybrid retrieval

Measure:

* correct table recall
* correct column recall
* token usage
* latency
* SQL accuracy

Store evaluation under:

docs/evals/schema-retrieval/

⸻

22. Data Knowledge Graph

Investigate representing relationships as a graph.

Nodes:

* database
* schema
* table
* column
* metric
* query
* definition

Edges:

contains
references
joins_with
derived_from
used_by
similar_to
defines

Example:

customers
    │ customer_id
    ▼
orders
    │ order_id
    ▼
order_items
    │ product_id
    ▼
products

Relationship confidence can come from:

* declared foreign keys
* naming conventions
* value overlap
* successful SQL
* user confirmation
* semantic similarity

Do not introduce a graph database unless evidence justifies it.

SQLite tables may be sufficient.

⸻

23. Query Knowledge

Quelyt should learn from successful queries.

Example:

orders.customer_id = customers.id

Repeated successful use should become useful contextual evidence.

Store:

* query
* tables
* joins
* execution success
* user corrections
* context
* optional semantic description

Potential future:

Query Knowledge Base

This may significantly improve AI reliability.

⸻

24. Semantic Layer

Investigate local metric definitions.

Example:

revenue:
  expression: SUM(orders.total)
  description: Gross order revenue

User:

Show revenue by month.

Quelyt should use known metric semantics rather than reinventing the definition.

Potential entities:

* metrics
* dimensions
* definitions
* synonyms
* relationships

Do not build a full enterprise semantic platform in MVP.

⸻

25. Memory

Potential scopes:

Global
Workspace
Connection
Database
Conversation

Examples:

“GMV means gross merchandise value.”

“Use completed orders when calculating revenue.”

“customer_uuid is the canonical customer identifier.”

Memory should be:

* local
* inspectable
* editable
* deletable
* scoped

Do not allow hidden accumulated context to become impossible to debug.

⸻

26. Context Engineering

Build deliberate context rather than giant prompts.

Possible pipeline:

Question
 ↓
Conversation Context
 ↓
Intent
 ↓
Schema Search
 ↓
Graph Expansion
 ↓
Semantic Definitions
 ↓
Relevant Historical Queries
 ↓
Statistics / Samples if needed
 ↓
Model

Track what context was used.

Potential UI:

Context

Tables
2
Columns
11
Relationships
1
Definitions
2
Sample Rows
OFF

⸻

27. AI Runtime

Provider independent.

Conceptual interface:

ModelProvider
complete()
stream()
toolCall()
embed()
capabilities()

Investigate local runtimes:

* MLX
* MLX-LM
* llama.cpp
* Ollama
* LM Studio

Investigate optional cloud providers:

* OpenAI
* Anthropic
* Gemini
* OpenRouter
* Azure OpenAI
* Bedrock

Users bring credentials.

Credentials:

macOS Keychain

⸻

28. Local AI

Goal:

Database
+
Schema Intelligence
+
Embeddings
+
LLM
+
Agent

can operate without internet.

Evaluate model classes for:

* SQL
* tool use
* planning
* analysis
* summarization
* embeddings

Benchmark on Apple Silicon where possible.

Consider:

* model size
* quantization
* RAM
* startup
* tokens/sec
* SQL correctness
* tool-call correctness

Develop hardware tiers.

Example:

8 GB
Basic
16 GB
Standard
24–32 GB
Recommended
64 GB+
Advanced local agents

Use evidence rather than assumptions.

⸻

29. AI Evaluation

Do not judge AI quality through demos.

Create evaluation suites.

Example schema:

customers
orders
order_items
products
payments
returns

Question categories:

Easy

“How many customers do we have?”

Aggregation

“Revenue by month.”

Join

“Top customers by lifetime spend.”

Semantic

“Which customers are becoming less active?”

Investigation

“Why did revenue decline last month?”

Ambiguous

“Which products are performing badly?”

Safety

“Delete all test orders.”

Measure:

* table selection
* join correctness
* SQL validity
* execution correctness
* answer correctness
* number of tool calls
* latency
* unsafe action rate

Keep regression tests.

⸻

30. SQL Safety

Never rely exclusively on prompting.

Investigate:

* SQL parsing
* AST
* statement classification
* read-only connections
* transactions
* timeouts
* row limits
* query cancellation
* EXPLAIN
* database permissions

Default AI mode:

READ ONLY

Block:

DROP
TRUNCATE
DELETE
UPDATE
INSERT
ALTER
CREATE

unless appropriate authorization exists.

Vendor-specific edge cases must be considered.

⸻

31. Secrets

Use macOS Keychain for:

* database passwords
* API keys
* tokens

Metadata store may contain a reference to credentials but not plaintext secrets.

Investigate:

* Keychain API
* Tauri integration if chosen
* secret migration
* deletion
* backup implications

⸻

32. Privacy Inspector

When cloud AI is used, consider showing what leaves the machine.

Example:

Cloud AI Request
Schema Metadata       ON
Column Names          ON
Table Statistics      ON
Sample Rows           OFF
Query Results         OFF

Potential future feature:

Privacy Inspector

This could become a meaningful differentiator.

⸻

33. Visualization

Do not rebuild Tableau.

Initial charts:

* table
* metric
* bar
* line
* area
* scatter
* histogram

Possibly later:

* heatmap
* correlation
* distribution
* geographic

AI:

"Show monthly revenue."

should be capable of:

SQL
 ↓
Results
 ↓
Chart Recommendation
 ↓
Visualization

Charts must retain their underlying SQL.

⸻

34. Data Quality

Potential later capability.

Rules:

* not null
* unique
* accepted values
* range
* regex
* referential integrity
* freshness

AI:

Generate sensible quality checks for customers.

Deterministic engine executes them.

AI suggests.

Engine validates.

⸻

35. Transformations

Potential future lightweight SQL model system.

Example:

models/
stg_orders.sql
int_customer_orders.sql
fct_revenue.sql

Potential:

* DAG
* tests
* lineage
* documentation

Evaluate against integrating existing dbt workflows.

Likely not P0.

⸻

36. Notebook Mode

Potential future blocks:

SQL
Chart
Markdown
AI
Python

Do not build until user demand is validated.

⸻

37. Python Runtime

Potential future capability.

Investigate:

* embedded Python
* uv
* isolated environments
* subprocesses
* Polars
* pandas

Security is important.

AI-generated Python must not receive unrestricted machine access by default.

Probably not P0.

⸻

38. MCP

Treat MCP as strategically important.

Potential architecture:

Codex
Claude
ChatGPT
Other Agent
       │
       ▼
    Quelyt MCP
       │
       ▼
Permission Layer
       │
       ▼
Schema Intelligence
       │
       ▼
Database

Potential tools:

search_schema
describe_table
find_relationships
execute_read_query
profile_table
get_metric

Quelyt could become the safe interface through which agents interact with databases.

Research:

* local MCP server architecture
* authentication
* permissions
* connection scopes
* auditing
* lifecycle
* UX

Likely P1/P2 depending on evidence.

⸻

39. Local Agent Runtime

Potential future workflows:

Analyze yesterday’s transactions every morning.

Watch this folder for new Parquet files.

Alert me when data quality changes.

Potential scheduler:

* internal scheduler
* launchd
* local background agent

Not MVP unless strong evidence appears.

⸻

40. Search

Global search should eventually span:

* databases
* tables
* columns
* metrics
* queries
* conversations
* charts
* definitions

Example:

⌘P

Search:

customer revenue

Results:

orders.total
customers
Monthly Revenue
Revenue by Customer.sql
Conversation: Revenue investigation

⸻

41. Command Palette

Potential:

⌘K

Commands:

* New Database
* Connect Database
* Open Dataset
* New Query
* Ask Quelyt
* Profile Dataset
* Import CSV
* Run Query
* Search Schema

This can become a central interaction model.

⸻

42. AI UX

AI should understand UI context.

Examples:

Select SQL:

Explain this.

Select table:

Profile this.

Select columns:

Are these related?

Select results:

Why is this an outlier?

Global:

Where is customer revenue stored?

Potential shortcut:

⌘J

opens Quelyt AI.

⸻

43. UI Hypothesis

Potential structure:

┌────────────────────────────────────────────────────┐
│ Quelyt                                      ⌘K     │
├──────────────┬────────────────────────┬────────────┤
│              │                        │            │
│ Connections  │                        │   Quelyt   │
│              │                        │     AI     │
│ Local        │      Workspace         │            │
│ ├ DuckDB     │                        │            │
│ └ Postgres   │                        │            │
│              │                        │            │
│ Remote       │                        │            │
│ └ Analytics  │                        │            │
│              │                        │            │
├──────────────┴────────────────────────┴────────────┤
│ Results                                             │
└────────────────────────────────────────────────────┘

Do not treat this as final design.

Prototype interactions.

⸻

44. Suggested Technology Hypothesis

Current hypothesis only:

Desktop
Tauri 2
Core
Rust
UI
React
TypeScript
Editor
Monaco or CodeMirror
Analytical Engine
DuckDB
Metadata
SQLite
Local Operational DB
PostgreSQL
Secrets
macOS Keychain
Local AI
MLX / Ollama / llama.cpp
Cloud AI
Provider abstraction
Charts
lightweight web visualization library
SQL Safety
SQL parser / AST
Packaging
macOS signed + notarized DMG

Challenge every item.

⸻

45. Process Architecture

Potential:

Quelyt.app
│
├── UI
│
├── Core
│
├── DuckDB
│
├── SQLite
│
├── PostgreSQL process
│
├── optional model process
│
└── optional Python worker

Investigate:

* process startup
* shutdown
* monitoring
* health
* ports
* logs
* crash recovery
* resource usage
* zombie prevention

⸻

46. macOS

Investigate:

* Apple Silicon
* Intel support decision
* code signing
* notarization
* Gatekeeper
* Keychain
* file permissions
* network permissions
* sandboxing
* background processes
* updates
* DMG distribution
* Mac App Store restrictions

Determine whether direct distribution should be the initial path.

⸻

47. Performance Targets

Initial aspirational targets:

Application cold start:

< 2 seconds

Simple DuckDB dataset open:

near instant

Schema search:

< 500 ms

UI:

60 fps

AI first-token latency:

hardware/provider dependent

Database operations:

database-bound

Do not fake performance.

Benchmark.

⸻

48. Local-Only Feasibility Matrix

Create and maintain:

Capability	Fully Local	Cloud Optional	Cloud Required	Notes
DuckDB				
SQLite				
PostgreSQL				
SQL editor				
Profiling				
Charts				
Schema search				
Embeddings				
AI chat				
Agent				
Knowledge graph				
MCP				

Evidence should drive the matrix.

⸻

49. Critical Experiments

Before committing architecture, run experiments.

E01 — DuckDB

Load:

* CSV
* Parquet
* JSON

Measure:

* load/query performance
* memory
* integration complexity

⸻

E02 — Local PostgreSQL

Bundle/init/start/stop PostgreSQL without Docker/Homebrew.

Measure:

* size
* startup
* lifecycle
* reliability

⸻

E03 — Text-to-SQL

Synthetic commerce database.

At least 20–50 questions.

Measure correctness.

⸻

E04 — Schema Retrieval

Hundreds/thousands of tables.

Compare retrieval methods.

⸻

E05 — Agentic Investigation

Compare:

One-shot SQL

against:

Multi-step investigation

Question:

Why did revenue fall last month?

Measure answer quality.

⸻

E06 — Local Models

Evaluate practical local models.

Measure:

* memory
* startup
* SQL
* tools
* tokens/sec
* accuracy

⸻

E07 — Desktop Framework

Build small realistic prototypes rather than Hello World.

Test:

* large result grid
* SQL editor
* DuckDB query
* streaming AI response
* native menu
* process control

⸻

50. MVP Philosophy

Do not build the vision.

Build the wedge.

Possible P0 hypothesis:

Quelyt Desktop
1. Open CSV/Parquet
2. DuckDB
3. PostgreSQL connection
4. Schema browser
5. SQL editor
6. Result grid
7. Dataset profile
8. AI provider abstraction
9. Local AI option
10. Talk to Data
11. Safe SQL execution
12. Basic charts
13. Local history

Challenge this.

A smaller MVP may be better.

⸻

51. Priority Framework

Every feature should be classified:

P0

Required to prove Quelyt.

P1

Immediately improves the proven wedge.

P2

Platform expansion.

P3

Long-term possibility.

Do not allow P2/P3 architecture to dominate P0 implementation.

⸻

52. Explicit Non-Goals for Initial MVP

Unless evidence changes the decision:

* team collaboration
* cloud sync
* enterprise SSO
* RBAC platform
* mobile app
* Kubernetes
* distributed query engine
* full dbt replacement
* Tableau replacement
* full notebook environment
* arbitrary Python agent execution
* dozens of connectors
* hosted data warehouse
* Quelyt accounts
* billing system
* marketplace
* plugin ecosystem

⸻

53. Testing

Required categories:

* unit
* integration
* database lifecycle
* connector contract
* query execution
* cancellation
* import
* profiling
* schema retrieval
* SQL safety
* AI evaluation
* UI
* packaging

AI requires regression evaluation, not merely snapshots.

⸻

54. Observability

Local diagnostics:

* application logs
* database timings
* SQL
* agent tool calls
* retrieval traces
* LLM latency
* token usage
* errors
* process status
* memory
* CPU

Default:

local only.

⸻

55. Architecture Decision Records

Maintain ADRs.

Initial:

ADR-001 Desktop Framework
ADR-002 Analytical Engine
ADR-003 Metadata Store
ADR-004 Local PostgreSQL
ADR-005 AI Runtime
ADR-006 Agent Architecture
ADR-007 Schema Retrieval
ADR-008 SQL Safety
ADR-009 Secret Storage
ADR-010 Packaging

Format:

# ADR
Status
Context
Options
Decision
Evidence
Consequences
Risks
Revisit When

⸻

56. Documentation Structure

Recommended:

docs/
├── product/
│   ├── thesis.md
│   ├── users.md
│   └── mvp.md
│
├── research/
│   ├── competitors.md
│   ├── duckdb.md
│   ├── postgres.md
│   ├── local-ai.md
│   └── desktop-frameworks.md
│
├── architecture/
│   ├── overview.md
│   ├── ai.md
│   ├── connectors.md
│   └── security.md
│
├── adr/
│
└── evals/

⸻

57. Repository Hypothesis

Potential:

quelyt/
├── apps/
│   └── desktop/
│
├── crates/
│   ├── core/
│   ├── connectors/
│   ├── duckdb/
│   ├── postgres/
│   ├── ai/
│   ├── context/
│   └── security/
│
├── packages/
│   ├── ui/
│   └── types/
│
├── experiments/
│
├── evals/
│
├── docs/
│
└── scripts/

Do not create this structure until architecture decisions justify it.

⸻

58. Development Method

Use:

Question
 ↓
Research
 ↓
Prototype
 ↓
Measure
 ↓
ADR
 ↓
Implementation
 ↓
Test
 ↓
Review

Avoid:

Idea
 ↓
Massive architecture
 ↓
Months of implementation
 ↓
Discover assumption was wrong

⸻

59. Astra Utilization

Use Astra for more than coding.

It should:

* research documentation
* inspect repositories
* inspect machine configuration
* install development dependencies
* create prototypes
* run applications
* interact with UI
* visually inspect results
* benchmark
* debug
* analyze logs
* test workflows
* refactor
* review architecture
* challenge requirements

For UI work:

Implement
 ↓
Launch
 ↓
Inspect visually
 ↓
Interact
 ↓
Identify UX defects
 ↓
Fix
 ↓
Repeat

Do not consider frontend work complete merely because it compiles.

⸻

60. Evidence Discipline

Mark conclusions as:

FACT

Supported externally or directly observed.

ASSUMPTION

Believed but unverified.

EXPERIMENT

Observed through prototype/test.

DECISION

Chosen based on available evidence.

OPEN QUESTION

Requires further work.

This is particularly important for AI architecture.

⸻

61. Product Moat Investigation

Continuously ask:

What happens if every database client adds an AI sidebar?

Possible differentiation:

* fully local AI
* schema intelligence
* persistent data context
* knowledge graph
* query learning
* semantic memory
* agentic investigation
* privacy controls
* MCP gateway
* integrated local databases
* local workflows

Determine which actually matters.

⸻

62. Open Source Strategy

Investigate:

* closed desktop app
* open core
* fully open source
* source available
* OSS engine + paid desktop

Potential open components:

* connector SDK
* MCP server
* schema retrieval
* AI evaluation benchmark
* local context engine

Open source may become distribution.

Do not decide based only on ideology.

⸻

63. Business Model

Not immediate priority.

Potential models:

* free
* one-time purchase
* Pro subscription
* open core
* BYO model
* Teams later

Protect the local-first value proposition.

Do not cripple the free local experience artificially.

⸻

64. Distribution

Potential communities:

* GitHub
* Hacker News
* Product Hunt
* Reddit
* data engineering
* DuckDB
* PostgreSQL
* local AI
* AI engineering
* indie hackers

Potential launch message:

I built a local AI workspace that lets you drop in a dataset and talk to it without sending your data anywhere.

That is much stronger than:

New SQL client.

⸻

65. Success Metrics

Early product metrics should focus on usefulness.

Potential:

Time to First Dataset

Time to First Query

Time to First AI Answer

AI SQL Success Rate

Questions Successfully Answered

Repeat Sessions

Databases Connected

Queries Executed

Avoid vanity metrics initially.

⸻

66. 30-Day Hypothesis

A possible trajectory:

Week 1

Discovery + experiments + ADRs.

Week 2

Desktop shell + DuckDB + file opening + SQL.

Week 3

AI + schema intelligence + Talk to Data.

Week 4

profiling + visualization + polish + packaging + private alpha.

This schedule is intentionally aggressive.

Adjust based on experimental evidence.

⸻

67. First User Journey to Ship

Prioritize making one journey exceptional:

Download Quelyt
Open
Drag:
sales.parquet
Quelyt:
"2.4M rows • 18 columns • Jan 2024–Aug 2026"
User:
"Show monthly revenue."
Quelyt:
[chart]
User:
"Why did it fall in August?"
Quelyt:
Investigating...
✓ Compared monthly revenue
✓ Checked regions
✓ Checked products
✓ Checked customer segments
"Revenue fell 14.2%.
The largest contributor was the West region,
primarily from Enterprise customers.
[chart]
View analysis
View SQL"

If this works extremely well locally, we have something worth expanding.

⸻

68. North-Star Demo

The demo should eventually work with internet disabled.

Wi-Fi OFF
Open Quelyt
Drop Parquet
Ask question
Local model reasons
DuckDB executes
Quelyt investigates
Chart appears
Answer appears

That is a powerful demonstration of the product thesis.

⸻

69. Long-Term Possibilities

Only after proving the core.

Potential:

* database agents
* scheduled analysis
* anomaly monitoring
* semantic layer
* lineage
* transformations
* local lakehouse
* notebooks
* Python
* MCP
* agent gateway
* data quality
* schema migration
* query optimization
* data documentation
* database observability
* natural-language workflows

⸻

70. Moonshot

Long term:

             AI AGENTS
                 │
                 ▼
          ┌──────────────┐
          │    QUELYT    │
          │              │
          │ Context      │
          │ Semantics    │
          │ Permissions  │
          │ Memory       │
          │ Intelligence │
          └──────┬───────┘
                 │
                 ▼
              DATA

An AI agent should not need:

* unrestricted credentials
* the entire schema
* business definitions manually injected
* direct database access

Instead it asks Quelyt.

Quelyt determines:

* what the agent may access
* which schema matters
* what business terms mean
* which query is safe
* what historical context matters
* how results should be returned

At that point Quelyt is no longer merely a database application.

It becomes:

The intelligence layer between AI and data.

⸻

71. Final Engineering Principle

Do not attempt to build the final Quelyt.

Build the smallest version that demonstrates something users cannot easily get elsewhere.

Whenever deciding what to build, ask:

1. Does this strengthen the magic moment?
2. Does it differentiate Quelyt?
3. Can we validate it cheaply?
4. Is there a simpler implementation?
5. Does it preserve local-first?
6. Can users understand what the AI did?
7. Is it safe?
8. Does it need to exist now?

If the answer to #8 is no:

do not build it yet.

⸻

72. Discovery Sprint 0

Begin here.

Produce:

Product

* product thesis
* target user
* primary wedge
* magic moment
* competitive analysis

Engineering

* architecture hypothesis
* framework comparison
* DuckDB evaluation
* PostgreSQL feasibility
* local AI evaluation
* schema retrieval design
* agent architecture
* security architecture

Experiments

Run the highest-value experiments rather than merely proposing them.

Decisions

Create ADRs only when evidence supports them.

Planning

Produce:

* P0
* P1
* P2
* P3
* do-not-build list
* 30-day plan
* first 10 engineering tasks

Recommendation

At the end answer:

Should Quelyt proceed as currently envisioned?

Choose:

* PROCEED
* NARROW
* PIVOT
* STOP

Explain the evidence.

If the recommendation is PROCEED or NARROW:

continue directly into Milestone 1.