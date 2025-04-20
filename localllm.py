import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, AutoConfig
from accelerate import init_empty_weights, infer_auto_device_map
from langchain.llms.base import BaseLLM
from typing import Optional, List
import os

class LocalLLM(BaseLLM):
    def __init__(self, model_name="mistralai/Mistral-7B-Instruct-v0.1", offload_dir="offload"):
        super().__init__()
        self._model_name = model_name
        self._offload_dir = offload_dir
        os.makedirs(self._offload_dir, exist_ok=True)
        self._tokenizer = AutoTokenizer.from_pretrained(model_name)
        config = AutoConfig.from_pretrained(model_name)
        with init_empty_weights():
            model_init = AutoModelForCausalLM.from_config(config)

        device_map = infer_auto_device_map(
            model_init,
            no_split_module_classes=["MistralDecoderLayer"]
        )

        self._model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.float16,
            device_map=device_map,
            offload_folder=self._offload_dir,
            low_cpu_mem_usage=True
        )

        self._model.eval()
        self.callbacks = []

    def _generate(self, prompt: str, stop: Optional[List[str]] = None) -> str:
        inputs = self._tokenizer(prompt, return_tensors="pt")
        inputs = {k: v.to(self._model.device) for k, v in inputs.items()}

        with torch.no_grad():
            output = self._model.generate(
                **inputs,
                max_new_tokens=100,
                temperature=0.7,
                repetition_penalty=1.2,
                do_sample=False
            )

        decoded_output = self._tokenizer.decode(output[0], skip_special_tokens=True)
        return decoded_output.replace(prompt, "").strip()

    def _call(self, prompt: str, stop: Optional[List[str]] = None) -> str:
        return self._generate(prompt, stop)

    @property
    def _llm_type(self) -> str:
        return "local-llm"
