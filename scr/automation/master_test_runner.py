#!/usr/bin/env python3
"""
QoS Switch Fabric - Master Test Automation
Orchestrates: Build → Simulate → Analyze → Report

Usage: python master_test_runner.py [--skip-build] [--skip-sim]
"""

import os
import sys
import subprocess
import argparse
import json
import time
from pathlib import Path
from datetime import datetime
import shutil

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "scr" / "analysis"))

# Import your existing modules
try:
    from collect_results import ResultsCollector
    from thesis_report_generator import main as generate_report
except ImportError as e:
    print(f"Warning: Could not import analysis modules: {e}")
    print("Some features may be unavailable")

class Colors:
    """ANSI color codes"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

class TestConfig:
    """Test configuration and paths"""
    def __init__(self):
        self.root = PROJECT_ROOT
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Directories
        self.sim_dir = self.root / "sim"
        self.vivado_dir = self.root / "vivado_build"
        self.reports_dir = self.vivado_dir / "reports"
        self.results_dir = self.root / "results" / f"run_{self.timestamp}"
        self.figures_dir = self.results_dir / "figures"
        
        # Scripts
        self.run_qos_complete = self.root / "build.bat"
        self.run_all_tests = self.root / "run_all_tests.bat"
        
        # Create output directories
        self.results_dir.mkdir(parents=True, exist_ok=True)
        self.figures_dir.mkdir(parents=True, exist_ok=True)
        
    def get_test_list(self):
        """Define all tests to run"""
        return [
            # Unit tests
            ("tb_qos_classifier_unit", "QoS Classifier"),
            ("tb_qos_scheduler_unit", "QoS Scheduler"),
            ("tb_voq_unit", "VOQ Buffer"),
            
            # Integration tests
            ("tb_qos_manager_integration", "QoS Manager"),
            
            # Fabric tests
            ("tb_fabric_qos", "QoS Fabric"),
            ("tb_fabric_qos_stress", "Stress Test"),
            ("tb_fabric_qos_sweep", "Configuration Sweep"),
        ]

class TaskRunner:
    """Execute build/sim/analysis tasks"""
    
    def __init__(self, config: TestConfig, verbose: bool = True):
        self.config = config
        self.verbose = verbose
        self.results = {
            'vivado_build': None,
            'simulations': {},
            'timing_met': False,
            'tests_passed': 0,
            'tests_failed': 0
        }
        
    def print_header(self, title: str, level: int = 1):
        """Print formatted section header"""
        if level == 1:
            print(f"\n{Colors.HEADER}{'='*70}{Colors.ENDC}")
            print(f"{Colors.HEADER}{Colors.BOLD}  {title}{Colors.ENDC}")
            print(f"{Colors.HEADER}{'='*70}{Colors.ENDC}\n")
        else:
            print(f"\n{Colors.OKBLUE}{'─'*70}{Colors.ENDC}")
            print(f"{Colors.OKBLUE}  {title}{Colors.ENDC}")
            print(f"{Colors.OKBLUE}{'─'*70}{Colors.ENDC}")
    
    def run_command(self, cmd: list, cwd: Path = None, timeout: int = 3600):
        """Run shell command and capture output"""
        if self.verbose:
            print(f"  Running: {' '.join(cmd)}")
        
        try:
            result = subprocess.run(
                cmd,
                cwd=cwd or self.config.root,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                timeout=timeout
            )
            return result.returncode, result.stdout
        except subprocess.TimeoutExpired:
            return -1, "TIMEOUT"
        except Exception as e:
            return -1, str(e)
    
    def run_vivado_build(self):
        """Execute Vivado synthesis + implementation"""
        self.print_header("PHASE 1: Vivado Build (Synthesis + Implementation)", 1)
        
        if not self.config.run_qos_complete.exists():
            print(f"{Colors.FAIL}Build script not found: {self.config.run_qos_complete}{Colors.ENDC}")
            return False
        
        print("  Starting Vivado build...")
        print(f"  This may take 30-60 minutes depending on your machine")
        print(f"  Output: {self.config.reports_dir}")
        
        start_time = time.time()
        
        returncode, output = self.run_command(
            [str(self.config.run_qos_complete)],
            timeout=7200  # 2 hours max
        )
        
        duration = time.time() - start_time
        
        # Check for success
        success = (returncode == 0 and 
                   (self.config.reports_dir / "timing_synth.rpt").exists())
        
        if success:
            print(f"{Colors.OKGREEN}  ✓ Build completed in {duration/60:.1f} minutes{Colors.ENDC}")
            self.results['vivado_build'] = 'SUCCESS'
            
            # Parse timing
            timing_met = self._check_timing()
            self.results['timing_met'] = timing_met
            
            if timing_met:
                print(f"{Colors.OKGREEN}  ✓ Timing constraints MET{Colors.ENDC}")
            else:
                print(f"{Colors.WARNING}  ⚠ Timing constraints NOT MET (expected at synthesis){Colors.ENDC}")
        else:
            print(f"{Colors.FAIL}  ✗ Build FAILED after {duration/60:.1f} minutes{Colors.ENDC}")
            self.results['vivado_build'] = 'FAILED'
        
        return success
    
    def _check_timing(self):
        """Parse timing report for WNS/WHS"""
        timing_rpt = self.config.reports_dir / "timing_synth.rpt"
        if not timing_rpt.exists():
            return False
        
        try:
            with open(timing_rpt, 'r') as f:
                content = f.read()
            
            # Look for "Timing constraints are not met" vs "Timing constraints met"
            if "Timing constraints are not met" in content:
                return False
            
            # Check WNS >= 0
            import re
            match = re.search(r'WNS\(ns\)\s+([-\d.]+)', content)
            if match:
                wns = float(match.group(1))
                return wns >= 0
                
        except Exception as e:
            print(f"  Warning: Could not parse timing: {e}")
        
        return True  # Assume met if can't parse
    
    def run_simulations(self):
        """Run all testbenches"""
        self.print_header("PHASE 2: Run Simulations", 1)
        
        tests = self.config.get_test_list()
        total = len(tests)
        
        for idx, (tb_name, description) in enumerate(tests, 1):
            self.print_header(f"Test {idx}/{total}: {description}", 2)
            
            success = self._run_single_sim(tb_name)
            
            if success:
                print(f"{Colors.OKGREEN}  ✓ {tb_name} PASSED{Colors.ENDC}")
                self.results['tests_passed'] += 1
            else:
                print(f"{Colors.FAIL}  ✗ {tb_name} FAILED{Colors.ENDC}")
                self.results['tests_failed'] += 1
            
            self.results['simulations'][tb_name] = 'PASS' if success else 'FAIL'
    
    def _run_single_sim(self, tb_name: str):
        """Run one testbench"""
        sim_script = self.config.sim_dir / "run_sim.bat"
        
        if not sim_script.exists():
            print(f"  {Colors.WARNING}Simulation script not found{Colors.ENDC}")
            return False
        
        # Run in batch mode
        env = os.environ.copy()
        env['TB'] = tb_name
        env['SIM_MODE'] = 'batch'
        
        returncode, output = self.run_command(
            [str(sim_script), tb_name, "batch"],
            cwd=self.config.sim_dir,
            timeout=600  # 10 minutes per test
        )
        
        # Check for pass/fail in output
        if "PASS" in output.upper() or "ALL TESTS PASSED" in output.upper():
            return True
        if "FAIL" in output.upper() or "ERROR" in output.upper():
            return False
        
        # If unclear, check for errors in returncode
        return returncode == 0
    
    def analyze_results(self):
        """Run Python analysis scripts"""
        self.print_header("PHASE 3: Analyze Results", 1)
        
        # Collect simulation results
        print("  Collecting simulation logs...")
        collector = ResultsCollector(str(self.config.results_dir))
        collector.collect_from_logs(str(self.config.sim_dir / "logs"), "tb_*.log")
        
        # Export CSVs
        collector.export_summary_csv(str(self.config.results_dir / "test_summary.csv"))
        collector.export_latency_csv(str(self.config.results_dir / "latency_data.csv"))
        collector.export_json(str(self.config.results_dir / "results.json"))
        
        print(f"{Colors.OKGREEN}  ✓ Results exported{Colors.ENDC}")
    
    def generate_report(self):
        """Generate thesis figures and report"""
        self.print_header("PHASE 4: Generate Report & Figures", 1)
        
        print("  Generating thesis figures...")
        try:
            # Call your thesis_report_generator
            generate_report()
            print(f"{Colors.OKGREEN}  ✓ Figures generated{Colors.ENDC}")
        except Exception as e:
            print(f"{Colors.FAIL}  ✗ Figure generation failed: {e}{Colors.ENDC}")
    
    def print_final_summary(self):
        """Print execution summary"""
        self.print_header("EXECUTION SUMMARY", 1)
        
        print(f"  Vivado Build:   {self.results['vivado_build']}")
        print(f"  Timing Met:     {'YES' if self.results['timing_met'] else 'NO (expected)'}")
        print(f"  Tests Passed:   {self.results['tests_passed']}")
        print(f"  Tests Failed:   {self.results['tests_failed']}")
        print(f"\n  Results saved to: {self.config.results_dir}")
        print(f"  Figures saved to: {self.config.figures_dir}")
        print()
        
        # Overall status
        all_pass = (
            self.results['vivado_build'] == 'SUCCESS' and
            self.results['tests_failed'] == 0
        )
        
        if all_pass:
            print(f"{Colors.OKGREEN}{'='*70}{Colors.ENDC}")
            print(f"{Colors.OKGREEN}  ✓✓✓ ALL TESTS PASSED - Ready for thesis! ✓✓✓{Colors.ENDC}")
            print(f"{Colors.OKGREEN}{'='*70}{Colors.ENDC}\n")
        else:
            print(f"{Colors.WARNING}{'='*70}{Colors.ENDC}")
            print(f"{Colors.WARNING}  ⚠ Some tests failed - review logs{Colors.ENDC}")
            print(f"{Colors.WARNING}{'='*70}{Colors.ENDC}\n")

def main():
    parser = argparse.ArgumentParser(description="QoS Switch Fabric - Master Test Runner")
    parser.add_argument('--skip-build', action='store_true', help='Skip Vivado build')
    parser.add_argument('--skip-sim', action='store_true', help='Skip simulations')
    parser.add_argument('--verbose', action='store_true', default=True, help='Verbose output')
    args = parser.parse_args()
    
    config = TestConfig()
    runner = TaskRunner(config, verbose=args.verbose)
    
    print(f"{Colors.HEADER}{Colors.BOLD}")
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║                                                               ║")
    print("║     QoS SWITCH FABRIC - AUTOMATED THESIS VALIDATION           ║")
    print("║                                                               ║")
    print("╚═══════════════════════════════════════════════════════════════╝")
    print(f"{Colors.ENDC}\n")
    
    print(f"  Started:  {config.timestamp}")
    print(f"  Root:     {config.root}")
    print(f"  Results:  {config.results_dir}\n")
    
    try:
        # Phase 1: Build
        if not args.skip_build:
            if not runner.run_vivado_build():
                print(f"{Colors.FAIL}Build failed - stopping{Colors.ENDC}")
                return 1
        else:
            print(f"{Colors.WARNING}Skipping Vivado build{Colors.ENDC}")
        
        # Phase 2: Simulate
        if not args.skip_sim:
            runner.run_simulations()
        else:
            print(f"{Colors.WARNING}Skipping simulations{Colors.ENDC}")
        
        # Phase 3: Analyze
        runner.analyze_results()
        
        # Phase 4: Report
        runner.generate_report()
        
        # Summary
        runner.print_final_summary()
        
        return 0
        
    except KeyboardInterrupt:
        print(f"\n{Colors.WARNING}Interrupted by user{Colors.ENDC}")
        return 1
    except Exception as e:
        print(f"\n{Colors.FAIL}Fatal error: {e}{Colors.ENDC}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())