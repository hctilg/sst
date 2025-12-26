#!/usr/bin/env bash

translate() {
  local text="$1"

  curl -sG "https://translate.googleapis.com/translate_a/single?" \
    --data-urlencode "client=gtx" \
    --data-urlencode "sl=$SOURCE_LANG" \
    --data-urlencode "tl=$TARGET_LANG" \
    --data-urlencode "dt=t" \
    --data-urlencode "q=$text" \
  | jq -r '.[0][0][0]'
}

if [[ "${1,,}" == "--help" || "${1,,}" == "-h" ]]; then
  echo "Usage: sst [OPTION]... [FILE]...

  -i  --input          path of the input  subtitle file in .srt format
  -o  --input          path of the output subtitle file in .srt format
  -sl --source-lang    current subtitle language <lang-code>
  -tl --target-lang    target  subtitle language <lang-code>
  -l --list-lang       show all supported languages + <lang-codes>
  -u --update          update 'sst' to latest version
  -r --uninstall       uninstall 'sst' from the system
  -h --help            show help message

Examples:
  sst
  sst -i subtitle.srt -o translated.srt -sl en -tl fa

Report bugs to: https://github.com/hctilg/sst/issues/new"
  exit;
fi

if [[ "${1,,}" == "--list-lang" || "${1,,}" == "-l" ]]; then
  echo "Check out <https://docs.cloud.google.com/translate/docs/languages>,
 I didn't feel like writing them :)"
  exit;
fi

if [[ "${1,,}" == "--update" || "${1,,}" == "-u" ]]; then
  echo -e "\n  [#] Reinstaling..."
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/hctilg/sst/main/install.sh)"
  wait
  exit;
fi

if [[ "${1,,}" == "--uninstall" || "${1,,}" == "-r" ]]; then
  read -rp "Do you want to continue? (yes/No) > " answer

  if [[ ${answer,,} != "yes" ]]; then
    exit 1
  fi

  echo -e "\n[#] Uninstaling..."
  
  if [[ $(uname -o) == "Android" ]]; then # Termux
    rm -rf "/data/data/com.termux/files/usr/bin/sst"
  else
    sudo rm -rf "/usr/local/bin/sst"
  fi

  wait

  echo -e "\n[#] Done."

  exit;
fi

INPUT_FILE=""
OUTPUT_FILE=""
SOURCE_LANG="en"
TARGET_LANG="fa"

args=("$@")
lower_args=()
for a in "${args[@]}"; do
  lower_args+=( "$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')" )
done

for i in "${!lower_args[@]}"; do
  case "${lower_args[i]}" in
    -i|--input)
      if (( i + 1 < ${#args[@]} )); then
        INPUT_FILE="${args[i+1]}"
      fi
    ;;
    -o|--output)
      if (( i + 1 < ${#args[@]} )); then
        OUTPUT_FILE="${args[i+1]}"
      fi
    ;;
    -sl|--source-lang)
      if (( i + 1 < ${#args[@]} )); then
        SOURCE_LANG="${args[i+1]}"
      fi
    ;;
    -tl|--target-lang)
      if (( i + 1 < ${#args[@]} )); then
        TARGET_LANG="${args[i+1]}"
      fi
    ;;
  esac
done

if [[ ! -e $INPUT_FILE ]]; then
  read -p "Subtitle File(.srt) Path: " INPUT_FILE

  if [[ ! -e $INPUT_FILE ]]; then
    echo -e "\n  [!] File not exist.\n"
    exit
  fi
fi

if [[ -z "${OUTPUT_FILE//[[:space:]]/}" ]]; then
  OUTPUT_FILE=$(pwd)"/translated."$(basename "$INPUT_FILE")
fi

> "$OUTPUT_FILE"

if [[ $SOURCE_LANG == 'en' ]]; then
  read -p "Current subtitle language (Enter to default=en): " INPUT_FILE_NOW
  if [[ ! -z "${INPUT_FILE_NOW//[[:space:]]/}" ]]; then
    SOURCE_LANG="$INPUT_FILE_NOW"
  fi
fi

if [[ $TARGET_LANG == 'fa' ]]; then
  read -p "Target subtitle language (Enter to default=fa): " TARGET_LANG_NOW
  if [[ ! -z "${TARGET_LANG_NOW//[[:space:]]/}" ]]; then
    TARGET_LANG="$TARGET_LANG_NOW"
  fi
fi

echo -e "\n[*] Loading srt file..."

INPUT_DATA=$(< "$INPUT_FILE")"\n"

PARTS=()
TMP_CONTENT=""
while IFS= read -r LINE; do
  if [[ -z "${LINE//[[:space:]]/}" ]]; then
    if [[ -n $TMP_CONTENT ]]; then
      PARTS+=("$TMP_CONTENT")
      TMP_CONTENT=""
    fi
  else
    TMP_CONTENT+="${LINE}"$'\n'
  fi
done <<< $INPUT_DATA

if [[ -n $TMP_CONTENT ]]; then
  PARTS+=("$TMP_CONTENT")
fi

LENGTH=${#PARTS[@]}
for ((i=0; i<LENGTH; i++)); do
  PART=${PARTS[$i]}

  DETAILS=$(printf "$PART" | sed -n '2p')
  PARAGRAPH=$(echo "$PART" | tail -n +3)

  TRANSLATED=""
  while IFS= read -r PL; do
    LINE_TRANSLATED=$(translate "$PL")
    TRANSLATED+=$'\n'"${LINE_TRANSLATED}"
  done <<< $PARAGRAPH

  if [[ -z "${TRANSLATED//[[:space:]]/}" ]]; then
    TRANSLATED=$(translate "$PARAGRAPH")
  fi

  {
    echo $(($i+1))
    echo $DETAILS
    echo $TRANSLATED
    echo
  } >> "$OUTPUT_FILE"

  PERCENT=$(( i * 100 / LENGTH ))
  printf "\r[#] Translating...  | (%d%%) [%d/%d]" "$PERCENT" "$i" "$LENGTH"
done

printf "\r[#] Translating...  | (%d%%) [%d/%d]" "100" "$LENGTH" "$LENGTH"
echo -e "\n[#] Translation completed."
echo -e " └─╼ ‘$OUTPUT_FILE’ saved.\n"
