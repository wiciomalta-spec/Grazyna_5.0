def init_ui(self):
    self.setWindowTitle("MegaWypaĹ›ny Panel Sterowania AIChat 2.0")
    self.setGeometry(100, 100, 1200, 800)
    self.setStyleSheet("""
        background-color: #121212;
        color: #00f0ff;
        font-family: 'Consolas';
        font-size: 14px;
    """)

    # GĹ‚Ăłwne widgety
    self.central_widget = QWidget()
    self.setCentralWidget(self.central_widget)
    self.layout = QHBoxLayout(self.central_widget)

    # Lewy panel: 3D Rings + Stan Systemu
    self.left_panel = QWidget()
    self.left_layout = QVBoxLayout(self.left_panel)
    self.init_3d_rings()
    self.init_system_status()

    # Prawy panel: Logi + Konsola
    self.right_panel = QWidget()
    self.right_layout = QVBoxLayout(self.right_panel)
    self.init_logs()
    self.init_console()

    # Dodanie panelu gĹ‚osowego
    self.init_voice_control()

    # Finalizacja layoutu
    self.layout.addWidget(self.left_panel, 70)
    self.layout.addWidget(self.right_panel, 30)

def init_3d_rings(self):
    # Wizualizacja 3D pierĹ›cieni
    self.figure = Figure(figsize=(5, 4), dpi=100, facecolor="#121212")
    self.canvas = FigureCanvas(self.figure)
    self.ax = self.figure.add_subplot(111, projection="3d")
    self.left_layout.addWidget(self.canvas)
    self.animate_rings()

def animate_rings(self):
    # Animacja pierĹ›cieni
    def update(frame):
        self.ax.clear()
        self.ax.set_facecolor("#121212")

        # Symulacja pierĹ›cieni
        for i in range(1, 4):
            theta = np.linspace(0, 2 * np.pi, 100)
            z = i * np.ones_like(theta)
            r = i
            x = r * np.cos(theta)
            y = r * np.sin(theta)
            self.ax.plot(x, y, z, color="cyan", alpha=0.7, linewidth=2)

        self.ax.set_xlim(-5, 5)
        self.ax.set_ylim(-5, 5)
        self.ax.set_zlim(0, 5)
        self.ax.set_title("PierĹ›cienie ATK Engine", color="white")
        self.ax.grid(False)
        self.ax.axis("off")

    self.ani = animation.FuncAnimation(self.figure, update, frames=100, interval=50)

def init_system_status(self):
    # Sekcja stanu systemu
    self.status_label = QLabel("Stan Systemu: Aktywny")
    self.status_label.setFont(QFont("Consolas", 16))
    self.left_layout.addWidget(self.status_label)

    self.progress_bar = QProgressBar()
    self.progress_bar.setStyleSheet("""
        QProgressBar {
            border: 2px solid #00f0ff;
            border-radius: 5px;
            text-align: center;
        }
        QProgressBar::chunk {
            background-color: #00f0ff;
            width: 10px;
            margin: 1px;
        }
    """)
    self.left_layout.addWidget(self.progress_bar)

def init_logs(self):
    # Sekcja logĂłw
    self.logs_label = QLabel("Logi Systemowe:")
    self.logs_label.setFont(QFont("Consolas", 14))
    self.right_layout.addWidget(self.logs_label)

    self.logs_list = QListWidget()
    self.logs_list.setStyleSheet("""
        QListWidget {
            background-color: #1e1e1e;
            color: #00f0ff;
            border: 1px solid #00f0ff;
        }
    """)
    self.right_layout.addWidget(self.logs_list)

def init_console(self):
    # Sekcja konsoli tekstowej
    self.console_label = QLabel("Konsola Komend:")
    self.console_label.setFont(QFont("Consolas", 14))
    self.right_layout.addWidget(self.console_label)

    self.command_input = QLineEdit()
    self.command_input.setStyleSheet("""
        QLineEdit {
            background-color: #1e1e1e;
            color: #00f0ff;
            border: 1px solid #00f0ff;
            padding: 5px;
        }
    """)
    self.right_layout.addWidget(self.command_input)

    self.send_button = QPushButton("Wykonaj")
    self.send_button.setStyleSheet("""
        QPushButton {
            background-color: #00f0ff;
            color: #121212;
            border: none;
            padding: 5px;
            font-weight: bold;
        }
        QPushButton:hover {
            background-color: #00ccff;
        }
    """)
    self.send_button.clicked.connect(self.execute_command)
    self.right_layout.addWidget(self.send_button)

def init_voice_control(self):
    # Sekcja sterowania gĹ‚osowego
    self.voice_button = QPushButton("đźŽ¤ Rozpocznij NasĹ‚uchiwanie")
    self.voice_button.setStyleSheet("""
        QPushButton {
            background-color: #ff00ff;
            color: white;
            border: none;
            padding: 10px;
            font-size: 16px;
        }
        QPushButton:hover {
            background-color: #cc00cc;
        }
    """)
    self.voice_button.clicked.connect(self.start_listening)
    self.right_layout.addWidget(self.voice_button)

def init_speech_recognition(self):
    self.recognizer = sr.Recognizer()
    self.microphone = sr.Microphone()

def start_listening(self):
    self.logs_list.addItem("NasĹ‚uchiwanie gĹ‚osowe... MĂłw teraz!")
    with self.microphone as source:
        self.recognizer.adjust_for_ambient_noise(source)
        audio = self.recognizer.listen(source)

    try:
        command = self.recognizer.recognize_google(audio, language="pl-PL")
        self.logs_list.addItem(f"Rozpoznano: {command}")
        self.command_input.setText(command)
        self.execute_command()
    except sr.UnknownValueError:
        self.logs_list.addItem("Nie rozpoznano mowy.")
    except sr.RequestError as e:
        self.logs_list.addItem(f"Błąd serwisu rozpoznawania mowy: {e}")

def execute_command(self):
    command = self.command_input.text()
    if not command:
        return

    self.logs_list.addItem(f"> {command}")
    self.command_input.clear()

    # Wykonaj komendÄ™ w AIChat
    response = self.ai_chat.ask(command)
    self.logs_list.addItem(f"AI: {response}")

    # Aktualizuj stan systemu
    self.update_system_status()

def update_system_status(self):
    # Symulacja aktualizacji stanu
    self.progress_bar.setValue(np.random.randint(0, 100))
    self.status_label.setText(f"Stan Systemu: {np.random.choice(['Aktywny', 'Gotowy', 'Przetwarzanie', 'Błąd'])}")

def init_real_time_updates(self):
    # Symulacja aktualizacji w czasie rzeczywistym
    self.timer = QTimer(self)
    self.timer.timeout.connect(self.update_system_status)
    self.timer.start(2000)

