from flask import Flask, request, jsonify
from flask_cors import CORS
import logging
from langchain_ollama.llms import OllamaLLM
from langchain_core.prompts import PromptTemplate
import os
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Model configuration
MODEL_NAME = "mistral:latest"  # Same model as in your working Streamlit app

# Initialize LangChain Ollama integration
try:
    llm = OllamaLLM(model=MODEL_NAME)
    logger.info(f"OllamaLLM initialized with model: {MODEL_NAME}")
except Exception as e:
    logger.error(f"Error initializing OllamaLLM: {e}")
    llm = None

# Templates for generating LinkedIn posts
generate_template = """
You are a professional LinkedIn post generator. Create an engaging and professional post based on the following context.
The post should follow LinkedIn best practices, include relevant hashtags, and be appropriately formatted.

USER CONTEXT:
{context}

LINKEDIN POST:
"""

regenerate_template = """
You are a professional LinkedIn post generator. Create a NEW engaging and professional post based on the following context.
This should be completely different from any previous post.
The post should follow LinkedIn best practices, include relevant hashtags, and be appropriately formatted.

USER CONTEXT:
{context}

NEW LINKEDIN POST:
"""

reduce_template = """
Make this LinkedIn post more concise while preserving the key message.
Aim for about half the original length.

ORIGINAL POST:
{post}

SHORTER LINKEDIN POST:
"""

elaborate_template = """
Expand this LinkedIn post with more details, examples, or insights.
Make it more compelling and detailed while maintaining professionalism.

ORIGINAL POST:
{post}

EXPANDED LINKEDIN POST:
"""

def is_ollama_available():
    """Check if Ollama is available by attempting to generate a short response."""
    if llm is None:
        return False
    
    try:
        # Try to generate a simple response to check if Ollama is responding
        response = llm.invoke("Say hello in one word.")
        return True
    except Exception as e:
        logger.error(f"Error checking Ollama availability: {e}")
        return False

def generate_linkedin_post(context):
    """Generate a LinkedIn post using the LangChain OllamaLLM."""
    prompt = PromptTemplate.from_template(generate_template)
    
    try:
        # Set a timeout for the generation
        start_time = time.time()
        generated_text = llm.invoke(prompt.format(context=context))
        elapsed_time = time.time() - start_time
        logger.info(f"Generated text in {elapsed_time:.2f} seconds")
        
        return generated_text
    except Exception as e:
        logger.exception(f"Error generating LinkedIn post: {e}")
        return f"Error generating LinkedIn post: {str(e)}"

def regenerate_linkedin_post(context):
    """Generate a completely new LinkedIn post."""
    prompt = PromptTemplate.from_template(regenerate_template)
    
    try:
        generated_text = llm.invoke(prompt.format(context=context))
        return generated_text
    except Exception as e:
        logger.exception(f"Error regenerating LinkedIn post: {e}")
        return f"Error regenerating LinkedIn post: {str(e)}"

def modify_linkedin_post(post, action):
    """Modify an existing LinkedIn post (reduce or elaborate)."""
    if action == "reduce":
        prompt = PromptTemplate.from_template(reduce_template)
    elif action == "elaborate":
        prompt = PromptTemplate.from_template(elaborate_template)
    else:
        return f"Invalid action: {action}"
    
    try:
        modified_text = llm.invoke(prompt.format(post=post))
        return modified_text
    except Exception as e:
        logger.exception(f"Error modifying LinkedIn post: {e}")
        return f"Error modifying LinkedIn post: {str(e)}"

@app.route('/', methods=['GET'])
def root():
    """Root endpoint with API status."""
    ollama_available = is_ollama_available()
    
    return jsonify({
        "status": "API is running",
        "ollama_available": ollama_available,
        "model": MODEL_NAME,
        "endpoints": [
            "/",
            "/health",
            "/generate_post",
            "/regenerate_post",
            "/modify_post"
        ]
    })

@app.route('/health', methods=['GET'])
def health_check():
    """Simple health check endpoint."""
    return jsonify({"status": "ok"})

@app.route('/generate_post', methods=['POST'])
def generate_post():
    """Generate a LinkedIn post based on the provided context."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400
    
    data = request.get_json()
    if 'context' not in data:
        return jsonify({"error": "Missing 'context' field"}), 400
    
    if not is_ollama_available():
        return jsonify({"error": "Ollama service is not available"}), 500
    
    logger.info(f"Generating LinkedIn post for context: {data['context'][:50]}...")
    generated_text = generate_linkedin_post(data['context'])
    
    if isinstance(generated_text, str) and generated_text.startswith("Error"):
        return jsonify({"error": generated_text}), 500
    
    return jsonify({"post": generated_text.strip()})

@app.route('/regenerate_post', methods=['POST'])
def regenerate_post():
    """Generate a new LinkedIn post with a different approach."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400
    
    data = request.get_json()
    if 'context' not in data:
        return jsonify({"error": "Missing 'context' field"}), 400
    
    if not is_ollama_available():
        return jsonify({"error": "Ollama service is not available"}), 500
    
    logger.info(f"Regenerating LinkedIn post for context: {data['context'][:50]}...")
    generated_text = regenerate_linkedin_post(data['context'])
    
    if isinstance(generated_text, str) and generated_text.startswith("Error"):
        return jsonify({"error": generated_text}), 500
    
    return jsonify({"post": generated_text.strip()})

@app.route('/modify_post', methods=['POST'])
def modify_post():
    """Modify the existing post according to the action (reduce or elaborate)."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400
    
    data = request.get_json()
    required_fields = ['context', 'current_post', 'action']
    missing_fields = [field for field in required_fields if field not in data]
    
    if missing_fields:
        return jsonify({"error": f"Missing fields: {', '.join(missing_fields)}"}), 400
    
    if not is_ollama_available():
        return jsonify({"error": "Ollama service is not available"}), 500
    
    logger.info(f"Modifying LinkedIn post with action: {data['action']}")
    
    if data['action'] not in ["reduce", "elaborate"]:
        return jsonify({"error": "Invalid action. Use 'reduce' or 'elaborate'."}), 400
    
    modified_text = modify_linkedin_post(data['current_post'], data['action'])
    
    if isinstance(modified_text, str) and modified_text.startswith("Error"):
        return jsonify({"error": modified_text}), 500
    
    return jsonify({"post": modified_text.strip()})

if __name__ == "__main__":
    print("\n" + "="*80)
    print("LinkedIn Post Generator API using LangChain and Ollama")
    print("="*80)
    
    # Make sure the model is loaded
    ollama_available = is_ollama_available()
    print(f"Ollama availability: {'Available' if ollama_available else 'Not available'}")
    print(f"Using model: {MODEL_NAME}")

    if not ollama_available:
        print("\nIMPORTANT: Ollama service is not responding.")
        print("1. Make sure Ollama is running with: ollama serve")
        print(f"2. Make sure the model is available with: ollama pull {MODEL_NAME}")
        print("3. Check your system resources (RAM, disk space)")
    
    print("\nAPI is running at: http://localhost:8000")
    print("="*80 + "\n")
    
    app.run(host="0.0.0.0", port=8000, debug=True)