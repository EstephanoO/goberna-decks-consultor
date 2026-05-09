#!/bin/bash
# Goberna Decks · Setup Consultor (Mac)
# Uso: curl -fsSL https://electoral.goberna.club/setup-mac.sh | bash

set -e

echo ""
echo "════════════════════════════════════════════════"
echo "  Goberna Decks · Setup Consultor (Mac)"
echo "════════════════════════════════════════════════"
echo ""

# 1. Xcode CLI tools
if ! xcode-select -p &>/dev/null; then
  echo "▸ Instalando Xcode Command Line Tools (puede tardar)..."
  xcode-select --install || true
  echo ""
  echo "  ⚠️  Cuando termine la instalación de Xcode, volvé a correr este comando."
  exit 0
fi
echo "✓ Xcode CLI ok"

# 2. Homebrew
if ! command -v brew &>/dev/null; then
  echo "▸ Instalando Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Asegurar que brew esté en el PATH para esta sesión
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
echo "✓ Homebrew ok"

# 3. Node + Git
echo "▸ Instalando Node.js + Git..."
brew install node git || true
echo "✓ Node $(node --version) · Git $(git --version | head -1)"

# 4. Claude Code
echo "▸ Instalando Claude Code..."
npm install -g @anthropic-ai/claude-code
echo "✓ Claude Code ok"

# 5. Clonar / actualizar repo
WORKDIR="$HOME/Goberna/decks"
mkdir -p "$HOME/Goberna"
if [[ -d "$WORKDIR/.git" ]]; then
  echo "▸ Actualizando repo existente en $WORKDIR..."
  cd "$WORKDIR" && git pull --ff-only
else
  echo "▸ Clonando repo a $WORKDIR..."
  git clone https://github.com/EstephanoO/goberna-decks-consultor.git "$WORKDIR"
fi
echo "✓ Repo en $WORKDIR"

# 6. Instalar deps del MCP server local (dentro del repo clonado)
echo "▸ Instalando MCP server (goberna-mcp)..."
(cd "$WORKDIR/mcp-server" && npm install --silent)
echo "✓ MCP server listo"

# 7. Token de Goberna (para que el MCP pueda llamar a la API)
TOKEN_DIR="$HOME/.config/goberna"
TOKEN_FILE="$TOKEN_DIR/token"
mkdir -p "$TOKEN_DIR"
chmod 700 "$TOKEN_DIR"
if [[ ! -f "$TOKEN_FILE" ]]; then
  echo ""
  echo "════════════════════════════════════════════════"
  echo "  TOKEN GOBERNA"
  echo "════════════════════════════════════════════════"
  echo ""
  echo "  Pedile al admin de Goberna que te genere tu token de consultor."
  echo "  Cuando lo tengas, pegalo acá (vas a verlo escondido — terminá con Enter):"
  echo ""
  read -rsp "  Token: " GOBERNA_TOKEN
  echo ""
  if [[ -n "$GOBERNA_TOKEN" ]]; then
    echo "$GOBERNA_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo "✓ Token guardado en $TOKEN_FILE"
  else
    echo "⚠️  Sin token. Vas a poder generar decks pero no listar candidatos hasta que lo pongas."
    echo "    Cuando lo tengas: echo 'tu-token' > $TOKEN_FILE"
  fi
else
  echo "✓ Token ya existe en $TOKEN_FILE"
fi

# 8. Registrar MCP server en Claude Code
echo "▸ Registrando MCP en Claude Code..."
claude mcp add --scope user goberna node "$WORKDIR/mcp-server/index.mjs" 2>/dev/null || \
  claude mcp add goberna node "$WORKDIR/mcp-server/index.mjs" 2>/dev/null || \
  echo "  ⚠️  No pude registrar el MCP automáticamente. Hacelo manual:"
echo "✓ MCP registrado (verificalo con: claude mcp list)"

# 9. Alias `deck` y `deck-preview` en shell rc
SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == *"bash"* ]] && SHELL_RC="$HOME/.bashrc"
touch "$SHELL_RC"

if ! grep -q "# === Goberna Decks ===" "$SHELL_RC"; then
  cat >> "$SHELL_RC" <<'EOF'

# === Goberna Decks ===
alias deck='cd ~/Goberna/decks && claude'
alias deck-preview='cd ~/Goberna/decks && npm start'
alias deck-update='cd ~/Goberna/decks && git pull --ff-only'
EOF
  echo "✓ Aliases agregados a $SHELL_RC"
else
  echo "✓ Aliases ya existen en $SHELL_RC"
fi

echo ""
echo "════════════════════════════════════════════════"
echo "  ✅  Setup completo"
echo "════════════════════════════════════════════════"
echo ""
echo "  PRÓXIMOS PASOS:"
echo ""
echo "  1. Cerrá esta Terminal y abrí una nueva"
echo "     (para que los aliases 'deck' funcionen)"
echo ""
echo "  2. Autenticá Claude:"
echo "     claude /login"
echo ""
echo "  3. Para arrancar a generar un deck, tipeá:"
echo "     deck"
echo ""
echo "  4. Para ver tus decks en el browser, en otra terminal:"
echo "     deck-preview"
echo "     (después abrí http://localhost:3000)"
echo ""
echo "  5. Si Goberna actualiza el kit, corré:"
echo "     deck-update"
echo ""
