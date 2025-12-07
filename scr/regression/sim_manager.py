#!/usr/bin/env python3
"""
QoS Switch Fabric - Batch Simulation Manager for Windows
Manages multiple testbench runs, generates reports, and tracks results
"""

import os
import sys
import subprocess
import argparse
import json
import time
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Tuple
import re

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

class SimConfig:
    """Simulation configuration and paths"""

    # Project root (relative to this script)
    PROJECT_ROOT = Path(__file__).parent.parent.parent
    SIM_DIR = PROJECT_ROOT / "sim"
    RESULTS_DIR = PROJECT_ROOT / "sim" / "results"
    LOG_DIR = PROJECT_ROOT / "sim" / "logs"

    # Testbench configurations
    TESTBENCHES = {
        # Unit tests (fast)
        'unit': [
            'tb_qos_classifier_unit',
            'tb_qos_scheduler_unit',
            'tb_voq_unit',
        ],

        # Integration tests (medium)
        'integration': [
            'tb_fabric_basic',
            'tb_fabric_qos',
        ],

        # Stress tests (slow)
        'stress': [
            'tb_fabric_qos_stress',
            'tb_fabric_qos_sweep',
        ],

        # All tests
        'all': [],  # Will be populated from above
    }

    # ModelSim/QuestaSim executable
    VSIM_EXE = "vsim"  # Assumes vsim is in PATH

    # Simulation timeout (seconds)
    TIMEOUT = {
        'unit': 300,        # 5 minutes
        'integration': 900, # 15 minutes
        'stress': 3600,     # 1 hour
    }

    def __init__(self):
        # Flatten 'all' category
        all_tbs = []
        for category, tbs in self.TESTBENCHES.items():
            if category != 'all':
                all_tbs.extend(tbs)
        self.TESTBENCHES['all'] = sorted(set(all_tbs))

        # Create directories
        self.RESULTS_DIR.mkdir(parents=True, exist_ok=True)
        self.LOG_DIR.mkdir(parents=True, exist_ok=True)

# ═══════════════════════════════════════════════════════════════════════════════
# Simulation Result Parsing
# ═══════════════════════════════════════════════════════════════════════════════

class SimResult:
    """Simulation result container"""

    def __init__(self, testbench: str):
        self.testbench = testbench
        self.status = 'UNKNOWN'  # PASS, FAIL, TIMEOUT, ERROR
        self.runtime = 0.0
        self.passed_tests = 0
        self.failed_tests = 0
        self.total_tests = 0
        self.errors = []
        self.warnings = []
        self.log_file = None

    def parse_log(self, log_file: Path):
        """Parse simulation log file for results"""
        self.log_file = log_file

        if not log_file.exists():
            self.status = 'ERROR'
            self.errors.append(f"Log file not found: {log_file}")
            return

        try:
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                log_content = f.read()

            # Check for simulation completion
            if "# ** Note: $finish" in log_content or "Simulation complete" in log_content:
                # Look for test summary
                self._parse_test_summary(log_content)

                # If no explicit failures found, assume pass
                if self.failed_tests == 0 and "Error:" not in log_content:
                    self.status = 'PASS'
                else:
                    self.status = 'FAIL'
            elif "TIMEOUT" in log_content:
                self.status = 'TIMEOUT'
            else:
                self.status = 'ERROR'
                self.errors.append("Simulation did not complete")

            # Extract errors and warnings
            self._extract_errors_warnings(log_content)

        except Exception as e:
            self.status = 'ERROR'
            self.errors.append(f"Failed to parse log: {e}")

    def _parse_test_summary(self, log_content: str):
        """Extract test statistics from log"""
        # Pattern: "Total Tests: XXXX"
        total_match = re.search(r'Total Tests:\s*(\d+)', log_content, re.IGNORECASE)
        if total_match:
            self.total_tests = int(total_match.group(1))

        # Pattern: "Passed: XXXX"
        pass_match = re.search(r'Passed:\s*(\d+)', log_content, re.IGNORECASE)
        if pass_match:
            self.passed_tests = int(pass_match.group(1))

        # Pattern: "Failed: XXXX"
        fail_match = re.search(r'Failed:\s*(\d+)', log_content, re.IGNORECASE)
        if fail_match:
            self.failed_tests = int(fail_match.group(1))

    def _extract_errors_warnings(self, log_content: str):
        """Extract error and warning messages"""
        # Extract errors
        error_pattern = r'\*\* Error:.*'
        self.errors.extend(re.findall(error_pattern, log_content)[:10])  # Limit to 10

        # Extract warnings
        warning_pattern = r'\*\* Warning:.*'
        self.warnings.extend(re.findall(warning_pattern, log_content)[:10])  # Limit to 10

    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization"""
        return {
            'testbench': self.testbench,
            'status': self.status,
            'runtime': round(self.runtime, 2),
            'passed_tests': self.passed_tests,
            'failed_tests': self.failed_tests,
            'total_tests': self.total_tests,
            'errors': self.errors,
            'warnings': self.warnings,
            'log_file': str(self.log_file) if self.log_file else None,
        }

# ═══════════════════════════════════════════════════════════════════════════════
# Simulation Runner
# ═══════════════════════════════════════════════════════════════════════════════

class SimRunner:
    """Manages simulation execution"""

    def __init__(self, config: SimConfig, verbose: bool = False):
        self.config = config
        self.verbose = verbose
        self.results: List[SimResult] = []

    def run_testbench(self, testbench: str, category: str = 'unit') -> SimResult:
        """Run a single testbench"""
        result = SimResult(testbench)

        print(f"\n{'═'*70}")
        print(f"  Running: {testbench}")
        print(f"{'═'*70}")

        # Determine timeout
        timeout = self.config.TIMEOUT.get(category, 600)

        # Log file path
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_file = self.config.LOG_DIR / f"{testbench}_{timestamp}.log"

        # Build command
        tcl_script = self.config.SIM_DIR / "sim_qos.tcl"

        cmd = [
            self.config.VSIM_EXE,
            '-c',  # Command-line mode (no GUI)
            '-do', f"set TB {testbench}; set env(SIM_MODE) batch; do {tcl_script}; quit -f"
        ]

        if self.verbose:
            print(f"  Command: {' '.join(cmd)}")
            print(f"  Timeout: {timeout}s")
            print(f"  Log: {log_file}")

        # Run simulation
        start_time = time.time()

        try:
            # Change to sim directory
            original_dir = os.getcwd()
            os.chdir(self.config.SIM_DIR)

            with open(log_file, 'w') as log:
                process = subprocess.Popen(
                    cmd,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    text=True,
                    cwd=str(self.config.SIM_DIR)
                )

                try:
                    process.wait(timeout=timeout)
                    result.runtime = time.time() - start_time

                    if process.returncode == 0:
                        print(f"   Completed in {result.runtime:.1f}s")
                    else:
                        print(f"   Failed with return code {process.returncode}")
                        result.status = 'FAIL'

                except subprocess.TimeoutExpired:
                    process.kill()
                    result.runtime = timeout
                    result.status = 'TIMEOUT'
                    print(f"   TIMEOUT after {timeout}s")

        except Exception as e:
            result.status = 'ERROR'
            result.errors.append(str(e))
            print(f"   ERROR: {e}")

        finally:
            os.chdir(original_dir)

        # Parse log file
        result.parse_log(log_file)

        # Print summary
        self._print_result_summary(result)

        self.results.append(result)
        return result

    def _print_result_summary(self, result: SimResult):
        """Print quick result summary"""
        status_icon = {
            'PASS': '',
            'FAIL': '',
            'TIMEOUT': '⏱⏱⏱',
            'ERROR': '❌❌❌',
            'UNKNOWN': '???'
        }

        icon = status_icon.get(result.status, '???')
        print(f"  {icon} {result.status}")

        if result.total_tests > 0:
            print(f"      Tests: {result.passed_tests}/{result.total_tests} passed")

        if result.errors:
            print(f"      Errors: {len(result.errors)}")
            if self.verbose:
                for err in result.errors[:3]:
                    print(f"        - {err[:80]}")

    def run_suite(self, category: str) -> List[SimResult]:
        """Run a suite of testbenches"""
        testbenches = self.config.TESTBENCHES.get(category, [])

        print(f"\n╔{'═'*68}╗")
        print(f"║  Running {category.upper()} Test Suite ({len(testbenches)} tests)")
        print(f"╚{'═'*68}╝")

        for tb in testbenches:
            self.run_testbench(tb, category)

        return self.results

    def generate_report(self, output_file: Path = None):
        """Generate comprehensive test report"""
        if output_file is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            output_file = self.config.RESULTS_DIR / f"sim_report_{timestamp}.txt"

        total = len(self.results)
        passed = sum(1 for r in self.results if r.status == 'PASS')
        failed = sum(1 for r in self.results if r.status == 'FAIL')
        timeout = sum(1 for r in self.results if r.status == 'TIMEOUT')
        error = sum(1 for r in self.results if r.status == 'ERROR')

        with open(output_file, 'w') as f:
            f.write("╔" + "═"*78 + "╗\n")
            f.write("║" + " "*20 + "QoS SWITCH FABRIC SIMULATION REPORT" + " "*23 + "║\n")
            f.write("╠" + "═"*78 + "╣\n")
            f.write(f"║  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}" + " "*43 + "║\n")
            f.write(f"║  Total Tests: {total:3d}" + " "*61 + "║\n")
            f.write("╠" + "═"*78 + "╣\n")
            f.write(f"║   PASSED:  {passed:3d}" + " "*61 + "║\n")
            f.write(f"║   FAILED:  {failed:3d}" + " "*61 + "║\n")
            f.write(f"║  ⏱ TIMEOUT: {timeout:3d}" + " "*61 + "║\n")
            f.write(f"║  ❌ ERROR:   {error:3d}" + " "*61 + "║\n")
            f.write("╚" + "═"*78 + "╝\n\n")

            # Detailed results
            f.write("\nDETAILED RESULTS:\n")
            f.write("─"*80 + "\n")

            for result in self.results:
                f.write(f"\n[{result.status:7s}] {result.testbench}\n")
                f.write(f"  Runtime: {result.runtime:.2f}s\n")

                if result.total_tests > 0:
                    f.write(f"  Tests: {result.passed_tests}/{result.total_tests} passed\n")

                if result.errors:
                    f.write(f"  Errors ({len(result.errors)}):\n")
                    for err in result.errors[:5]:
                        f.write(f"    - {err}\n")

                if result.warnings:
                    f.write(f"  Warnings ({len(result.warnings)}):\n")
                    for warn in result.warnings[:3]:
                        f.write(f"    - {warn}\n")

                f.write(f"  Log: {result.log_file}\n")

        print(f"\n Report saved: {output_file}")

        # Also save JSON version
        json_file = output_file.with_suffix('.json')
        with open(json_file, 'w') as f:
            json.dump({
                'timestamp': datetime.now().isoformat(),
                'summary': {
                    'total': total,
                    'passed': passed,
                    'failed': failed,
                    'timeout': timeout,
                    'error': error,
                },
                'results': [r.to_dict() for r in self.results]
            }, f, indent=2)

        print(f" JSON report saved: {json_file}")

        return output_file

# ═══════════════════════════════════════════════════════════════════════════════
# Main Entry Point
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description='QoS Switch Fabric Batch Simulation Manager',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all unit tests
  python sim_manager.py --suite unit

  # Run specific testbenches
  python sim_manager.py --tb tb_qos_classifier_unit tb_voq_unit

  # Run full regression
  python sim_manager.py --suite all --verbose

  # Generate report from previous run
  python sim_manager.py --report-only
        """
    )

    parser.add_argument('--suite', choices=['unit', 'integration', 'stress', 'all'],
                        help='Run predefined test suite')
    parser.add_argument('--tb', nargs='+', metavar='TESTBENCH',
                        help='Run specific testbench(es)')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Verbose output')
    parser.add_argument('--report-only', action='store_true',
                        help='Only generate report from existing logs')

    args = parser.parse_args()

    # Configuration
    config = SimConfig()
    runner = SimRunner(config, verbose=args.verbose)

    # Determine what to run
    if args.report_only:
        # Just generate report from previous run
        # (In a real implementation, you'd load previous results)
        print("Report-only mode not fully implemented yet")
        return 0

    if args.suite:
        runner.run_suite(args.suite)
    elif args.tb:
        for tb in args.tb:
            runner.run_testbench(tb)
    else:
        parser.print_help()
        return 1

    # Generate report
    report_file = runner.generate_report()

    # Print final summary
    print(f"\n{'═'*80}")
    print("  FINAL SUMMARY")
    print(f"{'═'*80}")

    total = len(runner.results)
    passed = sum(1 for r in runner.results if r.status == 'PASS')

    print(f"  Total: {total}  |  Passed: {passed}  |  Failed: {total - passed}")

    if passed == total:
        print("\n   ALL TESTS PASSED \n")
        return 0
    else:
        print("\n   SOME TESTS FAILED \n")
        return 1

if __name__ == '__main__':
    sys.exit(main())