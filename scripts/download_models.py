import os
import sys
import yaml
from pathlib import Path
import logging

try:
    import transformers
    import huggingface_hub
except ImportError:
    print("Error: transformers and huggingface_hub must be installed.")
    sys.exit(1)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("download_models")

def load_config(config_path):
    with open(config_path, "r") as f:
        return yaml.safe_load(f)

def download_models(config_file: Path):
    if not config_file.exists():
        logger.error(f"Config file not found: {config_file}")
        sys.exit(1)

    config = load_config(config_file)
    
    # Iterate over all versions in the config
    for version_key, version_config in config.items():
        logger.info(f"Downloading models for {version_key}...")
        
        # Segmentation Model
        seg_config = version_config.get("SEGMENTATION_MODEL")
        if seg_config:
            logger.info(f"  - Segmentation Model: {seg_config['REPO']}")
            transformers.AutoModelForTokenClassification.from_pretrained(
                pretrained_model_name_or_path=seg_config["REPO"],
                revision=seg_config["REVISION"]
            )
            logger.info(f"  - Segmentation Tokenizer: {seg_config['TOKENIZER']}")
            huggingface_hub.hf_hub_download(
                repo_id=seg_config["TOKENIZER"], 
                filename="tokenizer.json"
            )

        # Statement Model
        stmt_config = version_config.get("STATEMENT_MODEL")
        if stmt_config:
            logger.info(f"  - Statement Model: {stmt_config['REPO']}")
            transformers.T5ForConditionalGeneration.from_pretrained(
                stmt_config["REPO"], 
                revision=stmt_config["REVISION"]
            )
            logger.info(f"  - Statement Tokenizer: {stmt_config['TOKENIZER']}")
            transformers.RobertaTokenizer.from_pretrained(
                stmt_config["TOKENIZER"]
            )

if __name__ == "__main__":
    # Assuming this is run from the root or where pylingual package is accessible
    # adjusted to point to where it will likely be in the container or repo
    possible_config_paths = [
        Path("pylingual/pylingual/decompiler_config.yaml"), # Repository structure
        Path("/app/pylingual/pylingual/decompiler_config.yaml"), # Container structure
    ]
    
    config_path = None
    for p in possible_config_paths:
        if p.exists():
            config_path = p
            break
            
    if not config_path:
        logger.error("Could not find decompiler_config.yaml")
        sys.exit(1)
        
    download_models(config_path)
