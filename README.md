```markdown
# 🔥 Ollama Benchmark Suite — MacBook M4 (CPU / GPU / ANE)

Este repositório contém uma suíte completa de benchmark para avaliar o desempenho de modelos executados via **Ollama** no **MacBook M4**, medindo:

- 🧠 **Uso da CPU (%)**
- 🎨 **Uso da GPU (Metal – % baseado em potência)**
- ⚡ **Uso da ANE (Apple Neural Engine)**
- ⏱️ Latência por modelo
- 🚀 Tokens por segundo (velocidade real)
- 📊 Relatório HTML profissional com:
  - Dashboard visual
  - Gráficos PNG
  - Badges de dominância (CPU / GPU / ANE)
  - Indicadores automáticos de ANE suportado / não suportado

---

## 📁 Estrutura do Repositório

/
├── scripts/
│   └── ollama_benchmark_m4_final.sh     # Script principal de benchmark
│
├── results/
│   ├── benchmark_results.csv            # CSV com métricas numéricas
│   ├── grafico_cpu.png
│   ├── grafico_gpu.png
│   ├── grafico_ane.png
│   ├── grafico_latencia.png
│   ├── grafico_velocidade.png
│   └── logs/                            # Futuro: logging completo
│
├── reports/
│   └── relatorio_final.html             # Relatório completo em HTML
│
├── .github/
│   └── workflows/
│       └── benchmark-ci.yml             # CI automatizado
│
├── LICENSE
└── README.md

---

## ⚙️ Requisitos

### macOS (Apple Silicon M4)
- `ollama`
- `powermetrics`
- Python 3.9+:
  ```bash
  pip3 install pandas matplotlib
````

---

## 🚀 Como rodar o benchmark

Clone o repositório:

```bash
git clone https://github.com/<SEU_USUARIO>/ollama-benchmark-m4.git
cd ollama-benchmark-m4
```

Dê permissão ao script:

```bash
chmod +x scripts/ollama_benchmark_m4_final.sh
```

Execute:

```bash
./scripts/ollama_benchmark_m4_final.sh
```

Ao final, abra:

```
reports/relatorio_final.html
```

---

## 🧠 Como o script funciona

1. Identifica automaticamente modelos:

   * compatíveis com ANE (1B–3B)
   * modelos grandes (7B–13B)
2. Mede em tempo real:

   * CPU (%)
   * GPU (% via powermetrics)
   * ANE (% via powermetrics)
3. Detecta se ANE foi realmente ativado
4. Gera gráficos e relatório HTML
5. Classifica modelos em:

   * CPU dominante
   * GPU dominante
   * ANE dominante

---

## 🧪 CI Automático

O repositório inclui um workflow GitHub Actions que:

* valida sintaxe do script
* valida dependências Python
* roda geração de relatório em modo simulado

Arquivo:
`.github/workflows/benchmark-ci.yml`

---

## 📜 Licença

Este projeto está licenciado sob a licença **MIT** — veja `LICENSE` para mais detalhes.

---

## 🤝 Contribuições

Pull Requests são bem-vindos!
Use a branch `dev` como base para novos recursos:

```bash
git checkout dev
```

---

## ✨ Autor

**Lincoln Herbert Teixeira**
Professor EBTT — UTFPR
Especialista em Redes 4G/5G, IA, ESP32, Sistemas Inteligentes e Computação Veicular.

---

````