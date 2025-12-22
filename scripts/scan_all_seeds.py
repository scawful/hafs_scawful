import os
import re
import json
from pathlib import Path

class RoutineScanner:
    def __init__(self, search_dirs: list[str]):
        self.search_dirs = [Path(d) for d in search_dirs]
        self.label_pattern = re.compile(r"^([A-Za-z0-9_]+):")
        self.return_pattern = re.compile(r"\b(RTS|RTL|RTI)\b", re.IGNORECASE)

    def scan_file(self, file_path: Path) -> list:
        routines = []
        if not file_path.exists():
            return routines

        current_routine = None
        current_name = ""
        
        try:
            with open(file_path, 'r', errors='replace') as f:
                for line in f:
                    stripped = line.strip()
                    label_match = self.label_pattern.match(stripped)
                    
                    if label_match:
                        if current_routine:
                            routines.append({
                                "name": current_name,
                                "code": "\n".join(current_routine),
                                "file": str(file_path.name)
                            })
                        
                        current_name = label_match.group(1)
                        current_routine = [line.rstrip()]
                        continue
                    
                    if current_routine is not None:
                        current_routine.append(line.rstrip())
                        
                        if self.return_pattern.search(stripped):
                            routines.append({
                                "name": current_name,
                                "code": "\n".join(current_routine),
                                "file": str(file_path.name)
                            })
                            current_routine = None
                            current_name = ""
        except Exception as e:
            print(f"Error scanning {file_path}: {e}")
        
        return routines

    def scan_all(self, output_path: str):
        all_routines = []
        for search_dir in self.search_dirs:
            if not search_dir.exists():
                continue
            print(f"Scanning directory: {search_dir}")
            for ext in ['*.asm', '*.s']:
                for file_path in search_dir.glob(f"**/{ext}"):
                    # Skip common build or temp dirs
                    if 'build' in str(file_path) or '.git' in str(file_path):
                        continue
                    routines = self.scan_file(file_path)
                    all_routines.extend(routines)
                    print(f"  Scanned {len(routines)} routines from {file_path.name}")
        
        with open(output_path, "w") as f:
            json.dump(all_routines, f, indent=2)
        print(f"Total routines saved to {output_path}: {len(all_routines)}")

if __name__ == "__main__":
    scanner = RoutineScanner([
        "/Users/scawful/Code/usdasm",
        "/Users/scawful/Code/Oracle-of-Secrets/Items",
        "/Users/scawful/Code/Oracle-of-Secrets/Core",
        "/Users/scawful/Code/Oracle-of-Secrets/Dungeons",
        "/Users/scawful/Code/Oracle-of-Secrets/Overworld"
    ])
    scanner.scan_all("master_routines_library.json")
