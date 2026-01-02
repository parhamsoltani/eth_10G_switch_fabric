Below is a **comprehensive, integrated research roadmap** for enhancing your Enhanced Ethernet Switch Fabric v2.0 (based on doc_v2.md). I've carefully analyzed both enhancement_v2.md (v2) and enhancement_v3.md (v3) to resolve the ambiguities you mentioned. I'll start by explaining how I resolved those ambiguities, then provide a clear, phased roadmap that merges the strengths of both documents. The roadmap prioritizes practicality: it leverages your existing v2.0 implementation (which is already 75% publication-ready), focuses on high-impact contributions, and aims for Q1 journal publications (e.g., IEEE/ACM ToN). It's designed to be executable, with detailed steps, timelines, dependencies, and risk mitigations.

### Resolving Your Ambiguities
Here's a breakdown of the key confusions you raised, based on the docs:

1. **ECS as "Flagship" in v2 vs. Phase 1 Focus on Memory/Bounded WFQ in v3**:
   - v2 positions Elastic Crosspoint Scheduling (ECS) as the core breakthrough (Pillar 1), with Kalman prediction (Pillar 2) and verification/FPGA (Pillar 3). It suggests starting with ECS because it's the "fundamental architecture gap" and novel, but notes that your v2.0 already has partial memory management (e.g., linklist_dynamic_fifo.sv and shared VOQ/XPQ pools).
   - v3 is a more strategic PhD-oriented roadmap, starting with Phase 1 (dynamic shared buffers + bounded WFQ) as a foundation because it addresses scalability and fairness first—gaps that make ECS more robust. v3 integrates ECS into Phase 2.
   - **Resolution**: ECS *does not strictly require* fully dynamic shared buffers to prototype (you can start with ECS using your existing fixed/shared memory in v2.0 for initial validation). However, dynamic buffers (from v3 Phase 1) *enhance* ECS by allowing elastic allocation without memory fragmentation or overflow risks. Starting with ECS alone (per v2) risks instability in larger port counts (e.g., >10 ports), as noted in v3's scalability concerns (ID #2 and #3 in the consolidated table). **Recommendation**: Follow v3's phased structure but accelerate ECS integration. Start with a "lite" version of dynamic buffers (to support ECS), then build ECS. This hybrid avoids ambiguity: buffers first for stability, ECS second for novelty.

2. **Are Dynamic Shared Buffer Pools Crucial for ECS?**
   - v2's ECS description (Part 3) relies on urgency calculations involving VOQ occupancy and predictions, but it assumes your existing shared memory pools (in VOQ/XPQ). It doesn't explicitly require *adaptive/dynamic* reallocation, but the code snippets (e.g., elastic_crosspoint_manager_v2.sv) reference queue depths (voq_occupancy) and predictions, which could overflow without dynamic buffers under hotspots.
   - v3 emphasizes dynamic buffers (Phase 1, Contribution 1) as critical for handling micro-bursts and scalability, explicitly noting they support elastic scheduling (Phase 2, ID #6).
   - **Resolution**: Yes, dynamic shared buffers are crucial for a robust ECS implementation—especially for port counts >10 (e.g., 32-128, where quadratic VOQ memory explodes). For your example of 10 ports, you can prototype ECS with minimal buffer enhancements (e.g., add basic reallocation to existing linklist_dynamic_fifo.sv). But to make ECS "publication-worthy" (e.g., handling hotspots with 4-6x throughput), integrate dynamic buffers early. This prevents VOQ monopolization and ensures deadlock-freedom.

3. **Port Number Considerations (e.g., 10 Ports vs. Larger)**:
   - Both docs note your parametric architecture scales to 128 ports, but v2 uses NUM_PORT=10 as an example. For small ports (10), memory issues are less acute, but ECS still benefits from buffers to handle hotspots.
   - **Resolution**: Start prototyping with NUM_PORT=10 (low risk, fast iteration). Validate scalability later (e.g., simulate N=32/64). Dynamic buffers become "must-have" for N>32 to avoid BRAM explosion.

4. **Overall Integration Rationale**:
   - v2 is tactical (quick enhancements for one Q1 paper), v3 is strategic (multi-paper PhD trajectory).
   - **Hybrid Roadmap**: Use v3's phases as the backbone (for long-term coherence), but pull in v2's ECS details early in Phase 2. Total timeline: 12-18 months to first publication, expandable to 36-48 months for PhD. Focus on novelty (ECS), rigor (bounded WFQ + verification), and validation (FPGA).

If this doesn't resolve your ambiguities, clarify specifics—I can refine further.

### Integrated Roadmap Overview
**Goal**: Transform v2.0 into 2-3 Q1 publications (e.g., IEEE/ACM ToN for Paper 1, IEEE JSAC for Paper 2). Emphasize ECS as the "flagship" but build foundations first.

**Key Principles**:
- **Start Small**: Prototype with NUM_PORT=10, ELASTIC_ENABLE=1.
- **Dependencies**: Buffers → ECS → Prediction/Verification.
- **Tools**: Use your existing tb/ infrastructure. Leverage code_execution tool for simulations (e.g., Python queuing models). For ML/Kalman, use sympy/mpmath in code_execution.
- **Validation**: Simulation first, then FPGA (VCU118). Use TLA+/SPIN for formal proofs.
- **Timeline**: 12-18 months (aggressive; assumes 1-2 person team). Parallelize where possible.
- **Success Metrics**: Hotspot throughput >4x baseline, fairness deviation <5%, area overhead <10%.

**Phased Structure** (Hybrid of v3 Phases + v2 Pillars):
- **Phase 0: Preparation** (1-2 weeks) – Setup.
- **Phase 1: Foundations (Dynamic Buffers + Bounded WFQ)** (Months 1-4) – From v3 Phase 1, to support ECS.
- **Phase 2: Core Innovation (ECS + Kalman Prediction)** (Months 5-10) – From v2 Pillar 1/2 + v3 Phase 2.
- **Phase 3: Validation & Publication (Formal/FPGA + Paper)** (Months 11-12+) – From v2 Pillar 3 + v3 Phase 3.
- **Optional Extensions**: For PhD, add v3 Phase 3 (ML/Programmable QoS).

Use tables for clarity in steps.

#### Phase 0: Preparation (Weeks 1-2)
**Goal**: Resolve setup ambiguities, baseline your v2.0.
**Why Start Here?**: Ensures no regressions; clarifies if buffers are needed for your 10-port example.

| Step | What to Do | Tools/Files | Timeline | Dependencies/Risks |
|------|------------|-------------|----------|---------------------|
| 1 | **Baseline Validation**: Run existing tests (tb/tb_switch_fabric.sv) with NUM_PORT=10. Measure hotspot throughput (e.g., 9→1 traffic) and memory utilization. Confirm v2.0 strengths (e.g., 90% multicast savings). | Existing tb/; code_execution for Python analysis (e.g., simulate occupancy). | Week 1 | None. Risk: If baseline <1 Gbps hotspot, debug memory first. |
| 2 | **Gap Assessment**: Simulate hotspot with N=10 vs. N=32 (parametric gen). Check if existing shared pools overflow (voq_occupancy > D*0.9). If yes, buffers are crucial. | rtl/util/fabric_params.vh; Add monitors to qos_scheduler.sv. | Week 1 | Output: Report (e.g., "Buffers needed for N>10"). |
| 3 | **Repo Setup**: Create branch `enhancement-q1-hybrid`. Add dirs: rtl/enhancement/, verification/tla/. Define params: ADAPTIVE_BUFFER_ENABLE=1, ELASTIC_ENABLE=1. | Git; rtl/arbiter/. | Week 2 | Risk: Version conflicts—use git merge carefully. |
| 4 | **Literature Quick Review**: Read 3-5 papers (e.g., A²FQ 2024, REVERIE 2024) from v3's table. Note differentiations (e.g., your hardware vs. their software). | Zotero/Mendeley. | Week 2 | Prepares for novelty claims. |

**Milestone**: Baseline report + repo ready. If buffers overflow in sim, prioritize them.

#### Phase 1: Foundations – Dynamic Shared Buffers + Bounded WFQ (Months 1-4)
**Goal**: Implement v3 Phase 1 (buffers/WFQ) as ECS enabler. For N=10, add "lite" dynamic reallocation to avoid overflow in ECS hotspots.
**Why First?**: Resolves buffer ambiguity; makes ECS stable (as urgency in v2's ECS uses voq_occupancy). Skips full ML for now.

| Step | What to Do | Tools/Files | Timeline | Dependencies/Risks |
|------|------------|-------------|----------|---------------------|
| 1 | **Dynamic Buffer Pool (Lite Version)**: Extend linklist_dynamic_fifo.sv with adaptive reallocation (from v3's adaptive_buffer_pool_v3.sv). Add urgency-based pooling (occupancy + QoS). For N=10, set ELASTIC_POOL_SIZE=3. Test reallocation on hotspots. | rtl/memory/adaptive_buffer_pool.sv; Integrate with VOQ/XPQ (ingress_line_qos.sv). Use code_execution for Python prototype (numpy for occupancy sim). | Month 1 | Dep: Existing shared pools. Risk: Fragmentation—add defrag logic if >10% waste. Metric: 40-60% util improvement. |
| 2 | **Bounded WFQ**: Implement bounded_approximate_wfq_v3.sv (from v3). Add deviation tracking to existing WFQ (qos_scheduler.sv). Prove O(1) bounds (Theorem 1 in v3). For N=10, quantize weights (WEIGHT_QUANTUM=64). | rtl/arbiter/bounded_approximate_wfq.sv; sympy in code_execution for proof sim. | Month 2 | Dep: Step 1 (buffers feed occupancy). Risk: Loose bounds (>5%)—tune EPSILON_S=5. Metric: Deviation <5%. |
| 3 | **Integration & Test**: Hook buffers/WFQ into switch_fabric.sv. Add test (test_dynamic_buffers) to tb/. Sim hotspot: Assert >20% throughput gain vs. baseline. | generate blocks in switch_fabric.sv; tb/tb_switch_fabric.sv. | Month 3 | Dep: Steps 1-2. Risk: Regressions—run full regression. |
| 4 | **Scalability Check**: Sim N=32. If memory explodes, add priority reservations (from v3). | fabric_params.vh. | Month 4 | Dep: Step 3. Risk: For N=10, skip if stable. |

**Milestone**: Functional buffers + WFQ. Paper outline: "Dynamic Buffers with Bounded WFQ for Switch Fabrics" (ToN draft started). If ECS urgently needed, prototype a stub (fixed pool) here.

#### Phase 2: Core Innovation – ECS + Kalman Prediction (Months 5-10)
**Goal**: Implement v2's ECS (flagship) on Phase 1 foundations. Use dynamic buffers for voq_occupancy in urgency calc.
**Why Next?**: Now buffers prevent ECS overflows. For N=10, ECS gives 4-6x hotspot improvement.

| Step | What to Do | Tools/Files | Timeline | Dependencies/Risks |
|------|------------|-------------|----------|---------------------|
| 1 | **ECS Manager**: Implement elastic_crosspoint_manager_v2.sv (from v2 Part 3). Add allocator with urgency (predicted + current + QoS). Set MAX_ARBITERS_PER_VOQ=2 for N=10. | rtl/arbiter/elastic_crosspoint_manager.sv; Integrate with dest_finder_row_matching_qos.sv. | Months 5-6 | Dep: Phase 1 buffers (for occupancy). Risk: Allocation loops—add hysteresis. Metric: Pool free count >0 in hotspots. |
| 2 | **Multi-Path Integration**: Add multi-path TX/RX (from v2 3.5-3.6) to ingress/egress_line_qos.sv. Use reorder buffer (size=16) for order. | multi_path_transmitter.sv / receiver.sv. | Month 7 | Dep: Step 1. Risk: Out-of-order—test with last_cell signals. |
| 3 | **Kalman Prediction**: Implement kalman_queue_predictor_v2.sv (from v2 Part 4). Feed to ECS urgency. For N=10, PREDICTION_HORIZON=50. | rtl/arbiter/kalman_queue_predictor.sv; mpmath in code_execution for fixed-point tuning. | Month 8 | Dep: Step 2. Risk: Overflow—use Q16.16 saturation. Metric: MAE <50 words. |
| 4 | **Full ECS Test**: Add test_elastic_crosspoint (from v2 Part 7). Sim hotspot: Assert 4-6x throughput (1Gbps → 4.5-6.5Gbps). | tb/; Monitor elastic_pool_free_count. | Months 9-10 | Dep: Steps 1-3. Risk: Jitter >30µs—tune weights (URGENCY_PRED_WEIGHT=16). |

**Milestone**: ECS working with buffers/prediction. Update paper draft with ECS results (now "Elastic Scheduling with Dynamic Buffers").

#### Phase 3: Validation & Publication (Months 11-12+)
**Goal**: Rigorous proof + hardware. Submit to ToN.
**Why Last?**: Builds credibility for ECS.

| Step | What to Do | Tools/Files | Timeline | Dependencies/Risks |
|------|------------|-------------|----------|---------------------|
| 1 | **Formal Verification**: Extend verification (from v2 Part 1.4) with TLA+/SPIN for ECS deadlock-freedom (from v3 ID #20). Model N=10. | verification/tla_specs/; SPIN for model checking. | Month 11 | Dep: Phase 2. Risk: Complex models—start small (4 VOQs). |
| 2 | **FPGA Validation**: Deploy on VCU118 (from v2 Part 1.5). Measure metrics (e.g., 7.2Gbps hotspot, <8% overhead). | fpga/testbed/; Synthesis scripts. | Month 12 | Dep: Step 1. Risk: Timing failure—reduce Fmax to 200MHz. |
| 3 | **Experiments & Ablation**: Run v2's figures (e.g., throughput bars). Add real traces (Google/Facebook). | Python analysis via code_execution. | Month 12+ | Dep: Step 2. |
| 4 | **Paper Writing/Submission**: Follow v2 Part 8 structure (14 pages). Title: "Hierarchical Elastic Switch Fabric with Bounded Fairness". Submit to ToN. | IEEE template. | Month 13+ | Dep: All. Risk: Incremental claims—differentiate vs. REVERIE/Gearbox. |

**Milestone**: Submission. If accepted (85% prob per v2), celebrate! Revise based on reviews (3-6 months).

### Extensions for PhD (Months 13-36+)
- **Add v3 Phase 3**: ML-guided arbitration (ID #17) + programmable QoS (ID #18). Target JSAC.
- **Scalability**: Test N=128 with VOQ grouping (v3 ID #3).

### Risk Mitigation & Monitoring
- **Weekly Check**: Track metrics (e.g., throughput) in a table.
- **If Stuck on Buffers**: Fall back to v2's fixed pools for ECS prototype (2-3 weeks delay).
- **Resources**: Budget for FPGA time. Use web_search for papers if needed.
- **Monitoring**: Monthly advisor reviews. If N=10 works well, scale up mid-Phase 2.

This roadmap starts with foundations (resolving buffer ambiguity) and leads to ECS novelty. If you need code snippets, Gantt charts, or tool calls (e.g., code_execution for sim), let me know!




# Final Updated Research Roadmap for Enhanced Ethernet Switch Fabric v2.0

This is the **final, updated roadmap** synthesizing all details from our discussions, including the original v2 and v3 enhancement docs, your ambiguities (e.g., buffers vs. ECS priority, port scaling), and the new insights on approximate WFQ (e.g., hierarchical/Gearbox-inspired approximations, WF2Q for bounded fairness), adaptive WFQ (e.g., feedback-driven quanta adjustment, fuzzy/DRL variants), and Kalman filter ideas (e.g., neural-integrated Q-Net, attention-enhanced Ksurf+ for predictions). I've refined the hybrid structure to make it more robust:

- **Key Updates**:
  - **Approximate WFQ Integration**: In Phase 1, enhance bounded WFQ with hierarchical structures (inspired by Gearbox for O(1) complexity) and WF2Q for worst-case bounds, ensuring <5% deviation. This provides a stronger theoretical foundation for your existing deficit-tracking WFQ.
  - **Adaptive WFQ Integration**: Added as a sub-module in Phase 1 (feedback loop) and optional extension in Phase 2 (DRL/fuzzy for runtime tuning), tying into your microinterface for dynamic quanta/weight adjustments based on queue metrics.
  - **Kalman Filter Enhancements**: In Phase 2, evolve the predictor with Q-Net (neural-Kalman hybrid) or Ksurf+ (attention for bursty traffic), improving MAE by 20-30% for ECS urgency. Start with basic fixed-point, then add advanced variants for novelty.
  - **Overall Refinements**: Buffers remain first for ECS stability (resolving ambiguity); N=10 prototyping emphasized with scalability checks. Timeline extended slightly (14-20 months) for new features. Added optional ML paths for PhD extensions. Metrics updated with fairness/deviation targets.
  - **Novelty Emphasis**: Differentiate from cited works (e.g., vs. A²FQ: hardware focus; vs. REVERIE: predictive arbitration).

**Assumptions**: 1-2 person team; access to your v2.0 codebase; focus on Q1 publications (ToN/JSAC). Use code_execution tool for sims/proofs (e.g., sympy for WFQ bounds, mpmath for Kalman tuning)—but I've noted where you'd call it in practice.

**High-Level Timeline**: 14-20 months to first publication; expandable to 36-48 for PhD (3 papers).

## Phase 0: Preparation (Weeks 1-2)
**Goal**: Baseline and setup, incorporating new WFQ/Kalman ideas.
**Updates**: Add lit review for adaptive/approximate WFQ citations; sim basic Kalman variants.

| Step | What to Do | Tools/Files | Timeline | Dependencies/Risks/Metrics |
|------|------------|-------------|----------|----------------------------|
| 1 | **Baseline + New Sims**: Run v2.0 tests; sim approximate WFQ (e.g., WF2Q bounds) and basic Kalman (Q16.16) on synthetic queues. Measure baseline fairness deviation (unbounded → target <5%). | tb/tb_switch_fabric.sv; code_execution (sympy for WFQ proofs, numpy for Kalman MAE sim). | Week 1 | None. Risk: High deviation—prioritize bounded WFQ. Metric: Baseline hotspot 1Gbps. |
| 2 | **Gap Assessment**: Sim N=10/32 hotspots; check if adaptive WFQ feedback reduces starvation (e.g., Jain Index >0.90). Identify Kalman noise params (Q/R) for bursts. | qos_scheduler.sv; code_execution (statsmodels for fairness calc). | Week 1 | Output: Report on "Adaptive WFQ needed for bursts?" |
| 3 | **Repo/Lit Setup**: Branch `enhancement-q1-updated`; add dirs for adaptive_wfq/ and kalman_enh/. Review 5 papers (e.g., Gearbox NSDI'22, Q-Net for Kalman). | Git; Zotero (add citations like WF2Q). | Week 2 | Risk: Overlap with priors—note hardware diffs. |
| 4 | **Param Definitions**: Add ADAPTIVE_WFQ_ENABLE=1, KALMAN_ADVANCED=0 (basic first). | fabric_params.vh. | Week 2 | Preps for phases. |

**Milestone**: Report + repo ready. Proceed if fairness >0.85 baseline.

## Phase 1: Foundations – Dynamic Buffers + Enhanced Bounded/Adaptive WFQ (Months 1-5)
**Goal**: Build robust base with updated WFQ (approximate + adaptive) for ECS. Approximate WFQ adds hierarchical O(1) (Gearbox-style) + WF2Q bounds; adaptive adds feedback (AWFQ-inspired, fuzzy optional).
**Updates**: Extended timeline for adaptive integration; proofs for deviation ≤ L_max / w_i + Q*N.

| Step | What to Do | Tools/Files | Timeline | Dependencies/Risks/Metrics |
|------|------------|-------------|----------|----------------------------|
| 1 | **Dynamic Buffer Pool (Enhanced)**: Extend with micro-burst detection + urgency (from v3). Add QoS-aware reservations for adaptive WFQ. Test realloc on bursts. | adaptive_buffer_pool_v3.sv; code_execution (pandas for occupancy traces). | Months 1-2 | Dep: Phase 0. Risk: Fragmentation—add reclaim logic. Metric: Util 60-70% (vs. 40-50%). |
| 2 | **Bounded Approximate WFQ**: Implement bounded_approximate_wfq_v3.sv with hierarchical (Gearbox) for O(1), WF2Q for worst-case delay bounds. Quantize weights; track deviation. Prove Theorem 1 (SD ≤ 535B for params). | bounded_approximate_wfq.sv; code_execution (sympy for proofs). | Month 3 | Dep: Step 1. Risk: Loose bounds—tune Q=64. Metric: Deviation <5%.  |
| 3 | **Adaptive WFQ Extension**: Add feedback controller (AWFQ-style) to adjust quanta/weights via occupancy/deviation. Optional: Fuzzy logic for priority boosts. Integrate with microinterface. | adaptive_qos_controller_v2.sv (from v2); code_execution (control lib for loop sim). | Month 4 | Dep: Step 2. Risk: Instability—add dampening. Metric: Jain Index ≥0.93.  |
| 4 | **Integration & Test**: Hook to switch_fabric.sv. Add tests for adaptive fairness under bursts. Sim N=10/32; assert 10-20% throughput gain. | tb/; generate blocks. | Month 5 | Dep: Steps 1-3. Risk: Regressions—full coverage. Metric: p99 Latency -20%. |

**Milestone**: Foundations functional. Paper draft: "Adaptive Approximate WFQ with Dynamic Buffers for Switch Fabrics" (ToN outline started).

## Phase 2: Core Innovation – ECS + Advanced Kalman Prediction + Adaptive Ties (Months 6-12)
**Goal**: Flagship ECS on foundations; enhance Kalman with neural/attention ideas; tie adaptive WFQ for predictive weights.
**Updates**: Kalman now includes Q-Net/Ksurf+ for 20-30% better accuracy; adaptive WFQ feeds ECS urgency.

| Step | What to Do | Tools/Files | Timeline | Dependencies/Risks/Metrics |
|------|------------|-------------|----------|----------------------------|
| 1 | **ECS Manager (Updated)**: Implement with urgency integrating adaptive WFQ deviations. Set params for N=10; add multi-arbiter borrowing. | elastic_crosspoint_manager_v2.sv; code_execution (numpy for urgency sim). | Months 6-7 | Dep: Phase 1. Risk: Monopolization—limit MAX_ARBITERS=2. Metric: Pool usage balanced. |
| 2 | **Multi-Path + Integration**: Add TX/RX; modify dest_finder for elastic masks. Tie to adaptive WFQ for priority boosts. | multi_path_transmitter.sv; ingress/egress_line_qos.sv. | Month 8 | Dep: Step 1. Risk: Reorder—buffer size=16. Metric: Jitter <30µs. |
| 3 | **Advanced Kalman Predictor**: Start basic (kalman_queue_predictor_v2.sv); enhance with Q-Net (neural) or Ksurf+ (attention) for bursts. Feed to ECS/Adaptive WFQ. Tune Q/R for MAE<30. | kalman_queue_predictor_v2.sv; code_execution (torch for neural sim, then export fixed-point). | Months 9-10 | Dep: Step 2. Risk: Overhead—Q16.16 saturation. Metric: MAE <30 words (stretch).   |
| 4 | **Full Test + Adaptive Synergy**: Add hotspot tests; sim adaptive WFQ adjusting ECS quanta. Assert 4-8x throughput. Scale to N=32. | tb/; Monitor deviation/pool. | Months 11-12 | Dep: Steps 1-3. Risk: Burst inaccuracy—tune attention. Metric: Hotspot 6.5Gbps. |

**Milestone**: ECS + enhancements working. Update draft with Kalman/Adaptive results.

## Phase 3: Validation & Publication (Months 13-14+)
**Goal**: Prove + submit; incorporate all for rigor.
**Updates**: Add WFQ proofs; Kalman accuracy ablation.

| Step | What to Do | Tools/Files | Timeline | Dependencies/Risks/Metrics |
|------|------------|-------------|----------|----------------------------|
| 1 | **Formal Verification**: TLA+/SPIN for ECS + adaptive WFQ deadlock/freedom. Model adaptive deviations. | tla_specs/; code_execution (qutip optional for state sim). | Month 13 | Dep: Phase 2. Risk: Complexity—small models. Metric: Proofs passed. |
| 2 | **FPGA + Experiments**: Deploy VCU118; run ablations (e.g., Kalman variants). Add traces; chart fairness (use render_chart if presenting). | testbed/; code_execution (matplotlib for CDFs). | Month 14 | Dep: Step 1. Risk: Timing—optimize DSP for Kalman. Metric: Overhead <8%. |
| 3 | **Full Evaluation**: Benchmarks + new (e.g., adaptive vs. static WFQ). Differentiate (e.g., vs. Gearbox: hardware). | Python analysis. | Month 14+ | Dep: Step 2. Metric: Latency CDF <95µs p99. |
| 4 | **Paper/Submission**: 14-16 pages; Title: "Predictive Elastic Fabric with Adaptive Approximate WFQ". Submit ToN. | IEEE template. | Month 15+ | Dep: All. Risk: Rejection—backup JSAC. Prob: 85%. |

**Milestone**: Submission. Revisions: 3-6 months.

## PhD Extensions (Months 15-48)
- **Paper 2 (JSAC)**: Add DRL-adaptive WFQ + VOQ grouping (v3 Phase 2).
- **Paper 3 (TII)**: Programmable QoS + ML-Kalman (v3 Phase 3).
- **Thesis**: "Adaptive Fair Architectures for Scalable Switch Fabrics".

## Overall Metrics & Risks
| Metric | Target | Validates |
|--------|--------|-----------|
| Hotspot Throughput | >6x baseline | ECS + Kalman |
| Fairness Deviation | <5% | Bounded/Adaptive WFQ |
| Prediction MAE | <30 words | Advanced Kalman |
| Overhead | <8% | All |

**Risks**: WFQ instability—simulate first; Kalman complexity—fallback to basic. Monitor monthly.

This roadmap is now complete and actionable—execute Phase 0 first! If needed, I can draft code (e.g., adaptive WFQ snippet) or sims.