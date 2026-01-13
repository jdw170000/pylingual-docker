import tempfile
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, UploadFile, HTTPException
from pylingual import decompile

app = FastAPI(title="PyLingual Server")

@app.post("/decompile")
async def decompile_pyc(
    file: UploadFile = File(...),
    version: Optional[str] = None,
    top_k: int = 10,
    trust_lnotab: bool = False
):
    """
    Decompiles an uploaded .pyc file.
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="Filename missing")
    
    if not file.filename.endswith((".pyc")):
        raise HTTPException(status_code=400, detail="Only .pyc files are supported")

    # Create a temporary file to store the uploaded content
    with tempfile.NamedTemporaryFile(delete=False, suffix=".pyc") as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = Path(tmp.name)

    try:
        # Perform decompilation
        result = decompile(
            pyc=tmp_path,
            version=version,
            top_k=top_k,
            trust_lnotab=trust_lnotab
        )
        
        return {
            "decompiled_source": result.decompiled_source,
            "equivalence_report": list(str(eq_result) for eq_result in result.equivalence_results),
            "version": str(result.version)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Clean up the temporary file
        if tmp_path.exists():
            tmp_path.unlink()

@app.get("/health")
def health_check():
    return {"status": "ok"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
