import re
import json
from pathlib import Path

class SchemaExtractor:
    def __init__(self, server_py_path: str):
        self.server_py_path = Path(server_py_path)

    def extract(self) -> list:
        tools = []
        if not self.server_py_path.exists():
            return tools

        content = self.server_py_path.read_text()
        
        # Simpler approach: find @mcp.tool and then the def line
        sections = content.split("@mcp.tool()")
        for section in sections[1:]: # Skip text before first tool
            # Find function name and args
            func_match = re.search(r"def\s+([a-zA-Z0-9_]+)\((.*?)\)", section)
            if not func_match:
                continue
            
            name = func_match.group(1)
            args = func_match.group(2)
            
            # Find docstring
            doc_match = re.search(r'"""(.*?)"""', section, re.DOTALL)
            description = doc_match.group(1).strip() if doc_match else ""
            
            tools.append({
                "name": name,
                "arguments": args.strip(),
                "description": description.split('\n')[0]
            })
        
        return tools

if __name__ == "__main__":
    extractor = SchemaExtractor("/Users/scawful/Code/yaze-mcp/server.py")
    schema = extractor.extract()
    output_path = "yaze_mcp_schema.json"
    with open(output_path, "w") as f:
        json.dump(schema, f, indent=2)
    print(f"Extracted {len(schema)} tools to {output_path}")