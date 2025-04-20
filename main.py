from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import os
from huggingface_hub import login
from langchain.vectorstores import FAISS
from langchain.embeddings import HuggingFaceEmbeddings
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.document_loaders import TextLoader
from epub_to_txt import EpubToTxt
from localllm import LocalLLM
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

app = Flask(__name__)
UPLOAD_FOLDER = 'book_txt_files'
BOOKNLP_FOLDER = 'BookNLP'
ENTITIES_FOLDER = os.path.join(BOOKNLP_FOLDER, UPLOAD_FOLDER)
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(ENTITIES_FOLDER, exist_ok=True)
chat_sessions = {}

@app.route('/get_response', methods=['POST'])
def get_response():
    user_input = request.form.get('message')
    character_name = request.form.get('name')
    book_path = request.form.get('fileName')
    if character_name not in chat_sessions:
        print(f"Loading '{book_path}'")
        chunks = load_and_split_book(book_path)
        print("Building semantic vector index")
        vectorstore = create_vector_store(chunks)
        print(f"Chat with {character_name}")
        chat_sessions[character_name] = build_character_chain(vectorstore, character_name)
    chat = chat_sessions[character_name]
    response = clean_response(chat(user_input))
    db = firestore.client()
    doc_ref = db.collection('characters').document(character_name)
    doc = doc_ref.get()
    if doc.exists:
        document_data = doc.to_dict()
        messages = document_data['messages']
        messages.insert(0, response)
        doc_ref.update({
            'messages': messages
        })
    else:
        print('Document does not exist')
    return jsonify({
        'status': 'success',
        'response': response
    })

    
@app.route('/upload_epub', methods=['POST'])
def upload_epub():
    if 'file' not in request.files:
        return jsonify({'error': 'Missing file parameter'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    
    filename = secure_filename(file.filename)
    epub_path = os.path.join(UPLOAD_FOLDER, filename)
    file.save(epub_path)
    txt_path = epub_path.replace('.epub', '.txt')
    try:
        converter = EpubToTxt(epub_path)
        converter.convert_to_txt(txt_path)
        with open(txt_path, 'r', encoding='utf-8') as f:
            content = f.read()
        os.remove(epub_path)
        converter.apply_book_nlp(txt_path, BOOKNLP_FOLDER)
        main_chars = converter.get_two_main_characters(BOOKNLP_FOLDER + '/' + txt_path.replace('.txt', '.entities'))
        db = firestore.client()
        for char in main_chars:
            data = {
                'name': char,
                'file': txt_path,
                'messages': [],
                'avatar': ''
            }
            doc_ref = db.collection('characters').document(char)
            doc_ref.set(data)
        for filename in os.listdir(ENTITIES_FOLDER):
            file_path = os.path.join(ENTITIES_FOLDER, filename)
            if os.path.isfile(file_path):
                os.remove(file_path)
        return jsonify({
            'status': 'success',
            'text': content
        })
    except Exception as e:
        print(e)
        return jsonify({'error': str(e)}), 500

def load_and_split_book(book_path):
    loader = TextLoader(book_path)
    documents = loader.load()
    splitter = RecursiveCharacterTextSplitter(chunk_size=1024, chunk_overlap=88)
    return splitter.split_documents(documents)

def create_vector_store(chunks):
    embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
    vectorstore = FAISS.from_documents(chunks, embeddings)
    return vectorstore

def build_character_chain(vectorstore, character_name):
    retriever = vectorstore.as_retriever(search_kwargs={"k": 10})

    llm = LocalLLM()

    def ask_character(question):
        docs = retriever.get_relevant_documents(question + ', ' + character_name)
        context = "\n\n".join([doc.page_content for doc in docs])

        prompt = (
            f"You are {character_name}, a fictional character from a fantasy novel. "
            f"You're having a real conversation with the user, based on your personality, experiences, and memories from the story. "
            f"Speak like yourself — not like an author, philosopher, or narrator. Be honest, vulnerable, and specific when answering personal questions.\n\n"
            f"Give examples from your life. Let emotion guide your words. You don't have to share everything — you can hesitate, trail off, or avoid things that hurt too much.\n\n"
            f"Context:\n{context}\n\n"
            f"User: {question}\n"
            f"{character_name}:"
        )  
        
        return llm._call(prompt)
        
    return ask_character

def clean_response(response):
    response = response.split('\n')[0]
    if (len(response.split('.')) > 1):
        response = '.'.join(response.split('.')[:-1])
    return response


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)
