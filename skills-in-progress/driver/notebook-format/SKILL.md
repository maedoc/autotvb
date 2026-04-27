---
name: tvb-driver-notebook-format
description: Ensure valid .ipynb JSON serialization and Python string hygiene. Use when creating or editing Jupyter notebooks to prevent SyntaxError from literal backslash-n characters or raw newlines inside quoted strings. Triggers on .ipynb, notebook, json, SyntaxError, serialization.
---

# TVB Driver: Notebook Formatting & Validation

## The Literal Backslash-n Trap
When generating `.ipynb` files, NEVER write a code cell source as a single JSON string where newline characters are encoded as `\n` (backslash, n):

Bad raw JSON:
```json
"source": "from tvb.simulator.lab import *\\nimport numpy\\n"
```

Instead, use a JSON array of strings with newline characters naturally terminating each line:

Good raw JSON:
```json
"source": [
    "from tvb.simulator.lab import *\n",
    "import numpy\n"
]
```

This distinction matters because `\\n` in a JSON string decodes to a literal backslash and `n`, which Python misinterprets as a line continuation.

## Python String Hygiene Inside Cells
Do NOT include raw newline characters inside double-quoted Python strings in a code cell:

```python
ax.set_title("Post-stimulus FC (fast variable)
600 ms → 5000 ms")
```

Use one of:

```python
ax.set_title("Post-stimulus FC (fast variable)\n600 ms → 5000 ms")
# or keep it on one line
ax.set_title("Post-stimulus FC (fast variable); 600 ms → 5000 ms")
```

## Validation Checklist
Before executing:
1. `python -m json.tool sandbox/workflow.ipynb > /dev/null` — confirms valid JSON.
2. Convert to script and syntax-check: `jupyter nbconvert --to script sandbox/workflow.ipynb --stdout | python -m py_compile -` — confirms valid Python syntax.
3. Inspect the raw `.ipynb` file: code cell sources must be JSON arrays of strings with real line breaks, never a single string containing literal backslash-n.