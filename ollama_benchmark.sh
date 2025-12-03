#!/bin/bash

# -------------------------------------------
#  OLLAMA BENCHMARK SCRIPT
#  Testa latência, velocidade, throughput
#  Gera relatório final em benchmark_report.txt
# -------------------------------------------

MODELS=("llama3:8b" "mistral:7b" "qwen2:7b" "deepseek-r1:7b")
REPORT="benchmark_report.txt"

echo "======================================" > $REPORT
echo "  OLLAMA BENCHMARK REPORT" >> $REPORT
echo "  Date: $(date)" >> $REPORT
echo "======================================" >> $REPORT
echo "" >> $REPORT


test_model() {
    MODEL=$1
    echo "Testando modelo: $MODEL"
    echo "--------------------------------------" >> $REPORT
    echo "Modelo: $MODEL" >> $REPORT

    # ---------------------------
    # 1. Teste de Latência Inicial
    # ---------------------------
    echo " 1) Testando latência inicial..."
    START=$(gdate +%s.%N 2>/dev/null || date +%s)
    RESPONSE=$(ollama run $MODEL "Say 'OK' to test latency.")
    END=$(gdate +%s.%N 2>/dev/null || date +%s)
    LATENCY=$(echo "$END - $START" | bc)

    echo "Latência inicial: ${LATENCY}s" >> $REPORT
    echo "Resposta curta: $RESPONSE" >> $REPORT
    echo "" >> $REPORT


    # ---------------------------
    # 2. Benchmark nativo Ollama
    # ---------------------------
    echo " 2) Executando ollama benchmark..."
    BENCH=$(ollama benchmark $MODEL)
    
    TOKENS_PER_SEC=$(echo "$BENCH" | grep "tokens/s" | awk '{print $NF}')
    LOAD_TIME=$(echo "$BENCH" | grep "load time" | awk '{print $3}')
    
    echo "$BENCH" >> $REPORT
    echo "" >> $REPORT


    # ---------------------------
    # 3. Teste de geração longa
    # ---------------------------
    echo " 3) Testando geração longa..."
    START2=$(gdate +%s.%N 2>/dev/null || date +%s)
    LONG_RESPONSE=$(ollama run $MODEL "Explique redes 4G e 5G em 1000 palavras.")
    END2=$(gdate +%s.%N 2>/dev/null || date +%s)
    TOTAL_TIME=$(echo "$END2 - $START2" | bc)

    RESPONSE_SIZE=$(printf "%s" "$LONG_RESPONSE" | wc -w)

    echo "Tempo total na geração longa: ${TOTAL_TIME}s" >> $REPORT
    echo "Tamanho da resposta (palavras): $RESPONSE_SIZE" >> $REPORT
    echo "" >> $REPORT
    echo "" >> $REPORT
}


echo "Iniciando benchmarks..."
for model in "${MODELS[@]}"; do
    test_model $model
done

echo "======================================" >> $REPORT
echo "           FIM DOS TESTES             " >> $REPORT
echo "======================================" >> $REPORT

echo "Benchmark finalizado!"
echo "Relatório salvo em: $REPORT"

