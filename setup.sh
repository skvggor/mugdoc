#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

CURRENT_STEP=0
TOTAL_STEPS=0

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo ""
  echo -e "  ${DIM}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC}"
}

log_detail() { echo -e "       ${DIM}$1${NC}"; }
log_success() { echo -e "       ${GREEN}\xe2\x9c\x94${NC} $1"; }
log_warning() { echo -e "       ${YELLOW}\xe2\x96\xb2${NC} $1" >&2; }
log_error() { echo -e "  ${RED}\xe2\x9c\x98 $1${NC}" >&2; }

spinner() {
  local pid=$1
  local label=$2
  local frames=('\xe2\xa0\x8b' '\xe2\xa0\x99' '\xe2\xa0\xb9' '\xe2\xa0\xb8' '\xe2\xa0\xbc' '\xe2\xa0\xb4' '\xe2\xa0\xa6' '\xe2\xa0\xa7' '\xe2\xa0\x87' '\xe2\xa0\x8f')
  local i=0

  tput civis 2>/dev/null || true

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r       ${CYAN}%b${NC} %s" "${frames[$i]}" "$label"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.1
  done

  wait "$pid" 2>/dev/null
  local exit_code=$?
  printf "\r\033[2K"

  tput cnorm 2>/dev/null || true

  return $exit_code
}

banner() {
  echo ""
  echo -e "  ${MAGENTA}${BOLD}mugdoc${NC} ${DIM}\xe2\x94\x80 generate docs from your README${NC}"
  echo -e "  ${DIM}$(printf '\xe2\x94\x80%.0s' {1..42})${NC}"
}

pad() {
  local text="$1"
  local width="$2"
  local text_length=${#text}
  local padding=$((width - text_length))
  printf '%s' "$text"
  [ "$padding" -gt 0 ] && printf '%*s' "$padding" ""
}

box_line() {
  local width="$1"
  printf '\xe2\x94\x80%.0s' $(seq 1 "$width")
}

print_summary() {
  local project_name="$1"
  local base_domain="$2"
  local docs_directory="$3"
  local package_manager="$4"

  local site_url="https://${project_name}.${base_domain}"
  local preview_command="cd ${docs_directory} && ${package_manager} run preview"
  local build_command="cd ${docs_directory} && ${package_manager} run build"
  local dev_command="cd ${docs_directory} && ${package_manager} run dev"

  local lines=(
    "project  ${project_name}"
    "site     ${site_url}"
    "dev      ${dev_command}"
    "build    ${build_command}"
    "preview  ${preview_command}"
  )

  local inner_width=18
  for line in "${lines[@]}"; do
    local length=${#line}
    [ "$length" -gt "$inner_width" ] && inner_width=$length
  done
  inner_width=$((inner_width + 4))

  echo ""
  echo -e "  ${DIM}\xe2\x94\x8c$(box_line "$inner_width")\xe2\x94\x90${NC}"
  echo -e "  ${DIM}\xe2\x94\x82${NC}  $(pad "" $((inner_width - 2)))${DIM}\xe2\x94\x82${NC}"
  echo -e "  ${DIM}\xe2\x94\x82${NC}  ${GREEN}${BOLD}$(pad "Setup complete" $((inner_width - 2)))${NC}${DIM}\xe2\x94\x82${NC}"
  echo -e "  ${DIM}\xe2\x94\x82${NC}  $(pad "" $((inner_width - 2)))${DIM}\xe2\x94\x82${NC}"
  echo -e "  ${DIM}\xe2\x94\x9c$(box_line "$inner_width")\xe2\x94\xa4${NC}"
  echo -e "  ${DIM}\xe2\x94\x82${NC}  ${DIM}project${NC}  ${BOLD}$(pad "${project_name}" $((inner_width - 11)))${NC}${DIM}\xe2\x94\x82${NC}"
  echo -e "  ${DIM}\xe2\x94\x82${NC}  ${DIM}site${NC}     $(pad "${site_url}" $((inner_width - 11)))${DIM}\xe2\x94\x82${NC}"
  echo -e "  ${DIM}\xe2\x94\x9c$(box_line "$inner_width")\xe2\x94\xa4${NC}"
  echo -e "  ${DIM}\xe2\x94\x82${NC}  ${CYAN}dev${NC}      $(pad "${dev_command}" $((inner_width - 11)))${DIM}\xe2\x94\x82${NC}"
  echo -e "  ${DIM}\xe2\x94\x82${NC}  ${CYAN}build${NC}    $(pad "${build_command}" $((inner_width - 11)))${DIM}\xe2\x94\x82${NC}"
  echo -e "  ${DIM}\xe2\x94\x82${NC}  ${CYAN}preview${NC}  $(pad "${preview_command}" $((inner_width - 11)))${DIM}\xe2\x94\x82${NC}"
  echo -e "  ${DIM}\xe2\x94\x82${NC}  $(pad "" $((inner_width - 2)))${DIM}\xe2\x94\x82${NC}"
  echo -e "  ${DIM}\xe2\x94\x94$(box_line "$inner_width")\xe2\x94\x98${NC}"
  echo ""
}

BASE_DOMAIN=""
DEPLOY_PATH=""
PORT="3000"

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain)
      if [[ -z "${2-}" ]] || [[ "$2" == --* ]]; then
        log_error "--domain requires an argument."
        exit 1
      fi
      BASE_DOMAIN="$2"
      shift 2
      ;;
    --deploy)
      if [[ -z "${2-}" ]] || [[ "$2" == --* ]]; then
        log_error "--deploy requires a path argument (e.g. /root/projects/my-project)."
        exit 1
      fi
      DEPLOY_PATH="$2"
      shift 2
      ;;
    --port)
      if [[ -z "${2-}" ]] || [[ "$2" == --* ]]; then
        log_error "--port requires a number (e.g. 3000)."
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
        log_error "--port must be a number between 1 and 65535."
        exit 1
      fi
      PORT="$2"
      shift 2
      ;;
    --help)
      echo ""
      echo -e "  ${MAGENTA}${BOLD}mugdoc${NC} ${DIM}\xe2\x94\x80 generate docs from your README${NC}"
      echo ""
      echo -e "  ${BOLD}Usage${NC}"
      echo -e "    ./setup.sh ${DIM}[options]${NC}"
      echo ""
  echo -e "  ${BOLD}Options${NC}"
  echo -e "    --domain ${DIM}<domain>${NC}   Base domain for site URL ${DIM}(required)${NC}"
  echo -e "    --deploy ${DIM}<path>${NC}     Absolute path to the project on the server."
  echo -e "                        Generates Dockerfile, compose.yml,"
  echo -e "                        and a GitHub Actions workflow for SSH deploy."
  echo -e "    --port ${DIM}<number>${NC}     Container port for the docs site"
  echo -e "                        ${DIM}(requires --deploy, default: 3000)${NC}"
  echo -e "    --help               Show this help message"
      echo ""
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ -z "$BASE_DOMAIN" ]; then
  log_error "--domain is required."
  exit 1
fi

if [ -n "$PORT" ] && [ -z "$DEPLOY_PATH" ]; then
  log_error "--port requires --deploy to be specified."
  exit 1
fi

detect_project_name() {
  local project_name=""

  if [ -f "$PROJECT_ROOT/package.json" ]; then
    project_name=$(grep -o '"name"\s*:\s*"[^"]*"' "$PROJECT_ROOT/package.json" 2>/dev/null | head -1 | cut -d'"' -f4)
  fi

  if [ -z "$project_name" ] && [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
    project_name=$(grep -A2 "\[package\]" "$PROJECT_ROOT/Cargo.toml" 2>/dev/null | grep "name\s*=" | head -1 | cut -d'"' -f2)
  fi

  if [ -z "$project_name" ] && [ -f "$PROJECT_ROOT/go.mod" ]; then
    project_name=$(grep "^module" "$PROJECT_ROOT/go.mod" 2>/dev/null | head -1 | awk '{print $2}' | awk -F'/' '{print $NF}')
  fi

  if [ -z "$project_name" ] && [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
    project_name=$(grep -A2 "\[project\]" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null | grep "name\s*=" | head -1 | cut -d'"' -f2)
  fi

  if [ -z "$project_name" ]; then
    project_name="$(basename "$PROJECT_ROOT")"
    log_warning "Could not detect project name. Using directory name: $project_name"
  fi

  echo "$project_name" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/-\+/-/g' -e 's/^-//' -e 's/-$//'
}

extract_description() {
  local description=""

  if [ -f "$PROJECT_ROOT/README.md" ]; then
    description=$(sed -e 's/^[[:space:]]*//' "$PROJECT_ROOT/README.md" | grep -v '^#' | grep -v '^<' | grep -v '^\[' | grep -v '^```' | grep -v '^$' | head -1 | sed 's/[[:space:]]*$//')
  fi

  if [ -z "$description" ] && [ -f "$PROJECT_ROOT/package.json" ]; then
    description=$(grep -o '"description"\s*:\s*"[^"]*"' "$PROJECT_ROOT/package.json" 2>/dev/null | head -1 | cut -d'"' -f4)
  fi

  if [ -z "$description" ]; then
    description="Project documentation"
    log_warning "Could not extract description. Using fallback."
  fi

  echo "$description" | cut -c1-200
}

readme_content_without_title() {
  if [ ! -f "$PROJECT_ROOT/README.md" ]; then
    echo "Documentation for this project."
    return
  fi

  local readme_file="$PROJECT_ROOT/README.md"
  local start_line=1

  local markdown_heading
  markdown_heading=$(grep -n '^# ' "$readme_file" | head -1 | cut -d: -f1) || true

  local html_heading_close
  html_heading_close=$(grep -n '</h1>\|</h2>' "$readme_file" | head -1 | cut -d: -f1) || true

  local html_block_end
  html_block_end=$(grep -n '^</p>' "$readme_file" | head -1 | cut -d: -f1) || true

  if [ -n "$html_block_end" ] && [ -n "$html_heading_close" ]; then
    local max=$((html_block_end > html_heading_close ? html_block_end : html_heading_close))
    start_line=$((max + 1))
  elif [ -n "$markdown_heading" ]; then
    start_line=$((markdown_heading + 1))
  elif [ -n "$html_heading_close" ]; then
    start_line=$((html_heading_close + 1))
  fi

  tail -n +"$start_line" "$readme_file" | sed '/\S/,$!d'
}

copy_readme_images() {
  local index_file="$1"
  local public_dir="$SCRIPT_DIR/public"

  local image_paths
  image_paths=$(grep -oP '!\[[^\]]*\]\(\K[^)]+' "$index_file" 2>/dev/null || true)
  image_paths+=$'\n'
  image_paths+=$(grep -oP '<img[^>]+src=["'\'']\K[^"'\'']+' "$index_file" 2>/dev/null || true)

  echo "$image_paths" | sort -u | while IFS= read -r image_path; do
    [ -z "$image_path" ] && continue

    [[ "$image_path" =~ ^https?:// ]] && continue
    [[ "$image_path" =~ ^// ]] && continue

    local resolved_path="$image_path"
    resolved_path="${resolved_path#./}"

    local source_file="$PROJECT_ROOT/$resolved_path"

    if [ -f "$source_file" ]; then
      local filename
      filename=$(basename "$resolved_path")
      mkdir -p "$public_dir"
      cp "$source_file" "$public_dir/$filename"

      sed -i "s|${image_path}|/${filename}|g" "$index_file"
      log_success "Copied image: ${DIM}$resolved_path${NC}"
    else
      log_warning "Image not found: $source_file"
    fi
  done
}

generate_index() {
  local project_name="$1"
  local description="$2"
  local index_file="$SCRIPT_DIR/src/content/docs/index.md"

  {
    echo "---"
    echo "title: \"${project_name}\""
    echo "description: \"${description}\""
    echo "---"
    echo ""
    readme_content_without_title
  } > "$index_file"

  copy_readme_images "$index_file"
}

apply_config_placeholders() {
  local file="$1"
  local project_name="$2"
  local base_domain="$3"

  sed -i "s|{{BASE_DOMAIN}}|${base_domain}|g" "$file"
  sed -i "s|{{PROJECT_NAME}}|${project_name}|g" "$file"
}

detect_package_manager() {
  if command -v pnpm &>/dev/null; then
    echo "pnpm"
  elif command -v yarn &>/dev/null; then
    echo "yarn"
  else
    echo "npm"
  fi
}

install_dependencies() {
  local package_manager="$1"

  case "$package_manager" in
    pnpm) pnpm install --dir "$SCRIPT_DIR" ;;
    yarn) yarn install --cwd "$SCRIPT_DIR" ;;
    *) npm install --prefix "$SCRIPT_DIR" ;;
  esac
}

configure_deploy() {
  local project_name="$1"
  local base_domain="$2"
  local deploy_path="$3"
  local port="$4"
  local docs_directory="docs"

  apply_config_placeholders "$SCRIPT_DIR/compose.yml" "$project_name" "$base_domain"
  sed -i "s|{{PORT}}|${port}|g" "$SCRIPT_DIR/compose.yml"

  sed -i "s|{{PORT}}|${port}|g" "$SCRIPT_DIR/Dockerfile"

  local workflow_file="$SCRIPT_DIR/deploy-docs.yml"
  sed -i "s|{{DOCS_DIR}}|${docs_directory}|g" "$workflow_file"
  sed -i "s|{{DEPLOY_PATH}}|${deploy_path}|g" "$workflow_file"

  local workflow_dir="$PROJECT_ROOT/.github/workflows"
  mkdir -p "$workflow_dir"
  cp "$workflow_file" "$workflow_dir/deploy-docs.yml"
  rm "$workflow_file"
  log_success "GitHub Actions workflow"

  log_success "Dockerfile + compose.yml"
}

remove_deploy_files() {
  rm -f "$SCRIPT_DIR/Dockerfile"
  rm -f "$SCRIPT_DIR/.dockerignore"
  rm -f "$SCRIPT_DIR/compose.yml"
  rm -f "$SCRIPT_DIR/deploy-docs.yml"
}

main() {
  if [ -n "$DEPLOY_PATH" ]; then
    TOTAL_STEPS=7
  else
    TOTAL_STEPS=6
  fi

  banner

  step "Checking environment"
  if ! command -v node &>/dev/null; then
    log_error "Node.js is required but not installed."
    exit 1
  fi
  log_success "Node.js $(node --version)"

  local package_manager
  package_manager=$(detect_package_manager)
  log_success "$package_manager"

  step "Detecting project"
  local project_name
  project_name=$(detect_project_name)
  log_success "$project_name"

  local description
  description=$(extract_description)
  log_detail "${ITALIC}${description}${NC}"

  step "Configuring site"
  apply_config_placeholders "$SCRIPT_DIR/astro.config.mjs" "$project_name" "$BASE_DOMAIN"
  log_success "astro.config.mjs"

  step "Generating documentation"
  generate_index "$project_name" "$description"
  log_success "index.md from README"

  if [ -d "$PROJECT_ROOT/assets" ]; then
    mkdir -p "$SCRIPT_DIR/public"
    cp -r "$PROJECT_ROOT/assets"/* "$SCRIPT_DIR/public/" 2>/dev/null || true
    log_success "Assets copied"
  fi

  step "Installing dependencies"
  install_dependencies "$package_manager" > /dev/null 2>&1 &
  local install_pid=$!

  if ! spinner "$install_pid" "Installing packages..."; then
    log_error "Failed to install dependencies."
    exit 1
  fi
  log_success "Dependencies installed"

  cat > "$SCRIPT_DIR/.gitignore" << 'EOF'
node_modules
dist
.astro
EOF

  if [ -n "$DEPLOY_PATH" ]; then
    step "Configuring deploy"
    configure_deploy "$project_name" "$BASE_DOMAIN" "$DEPLOY_PATH" "$PORT"
  else
    remove_deploy_files
  fi

  step "Cleaning up"
  rm -- "$0"
  log_success "setup.sh removed"

  print_summary "$project_name" "$BASE_DOMAIN" "docs" "$package_manager"
}

main "$@"
