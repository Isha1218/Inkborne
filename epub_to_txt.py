from booknlp.booknlp import BookNLP
from pathlib import Path
import os
import torch
import csv
import pandas as pd
import ebooklib
from bs4 import BeautifulSoup
from ebooklib import epub

class EpubToTxt:
    file = ''

    def __init__(self, file):
        self.file = file

    def convert_to_txt(self, dest_path):
        book = epub.read_epub(self.file)
        paragraphs = []
        for item in book.get_items():
            if item.get_type() == ebooklib.ITEM_DOCUMENT:
                soup = BeautifulSoup(item.get_content(), 'html.parser')
                for p in soup.find_all('p'):
                    paragraphs.append(p.get_text())

        with open(dest_path, 'w', encoding='utf-8') as f:
            f.write('\n\n'.join(paragraphs))

    def remove_position_ids_from_state_dict(self, model_file: str, device: torch.device):
        state_dict = torch.load(model_file, map_location=device)
        if 'bert.embeddings.position_ids' in state_dict:
            print(f"Removing 'bert.embeddings.position_ids' from {model_file}")
            del state_dict['bert.embeddings.position_ids']
        modified_model_file = model_file.replace('.model', '_modified.model')
        save_path = os.path.join('modified_models/', os.path.basename(modified_model_file))
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        torch.save(state_dict, save_path)
        print(f"Modified model saved to {save_path}")
        return save_path

    def apply_book_nlp(self, input_file: Path, output_directory: Path):
        model_params = {
            'pipeline': 'entity,quote,coref',
            'model': 'custom',
            'entity_model_path': 'entities_google_bert_uncased_L-6_H-768_A-12-v1.0.model',
            'coref_model_path': 'coref_google_bert_uncased_L-12_H-768_A-12-v1.0.model',
            'quote_attribution_model_path': 'speaker_google_bert_uncased_L-12_H-768_A-12-v1.0.1.model',
        }
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        model_params['entity_model_path'] = self.remove_position_ids_from_state_dict(model_params['entity_model_path'], device)
        model_params['coref_model_path'] = self.remove_position_ids_from_state_dict(model_params['coref_model_path'], device)
        model_params['quote_attribution_model_path'] = self.remove_position_ids_from_state_dict(model_params['quote_attribution_model_path'], device)

        print('Initializing BookNLP...')
        booknlp = BookNLP('en', model_params)
        booknlp.process(input_file, output_directory, input_file.split('.')[0])
    
    def get_two_main_characters(self, entities_file):
        quotes_data = []
        with open(entities_file, 'r') as file:
            reader = csv.DictReader(file, delimiter='\t')
            for row in reader:
                coref = row['COREF']
                prop = row['prop']
                cat = row['cat']
                char = row['text']
                quotes_data.append({
                    'coref': coref,
                    'prop': prop,
                    'cat': cat,
                    'char': char
                })
        df = pd.DataFrame(quotes_data)
        df = df[df['cat'] == 'PER']
        coref_freq = df['coref'].value_counts()
        prop_names = (
            df[df['prop'] == 'PROP']
            .groupby('coref')['char']
            .agg(lambda x: x.value_counts().idxmax())
            .reset_index()
        )
        prop_names['freq'] = prop_names['coref'].map(coref_freq)
        prop_names = prop_names.sort_values('freq', ascending=False)
        prop_names = prop_names.drop_duplicates(subset='char')
        top_2 = prop_names.head(2).drop(columns='freq')
        return top_2['char'].tolist()