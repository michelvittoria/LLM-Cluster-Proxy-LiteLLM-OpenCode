#!/usr/bin/env python3
"""
Script de teste para o LLM Cluster Proxy
Testa a conectividade e funcionalidade do proxy LiteLLM
"""

import os
import sys
import json
import requests
import time
from typing import Dict, List, Optional


class LLMProxyTester:
    def __init__(self, base_url: str = "http://localhost:4000"):
        self.base_url = base_url.rstrip("/")
        self.v1_url = f"{self.base_url}/v1"
        self.session = requests.Session()
        self.session.timeout = 30

    def test_connectivity(self) -> bool:
        """Testa a conectividade básica com o proxy"""
        print("🔌 Testando conectividade com o proxy...")
        try:
            response = self.session.get(f"{self.base_url}/health", timeout=5)
            if response.status_code == 200:
                print("✅ Conectividade OK")
                return True
            else:
                print(f"❌ Status inesperado: {response.status_code}")
                return False
        except requests.exceptions.ConnectionError:
            print("❌ Não foi possível conectar ao proxy")
            print("   Certifique-se de que o LiteLLM está rodando:")
            print("   litellm --config ~/litellm-config.yaml --port 4000 --drop_params")
            return False
        except Exception as e:
            print(f"❌ Erro de conexão: {e}")
            return False

    def list_models(self) -> Optional[List[Dict]]:
        """Lista os modelos disponíveis no proxy"""
        print("\n🤖 Listando modelos disponíveis...")
        try:
            response = self.session.get(f"{self.v1_url}/models", timeout=10)
            if response.status_code == 200:
                data = response.json()
                models = data.get("data", [])

                print(f"✅ {len(models)} modelo(s) encontrado(s):")
                for model in models:
                    model_id = model.get("id", "N/A")
                    print(f"   • {model_id}")

                return models
            else:
                print(f"❌ Falha ao listar modelos: {response.status_code}")
                return None
        except Exception as e:
            print(f"❌ Erro ao listar modelos: {e}")
            return None

    def test_chat_completion(self, model: str = "deepseek-chat") -> bool:
        """Testa uma completação de chat simples"""
        print(f"\n💬 Testando completação com modelo: {model}")

        payload = {
            "model": model,
            "messages": [
                {
                    "role": "system",
                    "content": "Você é um assistente útil. Responda brevemente.",
                },
                {
                    "role": "user",
                    "content": "Olá! Como você está? Responda em português.",
                },
            ],
            "max_tokens": 100,
            "temperature": 0.7,
        }

        try:
            start_time = time.time()
            response = self.session.post(
                f"{self.v1_url}/chat/completions", json=payload, timeout=30
            )
            elapsed_time = time.time() - start_time

            if response.status_code == 200:
                data = response.json()
                choices = data.get("choices", [])

                if choices:
                    message = choices[0].get("message", {})
                    content = message.get("content", "Sem conteúdo")

                    print(f"✅ Resposta recebida em {elapsed_time:.2f}s")
                    print(f"   Modelo usado: {data.get('model', 'N/A')}")
                    print(
                        f"   Tokens usados: {data.get('usage', {}).get('total_tokens', 'N/A')}"
                    )
                    print(f"   Resposta: {content[:100]}...")
                    return True
                else:
                    print("❌ Nenhuma escolha na resposta")
                    return False
            else:
                print(f"❌ Falha na completação: {response.status_code}")
                print(f"   Resposta: {response.text[:200]}")
                return False
        except Exception as e:
            print(f"❌ Erro na completação: {e}")
            return False

    def test_streaming(self, model: str = "deepseek-chat") -> bool:
        """Testa streaming de resposta (opcional)"""
        print(f"\n🌊 Testando streaming com modelo: {model}")

        payload = {
            "model": model,
            "messages": [
                {"role": "user", "content": "Escreva uma frase curta sobre tecnologia."}
            ],
            "max_tokens": 50,
            "temperature": 0.7,
            "stream": True,
        }

        try:
            print("   Aguardando resposta stream...", end="", flush=True)
            response = self.session.post(
                f"{self.v1_url}/chat/completions", json=payload, stream=True, timeout=30
            )

            if response.status_code == 200:
                chunks_received = 0
                for chunk in response.iter_lines():
                    if chunk:
                        chunks_received += 1

                print(f"\r✅ Streaming OK ({chunks_received} chunks recebidos)")
                return True
            else:
                print(f"\r❌ Falha no streaming: {response.status_code}")
                return False
        except Exception as e:
            print(f"\r❌ Erro no streaming: {e}")
            return False

    def run_full_test(self):
        """Executa todos os testes"""
        print("=" * 60)
        print("🧪 LLM CLUSTER PROXY - TESTE COMPLETO")
        print("=" * 60)

        results = {
            "connectivity": False,
            "models_listed": False,
            "chat_completion": False,
            "streaming": False,
        }

        # Teste 1: Conectividade
        results["connectivity"] = self.test_connectivity()
        if not results["connectivity"]:
            print("\n❌ Teste interrompido: Proxy não está acessível")
            return results

        # Teste 2: Listar modelos
        models = self.list_models()
        results["models_listed"] = models is not None and len(models) > 0

        if models:
            # Teste 3: Completação com o primeiro modelo
            first_model = models[0].get("id") if models else "deepseek-chat"
            results["chat_completion"] = self.test_chat_completion(first_model)

            # Teste 4: Streaming (opcional)
            try:
                results["streaming"] = self.test_streaming(first_model)
            except:
                print("⚠️  Streaming não suportado ou desabilitado")
                results["streaming"] = False

        # Resumo
        print("\n" + "=" * 60)
        print("📊 RESUMO DOS TESTES")
        print("=" * 60)

        for test_name, passed in results.items():
            status = "✅ PASS" if passed else "❌ FAIL"
            print(f"{status} {test_name.replace('_', ' ').title()}")

        total_passed = sum(results.values())
        total_tests = len(results)

        print(f"\n📈 Resultado: {total_passed}/{total_tests} testes passaram")

        if total_passed == total_tests:
            print(
                "\n🎉 Todos os testes passaram! O proxy está funcionando corretamente."
            )
        elif total_passed >= total_tests - 1:
            print("\n⚠️  A maioria dos testes passou. Verifique os itens com falha.")
        else:
            print("\n❌ Muitos testes falharam. Verifique a configuração do proxy.")

        return results


def main():
    """Função principal"""
    # Verificar argumentos
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    else:
        base_url = "http://localhost:4000"

    print(f"🔗 Usando URL do proxy: {base_url}")

    # Criar tester e executar testes
    tester = LLMProxyTester(base_url)
    results = tester.run_full_test()

    # Retornar código de saída apropriado
    if all(results.values()):
        sys.exit(0)  # Sucesso
    else:
        sys.exit(1)  # Falha


if __name__ == "__main__":
    main()
