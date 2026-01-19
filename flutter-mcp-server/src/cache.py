"""In-memory caching for Flutter operation results."""

import hashlib
import json
from collections import OrderedDict
from datetime import datetime, timedelta
from typing import Dict, Optional, Any, List
from .models import TestResult, AnalyzeResult, BuildResult


class ResultCache:
    """In-memory cache for Flutter operation results."""

    def __init__(
        self,
        max_test_runs: int = 10,
        max_analyze_runs: int = 5,
        max_build_runs: int = 3,
        ttl_seconds: int = 3600
    ):
        self.max_test_runs = max_test_runs
        self.max_analyze_runs = max_analyze_runs
        self.max_build_runs = max_build_runs
        self.ttl_seconds = ttl_seconds

        # OrderedDict maintains insertion order for LRU behavior
        self.test_cache: OrderedDict[str, tuple[TestResult, str]] = OrderedDict()
        self.analyze_cache: OrderedDict[str, tuple[AnalyzeResult, str]] = OrderedDict()
        self.build_cache: OrderedDict[str, tuple[BuildResult, str]] = OrderedDict()

        # Store full logs separately (only when verbose or small)
        self.logs: Dict[str, str] = {}

    def _generate_run_id(self, operation: str, params: Dict[str, Any]) -> str:
        """Generate unique run ID based on timestamp and parameters."""
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        param_str = json.dumps(params, sort_keys=True)
        param_hash = hashlib.sha256(param_str.encode()).hexdigest()[:8]
        return f"{operation}:{timestamp}:{param_hash}"

    def _is_expired(self, timestamp: datetime) -> bool:
        """Check if cached entry has expired."""
        age = datetime.now() - timestamp
        return age > timedelta(seconds=self.ttl_seconds)

    def _evict_oldest(self, cache: OrderedDict, max_size: int):
        """Remove oldest entry from cache if over max size."""
        while len(cache) > max_size:
            run_id, _ = cache.popitem(last=False)
            # Also remove associated log if exists
            if run_id in self.logs:
                del self.logs[run_id]

    def store_test_result(
        self,
        result: TestResult,
        params: Dict[str, Any],
        log: Optional[str] = None
    ) -> str:
        """Store test result in cache and return run ID."""
        run_id = self._generate_run_id("test", params)
        result.runId = run_id

        self.test_cache[run_id] = (result, json.dumps(params))
        self._evict_oldest(self.test_cache, self.max_test_runs)

        if log:
            self.logs[run_id] = log

        return run_id

    def store_analyze_result(
        self,
        result: AnalyzeResult,
        params: Dict[str, Any],
        log: Optional[str] = None
    ) -> str:
        """Store analyze result in cache and return run ID."""
        run_id = self._generate_run_id("analyze", params)
        result.runId = run_id

        self.analyze_cache[run_id] = (result, json.dumps(params))
        self._evict_oldest(self.analyze_cache, self.max_analyze_runs)

        if log:
            self.logs[run_id] = log

        return run_id

    def store_build_result(
        self,
        result: BuildResult,
        params: Dict[str, Any],
        log: Optional[str] = None
    ) -> str:
        """Store build result in cache and return run ID."""
        run_id = self._generate_run_id("build", params)
        result.runId = run_id

        self.build_cache[run_id] = (result, json.dumps(params))
        self._evict_oldest(self.build_cache, self.max_build_runs)

        if log:
            self.logs[run_id] = log

        return run_id

    def get_test_result(self, run_id: Optional[str] = None) -> Optional[TestResult]:
        """Get test result from cache. If run_id is None, returns latest."""
        if run_id is None:
            if not self.test_cache:
                return None
            run_id = next(reversed(self.test_cache))

        if run_id in self.test_cache:
            result, _ = self.test_cache[run_id]
            if not self._is_expired(result.timestamp):
                return result
            else:
                del self.test_cache[run_id]
                if run_id in self.logs:
                    del self.logs[run_id]

        return None

    def get_analyze_result(self, run_id: Optional[str] = None) -> Optional[AnalyzeResult]:
        """Get analyze result from cache. If run_id is None, returns latest."""
        if run_id is None:
            if not self.analyze_cache:
                return None
            run_id = next(reversed(self.analyze_cache))

        if run_id in self.analyze_cache:
            result, _ = self.analyze_cache[run_id]
            if not self._is_expired(result.timestamp):
                return result
            else:
                del self.analyze_cache[run_id]
                if run_id in self.logs:
                    del self.logs[run_id]

        return None

    def get_build_result(self, run_id: Optional[str] = None) -> Optional[BuildResult]:
        """Get build result from cache. If run_id is None, returns latest."""
        if run_id is None:
            if not self.build_cache:
                return None
            run_id = next(reversed(self.build_cache))

        if run_id in self.build_cache:
            result, _ = self.build_cache[run_id]
            if not self._is_expired(result.timestamp):
                return result
            else:
                del self.build_cache[run_id]
                if run_id in self.logs:
                    del self.logs[run_id]

        return None

    def get_log(self, run_id: str) -> Optional[str]:
        """Get full log output for a run."""
        return self.logs.get(run_id)

    def list_test_runs(self) -> List[Dict[str, Any]]:
        """List all cached test runs with summaries."""
        runs = []
        for run_id, (result, params) in reversed(self.test_cache.items()):
            if not self._is_expired(result.timestamp):
                runs.append({
                    "runId": run_id,
                    "timestamp": result.timestamp.isoformat(),
                    "success": result.success,
                    "summary": {
                        "passed": result.summary.passed,
                        "failed": result.summary.failed,
                        "total": result.summary.total
                    },
                    "params": json.loads(params),
                    "hasLog": run_id in self.logs,
                    "logSize": len(self.logs.get(run_id, "")) if run_id in self.logs else 0
                })
        return runs

    def clear_expired(self):
        """Remove all expired entries from cache."""
        # Test cache
        expired_test = [
            run_id for run_id, (result, _) in self.test_cache.items()
            if self._is_expired(result.timestamp)
        ]
        for run_id in expired_test:
            del self.test_cache[run_id]
            if run_id in self.logs:
                del self.logs[run_id]

        # Analyze cache
        expired_analyze = [
            run_id for run_id, (result, _) in self.analyze_cache.items()
            if self._is_expired(result.timestamp)
        ]
        for run_id in expired_analyze:
            del self.analyze_cache[run_id]
            if run_id in self.logs:
                del self.logs[run_id]

        # Build cache
        expired_build = [
            run_id for run_id, (result, _) in self.build_cache.items()
            if self._is_expired(result.timestamp)
        ]
        for run_id in expired_build:
            del self.build_cache[run_id]
            if run_id in self.logs:
                del self.logs[run_id]
