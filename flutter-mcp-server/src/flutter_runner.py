"""Flutter CLI wrapper for running Flutter commands."""

import subprocess
import time
from pathlib import Path
import os
import tempfile
from typing import List, Optional, Tuple, Union
import shutil


class FlutterRunner:
    """Wrapper for executing Flutter CLI commands."""

    def __init__(
        self,
        flutter_path: str = "flutter",
        docker_image: str = "ghcr.io/cirruslabs/flutter:stable",
        project_root: Optional[str] = None
    ):
        # CRITICAL: Docker is REQUIRED - Flutter is not installed on host
        # This parameter exists only for backward compatibility in config
        self.flutter_path = flutter_path
        self.docker_enabled = True  # Force Docker, ignore parameter
        self.docker_image = docker_image
        self.project_root = Path(project_root) if project_root else Path.cwd()

    def _check_docker_available(self) -> bool:
        """Check if Docker is available."""
        return shutil.which("docker") is not None

    def _build_docker_command(self, flutter_args: List[str], with_pub_get: bool = False) -> List[str]:
        """Build Docker command to run Flutter."""
        pub_cache_host = self.project_root / ".pub-cache"
        pub_cache_host.mkdir(parents=True, exist_ok=True)
        pub_cache_mount = f"{pub_cache_host.absolute()}:/app/.pub-cache"
        if with_pub_get:
            # Run pub get first, then the command, all in the same container
            flutter_cmd = " ".join(["flutter"] + flutter_args)
            return [
                "docker", "run",
                "--rm",
                "-e", "PUB_CACHE=/app/.pub-cache",
                "-v", f"{self.project_root.absolute()}:/app",
                "-v", pub_cache_mount,
                "-w", "/app",
                self.docker_image,
                "sh", "-c",
                f"flutter pub get > /dev/null 2>&1 && {flutter_cmd}"
            ]
        else:
            return [
                "docker", "run",
                "--rm",
                "-e", "PUB_CACHE=/app/.pub-cache",
                "-v", f"{self.project_root.absolute()}:/app",
                "-v", pub_cache_mount,
                "-w", "/app",
                self.docker_image,
                "flutter"
            ] + flutter_args

    def _add_cidfile(self, cmd: List[str], cidfile: str) -> List[str]:
        """Inject --cidfile into a docker run command."""
        if cmd and cmd[0] == 'docker' and 'run' in cmd:
            run_idx = cmd.index('run')
            return cmd[:run_idx + 1] + ['--cidfile', cidfile] + cmd[run_idx + 1:]
        return cmd

    def _kill_container(self, cidfile: str) -> None:
        """Kill and remove a Docker container identified by a cidfile."""
        try:
            with open(cidfile, 'r') as f:
                container_id = f.read().strip()
            if container_id:
                self.kill_container_id(container_id)
        except (FileNotFoundError, IOError, subprocess.TimeoutExpired):
            pass

    def kill_container_id(self, container_id: str) -> None:
        """Kill and remove a Docker container by ID."""
        if not container_id:
            return
        try:
            subprocess.run(
                ['docker', 'kill', container_id],
                capture_output=True, timeout=10
            )
            subprocess.run(
                ['docker', 'rm', container_id],
                capture_output=True, timeout=10
            )
        except subprocess.TimeoutExpired:
            pass

    def _read_cidfile(self, cidfile: str, timeout: float = 5.0) -> Optional[str]:
        """Wait briefly for cidfile to appear and return container ID."""
        start = time.time()
        while time.time() - start < timeout:
            if os.path.exists(cidfile):
                try:
                    with open(cidfile, 'r') as f:
                        container_id = f.read().strip()
                        return container_id or None
                except IOError:
                    return None
            time.sleep(0.05)
        return None

    def start_flutter_command(
        self,
        args: List[str],
        with_pub_get: bool = False,
        capture_output: bool = True
    ) -> Tuple[subprocess.Popen, Optional[str]]:
        """Start a Flutter command and return the process and cidfile path."""
        if not self._check_docker_available():
            raise RuntimeError(
                "Docker is not available but is REQUIRED. "
                "Flutter is NOT installed on this host. "
                "Please install Docker to use this MCP server."
            )

        cmd = self._build_docker_command(args, with_pub_get=with_pub_get)
        cidfile: Optional[str] = None
        if cmd and cmd[0] == 'docker' and 'run' in cmd:
            cidfile = tempfile.mktemp(prefix='flutter_mcp_')
            cmd = self._add_cidfile(cmd, cidfile)

        if capture_output:
            proc = subprocess.Popen(
                cmd,
                cwd=self.project_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
        else:
            proc = subprocess.Popen(cmd, cwd=self.project_root)

        return proc, cidfile

    def _run_command(
        self,
        cmd: List[str],
        timeout: int = 300,
        capture_output: bool = True
    ) -> Tuple[int, str, str]:
        """Run a command and return (returncode, stdout, stderr).

        For docker run commands, uses --cidfile so the container can be
        explicitly killed if the timeout fires (docker --rm alone does not
        kill a running container when the host process is interrupted).
        """
        # Track the container ID so we can kill it on timeout
        cidfile: Optional[str] = None
        if cmd and cmd[0] == 'docker' and 'run' in cmd:
            cidfile = tempfile.mktemp(prefix='flutter_mcp_')
            run_idx = cmd.index('run')
            cmd = cmd[:run_idx + 1] + ['--cidfile', cidfile] + cmd[run_idx + 1:]

        proc: Optional[subprocess.Popen] = None
        try:
            if capture_output:
                proc = subprocess.Popen(
                    cmd,
                    cwd=self.project_root,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE
                )
                stdout_bytes, stderr_bytes = proc.communicate(timeout=timeout)
                return proc.returncode, stdout_bytes.decode(), stderr_bytes.decode()
            else:
                proc = subprocess.Popen(cmd, cwd=self.project_root)
                proc.wait(timeout=timeout)
                return proc.returncode, "", ""

        except subprocess.TimeoutExpired:
            # Kill the host-side process first
            if proc:
                proc.kill()
                stdout_bytes, stderr_bytes = proc.communicate()
                stdout_str = stdout_bytes.decode() if stdout_bytes else ""
                stderr_str = stderr_bytes.decode() if stderr_bytes else ""
            else:
                stdout_str, stderr_str = "", ""

            # Kill the Docker container so it doesn't linger
            if cidfile:
                self._kill_container(cidfile)

            return -1, stdout_str, f"Command timed out after {timeout}s\n{stderr_str}"
        except Exception as e:
            if proc and proc.poll() is None:
                proc.kill()
                proc.communicate()
            return -1, "", str(e)
        finally:
            if cidfile:
                try:
                    os.unlink(cidfile)
                except OSError:
                    pass

    def run_flutter_command(
        self,
        args: List[str],
        with_pub_get: bool = False,
        timeout: int = 300
    ) -> Tuple[int, str, str]:
        """Run a Flutter command and return results.

        CRITICAL: All Flutter commands MUST run in Docker.
        Flutter is NOT installed on the host machine.

        Args:
            args: Flutter command arguments (e.g., ['test', '--reporter', 'compact'])
            with_pub_get: If True, run 'flutter pub get' first in the same container
            timeout: Command timeout in seconds

        Returns:
            Tuple of (returncode, stdout, stderr)
        """
        # CRITICAL: Always use Docker - Flutter is not installed on host
        if not self._check_docker_available():
            raise RuntimeError(
                "Docker is not available but is REQUIRED. "
                "Flutter is not installed on this host. "
                "Please install Docker to use this MCP server."
            )

        cmd = self._build_docker_command(args, with_pub_get=with_pub_get)
        return self._run_command(cmd, timeout=timeout)

    def test(
        self,
        path: Optional[Union[str, List[str]]] = None,
        name: Optional[str] = None,
        fail_fast: bool = False,
        coverage: bool = False,
        reporter: str = "compact",
        timeout: int = 300
    ) -> Tuple[int, str, str]:
        """Run Flutter tests in Docker."""
        args = ["test"]

        if reporter:
            args.extend(["--reporter", reporter])

        if path:
            if isinstance(path, list):
                args.extend(path)
            else:
                args.append(path)

        if name:
            args.extend(["--name", name])

        if fail_fast:
            args.append("--fail-fast")

        if coverage:
            args.append("--coverage")

        return self.run_flutter_command(args, with_pub_get=True, timeout=timeout)

    def analyze(
        self,
        path: Optional[str] = None,
        timeout: int = 120
    ) -> Tuple[int, str, str]:
        """Run Flutter analyze in Docker."""
        args = ["analyze"]

        if path:
            args.append(path)

        return self.run_flutter_command(args, with_pub_get=True, timeout=timeout)

    def build(
        self,
        target: str,
        mode: str = "debug",
        flavor: Optional[str] = None,
        build_number: Optional[str] = None,
        build_name: Optional[str] = None,
        dart_defines: Optional[dict] = None,
        timeout: int = 600
    ) -> Tuple[int, str, str]:
        """Run Flutter build in Docker."""
        args = ["build", target]

        if mode != "debug":
            args.append(f"--{mode}")

        if flavor:
            args.extend(["--flavor", flavor])

        if build_number:
            args.extend(["--build-number", build_number])

        if build_name:
            args.extend(["--build-name", build_name])

        # Add --dart-define flags
        if dart_defines:
            for key, value in dart_defines.items():
                args.extend(["--dart-define", f"{key}={value}"])

        return self.run_flutter_command(args, with_pub_get=True, timeout=timeout)

    def pub_get(
        self,
        timeout: int = 120
    ) -> Tuple[int, str, str]:
        """Run Flutter pub get in Docker."""
        return self.run_flutter_command(["pub", "get"], timeout=timeout)

    def pub_upgrade(
        self,
        timeout: int = 120
    ) -> Tuple[int, str, str]:
        """Run Flutter pub upgrade in Docker."""
        return self.run_flutter_command(["pub", "upgrade"], timeout=timeout)

    def pub_outdated(
        self,
        timeout: int = 120
    ) -> Tuple[int, str, str]:
        """Run Flutter pub outdated in Docker."""
        return self.run_flutter_command(["pub", "outdated"], timeout=timeout)

    def doctor(
        self,
        timeout: int = 60
    ) -> Tuple[int, str, str]:
        """Run Flutter doctor in Docker."""
        return self.run_flutter_command(["doctor"], timeout=timeout)

    def clean(
        self,
        timeout: int = 60
    ) -> Tuple[int, str, str]:
        """Run Flutter clean in Docker."""
        return self.run_flutter_command(["clean"], timeout=timeout)
