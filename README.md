# PyLingual Docker

This repository provides Docker images for [PyLingual](https://pylingual.io), a powerful Python bytecode decompiler.

We provide four image variants to balance between image size and pre-installed compatibility.

| Variant | Base Python | Pre-installed Pythons | Purpose |
| :--- | :--- | :--- | :--- |
| `lite-cli` | 3.14 | 3.14 | Thin wrapper around PyLingual's CLI. |
| `full-cli` | 3.14 | 3.6 - 3.14 | CLI tool with all supported Python versions pre-installed. |
| `lite-server` | 3.14 | 3.14 | Lightweight REST API. (Requires internet for first model download) |
| `full-server` | 3.14 | 3.6 - 3.14 | REST API with all supported Python versions pre-installed and models pre-loaded for offline use. |

## Building the Images

All images are built from the same `Dockerfile` using different targets.

**Note:** The `full` images download several gigabytes of models during the build process.

```bash
# Lite CLI
docker build --target lite-cli -t pylingual:lite-cli .

# Full CLI (Offline capable)
docker build --target full-cli -t pylingual:full-cli .

# Lite Server
docker build --target lite-server -t pylingual:lite-server .

# Full Server (Offline capable)
docker build --target full-server -t pylingual:full-server .
```

### Build Requirements

The build process uses `docker buildx` features (Mounts). Ensure you have a recent version of Docker.
Intermediate build stages are used to keep the final image size optimized.

## Using the CLI

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
