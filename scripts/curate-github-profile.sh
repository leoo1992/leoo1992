#!/usr/bin/env bash
# Curate the public GitHub profile: pin six portfolio repositories and archive
# only clearly named beginner exercises. No repository is deleted or privatized.
set -Eeuo pipefail
OWNER="leoo1992"

PINNED=(
  sentinela-sst
  sistema_ponto
  hero-app-back
  pulsebi
  quake-vision
  Leo-AI-poc
)

ARCHIVE=(
  GuessNumber
  CalculadoraJavaScript
  Calculadora_IMC
  MediaVariosValores
  verificadorValoresIguais
  ContadorDeNotasDisponiveis
  CustoViagem
  calculoIdade
  desafio
  aprendendo_Python
  JsTraining
  test-curso-dio-IDE-java-intelliJ
)

command -v gh >/dev/null 2>&1 || { echo "GitHub CLI (gh) is required."; exit 2; }
gh auth status >/dev/null

echo "Repositories to pin:"
printf '  - %s\n' "${PINNED[@]}"
echo
echo "Repositories to archive (not delete):"
printf '  - %s\n' "${ARCHIVE[@]}"
echo
read -r -p "Apply these profile changes? Type APPLY: " CONFIRM
[ "$CONFIRM" = "APPLY" ] || { echo "Cancelled."; exit 0; }

USER_ID="$(gh api graphql -f query='query { viewer { id } }' --jq '.data.viewer.id')"
NODE_IDS=()
for repo in "${PINNED[@]}"; do
  NODE_ID="$(gh api "repos/$OWNER/$repo" --jq '.node_id')"
  NODE_IDS+=("$NODE_ID")
done
ID_LIST="$(printf '%s\n' "${NODE_IDS[@]}" | jq -R -s 'split("\n")[:-1] | map(@json) | join(",")')"
QUERY="mutation { updateUserPinnedRepositories(input: { userId: \"$USER_ID\", repositoryIds: [$ID_LIST] }) { clientMutationId } }"
gh api graphql -f query="$QUERY" >/dev/null
echo "Pinned repositories updated."

for repo in "${ARCHIVE[@]}"; do
  gh api --method PATCH "repos/$OWNER/$repo" -F archived=true >/dev/null
  echo "Archived: $repo"
done

echo "Done. All repositories remain public; archived repositories remain accessible."
