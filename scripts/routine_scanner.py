import re
import json
from pathlib import Path

class RoutineScanner:
    def __init__(self, bank_asm_path: str):
        self.bank_asm_path = Path(bank_asm_path)
        # Matches labels that start at the beginning of a line
        self.label_pattern = re.compile(r"^([A-Za-z0-9_]+):")
        # Matches return instructions
        self.return_pattern = re.compile(r"\b(RTS|RTL|RTI)\b", re.IGNORECASE)

    def scan(self) -> list:
        routines = []
        if not self.bank_asm_path.exists():
            print(f"Error: {self.bank_asm_path} not found.")
            return routines

        current_routine = None
        current_name = ""
        
        with open(self.bank_asm_path, 'r') as f:
            for line in f:
                stripped = line.strip()
                label_match = self.label_pattern.match(stripped)
                
                if label_match:
                    # If we were already in a routine, finish it (even if no RTS found)
                    if current_routine:
                        routines.append({
                            "name": current_name,
                            "code": "\n".join(current_routine)
                        })
                    
                    current_name = label_match.group(1)
                    current_routine = [line.rstrip()]
                    continue
                
                if current_routine is not None:
                    current_routine.append(line.rstrip())
                    
                    if self.return_pattern.search(stripped):
                        routines.append({
                            "name": current_name,
                            "code": "\n".join(current_routine)
                        })
                        current_routine = None
                        current_name = ""
        
        return routines

if __name__ == "__main__":
    import sys
    bank_file = sys.argv[1] if len(sys.argv) > 1 else "/Users/scawful/Code/usdasm/bank_00.asm"
    scanner = RoutineScanner(bank_file)
    routines = scanner.scan()
    output_file = Path(bank_file).stem + "_routines.json"
    with open(output_file, "w") as f:
        json.dump(routines, f, indent=2)
    print(f"Scanned {len(routines)} routines from {bank_file}.")
