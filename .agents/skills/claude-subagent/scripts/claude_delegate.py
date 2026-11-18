#!/usr/bin/env python3
"""Compatibility name for delegate.py (dispatches to Claude unless --agent says otherwise)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from delegate import main  # noqa: E402

if __name__ == '__main__':
    sys.exit(main())
