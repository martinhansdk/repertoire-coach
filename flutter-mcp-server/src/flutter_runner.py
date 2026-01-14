"""Flutter CLI wrapper for running Flutter commands."""

import subprocess
import time
from pathlib import Path
from typing import List, Optional, Tuple
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
        if with_pub_get:
            # Run pub get first, then the command, all in the same container
            flutter_cmd = " ".join(["flutter"] + flutter_args)
            return [
                "docker", "run",
                "--rm",
                "-v", f"{self.project_root.absolute()}:/app",
                "-w", "/app",
                self.docker_image,
                "sh", "-c",
                f"flutter pub get > /dev/null 2>&1 && {flutter_cmd}"
            ]
        else:
            return [
                "docker", "run",
                "--rm",
                "-v", f"{self.project_root.absolute()}:/app",
                "-w", "/app",
                self.docker_image,
                "flutter"
            ] + flutter_args

    def _run_command(
        self,
        cmd: List[str],
        timeout: int = 300,
        capture_output: bool = True
    ) -> Tuple[int, str, str]:
        """Run a command and return (returncode, stdout, stderr)."""
        try:
            if capture_output:
                result = subprocess.run(
                    cmd,
                    cwd=self.project_root,
                    capture_output=True,
                    text=True,
                    timeout=timeout
                )
                return result.returncode, result.stdout, result.stderr
            else:
                # For streaming/interactive mode
                result = subprocess.run(
                    cmd,
                    cwd=self.project_root,
                    timeout=timeout
                )
                return result.returncode, "", ""

        except subprocess.TimeoutExpired as e:
            output = e.stdout.decode() if e.stdout else ""
            error = e.stderr.decode() if e.stderr else ""
            return -1, output, f"Command timed out after {timeout}s\n{error}"
        except Exception as e:
            return -1, "", str(e)

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
        path: Optional[str] = None,
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
