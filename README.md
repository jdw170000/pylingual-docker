# PyLingual Docker

This repository provides Docker images for [PyLingual](https://pylingual.io), a powerful Python bytecode decompiler.

We provide four image variants to balance between image size and pre-installed compatibility.

| Variant | Base Python | Pre-installed Pythons | Purpose |
| :--- | :--- | :--- | :--- |
| `lite-cli` | 3.14 | 3.14 | Thin wrapper around PyLingual's CLI. |
| `full-cli` | 3.14 | 3.6 - 3.14 | CLI tool with all Python versions pre-installed. |
| `lite-server` | 3.14 | 3.14 | Lightweight REST API. |
| `full-server` | 3.14 | 3.6 - 3.14 | REST API with all Python versions pre-installed. |

## Building the Images

All images are built from the same `Dockerfile` using different targets.

```bash
# Lite CLI
docker build --target lite-cli -t pylingual:lite-cli .

# Full CLI
docker build --target full-cli -t pylingual:full-cli .

# Lite Server
docker build --target lite-server -t pylingual:lite-server .

# Full Server
docker build --target full-server -t pylingual:full-server .
```

## Using the CLI

Run the CLI image and mount the directory containing your `.pyc` files.

```bash
docker run --rm -v $(pwd):/data pylingual:lite-cli /data/example.pyc -o /data
```

## Using the Server

Run the server image and map port 8000.

```bash
docker run -d -p 8000:8000 pylingual:lite-server
```

### API Endpoint: `/decompile`

Decompile a `.pyc` file by sending a POST request to the `/decompile` endpoint.

**Example with curl:**

```bash
curl -X POST http://localhost:8000/decompile \
  -F "file=@example.pyc"
```

**Response Format:**

```json
{
  "decompiled_source": "<decompiled source code>",
  "equivalence_report": ["..."],
  "version": "3.<minor version>"
}
```
