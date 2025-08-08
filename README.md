<img width="617" alt="inkborne_logo" src="https://github.com/user-attachments/assets/6806bdb8-2c15-4114-9ee3-081beb7be3f2" />

# Inkborne
The Inkborne app brings your favorite book characters to life by allowing you to chat with them. The user must first upload an epub to the book with the characters they want to chat with. The BookNLP python package is then used to process the book text and retrieve the two main characters of the book. The user is then able to communicate with a book character, via text messaging. Each query is passed through a RAG model combined with a pretrained Mistral-Instruct pre-trained LLM model to generate a response. In other words, the query is compared against chunks of text in the book and the chunks that best match the query are used as context for the llm model. From this context, the llm model then generates a response in the book character's point of view.

Here is a demo of the app:
https://github.com/user-attachments/assets/c308cfe9-01ec-445f-bde8-19db9249212d

Screenshots:
![Screenshot 2025-04-19 at 8 27 17 PM](https://github.com/user-attachments/assets/90724c5a-b9a2-42d9-8dfa-b234ddd41d23)
![Screenshot 2025-04-19 at 8 26 39 PM](https://github.com/user-attachments/assets/feb43c9d-e07d-4547-969a-78c57071a13d)
![IMG_4075](https://github.com/user-attachments/assets/5fad656a-ed59-4e5d-92c7-bd858c69b7f5)
![IMG_4074](https://github.com/user-attachments/assets/8e90a31b-c6b6-47b6-aca4-6beb36a7b589)
