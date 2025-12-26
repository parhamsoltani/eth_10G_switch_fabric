# QoS Switch Fabric Test Plan

## Test Environment

| Parameter | Value |
|-----------|-------|
| **Simulator** | QuestaSim/ModelSim |
| **Language** | SystemVerilog |
| **Duration** | ~5 minutes per test |
| **Coverage Goal** | 95% functional, 85% code |

---

## Test Cases

### Test 1: Basic Connectivity

**Objective:** Verify all 10×10 port paths work correctly

**Test Procedure:**
- Send one packet from each ingress port to each egress port (100 total packets)
- Use minimum Ethernet frame size (64 bytes)
- Use best-effort QoS priority (level 2)
- Verify each packet arrives within 1 microsecond

**Success Criteria:**
- ✅ All 100 packets received
- ✅ Zero packet loss
- ✅ Latency < 1 µs per packet

---

### Test 2: QoS Priority Enforcement

**Objective:** Verify that priority scheduling works correctly

**Test Setup:**
- Route: Port 0 → Port 1
- Traffic mix: 1000 packets at priority 0 (scavenger) + 1000 packets at priority 7 (control)
- Send both streams simultaneously

**Test Procedure:**
- Launch low priority stream (priority 0, 1500-byte packets)
- Launch high priority stream (priority 7, 1500-byte packets) at the same time
- Measure completion times for both streams
- Compare average latencies

**Success Criteria:**
- ✅ Priority 7 packets complete transmission first
- ✅ Priority 7 average latency < Priority 0 average latency
- ✅ Bandwidth ratio P7:P0 approximately 128:1

---

### Test 3: Congestion Handling

**Objective:** Stress test the switch under severe oversubscription

**Test Setup:**
- All 10 ingress ports → Port 0 (single egress)
- Creates 10:1 oversubscription (100 Gbps input → 10 Gbps output)
- Each source sends at 10 Gbps line rate

**Test Procedure:**
- Send 10,000 packets from each of the 10 ingress ports
- All packets destined for port 0
- Use random QoS levels (0-7)
- Use random packet sizes (64-1500 bytes)

**Success Criteria:**
- ✅ No deadlock occurs
- ✅ Packet loss < 0.01%
- ✅ High priority traffic maintains throughput despite congestion

---

### Test 4: VLAN PCP Classification

**Objective:** Verify correct parsing and classification of VLAN priority tags

**Test Procedure:**
- Send Ethernet frames with VLAN 802.1Q tags
- Test all 8 PCP (Priority Code Point) values (0-7)
- Verify internal QoS tag matches the PCP value
- Test frames without VLAN tags (should default to priority 1)

**Frame Structure:**
- TPID: 0x8100 (VLAN identifier)
- PCP: 3-bit priority field
- DEI: Drop eligible indicator
- VID: 12-bit VLAN ID

**Success Criteria:**
- ✅ All 8 PCP values correctly mapped to internal QoS
- ✅ Non-VLAN frames default to priority 1

---

### Test 5: IP DSCP Classification

**Objective:** Verify correct parsing of IP Differentiated Services Code Point

**Test Procedure:**
- Send IPv4 packets with all 64 possible DSCP values (0-63)
- Verify internal priority mapping: Priority = DSCP[7:5] (upper 3 bits)
- Test with various source/destination IP addresses

**Success Criteria:**
- ✅ All 64 DSCP values correctly mapped
- ✅ Priority extracted from upper 3 bits of DSCP field

---

### Test 6: Head-of-Line Blocking Prevention

**Objective:** Verify Virtual Output Queuing (VOQ) eliminates HOL blocking

**Test Setup:**
- Port 0 has traffic to both Port 1 and Port 2
- Port 1 egress is blocked (simulating congestion)
- Port 2 egress remains available

**Test Procedure:**
1. Force Port 1 TX ready signal to 0 (blocked)
2. Send 100 packets from Port 0 to Port 1 (will queue in VOQ)
3. Send 100 packets from Port 0 to Port 2 (should flow normally)
4. Verify Port 2 traffic completes without delay
5. Unblock Port 1 and verify queued traffic drains

**Success Criteria:**
- ✅ Port 2 traffic unaffected by Port 1 blockage
- ✅ Port 1 traffic eventually completes after unblocking

---

### Test 7: Jumbo Frame Handling

**Objective:** Verify support for large Ethernet frames (up to 9KB)

**Test Procedure:**
- Send 100 jumbo frames (9000 bytes each)
- Use random source/destination ports
- Use random QoS priorities
- Verify correct cell segmentation and reassembly

**Success Criteria:**
- ✅ All jumbo frames correctly segmented into cells
- ✅ Correct reassembly at egress ports
- ✅ No cell order corruption

---

### Test 8: Back-Pressure Handling

**Objective:** Verify flow control mechanisms work correctly

**Test Procedure:**
- Randomly pause TX ready signals on all output ports
- 20% pause probability
- Pause duration: 1-10 clock cycles (random)
- Send continuous random traffic for 100 microseconds
- Monitor packet delivery and VOQ occupancy

**Success Criteria:**
- ✅ Zero packet loss despite random pauses
- ✅ VOQs properly buffer packets during pauses
- ✅ Traffic resumes immediately when ready signal asserted

---

### Test 9: Weighted Fair Queuing

**Objective:** Verify bandwidth is distributed according to priority weights

**Test Setup:**
- Port 0 → Port 1
- Equal traffic volumes at priority 7 and priority 0
- Each stream sends 1000 packets of 1500 bytes

**Test Procedure:**
- Launch both streams simultaneously
- Measure actual throughput for each priority level
- Calculate bandwidth ratio

**Success Criteria:**
- ✅ Bandwidth ratio P7:P0 between 100:1 and 150:1 (target 128:1)

---

### Test 10: Reset and Initialization

**Objective:** Verify clean startup and reset behavior

**Test Procedure:**
1. Assert reset for 100 nanoseconds
2. Release reset
3. Check all state machines are idle
4. Verify all VOQs are empty
5. Send a test packet to confirm normal operation

**Success Criteria:**
- ✅ All FIFOs empty after reset
- ✅ All schedulers in idle state
- ✅ First packet after reset processed correctly

---

## Coverage Targets

| Coverage Type | Target |
|--------------|--------|
| Code Coverage | 85% |
| Functional Coverage | 95% |
| Assertion Coverage | 100% (critical paths) |
| QoS Levels | 100% (all 8 priorities) |
| Port Combinations | 100% (10×10 matrix) |

---

## Automated Regression

**Full Test Suite:**
```bash
./run_tests.sh --suite=full --coverage
```

**Quick Smoke Test (< 1 minute):**
```bash
./run_tests.sh --suite=smoke
```

**Nightly Stress Test (4 hours):**
```bash
./run_tests.sh --suite=stress --duration=4h
```

---

## Known Issues to Verify

| Issue | Test Approach |
|-------|---------------|
| ⚠️ Hold timing violations on input pads | Test with varied input delays |
| ⚠️ XDC constraint warnings (Tcl syntax) | Verify constraints applied correctly |
| ✅ Setup timing: WNS = +0.065 ns | Already passing at 156.25 MHz |