#!/bin/bash
set -euo pipefail

# =============================================================
#  OLLAMA BENCHMARK PARA MACBOOK M4 (HTML + GRÁFICOS)
#  - Execute como usuário normal (./ollama_benchmark_m4_html.sh)
#  - Vai pedir senha uma vez para powermetrics (sudo -v)
# =============================================================

# MODELOS a testar (ajuste conforme desejar)
MODELS=(
  "phi3:3.8b"
  "llama3.1:8b"
  "deepseek-r1:7b"
  "gemma2:9b"
)

CSV="benchmark_results.csv"
REPORT_HTML="relatorio_final.html"

# Referências para conversão (ajuste se souber números diferentes)
GPU_MAX_PWR=20000   # mW (20 W)
ANE_MAX_PWR=5000    # mW (5 W)

# Cabeçalho CSV
echo "model,latency_sec,total_time_sec,tokens,tokens_per_sec,cpu_percent,gpu_percent,ane_percent" > "$CSV"

# Verificações básicas
if ! command -v ollama >/dev/null 2>&1; then
  echo "Erro: 'ollama' não encontrado no PATH. Saia do sudo e certifique-se que 'ollama' roda como seu usuário."
  exit 1
fi

if ! command -v powermetrics >/dev/null 2>&1; then
  echo "Erro: 'powermetrics' não encontrado. Esse script exige powermetrics no macOS."
  exit 1
fi

# Cache de sudo para evitar pedir senha a cada chamada powermetrics
echo "Pedindo autenticação sudo para powermetrics (será solicitada senha apenas uma vez)..."
sudo -v

# Funções de medição
measure_gpu_once() {
  # coleta um sample do powermetrics para gpu_power; retorna valor em % (float)
  RAW=$(sudo powermetrics --samplers gpu_power -i 200 -n 1 2>/dev/null | grep -Ei "GPU Power" | awk '{print $3}' || true)
  if [[ -z "$RAW" ]]; then
    echo "0"
  else
    # converte mW -> %
    echo "$(awk -v raw="$RAW" -v max="$GPU_MAX_PWR" 'BEGIN{printf("%.2f", 100*raw/max)}')"
  fi
}

measure_ane_once() {
  RAW=$(sudo powermetrics --samplers ane_power -i 200 -n 1 2>/dev/null | grep -Ei "ANE Power" | awk '{print $3}' || true)
  if [[ -z "$RAW" ]]; then
    echo "0"
  else
    echo "$(awk -v raw="$RAW" -v max="$ANE_MAX_PWR" 'BEGIN{printf("%.2f", 100*raw/max)}')"
  fi
}

measure_cpu_for_pid() {
  PID="$1"
  # ps retorna %CPU; pode retornar blank se PID terminou
  OUT=$(ps -o %cpu= -p "$PID" 2>/dev/null || true)
  OUT=${OUT// /}  # trim spaces
  if [[ -z "$OUT" ]]; then
    echo "0"
  else
    # round to 2 decimals
    echo "$(awk -v v="$OUT" 'BEGIN{printf("%.2f", v)}')"
  fi
}

# Função para testar um modelo
test_model() {
  MODEL="$1"
  echo ""
  echo "=== Testando modelo: $MODEL ==="

  # Tenta pull (se já tiver, ok). Não usar sudo aqui.
  if ! ollama pull "$MODEL" >/dev/null 2>&1; then
    echo "Modelo $MODEL não encontrado/pull falhou. Pulando..."
    echo "$MODEL,SKIPPED,SKIPPED,0,0,0,0,0" >> "$CSV"
    return
  fi

  # latência (tempo de resposta para prompt "OK")
  START_LAT=$(python3 -c 'import time; print(time.time())')
  ollama run "$MODEL" "OK" >/dev/null 2>&1
  END_LAT=$(python3 -c 'import time; print(time.time())')
  LAT=$(awk -v a="$END_LAT" -v b="$START_LAT" 'BEGIN{printf("%.3f", a-b)}')

  # prompt pesado
  PROMPT="Explique redes 4G e 5G em 600 palavras."

  START_T=$(python3 -c 'import time; print(time.time())')

  # roda a geração em background e captura PID
  TMPFILE="$(mktemp)"
  ollama run "$MODEL" "$PROMPT" > "$TMPFILE" 2>/dev/null &
  OLLAMA_PID=$!

  # enquanto o processo estiver rodando, coleto amostras
  CPU_SAMPLES=()
  GPU_SAMPLES=()
  ANE_SAMPLES=()

  while kill -0 "$OLLAMA_PID" 2>/dev/null; do
    CPU_SAMPLES+=("$(measure_cpu_for_pid "$OLLAMA_PID")")
    GPU_SAMPLES+=("$(measure_gpu_once)")
    ANE_SAMPLES+=("$(measure_ane_once)")
    sleep 0.25
  done

  END_T=$(python3 -c 'import time; print(time.time())')

  # ler saída
  OUT_TEXT=$(cat "$TMPFILE" || echo "")
  rm -f "$TMPFILE"

  TOKENS=$(wc -w <<< "$OUT_TEXT" | awk '{print $1}')
  # prevenir divisão por zero
  TOTAL=$(awk -v a="$END_T" -v b="$START_T" 'BEGIN{t=a-b; if(t<=0) t=0.0001; printf("%.3f", t)}')
  TPS=$(awk -v tok="$TOKENS" -v t="$TOTAL" 'BEGIN{if(t>0) printf("%.2f", tok/t); else print "0.00"}')

  # média das amostras (tratando arrays possivelmente vazios)
  avg_from_array() {
    awk 'BEGIN{s=0;n=0} {if($1+0==0 && $1!="0") next; s+=($1+0); n+=1} END{ if(n==0) print 0; else printf("%.2f", s/n) }'
  }

  CPU_AVG=$(printf "%s\n" "${CPU_SAMPLES[@]}" | avg_from_array)
  GPU_AVG=$(printf "%s\n" "${GPU_SAMPLES[@]}" | avg_from_array)
  ANE_AVG=$(printf "%s\n" "${ANE_SAMPLES[@]}" | avg_from_array)

  echo "$MODEL,$LAT,$TOTAL,$TOKENS,$TPS,$CPU_AVG,$GPU_AVG,$ANE_AVG" >> "$CSV"
  echo "  → Lat: ${LAT}s  Total: ${TOTAL}s  Tokens: ${TOKENS}  TPS: ${TPS}  CPU%:${CPU_AVG}  GPU%:${GPU_AVG}  ANE%:${ANE_AVG}"
}

# Main loop
echo "Iniciando benchmarks: $(date)"
for M in "${MODELS[@]}"; do
  test_model "$M"
done
echo "Benchmarks concluídos. Gerando relatórios..."

# ==== Gera gráficos + HTML (Python) ====
python3 - <<'PY'
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import html

csv="benchmark_results.csv"
df = pd.read_csv(csv)

# converte colunas possíveis com SKIPPED para numéricos
for col in ["latency_sec","total_time_sec","tokens","tokens_per_sec","cpu_percent","gpu_percent","ane_percent"]:
    if col in df.columns:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)

# Gera gráficos
def save_bar(col, title, fname, ylabel):
    plt.figure(figsize=(10,5))
    plt.bar(df["model"], df[col], color="#2b7fb8")
    plt.xticks(rotation=45, ha='right')
    plt.ylabel(ylabel)
    plt.title(title)
    plt.tight_layout()
    plt.savefig(fname)
    plt.close()

save_bar("tokens_per_sec","Velocidade (tokens/s)","grafico_velocidade.png","tokens/s")
save_bar("latency_sec","Latência (s)","grafico_latencia.png","s")
save_bar("cpu_percent","CPU (%)","grafico_cpu.png","% CPU")
save_bar("gpu_percent","GPU (%)","grafico_gpu.png","% GPU")
save_bar("ane_percent","ANE (%)","grafico_ane.png","% ANE")

# Rankings (considerando apenas modelos com tokens_per_sec>0)
df_valid = df[df["tokens_per_sec"]>0]
if not df_valid.empty:
    fastest = df_valid.loc[df_valid["tokens_per_sec"].idxmax()]["model"]
    lowest_lat = df_valid.loc[df_valid["latency_sec"].idxmin()]["model"]
    best_precision = df_valid.loc[df_valid["tokens"].idxmax()]["model"]
    best_cost = df_valid.loc[df_valid["cpu_percent"].idxmin()]["model"]
else:
    fastest=lowest_lat=best_precision=best_cost = "—"

# Monta HTML
html_rows = df.to_html(index=False, escape=False)

html_content = f"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>Relatório Final — Benchmark Ollama M4</title>
<style>
body {{ font-family:-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial; margin:20px; color:#222; }}
table {{ border-collapse: collapse; width:100%; margin-bottom:20px; }}
th, td {{ border:1px solid #ddd; padding:8px; text-align:left; }}
th {{ background:#f6f6f6; }}
h1 {{ font-size:22px; }}
.card {{ padding:12px; border-radius:8px; background:#fbfbfb; margin-bottom:12px; box-shadow:0 1px 3px rgba(0,0,0,0.04); }}
img {{ max-width:100%; height:auto; border:1px solid #eee; padding:6px; background:#fff; }}
</style>
</head>
<body>
<h1>Relatório Final — Benchmark Ollama (MacBook M4)</h1>

<div class="card">
<h2>📌 Tabela de Resultados</h2>
{html_rows}
</div>

<div class="card">
<h2>🏆 Destaques</h2>
<ul>
<li><b>Mais rápido (tokens/s):</b> {html.escape(str(fastest))}</li>
<li><b>Menor latência:</b> {html.escape(str(lowest_lat))}</li>
<li><b>Melhor precisão (aprox.):</b> {html.escape(str(best_precision))}</li>
<li><b>Melhor custo-benefício (menor CPU):</b> {html.escape(str(best_cost))}</li>
</ul>
</div>

<div class="card">
<h2>📈 Gráficos</h2>
<h3>Velocidade</h3>
<img src="grafico_velocidade.png" alt="Velocidade (tokens/s)">
<h3>Latência</h3>
<img src="grafico_latencia.png" alt="Latência">
<h3>Uso médio da CPU (%)</h3>
<img src="grafico_cpu.png" alt="CPU">
<h3>Uso médio da GPU (%)</h3>
<img src="grafico_gpu.png" alt="GPU">
<h3>Uso médio da ANE (%)</h3>
<img src="grafico_ane.png" alt="ANE">
</div>

<footer style="margin-top:20px;color:#666;font-size:13px">
Relatório gerado em: {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}
</footer>
</body>
</html>
"""

with open("relatorio_final.html","w",encoding="utf-8") as f:
    f.write(html_content)

print("Relatório gerado: relatorio_final.html")
PY

echo "Relatório HTML + gráficos gerados: $REPORT_HTML"
