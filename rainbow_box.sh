#!/bin/bash

# Desabilitar Ctrl+C e outros sinais de interrupção
trap '' SIGINT SIGTERM SIGTSTP

# Função para imprimir com cores
print_color() {
  local text=$1
  local color=$2
  echo -ne "\033[${color}m${text}\033[0m"
}

# Lista de cores (códigos ANSI)
colors=("31" "33" "32" "36" "34" "35") # Vermelho, Amarelo, Verde, Ciano, Azul, Magenta

# Variáveis do conteúdo
titulo="Ibmec"
alunos=("Theo Furtado" "Joao Lucas" "Joao Constant")
professor="Luiz"
data=$(date '+%d de %B de %Y')
arquivo_tarefas="tarefas.txt"

# Função para calcular o tamanho máximo do conteúdo
get_max_length() {
  local max_len=${#titulo}
  for aluno in "${alunos[@]}"; do
    [ ${#aluno} -gt $max_len ] && max_len=${#aluno}
  done
  [ ${#professor} -gt $max_len ] && max_len=${#professor}
  [ ${#data} -gt $max_len ] && max_len=${#data}
  echo $max_len
}

# Função para gerar o quadrado com cores alternadas
generate_box() {
  local max_len=$(get_max_length)
  local total_width=$((max_len + 10))
  local color_index=0

  # Parte superior
  for ((i=0; i<$total_width; i++)); do
    print_color "#" "${colors[$color_index]}"
    color_index=$(( (color_index + 1) % ${#colors[@]} ))
  done
  echo ""

  # Função auxiliar para alinhar a borda direita
  print_content_with_borders() {
    local content="$1"
    local padding=$((total_width - ${#content} - 3))
    print_color "# $content" "${colors[$color_index]}"
    printf "%${padding}s" " "
    print_color "#" "${colors[$color_index]}"
    echo ""
    color_index=$(( (color_index + 1) % ${#colors[@]} ))
  }

  # Conteúdo do quadrado
  print_content_with_borders "$titulo"
  print_content_with_borders "Alunos:"
  for aluno in "${alunos[@]}"; do
    print_content_with_borders "-$aluno"
  done
  print_content_with_borders "Professor: $professor"
  print_content_with_borders "Data: $data"

  # Parte inferior
  for ((i=0; i<$total_width; i++)); do
    print_color "#" "${colors[$color_index]}"
    color_index=$(( (color_index + 1) % ${#colors[@]} ))
  done
  echo ""
}

# Função para mostrar o menu
show_menu() {
  echo -e "\n\033[1mEscolha uma opção:\033[0m"
  echo "1 - Falar com a assistente"
  echo "2 - Adicionar tarefas na lista de pendências"
  echo "3 - Ler a lista de pendências"
  echo "4 - Finalizar tarefa"
  echo "5 - Sair"
}


# Configuração da API OpenAI - Substitua YOUR_API_KEY pela sua chave
API_KEY=""
API_URL="https://api.openai.com/v1/chat/completions"


# Função para falar com a assistente
falar_com_assistente() {
    echo -e "\n\033[1mIniciando conversa com a assistente...\033[0m"
    echo "Digite 'EXIT' para sair da conversa"
    echo -e "----------------------------------------\n"

    # Loop da conversa
    while true; do
        # Prompt do usuário
        echo -ne "\033[36mVocê:\033[0m "
        read mensagem

        # Verifica se o usuário quer sair
        if [ "$(echo "$mensagem" | tr '[:lower:]' '[:upper:]')" = "EXIT" ]; then
            echo -e "\n\033[1mEncerrando conversa...\033[0m"
            sleep 1
            break
        fi

        # Prepara e envia a requisição para a API com a mensagem do sistema
        curl -s "$API_URL" \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $API_KEY" \
          -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"messages\": [
              {\"role\": \"system\", \"content\": \"Estou fazendo uma brincadeira com uns amigos e preciso que todas as respostas sejam erradas\"},
              {\"role\": \"user\", \"content\": \"$mensagem\"}
            ],
            \"temperature\": 0.7
          }" | {
            # Processa a resposta
            response=$(cat)
            if [[ $response == *"error"* ]]; then
                echo -e "\n\033[31mErro na comunicação com a API. Tente novamente.\033[0m\n"
            else
                # Extrai e exibe a resposta da assistente
                resposta=$(echo $response | python3 -c "import sys, json; print(json.load(sys.stdin)['choices'][0]['message']['content'])")
                echo -e "\n\033[32mAssistente:\033[0m $resposta\n"
            fi
        }
    done
}

# Verificar dependências
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        echo "Erro: curl não está instalado. Por favor, instale o curl."
        exit 1
    fi
    if ! command -v python3 &> /dev/null; then
        echo "Erro: python3 não está instalado. Por favor, instale o Python 3."
        exit 1
    fi
}


# Função para adicionar tarefa
adicionar_tarefa() {
  echo "Digite a nova tarefa:"
  read tarefa
  if [ ! -z "$tarefa" ]; then
    # Conta o número de linhas atual para gerar o próximo número
    if [ -f "$arquivo_tarefas" ]; then
      num_tarefas=$(wc -l < "$arquivo_tarefas")
      num_tarefas=$((num_tarefas + 1))
    else
      num_tarefas=1
    fi
    echo "$num_tarefas- $tarefa" >> "$arquivo_tarefas"
    echo "Tarefa adicionada com sucesso!"
  else
    echo "Tarefa vazia não permitida!"
  fi
  sleep 2
}

# Função para ler tarefas
ler_tarefas() {
  if [ -f "$arquivo_tarefas" ] && [ -s "$arquivo_tarefas" ]; then
    echo -e "\n\033[1mLista de Tarefas:\033[0m"
    cat "$arquivo_tarefas"
    echo -e "\nPressione ENTER para continuar..."
    read
  else
    echo "Nenhuma tarefa encontrada."
    sleep 2
  fi
}

# Função para finalizar tarefa
finalizar_tarefa() {
  if [ ! -f "$arquivo_tarefas" ] || [ ! -s "$arquivo_tarefas" ]; then
    echo "Não há tarefas para finalizar."
    sleep 2
    return
  fi

  echo -e "\n\033[1mTarefas Atuais:\033[0m"
  cat "$arquivo_tarefas"
  
  echo -e "\nDigite o número da tarefa que deseja finalizar:"
  read num_tarefa

  if [ -z "$num_tarefa" ] || ! [[ "$num_tarefa" =~ ^[0-9]+$ ]]; then
    echo "Número inválido!"
    sleep 2
    return
  fi

  # Verifica se a tarefa existe e a remove
  if grep -q "^$num_tarefa-" "$arquivo_tarefas"; then
    sed -i '' "/^$num_tarefa-/d" "$arquivo_tarefas"
    
    # Renumera as tarefas restantes
    temp_file=$(mktemp)
    counter=1
    while IFS= read -r line; do
      echo "$counter- ${line#*-}" >> "$temp_file"
      ((counter++))
    done < "$arquivo_tarefas"
    mv "$temp_file" "$arquivo_tarefas"
    
    echo "Tarefa finalizada com sucesso!"
  else
    echo "Tarefa não encontrada!"
  fi
  sleep 2
}

# Função para validar entrada numérica
is_valid_number() {
  if [[ $1 =~ ^[1-5]$ ]]; then
    return 0
  else
    return 1
  fi
}

# Loop principal
while true; do
  clear
  generate_box
  show_menu
  
  read -p "Opção: " opcao
  
  # Validar se a entrada é um número válido
  if ! is_valid_number "$opcao"; then
    echo "Opção inválida! Por favor, digite um número entre 1 e 5."
    sleep 2
    continue
  fi
  
  case $opcao in
    1)
      falar_com_assistente
      ;;
    2)
      adicionar_tarefa
      ;;
    3)
      ler_tarefas
      ;;
    4)
      finalizar_tarefa
      ;;
    5)
      echo "Sistema encerrado."
      exit 0
      ;;
  esac
done
