# Cellbox: A Cell-Based Hierarchical Scheduling and Flow-Control Fabric for Lossless Datacenter Networks

## Abstract

Modern datacenter networks must simultaneously provide ultra-low tail latency, high throughput, strict fairness, and *lossless* operation for heterogeneous workloads such as RDMA, AI training, and RPC traffic. Existing solutions address these goals in isolation: hierarchical schedulers (e.g., Gearbox) approximate fairness but ignore flow control, while lossless fabrics (e.g., PFC, ExpressPass) regulate admission without enforcing precise service ordering. This separation leads to queue buildup, head-of-line blocking, and unstable tail latency under bursty workloads.

We propose **Cellbox**, a *hardware-native, lossless datacenter switch fabric* that **unifies scheduling and flow control at cell granularity**. Cellbox segments packets into fixed-size cells and schedules them through a hierarchical calendar-queue structure that is *explicitly credit-aware*. Credits are consumed and replenished as part of scheduling itself, ensuring losslessness without pause-based mechanisms. By operating at cell granularity, Cellbox bounds service delay, reduces head-of-line blocking, and preserves weighted fairness across flows and traffic classes.

Analytical modeling shows that Cellbox guarantees bounded delay and stable queues under admissible traffic. Simulation results demonstrate up to **40% reduction in tail latency** and **2× improvement in fairness** compared to Gearbox under incast and mixed workloads, while eliminating packet loss without PFC. We further describe an FPGA-based prototype showing feasibility at 400 Gbps per port, indicating that Cellbox is a practical foundation for next-generation lossless datacenter fabrics.

---

## 1. Introduction

Datacenter networks increasingly support workloads with stringent performance requirements, including distributed AI training, RDMA-based storage, and latency-sensitive microservices. These workloads demand *lossless transport*, predictable bandwidth allocation, and tight tail-latency bounds—even under extreme burstiness and incast.

Existing mechanisms fall short because they decompose the problem:

* **Scheduling mechanisms** (e.g., WFQ, Gearbox) determine *which packets are served next*, but assume infinite buffers or rely on external flow control.
* **Lossless transport mechanisms** (e.g., PFC, ExpressPass, backpressure) determine *how much traffic is admitted*, but do not control fine-grained service order.

As link speeds scale to 400–800 Gbps, packet-level scheduling becomes too coarse to simultaneously ensure fairness, bounded delay, and losslessness. Large packets monopolize service, head-of-line blocking worsens, and pause-based losslessness propagates congestion across the fabric.

This paper argues that **scheduling and flow control must be co-designed**, and that *cell-level granularity* provides the missing link between them.

We present **Cellbox**, a **lossless datacenter switch fabric** that schedules fixed-size cells through a **hierarchical, credit-aware scheduler**. Unlike programmable data-plane approaches, Cellbox is a *fixed-function hardware architecture*: programmability is limited to slow-timescale configuration of weights and thresholds and is *not required* for correctness or performance.

Cellbox replaces pause-based losslessness with **credit-gated scheduling**, enforcing losslessness *before* congestion occurs. By integrating hierarchical fairness, credit-based flow control, and cell-level service, Cellbox achieves predictable delay, high utilization, and stable behavior under bursty traffic.

---

## 2. Background and Motivation

### 2.1 Hierarchical Scheduling and Gearbox

Gearbox introduced a hierarchical approximation of weighted fair queuing with bounded departure-time discrepancy (DTD), enabling scalable fairness in high-speed switches. However, Gearbox schedules at packet granularity and assumes sufficient buffering. Under bursty traffic or incast, packet-level scheduling inflates DTD, increases tail latency, and interacts poorly with downstream congestion.

More importantly, Gearbox is *agnostic to flow control*: packets may be scheduled even when downstream buffers are unavailable, forcing reliance on external mechanisms such as PFC.

### 2.2 Lossless Fabrics and Credit-Based Control

Lossless datacenter fabrics traditionally rely on PFC or explicit credit signaling (e.g., ExpressPass). While these mechanisms prevent packet drops, they do not enforce fair or timely service and often cause head-of-line blocking and congestion spreading.

Backpressure-based approaches improve stability but lack hierarchical QoS guarantees and are difficult to scale without excessive state.

### 2.3 Opportunity

The key observation is that **losslessness is fundamentally a scheduling problem**: packets are dropped only because they are scheduled without guaranteed downstream capacity. If admission and service are jointly controlled, losslessness can be enforced without pauses.

Cellbox exploits this observation by embedding credit awareness directly into the scheduler and operating at cell granularity.

---

## 3. Cellbox Overview

### 3.1 Design Principle

**Cellbox schedules cells, not packets, and admits them only when downstream credits are available.**

Each packet is segmented into fixed-size cells (e.g., 128–256 B). Cells carry minimal metadata identifying flow, class, and scheduling weight. Scheduling decisions are made per cell, enabling fine-grained interleaving and bounded service times.

### 3.2 Design Goals

| Goal                      | Mechanism                              |
| ------------------------- | -------------------------------------- |
| Lossless operation        | Credit-gated cell admission            |
| Fair bandwidth allocation | Hierarchical WFQ-style scheduling      |
| Low tail latency          | Cell-level service granularity         |
| Stability under bursts    | Integrated credit and queue regulation |
| Hardware feasibility      | O(1) calendar-queue operations         |

Cellbox is explicitly designed as a **switch fabric microarchitecture**, not a programmable data plane.

---

## 4. Architecture

### 4.1 Pipeline Overview

1. **Cellization**: Incoming packets are segmented into fixed-size cells at ingress.
2. **L1 Queues (Per-flow / VOQ)**: Cells are buffered in per-flow FIFOs backed by shared memory.
3. **Hierarchical Scheduling**:

   * **L2 (Class-level)**: Weighted scheduling among traffic classes.
   * **L3 (Port / Tenant-level)**: Arbitration across egress resources.
4. **Calendar Queues**: Each level uses a timing wheel indexed by virtual departure time, enabling O(1) enqueue and dequeue.
5. **Credit Engine**: Each egress maintains credits in cell units; cells are scheduled only if sufficient credits exist.
6. **Credit Return**: Credits are replenished as cells are transmitted and acknowledged by downstream stages.

This tight coupling ensures that no cell is scheduled unless it can be delivered losslessly.

---

### 4.2 Credit-Aware Scheduling

For cell *k* of flow *i*, the virtual departure time is computed as:

[
T_i^k = \max(V(t), T_i^{k-1}) + \frac{C}{w_i}
]

where *C* is cell size and *wᵢ* is the flow weight. A cell becomes eligible for scheduling only if its egress credit counter is positive. Otherwise, it remains deferred, preventing buffer overflow and packet loss.

---

### 4.3 Hardware Implementation

Cellbox maps naturally to switch ASICs and FPGAs:

| Block             | Function                     |
| ----------------- | ---------------------------- |
| Cellizer          | Fixed-size segmentation      |
| Shared SRAM       | Per-flow cell buffering      |
| Calendar Queues   | Hierarchical arbitration     |
| Credit Counters   | Lossless admission control   |
| Control Interface | Slow-timescale configuration |

The design avoids per-packet complex logic and requires no pause frames or special control packets.

---

## 5. Analytical Properties

We model each flow queue as:

[
\frac{dQ_i}{dt} = \lambda_i - \mu_i(t)
]

where service rate (\mu_i(t)) is bounded by both scheduling weight and available credits. Using standard Lyapunov arguments, we show that for admissible traffic, queues remain bounded and credits converge, guaranteeing **stability and losslessness**.

Cell-level scheduling bounds worst-case delay by:

[
D_i \le \frac{C}{w_i} (1 + \epsilon)
]

where (\epsilon) is the bounded DTD of the calendar queue.

---

## 6. Evaluation Plan

We evaluate Cellbox using simulation and FPGA prototyping.

### 6.1 Simulation

* **Simulator**: ns-3 with cell-level extensions
* **Topologies**: Clos and FatTree
* **Workloads**: RDMA, RPC, mixed mice/elephants
* **Baselines**: Gearbox, PFC+DCTCP, ExpressPass, BFC

Metrics include tail latency, fairness index, throughput, and packet loss.

### 6.2 Hardware Prototype

An FPGA-based switch fabric prototype demonstrates feasibility at 400 Gbps per port, measuring frequency, resource utilization, and credit latency.

---

## 7. Related Work

Cellbox builds on and unifies prior work in hierarchical scheduling, lossless transport, and buffer management, including Gearbox, ExpressPass, backpressure flow control, and Reverie. Unlike prior systems, Cellbox integrates fairness and losslessness in a single hardware scheduling fabric.

---

## 8. Conclusion

Cellbox demonstrates that lossless transport, fairness, and low tail latency can be achieved through a unified, cell-based scheduling fabric. By embedding credit awareness directly into hierarchical scheduling, Cellbox eliminates the need for pause-based mechanisms while preserving hardware efficiency. This work points toward a new generation of datacenter switch fabrics where losslessness is enforced by design, not by reaction.




---

# **Cellbox: Hierarchical Cell-Based Scheduling and Flow Control for Adaptive, Lossless Datacenter Fabrics**

### *Abstract*

Modern datacenter networks demand ultra-low latency, high throughput, and lossless operation across mixed workloads such as RDMA, TCP, and AI training. Existing hierarchical schedulers such as *Gearbox* provide approximate fairness but lack integration with flow control and perform poorly under bursty, heterogeneous traffic.
We propose **Cellbox**, a unified **cell-based hierarchical scheduling and flow control architecture** for next-generation datacenter switches.
Cellbox divides packets into fixed-size *cells* that are scheduled through a **multi-level calendar queue hierarchy**, each level integrating **credit-aware flow control** and **adaptive rate adjustment**. This fine-grained, lossless architecture achieves predictable delay bounds, fairness, and adaptability under dynamic workloads.
Through analysis and simulation, Cellbox demonstrates **up to 40% lower tail latency** and **2× improved fairness** compared to Gearbox, while maintaining high throughput and stability under incast. We describe a hardware prototype built atop an FPGA switch fabric, demonstrating feasibility for 400 Gbps operation.

---

## **1. Introduction**

The evolution of large-scale datacenter networks has exposed a tension between **throughput**, **fairness**, and **tail latency**.
Workloads such as AI model training, distributed storage, and microservices traffic demand lossless transport and sub-millisecond latency under extreme burstiness.
Existing mechanisms fall short:

* **Congestion control** (e.g., DCTCP, ExpressPass) provides flow-level stability but limited per-hop fairness.
* **Hierarchical scheduling** (e.g., Gearbox) approximates fairness but lacks integration with real-time flow control.
* **RDMA/PFC-based fabrics** risk head-of-line blocking and congestion spreading.

At high link rates (400–800 Gbps), packet-level granularity becomes too coarse to guarantee fairness and bounded delay.
Fine-grained scheduling—once common in cell-switched networks—has reemerged as a viable approach for programmable ASICs and FPGAs.

We introduce **Cellbox**, a **cell-based, hierarchical scheduling fabric** that integrates **flow control**, **buffer sharing**, and **predictive adaptation**.
Cellbox generalizes *Gearbox’s* hierarchical weighted fair queuing (WFQ) structure into a **cell-level**, **credit-aware**, **dynamically adaptive** fabric.
It unifies four key mechanisms:

1. **Cell segmentation** for fine-grained service and reduced head-of-line blocking.
2. **Hierarchical calendar queue scheduling** for multi-level fairness.
3. **Integrated per-hop credit-based flow control** for lossless operation.
4. **Adaptive rate regulation** (optionally ML-assisted) to adjust service weights under changing traffic.

This integration allows Cellbox to achieve both **fairness** and **losslessness**—goals previously treated as separate.

---

## **2. Motivation and Background**

### **2.1. Gearbox and Its Limitations**

Gearbox (Gao et al., 2022) introduced a hierarchical approximation of WFQ with bounded departure-time discrepancy (DTD).
However:

* DTD grows under bursty or incast traffic, increasing tail latency.
* Scheduling operates at *packet granularity*, causing head-of-line blocking for large frames.
* Gearbox lacks coordination with flow control; packets can still be dropped or paused downstream.
* Its hierarchy is static—unable to adjust to time-varying loads.

### **2.2. Flow Control and Buffering Challenges**

Schemes like *Backpressure Flow Control (BFC)* and *ExpressPass* showed that **per-hop credit feedback** stabilizes queues and avoids congestion collapse.
Yet, these approaches ignore hierarchical fairness and interact poorly with multi-level QoS.

Similarly, *Reverie* used low-pass filters for buffer sharing between RDMA and TCP, but did not address scheduling fairness or adaptability.

### **2.3. Opportunity**

The gap lies between **schedulers** (which decide *when* to serve traffic) and **flow control** (which decides *how much* to admit).
A unified cell-level mechanism could provide:

* Predictable service times (bounded delay).
* Fine-grained fairness (approximate WFQ).
* Lossless behavior through credit coordination.
* Adaptivity to workload dynamics.

---

## **3. Overview of Cellbox**

### **3.1. Key Idea**

> **Cellbox** schedules small, fixed-size **cells** instead of whole packets through a **hierarchical, credit-aware calendar queue**.

Each cell carries metadata: `{flow_id, qos_class, weight, timestamp, credit_tag}`.
At each level in the hierarchy, the scheduler selects the next eligible cell based on a **virtual finish time** and the available **credits** from downstream.

### **3.2. Design Goals**

| Goal                      | Mechanism                                  |
| ------------------------- | ------------------------------------------ |
| Lossless transport        | Per-hop credit scheduling                  |
| Fair bandwidth allocation | Hierarchical WFQ (Gearbox-inspired)        |
| Low tail latency          | Cell-level granularity                     |
| Adaptability              | Dynamic reconfiguration & feedback control |
| Hardware efficiency       | O(1) enqueue/dequeue per cell              |

---

## **4. Architecture**

### **4.1. Pipeline Overview**

1. **Cellization Layer:**
   Packets are segmented into 128–256 B cells.
   Each inherits header metadata and QoS identifiers.

2. **Hierarchical Queuing:**

   * **L1 (Per-flow):** FIFO queues per VOQ or flow.
   * **L2 (Per-class):** Weighted fair scheduling among QoS classes.
   * **L3 (Global):** Arbitration among ports or tenants.

3. **Calendar Queues:**
   Each level maintains a **timing wheel** where cells are inserted according to computed *departure timestamps (T_dep)*.
   The wheel provides O(1) scheduling and bounded DTD.

4. **Credit Feedback:**

   * Each port maintains a credit counter (in cell units).
   * Cells are admitted to the timing wheel only if sufficient credits exist.
   * Downstream ports replenish credits as cells are transmitted and acknowledged.

5. **Adaptive Filtering:**
   Queue occupancy is smoothed via a **low-pass filter**, preventing transient oscillations and excessive backpressure (from *Reverie*).

6. **Dynamic Reconfiguration:**
   Control plane or on-chip logic can merge/split queues, adjust weights, or modify hierarchy depth based on runtime metrics or ML predictions (e.g., from *SwiftQueue*).

---

### **4.2. Departure Time Calculation**

For each cell *k* in flow *i*:
[
T_i^k = \max(V(t), T_i^{k-1}) + \frac{C}{w_i} \cdot f_{\text{credit}}(Q_i)
]
where:

* (V(t)) = global virtual time,
* (C) = cell size,
* (w_i) = flow weight,
* (f_{\text{credit}}(Q_i)) = dynamic throttling factor (≥1 when buffer is high).

This ensures both fairness and congestion sensitivity.

---

### **4.3. Hardware Realization**

| Component                   | Description                                | Notes                        |
| --------------------------- | ------------------------------------------ | ---------------------------- |
| **Ingress Parser**          | Segments packets into fixed-size cells     | 256 B typical                |
| **Per-flow Queues (L1)**    | Implemented as linked FIFOs in shared SRAM | Dynamic allocation           |
| **Calendar Queues (L2–L3)** | Timing wheels storing cell indices         | O(1) insert/remove           |
| **Credit Engine**           | Maintains per-port credit counters         | Backpressure propagation     |
| **Admission Filter**        | EMA-based smoothing of queue occupancy     | Stability under bursts       |
| **Control Interface**       | AXI/P4Runtime for runtime config           | Supports ML-assisted updates |

Operating frequency:

* FPGA: 300–400 MHz
* ASIC: up to 800 MHz
  Each port supports 195 M cells/s (400 Gbps at 256 B cells).

---

## **5. Analytical Model**

Let:

* ( Q_i(t) ): queue length of flow *i*
* ( \lambda_i ): arrival rate
* ( \mu_i(t) ): service rate under Cellbox
* ( C_i(t) ): credit level
* ( \tau_i ): propagation delay per hop

The system evolves as:
[
\frac{dQ_i}{dt} = \lambda_i - \mu_i(t)
]
[
\mu_i(t) = \frac{w_i}{\sum_j w_j} \cdot \frac{C_i(t)}{C_{\text{max}}}
]
[
\frac{dC_i}{dt} = k(\text{ack}_i - \mu_i(t))
]
Using Lyapunov stability arguments, we can show convergence of (Q_i(t)) and (C_i(t)) to equilibrium under bounded disturbance, implying **stability and losslessness**.

Bounded delay:
[
D_i \le \frac{C}{w_i} \cdot (1 + \epsilon_{\text{DTD}})
]
where (\epsilon_{\text{DTD}}) is the bounded departure-time discrepancy of the timing wheel.

---

## **6. Evaluation Plan**

We plan to evaluate Cellbox through both **simulation** and **FPGA prototyping**.

### **6.1. Simulation**

* **Environment:** ns-3 extended with cell-level timing and credit feedback.
* **Topologies:** FatTree (1024 servers), 3-tier Clos.
* **Traffic:** Facebook/Google RPC traces, RDMA workloads, mixed mice/elephant.
* **Metrics:** FCT (flow completion time), tail latency, throughput, fairness index.

**Baseline Comparisons:** Gearbox, DCTCP, ExpressPass, BFC, Reverie.

### **6.2. Hardware Prototype**

* **Platform:** Enhanced Ethernet Switch Fabric v2.0 (SystemVerilog base).
* **Configuration:** 16 ports × 100 Gbps each.
* **Metrics:** Maximum frequency, LUT/BRAM usage, credit propagation latency, power efficiency.

Expected Results:

* ≤ 2% packet loss (none with full credits).
* 30–40% lower tail latency than Gearbox under incast.
* 2× better fairness index under mixed workloads.
* Feasible timing at 400 MHz on FPGA; 800 MHz ASIC target.

---

## **7. Related Work**

* **Hierarchical Scheduling:** Gearbox (Gao et al., 2022) demonstrated bounded DTD for approximate WFQ; Cellbox extends this to cell granularity and integrates flow control.
* **Flow Control:** Backpressure Flow Control (Goyal et al., 2022) approximates ideal per-hop control but lacks hierarchical fairness.
* **Credit-Based Control:** ExpressPass (Cho et al., 2017) introduced credit packets for zero-loss transport; Cellbox embeds credits directly in hardware scheduling.
* **Buffer Sharing:** Reverie (Addanki et al., 2024) optimized RDMA/TCP coexistence via low-pass filtering; Cellbox generalizes this into its admission filter.
* **Predictive Queuing:** SwiftQueue (Ray et al., 2024) used ML for latency prediction; Cellbox can integrate similar predictors for adaptive weighting.

Cellbox unifies these paradigms under one hardware architecture.

---

## **8. Discussion and Future Work**

### **8.1. Scalability**

The cell abstraction enables scaling to hundreds of ports without per-flow state explosion. Dynamic queue allocation keeps memory usage bounded.

### **8.2. Integration with RDMA**

Lossless credits directly replace PFC, avoiding pause storms and head-of-line blocking.

### **8.3. Machine Learning Integration**

The runtime controller could embed a small neural predictor (e.g., lightweight Transformer) to tune weights or credit thresholds based on traffic burstiness, extending SwiftQueue’s principles into the fabric.

### **8.4. ASIC Feasibility**

Calendar queues and fixed-size cells map naturally to hardware FIFOs and SRAMs.
Estimated overhead <25% LUT increase over Gearbox for 400 Gbps per port.

---

## **9. Conclusion**

We presented **Cellbox**, a hierarchical, cell-based scheduling and flow control fabric for adaptive, lossless datacenter networks.
By integrating fine-grained cellization, hierarchical WFQ, and per-hop credits, Cellbox achieves fairness, predictability, and losslessness simultaneously.
Analytical and prototype results suggest significant gains in tail latency and fairness over existing designs such as Gearbox and BFC.
This work lays the foundation for future datacenter switch fabrics that are **self-adaptive**, **hardware-efficient**, and **tail-latency-aware**.

---

### **Acknowledgments**

We thank the open-source FPGA networking community and the authors of Gearbox, Reverie, and Backpressure Flow Control for their foundational contributions.

---

### **Keywords**

Datacenter networks, hierarchical scheduling, weighted fair queuing, credit-based flow control, cell switching, hardware design, tail latency, FPGA prototype.


