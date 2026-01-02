#!/usr/bin/env python3
"""
QoS Switch Fabric - Test Result Collector and Analyzer
Parses simulation logs and generates CSV reports for thesis figures

Usage: python collect_results.py <log_dir> <results_dir> <timestamp>
"""

import os
import re
import sys
import csv
import json
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional, Tuple
from collections import defaultdict

@dataclass
class LatencyResult:
    """Latency measurement for a single QoS level"""
    qos_level: int
    priority_name: str
    packet_count: int
    avg_latency_ns: float
    min_latency_ns: float
    max_latency_ns: float
    std_dev_ns: float = 0.0

@dataclass 
class TestResult:
    """Complete test result"""
    test_name: str
    status: str
    timestamp: str
    duration_sec: float = 0.0
    packets_sent: int = 0
    packets_received: int = 0
    packet_loss_pct: float = 0.0
    latency_results: List[LatencyResult] = field(default_factory=list)
    throughput_gbps: float = 0.0
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)


class LogParser:
    """Parse QuestaSim/ModelSim simulation logs"""
    
    PRIORITY_NAMES = {
        0: 'BACKGROUND',
        1: 'BEST_EFFORT', 
        2: 'STANDARD',
        3: 'EXCELLENT',
        4: 'CRITICAL',
        5: 'VIDEO',
        6: 'VOICE',
        7: 'NETWORK_CONTROL'
    }
    
    # Regex patterns
    PATTERNS = {
        'packets_sent': [
            r'Packets?\s*Sent:?\s*(\d+)',
            r'Total\s*Sent:?\s*(\d+)',
            r'packets_sent\s*=\s*(\d+)',
        ],
        'packets_recv': [
            r'Packets?\s*Received:?\s*(\d+)',
            r'Total\s*Received:?\s*(\d+)',
            r'packets_recv\s*=\s*(\d+)',
        ],
        'latency': [
            # Format: "Priority N: X pkts, avg=Y.Yns, min=Z.Zns, max=W.Wns"
            r'Priority\s*(\d+)[^:]*:\s*(\d+)\s*pkts?,\s*avg\s*=\s*([\d.]+)\s*ns,\s*min\s*=\s*([\d.]+)\s*ns,\s*max\s*=\s*([\d.]+)\s*ns',
            # Format: "QoS N: avg=Y.Y ns"
            r'QoS\s*(\d+)[^:]*:\s*avg\s*=\s*([\d.]+)',
            # Format from qos_latency_tracker
            r'Priority\s+(\d+):\s+(\d+)\s+pkts,\s+avg=([\d.]+)ns,\s+min=([\d.]+)ns,\s+max=([\d.]+)ns',
        ],
        'test_passed': [
            r'ALL\s+TESTS?\s+PASSED',
            r'\bTEST\s+PASSED\b',
            r'\bPASSED\b(?!.*FAILED)',
        ],
        'test_failed': [
            r'\bFAILED\b',
            r'\bERROR\b',
            r'\bTIMEOUT\b',
        ],
    }
    
    def __init__(self, log_path: str):
        self.log_path = Path(log_path)
        self.content = ""
        
    def parse(self) -> TestResult:
        """Parse log file and extract test results"""
        if not self.log_path.exists():
            return TestResult(
                test_name=self.log_path.stem,
                status="ERROR",
                timestamp=datetime.now().isoformat(),
                errors=[f"Log file not found: {self.log_path}"]
            )
        
        with open(self.log_path, 'r', encoding='utf-8', errors='ignore') as f:
            self.content = f.read()
        
        # Extract test name from filename
        test_name = self._extract_test_name()
        
        result = TestResult(
            test_name=test_name,
            status=self._determine_status(),
            timestamp=datetime.now().isoformat()
        )
        
        # Extract metrics
        result.packets_sent = self._extract_first_match('packets_sent')
        result.packets_received = self._extract_first_match('packets_recv')
        
        if result.packets_sent > 0:
            result.packet_loss_pct = 100.0 * (result.packets_sent - result.packets_received) / result.packets_sent
        
        result.latency_results = self._extract_latency_results()
        result.errors = self._extract_messages(r'\bERROR\b')
        result.warnings = self._extract_messages(r'\bWARN')
        
        return result
    
    def _extract_test_name(self) -> str:
        """Extract test name from filename"""
        stem = self.log_path.stem
        # Remove timestamp suffix if present
        parts = stem.split('_')
        # Find where the timestamp starts (usually after tb_...)
        name_parts = []
        for p in parts:
            if p.isdigit() and len(p) >= 6:  # Looks like timestamp
                break
            name_parts.append(p)
        return '_'.join(name_parts) if name_parts else stem
    
    def _determine_status(self) -> str:
        """Determine overall test status"""
        # Check for explicit failure first
        for pattern in self.PATTERNS['test_failed']:
            if re.search(pattern, self.content, re.IGNORECASE):
                # But not if "0 errors" or similar
                if re.search(r'\b0\s+errors?\b', self.content, re.IGNORECASE):
                    continue
                return "FAILED"
        
        # Check for explicit pass
        for pattern in self.PATTERNS['test_passed']:
            if re.search(pattern, self.content, re.IGNORECASE):
                return "PASSED"
        
        return "UNKNOWN"
    
    def _extract_first_match(self, pattern_name: str) -> int:
        """Extract first integer match from patterns"""
        for pattern in self.PATTERNS.get(pattern_name, []):
            match = re.search(pattern, self.content, re.IGNORECASE)
            if match:
                try:
                    return int(match.group(1))
                except (ValueError, IndexError):
                    continue
        return 0
    
    def _extract_latency_results(self) -> List[LatencyResult]:
        """Extract per-QoS-level latency statistics"""
        results = []
        seen_qos = set()
        
        for pattern in self.PATTERNS['latency']:
            for match in re.finditer(pattern, self.content, re.IGNORECASE):
                try:
                    groups = match.groups()
                    qos_level = int(groups[0])
                    
                    if qos_level in seen_qos:
                        continue
                    seen_qos.add(qos_level)
                    
                    if len(groups) >= 5:
                        # Full format with min/max
                        results.append(LatencyResult(
                            qos_level=qos_level,
                            priority_name=self.PRIORITY_NAMES.get(qos_level, f'QOS_{qos_level}'),
                            packet_count=int(groups[1]),
                            avg_latency_ns=float(groups[2]),
                            min_latency_ns=float(groups[3]),
                            max_latency_ns=float(groups[4])
                        ))
                    elif len(groups) >= 2:
                        # Simple format
                        results.append(LatencyResult(
                            qos_level=qos_level,
                            priority_name=self.PRIORITY_NAMES.get(qos_level, f'QOS_{qos_level}'),
                            packet_count=0,
                            avg_latency_ns=float(groups[1]),
                            min_latency_ns=0.0,
                            max_latency_ns=0.0
                        ))
                except (ValueError, IndexError) as e:
                    continue
        
        return sorted(results, key=lambda x: x.qos_level, reverse=True)
    
    def _extract_messages(self, pattern: str, limit: int = 10) -> List[str]:
        """Extract error/warning messages"""
        messages = []
        for line in self.content.split('\n'):
            if re.search(pattern, line, re.IGNORECASE):
                clean_line = line.strip()[:200]
                if clean_line and clean_line not in messages:
                    messages.append(clean_line)
                    if len(messages) >= limit:
                        break
        return messages


class ResultsCollector:
    """Collect and aggregate results from multiple test runs"""
    
    def __init__(self, results_dir: str):
        self.results_dir = Path(results_dir)
        self.results: List[TestResult] = []
        
    def collect_from_logs(self, log_dir: str, pattern: str = "tb_*.log"):
        """Collect results from all log files matching pattern"""
        log_path = Path(log_dir)
        if not log_path.exists():
            print(f"Warning: Log directory not found: {log_dir}")
            return
            
        log_files = list(log_path.glob(pattern))
        print(f"Found {len(log_files)} log files in {log_dir}")
        
        for log_file in sorted(log_files):
            print(f"  Parsing: {log_file.name}")
            parser = LogParser(str(log_file))
            result = parser.parse()
            self.results.append(result)
    
    def export_summary_csv(self, output_file: str):
        """Export test summary to CSV"""
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        
        with open(output_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow([
                'Test Name', 'Status', 'Packets Sent', 'Packets Received',
                'Packet Loss %', 'Throughput Gbps', 'Errors', 'Warnings', 'Timestamp'
            ])
            for r in self.results:
                writer.writerow([
                    r.test_name, 
                    r.status, 
                    r.packets_sent, 
                    r.packets_received,
                    f"{r.packet_loss_pct:.2f}", 
                    f"{r.throughput_gbps:.2f}",
                    len(r.errors),
                    len(r.warnings),
                    r.timestamp
                ])
        print(f"Summary exported to: {output_file}")
    
    def export_latency_csv(self, output_file: str):
        """Export latency data for all tests to CSV"""
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        
        with open(output_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow([
                'Test Name', 'QoS Level', 'Priority Name', 'Packet Count',
                'Avg Latency (ns)', 'Min Latency (ns)', 'Max Latency (ns)'
            ])
            for r in self.results:
                for lat in r.latency_results:
                    writer.writerow([
                        r.test_name, 
                        lat.qos_level, 
                        lat.priority_name,
                        lat.packet_count, 
                        f"{lat.avg_latency_ns:.2f}",
                        f"{lat.min_latency_ns:.2f}", 
                        f"{lat.max_latency_ns:.2f}"
                    ])
        print(f"Latency data exported to: {output_file}")
    
    def export_json(self, output_file: str):
        """Export all results to JSON"""
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        
        data = []
        for r in self.results:
            d = {
                'test_name': r.test_name,
                'status': r.status,
                'timestamp': r.timestamp,
                'packets_sent': r.packets_sent,
                'packets_received': r.packets_received,
                'packet_loss_pct': r.packet_loss_pct,
                'latency_results': [asdict(lat) for lat in r.latency_results],
                'errors': r.errors,
                'warnings': r.warnings
            }
            data.append(d)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        print(f"JSON exported to: {output_file}")
    
    def print_summary(self):
        """Print summary to console"""
        print("\n" + "="*70)
        print("  TEST RESULTS SUMMARY")
        print("="*70)
        
        passed = sum(1 for r in self.results if r.status == "PASSED")
        failed = sum(1 for r in self.results if r.status == "FAILED")
        unknown = sum(1 for r in self.results if r.status == "UNKNOWN")
        
        print(f"  Total Tests: {len(self.results)}")
        print(f"  Passed:      {passed}")
        print(f"  Failed:      {failed}")
        if unknown > 0:
            print(f"  Unknown:     {unknown}")
        print("-"*70)
        
        for r in self.results:
            if r.status == "PASSED":
                status_icon = "✓"
            elif r.status == "FAILED":
                status_icon = "✗"
            else:
                status_icon = "?"
            
            print(f"  {status_icon} {r.test_name}: {r.status}")
            
            if r.packets_sent > 0:
                print(f"      Packets: {r.packets_received}/{r.packets_sent} "
                      f"(loss: {r.packet_loss_pct:.1f}%)")
            
            if r.latency_results:
                for lat in r.latency_results[:3]:
                    print(f"      QoS {lat.qos_level} ({lat.priority_name}): "
                          f"avg={lat.avg_latency_ns:.1f}ns")
        
        print("="*70)


def main():
    if len(sys.argv) < 3:
        print("Usage: collect_results.py <log_dir> <results_dir> [timestamp]")
        print("  log_dir:     Directory containing simulation logs")
        print("  results_dir: Directory for output CSV/JSON files")
        print("  timestamp:   Optional timestamp for output files")
        sys.exit(1)
    
    log_dir = sys.argv[1]
    results_dir = sys.argv[2]
    timestamp = sys.argv[3] if len(sys.argv) > 3 else datetime.now().strftime("%Y%m%d_%H%M%S")
    
    print(f"\nQoS Switch Fabric - Result Collector")
    print(f"="*50)
    print(f"Log directory:     {log_dir}")
    print(f"Results directory: {results_dir}")
    print(f"Timestamp:         {timestamp}")
    print()
    
    # Collect results
    collector = ResultsCollector(results_dir)
    collector.collect_from_logs(log_dir, "tb_*.log")
    
    if not collector.results:
        print("No test results found!")
        sys.exit(1)
    
    # Export results
    os.makedirs(results_dir, exist_ok=True)
    collector.export_summary_csv(os.path.join(results_dir, f"test_summary_{timestamp}.csv"))
    collector.export_latency_csv(os.path.join(results_dir, f"latency_data_{timestamp}.csv"))
    collector.export_json(os.path.join(results_dir, f"full_results_{timestamp}.json"))
    
    # Print summary
    collector.print_summary()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())