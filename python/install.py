import argparse
import os
import subprocess
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser("Install python package")
    parser.add_argument("--prefix", help="Install prefix", required=True)
    parser.add_argument(
        "--python", help="Python executable to use for setup.py", required=True
    )
    parser.add_argument(
        "--site-packages-dir",
        help="The site-packages directory relative to the prefix",
        required=True,
    )
    parser.add_argument(
        "--develop", help="Install with setup.py develop", action="store_true"
    )

    args = parser.parse_args()

    prefix = Path(args.prefix)
    site_packages_dir = Path(args.site_packages_dir)
    full_site_packages_dir = prefix / site_packages_dir
    full_site_packages_dir.mkdir(parents=True, exist_ok=True)
    if args.develop:
        action = "develop"
    else:
        action = "install"

    subprocess.run(
        [args.python, "setup.py", action]
        + ["--prefix", prefix],
        env={
            **os.environ,
            "PYTHONPATH": f"{os.getenv('PYTHONPATH')}{os.pathsep}{full_site_packages_dir}",
        },
        check=True,
    )


if __name__ == "__main__":
    main()
