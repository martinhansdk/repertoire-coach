#!/usr/bin/env python3
"""
Deploy script for Repertoire Coach

Deploys Android or iOS builds to connected devices from either:
- Local builds (build/ directory)
- GitHub Actions artifacts

Usage:
    ./scripts/deploy.py                     # Interactive menu
    ./scripts/deploy.py --local             # Use local build (interactive)
    ./scripts/deploy.py --github            # Use GitHub build (interactive)
    ./scripts/deploy.py --platform ios      # Deploy iOS build
    ./scripts/deploy.py --help              # Show help
"""

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import List, Optional, Tuple


class Platform(Enum):
    """Supported platforms"""
    ANDROID = "android"
    IOS = "ios"


class BuildSource(Enum):
    """Build source types"""
    LOCAL = "local"
    GITHUB = "github"


class Color:
    """Terminal colors"""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    RESET = '\033[0m'


@dataclass
class Build:
    """Represents a build artifact"""
    platform: Platform
    source: BuildSource
    path: Optional[Path] = None
    run_id: Optional[str] = None  # Long database ID for API calls
    run_number: Optional[int] = None  # Short sequential run number for display
    commit: Optional[str] = None
    commit_msg: Optional[str] = None
    date: Optional[datetime] = None
    build_type: Optional[str] = None  # debug, release, etc.
    artifact_name: Optional[str] = None

    def __str__(self) -> str:
        """String representation for menu display"""
        if self.source == BuildSource.LOCAL:
            age = self._format_age() if self.date else "unknown age"
            return (f"{self.source.value.capitalize()} - "
                   f"{self.platform.value.capitalize()} {self.build_type or 'build'} "
                   f"({age})\n    {self.path}")
        else:
            age = self._format_age() if self.date else "unknown date"
            commit_short = self.commit[:7] if self.commit else "unknown"
            run_display = f"#{self.run_number}" if self.run_number else f"ID {self.run_id}"
            return (f"GitHub - {self.platform.value.capitalize()} {self.build_type or 'build'} "
                   f"(run {run_display}, {age})\n"
                   f"    Commit: {commit_short} \"{self.commit_msg or 'No message'}\"")

    def _format_age(self) -> str:
        """Format time since build"""
        if not self.date:
            return "unknown"

        # Make datetime timezone-aware if needed for comparison
        now = datetime.now(self.date.tzinfo) if self.date.tzinfo else datetime.now()
        delta = now - self.date
        if delta.days > 0:
            return f"{delta.days} day{'s' if delta.days != 1 else ''} ago"
        elif delta.seconds > 3600:
            hours = delta.seconds // 3600
            return f"{hours} hour{'s' if hours != 1 else ''} ago"
        elif delta.seconds > 60:
            minutes = delta.seconds // 60
            return f"{minutes} minute{'s' if minutes != 1 else ''} ago"
        else:
            return "just now"


class DependencyChecker:
    """Check for required system dependencies"""

    @staticmethod
    def check_command(cmd: str) -> bool:
        """Check if a command is available"""
        return shutil.which(cmd) is not None

    @staticmethod
    def check_adb() -> Tuple[bool, str]:
        """Check if adb is available"""
        if DependencyChecker.check_command("adb"):
            return True, ""

        error = f"{Color.RED}Error: adb is not installed{Color.RESET}\n\n"
        if platform.system() == "Darwin":
            error += "Install with: brew install android-platform-tools\n"
        elif platform.system() == "Linux":
            error += "Install with: sudo apt-get install android-tools-adb\n"
        else:
            error += "Download Android SDK Platform Tools from:\n"
            error += "https://developer.android.com/studio/releases/platform-tools\n"
        return False, error

    @staticmethod
    def check_gh() -> Tuple[bool, str]:
        """Check if GitHub CLI is available"""
        if DependencyChecker.check_command("gh"):
            return True, ""

        error = f"{Color.RED}Error: gh (GitHub CLI) is not installed{Color.RESET}\n\n"
        if platform.system() == "Darwin":
            error += "Install with: brew install gh\n"
        elif platform.system() == "Linux":
            error += "Install with: sudo apt install gh\n"
        else:
            error += "Download from: https://cli.github.com/\n"
        error += "\nAfter installation, authenticate with: gh auth login\n"
        return False, error

    @staticmethod
    def check_ios_deploy() -> Tuple[bool, str]:
        """Check if iOS deployment tools are available"""
        # Check for ideviceinstaller (preferred)
        if DependencyChecker.check_command("ideviceinstaller"):
            return True, ""

        # Check for ios-deploy (alternative)
        if DependencyChecker.check_command("ios-deploy"):
            return True, ""

        error = f"{Color.RED}Error: No iOS deployment tool found{Color.RESET}\n\n"
        if platform.system() == "Darwin":
            error += "Install ideviceinstaller with:\n"
            error += "  brew install ideviceinstaller\n\n"
            error += "Or install ios-deploy with:\n"
            error += "  npm install -g ios-deploy\n"
        else:
            error += "iOS deployment is only supported on macOS\n"
        return False, error


class BuildFinder:
    """Find available builds"""

    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.build_dir = repo_root / "build"

    def find_local_android_builds(self) -> List[Build]:
        """Find local Android APK files"""
        builds = []
        apk_dir = self.build_dir / "app" / "outputs" / "flutter-apk"

        if not apk_dir.exists():
            return builds

        for apk_file in apk_dir.glob("*.apk"):
            # Determine build type from filename
            build_type = "debug" if "debug" in apk_file.name else "release"

            # Get file modification time
            mtime = datetime.fromtimestamp(apk_file.stat().st_mtime)

            builds.append(Build(
                platform=Platform.ANDROID,
                source=BuildSource.LOCAL,
                path=apk_file,
                date=mtime,
                build_type=build_type
            ))

        return builds

    def find_local_ios_builds(self) -> List[Build]:
        """Find local iOS IPA files"""
        builds = []
        ipa_dir = self.build_dir / "ios" / "ipa"

        if not ipa_dir.exists():
            return builds

        for ipa_file in ipa_dir.glob("*.ipa"):
            mtime = datetime.fromtimestamp(ipa_file.stat().st_mtime)

            builds.append(Build(
                platform=Platform.IOS,
                source=BuildSource.LOCAL,
                path=ipa_file,
                date=mtime,
                build_type="release"  # IPAs are typically release builds
            ))

        return builds

    def find_github_builds(self, platform_filter: Optional[Platform] = None) -> List[Build]:
        """Find builds from GitHub Actions"""
        builds = []

        try:
            # Get recent workflow runs
            result = subprocess.run(
                ["gh", "run", "list", "--workflow=Build Flutter App", "--json",
                 "databaseId,number,conclusion,headBranch,headSha,displayTitle,createdAt",
                 "--limit", "10"],
                capture_output=True,
                text=True,
                check=True
            )

            runs = json.loads(result.stdout)

            for run in runs:
                # Only include successful runs
                if run.get("conclusion") != "success":
                    continue

                run_id = str(run["databaseId"])
                run_number = run.get("number")
                commit = run.get("headSha", "")
                commit_msg = run.get("displayTitle", "")
                date_str = run.get("createdAt", "")
                date = datetime.fromisoformat(date_str.replace('Z', '+00:00')) if date_str else None

                # Get artifacts for this run
                artifacts = self._get_run_artifacts(run_id)

                for artifact in artifacts:
                    # Determine platform and build type from artifact name
                    artifact_name = artifact["name"]

                    if "android" in artifact_name.lower():
                        plt = Platform.ANDROID
                        build_type = "debug" if "debug" in artifact_name.lower() else "release"
                    elif "ios" in artifact_name.lower():
                        plt = Platform.IOS
                        build_type = "release"
                    else:
                        continue  # Unknown platform

                    # Apply platform filter
                    if platform_filter and plt != platform_filter:
                        continue

                    builds.append(Build(
                        platform=plt,
                        source=BuildSource.GITHUB,
                        run_id=run_id,
                        run_number=run_number,
                        commit=commit,
                        commit_msg=commit_msg,
                        date=date,
                        build_type=build_type,
                        artifact_name=artifact_name
                    ))

        except subprocess.CalledProcessError as e:
            print(f"{Color.YELLOW}Warning: Failed to fetch GitHub builds{Color.RESET}")
            print(f"Error: {e.stderr if e.stderr else str(e)}")
        except json.JSONDecodeError:
            print(f"{Color.YELLOW}Warning: Failed to parse GitHub response{Color.RESET}")

        return builds

    def _get_run_artifacts(self, run_id: str) -> List[dict]:
        """Get artifacts for a specific run"""
        try:
            # Use GitHub API to get artifacts
            result = subprocess.run(
                ["gh", "api", f"repos/:owner/:repo/actions/runs/{run_id}/artifacts"],
                capture_output=True,
                text=True,
                check=True
            )

            data = json.loads(result.stdout)
            return data.get("artifacts", [])

        except (subprocess.CalledProcessError, json.JSONDecodeError):
            return []


class Deployer:
    """Deploy builds to devices"""

    @staticmethod
    def check_android_devices() -> Tuple[bool, str]:
        """Check for connected Android devices"""
        try:
            result = subprocess.run(
                ["adb", "devices"],
                capture_output=True,
                text=True,
                check=True
            )

            # Parse device list (skip header line)
            lines = result.stdout.strip().split('\n')[1:]
            devices = [line.split('\t')[0] for line in lines if '\tdevice' in line]

            if not devices:
                return False, f"{Color.RED}No Android devices connected{Color.RESET}\n\nConnect a device and enable USB debugging."

            return True, f"Found {len(devices)} device(s): {', '.join(devices)}"

        except subprocess.CalledProcessError as e:
            return False, f"{Color.RED}Failed to check Android devices: {e}{Color.RESET}"

    @staticmethod
    def check_ios_devices() -> Tuple[bool, str]:
        """Check for connected iOS devices"""
        # Try ideviceinstaller first
        if shutil.which("ideviceinstaller"):
            try:
                result = subprocess.run(
                    ["ideviceinstaller", "--list-apps"],
                    capture_output=True,
                    text=True,
                    timeout=5
                )

                if result.returncode == 0:
                    return True, "iOS device connected"

            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                pass

        # Try ios-deploy as fallback
        if shutil.which("ios-deploy"):
            try:
                result = subprocess.run(
                    ["ios-deploy", "--detect"],
                    capture_output=True,
                    text=True,
                    timeout=5
                )

                if result.returncode == 0 and "Found" in result.stdout:
                    return True, "iOS device connected"

            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                pass

        return False, f"{Color.RED}No iOS devices connected{Color.RESET}\n\nConnect an iOS device via USB."

    @staticmethod
    def uninstall_android(package_name: str) -> bool:
        """Uninstall Android app"""
        print(f"\n{Color.CYAN}Uninstalling {package_name}...{Color.RESET}")

        try:
            result = subprocess.run(
                ["adb", "uninstall", package_name],
                capture_output=True,
                text=True
            )

            if result.returncode == 0:
                print(f"{Color.GREEN}✓ Successfully uninstalled{Color.RESET}")
                return True
            else:
                # App might not be installed, which is okay
                print(f"{Color.YELLOW}App not installed (or already removed){Color.RESET}")
                return True

        except subprocess.CalledProcessError as e:
            print(f"{Color.RED}✗ Uninstall failed: {e}{Color.RESET}")
            return False

    @staticmethod
    def deploy_android(apk_path: Path, force: bool = False) -> bool:
        """Deploy APK to Android device"""
        print(f"\n{Color.CYAN}Deploying {apk_path.name}...{Color.RESET}")

        try:
            # Uninstall first if force flag is set
            if force:
                # Extract package name from APK
                package_name = Deployer._get_android_package_name(apk_path)
                if package_name:
                    Deployer.uninstall_android(package_name)

            # Install APK (replace if exists)
            result = subprocess.run(
                ["adb", "install", "-r", str(apk_path)],
                capture_output=True,
                text=True
            )

            if result.returncode == 0:
                print(f"{Color.GREEN}✓ Successfully installed{Color.RESET}")
                return True
            else:
                print(f"{Color.RED}✗ Installation failed{Color.RESET}")
                print(result.stderr)
                return False

        except subprocess.CalledProcessError as e:
            print(f"{Color.RED}✗ Deployment failed: {e}{Color.RESET}")
            return False

    @staticmethod
    def _get_android_package_name(apk_path: Path) -> Optional[str]:
        """Extract package name from APK using aapt"""
        try:
            # Try to use aapt to get package name
            result = subprocess.run(
                ["aapt", "dump", "badging", str(apk_path)],
                capture_output=True,
                text=True
            )

            if result.returncode == 0:
                # Parse output for package name
                for line in result.stdout.split('\n'):
                    if line.startswith("package:"):
                        match = re.search(r"name='([^']+)'", line)
                        if match:
                            return match.group(1)

        except FileNotFoundError:
            # aapt not available, use hardcoded package name for this app
            pass

        # Fallback to hardcoded package name for this app
        return "com.repertoirecoach.repertoire_coach"

    @staticmethod
    def deploy_ios(ipa_path: Path) -> bool:
        """Deploy IPA to iOS device"""
        print(f"\n{Color.CYAN}Deploying {ipa_path.name}...{Color.RESET}")

        # Try ideviceinstaller first
        if shutil.which("ideviceinstaller"):
            try:
                result = subprocess.run(
                    ["ideviceinstaller", "-i", str(ipa_path)],
                    capture_output=True,
                    text=True
                )

                if result.returncode == 0:
                    print(f"{Color.GREEN}✓ Successfully installed{Color.RESET}")
                    return True
                else:
                    print(f"{Color.RED}✗ Installation failed{Color.RESET}")
                    print(result.stderr)
                    return False

            except subprocess.CalledProcessError as e:
                print(f"{Color.RED}✗ Deployment failed: {e}{Color.RESET}")
                return False

        # Try ios-deploy as fallback
        if shutil.which("ios-deploy"):
            try:
                result = subprocess.run(
                    ["ios-deploy", "--bundle", str(ipa_path)],
                    capture_output=True,
                    text=True
                )

                if result.returncode == 0:
                    print(f"{Color.GREEN}✓ Successfully installed{Color.RESET}")
                    return True
                else:
                    print(f"{Color.RED}✗ Installation failed{Color.RESET}")
                    print(result.stderr)
                    return False

            except subprocess.CalledProcessError as e:
                print(f"{Color.RED}✗ Deployment failed: {e}{Color.RESET}")
                return False

        print(f"{Color.RED}✗ No iOS deployment tool available{Color.RESET}")
        return False

    @staticmethod
    def download_github_artifact(build: Build, temp_dir: Path) -> Optional[Path]:
        """Download artifact from GitHub Actions"""
        print(f"\n{Color.CYAN}Downloading build from GitHub Actions...{Color.RESET}")
        run_display = f"#{build.run_number}" if build.run_number else f"ID {build.run_id}"
        print(f"  Run: {run_display}")
        print(f"  Artifact: {build.artifact_name}")

        try:
            # Download artifact (gh downloads as ZIP)
            download_dir = temp_dir / "download"
            download_dir.mkdir(exist_ok=True)

            print(f"{Color.CYAN}Downloading artifact...{Color.RESET}")
            result = subprocess.run(
                ["gh", "run", "download", build.run_id, "--name", build.artifact_name, "--dir", str(download_dir)],
                capture_output=True,
                text=True,
                check=True
            )

            # The artifact content is downloaded directly into the directory
            # Look for APK/IPA files recursively
            if build.platform == Platform.ANDROID:
                # Search for APK files recursively
                apk_files = list(download_dir.rglob("*.apk"))

                if not apk_files:
                    # Check if there are any ZIP files that need extraction
                    zip_files = list(download_dir.rglob("*.zip"))
                    for zip_file in zip_files:
                        print(f"{Color.CYAN}Extracting {zip_file.name}...{Color.RESET}")
                        with zipfile.ZipFile(zip_file, 'r') as zf:
                            zf.extractall(download_dir)

                    # Try finding APK again
                    apk_files = list(download_dir.rglob("*.apk"))

                if apk_files:
                    print(f"{Color.GREEN}✓ Found {apk_files[0].name}{Color.RESET}")
                    return apk_files[0]
            else:
                # Search for IPA files recursively
                ipa_files = list(download_dir.rglob("*.ipa"))

                if not ipa_files:
                    # Check if there are any ZIP files that need extraction
                    zip_files = list(download_dir.rglob("*.zip"))
                    for zip_file in zip_files:
                        print(f"{Color.CYAN}Extracting {zip_file.name}...{Color.RESET}")
                        with zipfile.ZipFile(zip_file, 'r') as zf:
                            zf.extractall(download_dir)

                    # Try finding IPA again
                    ipa_files = list(download_dir.rglob("*.ipa"))

                if ipa_files:
                    print(f"{Color.GREEN}✓ Found {ipa_files[0].name}{Color.RESET}")
                    return ipa_files[0]

            print(f"{Color.RED}✗ Build file not found in artifact{Color.RESET}")
            print(f"\nFiles in download directory:")
            for f in download_dir.rglob("*"):
                if f.is_file():
                    print(f"  - {f.relative_to(download_dir)}")
            return None

        except subprocess.CalledProcessError as e:
            print(f"{Color.RED}✗ Download failed: {e}{Color.RESET}")
            if e.stderr:
                print(e.stderr)
            return None
        except zipfile.BadZipFile as e:
            print(f"{Color.RED}✗ Failed to extract ZIP: {e}{Color.RESET}")
            return None


def show_menu(builds: List[Build]) -> Optional[Build]:
    """Show interactive menu for build selection"""
    if not builds:
        print(f"{Color.YELLOW}No builds available{Color.RESET}")
        return None

    print(f"\n{Color.BOLD}Available builds:{Color.RESET}\n")

    for i, build in enumerate(builds, 1):
        print(f"[{Color.CYAN}{i}{Color.RESET}] {build}\n")

    while True:
        try:
            choice = input(f"Select build to deploy [1-{len(builds)}] (or 'q' to quit): ").strip()

            if choice.lower() == 'q':
                return None

            index = int(choice) - 1
            if 0 <= index < len(builds):
                return builds[index]
            else:
                print(f"{Color.YELLOW}Invalid choice. Please enter a number between 1 and {len(builds)}{Color.RESET}")

        except ValueError:
            print(f"{Color.YELLOW}Invalid input. Please enter a number or 'q'{Color.RESET}")
        except KeyboardInterrupt:
            print("\n")
            return None


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Deploy Android or iOS builds to connected devices",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                                    # Interactive menu
  %(prog)s --local                            # Use local build (interactive)
  %(prog)s --github                           # Use GitHub build (interactive)
  %(prog)s --platform ios --local             # Deploy local iOS build
  %(prog)s --run 42 --build-type debug        # Deploy specific GitHub run by number
  %(prog)s --run-id 12345678 --force          # Uninstall first, then deploy (using run ID)
        """
    )

    parser.add_argument(
        "--platform",
        choices=["android", "ios"],
        default="android",
        help="Platform to deploy (default: android)"
    )

    parser.add_argument(
        "--local",
        action="store_true",
        help="Use local build"
    )

    parser.add_argument(
        "--github",
        action="store_true",
        help="Use GitHub Actions artifact"
    )

    parser.add_argument(
        "--run-id",
        "--run",
        type=str,
        dest="run_id",
        help="Specific GitHub Actions run number (e.g., 42) or run ID"
    )

    parser.add_argument(
        "--build-type",
        choices=["debug", "release"],
        help="Build type (debug or release)"
    )

    parser.add_argument(
        "--force",
        action="store_true",
        help="Uninstall existing app before installing (useful for switching between debug/release)"
    )

    args = parser.parse_args()

    # Determine platform
    platform_choice = Platform(args.platform)

    # Check dependencies based on what user wants to do
    if args.github or args.run_id:
        ok, msg = DependencyChecker.check_gh()
        if not ok:
            print(msg)
            return 1

    if platform_choice == Platform.ANDROID:
        ok, msg = DependencyChecker.check_adb()
        if not ok:
            print(msg)
            return 1
    else:
        ok, msg = DependencyChecker.check_ios_deploy()
        if not ok:
            print(msg)
            return 1

    # Find repository root
    repo_root = Path(__file__).parent.parent
    finder = BuildFinder(repo_root)

    # Find available builds
    builds = []

    if args.local:
        # Only local builds
        if platform_choice == Platform.ANDROID:
            builds = finder.find_local_android_builds()
        else:
            builds = finder.find_local_ios_builds()
    elif args.github or args.run_id:
        # Only GitHub builds
        builds = finder.find_github_builds(platform_choice)

        # Filter by run ID or run number if specified
        if args.run_id:
            # Try to match as run number first (shorter), then fall back to run ID
            builds = [b for b in builds if
                     (b.run_number and str(b.run_number) == args.run_id) or
                     b.run_id == args.run_id]

        # Filter by build type if specified
        if args.build_type:
            builds = [b for b in builds if b.build_type == args.build_type]
    else:
        # All builds
        if platform_choice == Platform.ANDROID:
            builds.extend(finder.find_local_android_builds())
        else:
            builds.extend(finder.find_local_ios_builds())

        # Only try GitHub if gh is available
        if DependencyChecker.check_command("gh"):
            builds.extend(finder.find_github_builds(platform_choice))

    # Sort builds by date (newest first)
    builds.sort(key=lambda b: b.date or datetime.min, reverse=True)

    # Select build
    if not builds:
        print(f"{Color.YELLOW}No builds found{Color.RESET}")
        print(f"\nTry building first with: {Color.CYAN}scripts/build.sh {args.platform}{Color.RESET}")
        return 1

    # Auto-select if only one build or specific run/build-type given
    auto_select = len(builds) == 1 or (args.run_id and args.build_type)

    if auto_select:
        selected_build = builds[0]
        print(f"\n{Color.CYAN}Auto-selecting build:{Color.RESET}")
        print(f"{selected_build}\n")
    else:
        # Show interactive menu
        selected_build = show_menu(builds)
        if not selected_build:
            print("Cancelled")
            return 0

    # Check for connected devices
    if selected_build.platform == Platform.ANDROID:
        ok, msg = Deployer.check_android_devices()
    else:
        ok, msg = Deployer.check_ios_devices()

    if not ok:
        print(f"\n{msg}")
        return 1

    print(f"{Color.GREEN}{msg}{Color.RESET}")

    # Deploy
    if selected_build.source == BuildSource.LOCAL:
        # Deploy local build
        if selected_build.platform == Platform.ANDROID:
            success = Deployer.deploy_android(selected_build.path, force=args.force)
        else:
            success = Deployer.deploy_ios(selected_build.path)
    else:
        # Download and deploy GitHub build
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            build_file = Deployer.download_github_artifact(selected_build, temp_path)

            if not build_file:
                return 1

            if selected_build.platform == Platform.ANDROID:
                success = Deployer.deploy_android(build_file, force=args.force)
            else:
                success = Deployer.deploy_ios(build_file)

    return 0 if success else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n{Color.YELLOW}Cancelled{Color.RESET}")
        sys.exit(0)
