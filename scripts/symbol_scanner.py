import re
import json
from pathlib import Path

class SymbolScanner:
    def __init__(self, ram_asm_path: str):
        self.ram_asm_path = Path(ram_asm_path)
        # Matches: LABEL = $XXXXXX or LABEL = $XXXX
        self.symbol_pattern = re.compile(r"^([A-Za-z0-9_]+)\s+=\s+(\$[0-9A-Fa-f]+)")

    def scan(self) -> dict:
        symbol_map = {}
        if not self.ram_asm_path.exists():
            print(f"Error: {self.ram_asm_path} not found.")
            return symbol_map

        with open(self.ram_asm_path, 'r') as f:
            for line in f:
                match = self.symbol_pattern.match(line.strip())
                if match:
                    label, addr = match.groups()
                    # Normalize to 24-bit if possible
                    if len(addr) == 5: # $XXXX
                        # Naive: assume $7E bank for RAM symbols if 16-bit
                        # This is a common pattern in ALTTP disassembly
                        full_addr = f"$7E{addr[1:]}"
                        symbol_map[full_addr] = label
                    
                    symbol_map[addr.upper()] = label
        
        return symbol_map

if __name__ == "__main__":
    scanner = SymbolScanner("/Users/scawful/Code/Oracle-of-Secrets/Core/ram.asm")
    symbols = scanner.scan()
    with open("symbols_map.json", "w") as f:
        json.dump(symbols, f, indent=2)
    print(f"Scanned {len(symbols)} symbols.")
