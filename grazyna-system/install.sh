#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# 🦞 GRAŻYNA 5.0 - AUTOMATYCZNY SKRYPT INSTALACYJNY
# ═══════════════════════════════════════════════════════════════════════════
# System autonomicznego zarządzania flotą pojazdów
# Wersja: 5.0.0
# Data: 2026-02-10
# ═══════════════════════════════════════════════════════════════════════════

set -e  # Zatrzymaj przy błędzie

# Kolory dla terminala
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logo ASCII
show_logo() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   🦞  GRAŻYNA 5.0 - Instalator Systemu                       ║
    ║                                                               ║
    ║   System Autonomicznego Zarządzania Flotą Pojazdów           ║
    ║   Wersja: 5.0.0 | Build: 2026.02.10                          ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Funkcje pomocnicze
print_step() {
    echo -e "\n${BLUE}▶${NC} ${GREEN}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Sprawdzenie systemu operacyjnego
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        print_success "Wykryto system: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        print_success "Wykryto system: macOS"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        print_success "Wykryto system: Windows (Git Bash/Cygwin)"
    else
        print_error "Nieobsługiwany system operacyjny: $OSTYPE"
        exit 1
    fi
}

# Sprawdzenie wymagań systemowych
check_requirements() {
    print_step "Sprawdzanie wymagań systemowych..."
    
    local missing_deps=()
    
    # Sprawdź Node.js
    if ! command -v node &> /dev/null; then
        missing_deps+=("Node.js (>= 18.x)")
        print_error "Node.js nie jest zainstalowany"
    else
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -lt 18 ]; then
            print_error "Node.js w wersji >= 18.x jest wymagany (zainstalowano: v$NODE_VERSION)"
            missing_deps+=("Node.js >= 18.x")
        else
            print_success "Node.js $(node -v) ✓"
        fi
    fi
    
    # Sprawdź npm
    if ! command -v npm &> /dev/null; then
        missing_deps+=("npm")
        print_error "npm nie jest zainstalowany"
    else
        print_success "npm $(npm -v) ✓"
    fi
    
    # Sprawdź git
    if ! command -v git &> /dev/null; then
        print_warning "Git nie jest zainstalowany (opcjonalny)"
    else
        print_success "Git $(git --version | cut -d' ' -f3) ✓"
    fi
    
    # Sprawdź Docker (opcjonalny)
    if ! command -v docker &> /dev/null; then
        print_warning "Docker nie jest zainstalowany (opcjonalny, wymagany dla produkcji)"
    else
        print_success "Docker $(docker --version | cut -d' ' -f3 | tr -d ',') ✓"
    fi
    
    # Sprawdź Python (dla backendu)
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("Python 3.8+")
        print_error "Python 3 nie jest zainstalowany"
    else
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        print_success "Python $(python3 --version | cut -d' ' -f2) ✓"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Brakujące zależności:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        print_info "Instrukcje instalacji:"
        echo "  Node.js: https://nodejs.org/"
        echo "  Python: https://www.python.org/"
        echo "  Docker: https://www.docker.com/"
        exit 1
    fi
    
    print_success "Wszystkie wymagania spełnione!"
}

# Instalacja Frontend (React + TypeScript)
install_frontend() {
    print_step "Instalacja Frontend (React + TypeScript + Vite)..."
    
    cd frontend
    
    print_info "Instalowanie zależności npm..."
    npm install --silent
    
    print_success "Frontend zainstalowany pomyślnie!"
    cd ..
}

# Instalacja Backend (Node.js + Express)
install_backend() {
    print_step "Instalacja Backend (Node.js + Express + TypeScript)..."
    
    cd backend
    
    print_info "Instalowanie zależności npm..."
    npm install --silent
    
    print_success "Backend zainstalowany pomyślnie!"
    cd ..
}

# Konfiguracja zmiennych środowiskowych
setup_environment() {
    print_step "Konfiguracja zmiennych środowiskowych..."
    
    # Frontend .env
    if [ ! -f "frontend/.env" ]; then
        cat > frontend/.env << EOF
# GRAŻYNA 5.0 - Konfiguracja Frontend
VITE_API_URL=http://localhost:3001/api
VITE_WS_URL=ws://localhost:3001
VITE_APP_NAME=GRAŻYNA 5.0
VITE_APP_VERSION=5.0.0
VITE_MAP_API_KEY=your_mapbox_api_key_here
EOF
        print_success "Utworzono frontend/.env"
    fi
    
    # Backend .env
    if [ ! -f "backend/.env" ]; then
        cat > backend/.env << EOF
# GRAŻYNA 5.0 - Konfiguracja Backend
NODE_ENV=development
PORT=3001
HOST=localhost

# Database
DATABASE_URL=postgresql://grazyna:grazyna123@localhost:5432/grazyna_db
REDIS_URL=redis://localhost:6379

# Security
JWT_SECRET=$(openssl rand -base64 32 2>/dev/null || echo "change-this-in-production")
SESSION_SECRET=$(openssl rand -base64 32 2>/dev/null || echo "change-this-in-production")

# CORS
CORS_ORIGIN=http://localhost:5173

# WebSocket
WS_PORT=3001

# Logging
LOG_LEVEL=debug
EOF
        print_success "Utworzono backend/.env"
    fi
}

# Inicjalizacja bazy danych
setup_database() {
    print_step "Konfiguracja bazy danych..."
    
    if command -v docker &> /dev/null; then
        print_info "Uruchamianie PostgreSQL i Redis przez Docker..."
        
        # Sprawdź czy kontenery już działają
        if docker ps | grep -q grazyna-postgres; then
            print_warning "Kontener PostgreSQL już działa"
        else
            docker run -d \
                --name grazyna-postgres \
                -e POSTGRES_DB=grazyna_db \
                -e POSTGRES_USER=grazyna \
                -e POSTGRES_PASSWORD=grazyna123 \
                -p 5432:5432 \
                postgres:15-alpine
            print_success "PostgreSQL uruchomiony"
        fi
        
        if docker ps | grep -q grazyna-redis; then
            print_warning "Kontener Redis już działa"
        else
            docker run -d \
                --name grazyna-redis \
                -p 6379:6379 \
                redis:7-alpine
            print_success "Redis uruchomiony"
        fi
    else
        print_warning "Docker nie jest dostępny - baza danych musi być skonfigurowana ręcznie"
        print_info "Zainstaluj PostgreSQL i Redis lokalnie lub użyj Docker"
    fi
}

# Build projektu
build_project() {
    print_step "Budowanie projektu..."
    
    # Build frontend
    cd frontend
    print_info "Budowanie frontend..."
    npm run build
    cd ..
    
    # Build backend
    cd backend
    print_info "Budowanie backend..."
    npm run build
    cd ..
    
    print_success "Projekt zbudowany pomyślnie!"
}

# Tworzenie skryptów startowych
create_startup_scripts() {
    print_step "Tworzenie skryptów startowych..."
    
    # Skrypt start.sh
    cat > start.sh << 'EOF'
#!/bin/bash
echo "🦞 Uruchamianie GRAŻYNA 5.0..."

# Sprawdź czy baza danych działa
if ! nc -z localhost 5432 2>/dev/null; then
    echo "⚠️  PostgreSQL nie działa. Uruchamianie..."
    docker start grazyna-postgres 2>/dev/null || echo "Uruchom PostgreSQL ręcznie"
fi

if ! nc -z localhost 6379 2>/dev/null; then
    echo "⚠️  Redis nie działa. Uruchamianie..."
    docker start grazyna-redis 2>/dev/null || echo "Uruchom Redis ręcznie"
fi

# Uruchom backend w tle
cd backend && npm run dev &
BACKEND_PID=$!

# Poczekaj na backend
sleep 3

# Uruchom frontend
cd ../frontend && npm run dev

# Zatrzymaj backend przy wyjściu
trap "kill $BACKEND_PID" EXIT
EOF
    chmod +x start.sh
    print_success "Utworzono start.sh"
    
    # Skrypt stop.sh
    cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Zatrzymywanie GRAŻYNA 5.0..."
pkill -f "vite"
pkill -f "node.*backend"
echo "✓ System zatrzymany"
EOF
    chmod +x stop.sh
    print_success "Utworzono stop.sh"
}

# Podsumowanie instalacji
show_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ INSTALACJA ZAKOŃCZONA POMYŚLNIE!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📋 Następne kroki:${NC}"
    echo ""
    echo -e "  ${BLUE}1.${NC} Uruchom system:"
    echo -e "     ${YELLOW}./start.sh${NC}"
    echo ""
    echo -e "  ${BLUE}2.${NC} Otwórz w przeglądarce:"
    echo -e "     ${YELLOW}http://localhost:5173${NC}"
    echo ""
    echo -e "  ${BLUE}3.${NC} Dokumentacja API:"
    echo -e "     ${YELLOW}http://localhost:3001/api/docs${NC}"
    echo ""
    echo -e "${CYAN}🛠️  Przydatne komendy:${NC}"
    echo ""
    echo -e "  ${YELLOW}./start.sh${NC}        - Uruchom system"
    echo -e "  ${YELLOW}./stop.sh${NC}         - Zatrzymaj system"
    echo -e "  ${YELLOW}npm run test${NC}      - Uruchom testy"
    echo -e "  ${YELLOW}npm run lint${NC}      - Sprawdź jakość kodu"
    echo ""
    echo -e "${CYAN}📚 Dokumentacja:${NC}"
    echo -e "  ${YELLOW}docs/README.md${NC}"
    echo ""
    echo -e "${PURPLE}🦞 Dziękujemy za wybór GRAŻYNA 5.0!${NC}"
    echo ""
}

# Główna funkcja instalacji
main() {
    clear
    show_logo
    
    detect_os
    check_requirements
    
    print_step "Rozpoczynam instalację..."
    
    setup_environment
    install_frontend
    install_backend
    setup_database
    create_startup_scripts
    
    print_step "Instalacja zakończona!"
    
    show_summary
}

# Obsługa przerwania (Ctrl+C)
trap 'echo -e "\n${RED}Instalacja przerwana przez użytkownika${NC}"; exit 1' INT

# Uruchom instalację
main
