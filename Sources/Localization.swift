import Foundation

extension Notification.Name {
    static let appLanguageChanged = Notification.Name("AsanaStatus.appLanguageChanged")
}

enum AppLanguage: String {
    case en, es

    var displayName: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        }
    }

    static var current: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: "appLanguage"), let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return .en
        }
        set {
            guard newValue != current else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage")
            NotificationCenter.default.post(name: .appLanguageChanged, object: nil)
        }
    }
}

/// All user-facing strings, switched live on `AppLanguage.current`. English is the default;
/// Spanish is used only when explicitly selected in Settings.
enum L {
    private static var es: Bool { AppLanguage.current == .es }

    // MARK: Setup window
    static var setupWindowTitle: String { es ? "AsanaStatus — Configuración" : "AsanaStatus — Setup" }
    static var setupSubtitle: String {
        es ? "Pega tu Personal Access Token de Asana para ver tu tiempo logueado esta semana vs tu meta."
           : "Paste your Asana Personal Access Token to see your time logged this week vs. your goal."
    }
    static var tokenLabel: String { "Personal Access Token" }
    static var tokenPlaceholder: String { "Personal Access Token" }
    static var workspaceLabel: String { "Workspace GID" }
    static var workspacePlaceholder: String {
        es ? "Workspace GID (opcional — se detecta solo)" : "Workspace GID (optional — auto-detected)"
    }
    static var goalLabel: String { es ? "Meta semanal (horas)" : "Weekly goal (hours)" }
    static var goalPlaceholder: String { es ? "Meta semanal en horas (ej. 40)" : "Weekly goal in hours (e.g. 40)" }
    static var weekStartLabel: String { es ? "La semana se reinicia el" : "Week resets on" }
    static var languageLabel: String { es ? "Idioma" : "Language" }
    static var saveButton: String { es ? "Guardar y Conectar" : "Save & Connect" }
    static var generateTokenLink: String { es ? "Generar un token →" : "Generate a token →" }

    static var tokenRequiredError: String { es ? "El token es requerido." : "Token is required." }
    static var goalInvalidError: String {
        es ? "La meta semanal debe ser un número mayor a 0." : "Weekly goal must be a number greater than 0."
    }
    static var connecting: String { es ? "Conectando…" : "Connecting…" }
    static var noWorkspacesError: String {
        es ? "Tu cuenta no tiene workspaces visibles con este token."
           : "Your account has no workspaces visible with this token."
    }
    static var multipleWorkspacesError: String {
        es ? "Tienes varios workspaces. Copia el GID que quieras usar en el campo 'Workspace GID' y guarda de nuevo:"
           : "You have multiple workspaces. Copy the GID you want to use into the 'Workspace GID' field and save again:"
    }

    static let weekdayNamesEs = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
    static let weekdayNamesEn = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static var weekdayNames: [String] { es ? weekdayNamesEs : weekdayNamesEn }

    // MARK: Popup
    static var thisWeekHeader: String { es ? "ESTA SEMANA" : "THIS WEEK" }
    static func ofGoal(_ hours: Double, percent: Int) -> String {
        es ? String(format: "de %.0fh (%d%%)", hours, percent) : String(format: "of %.0fh (%d%%)", hours, percent)
    }
    static var rightOnTrack: String { es ? "Justo a tiempo con tu objetivo semanal." : "Right on track with your weekly goal." }
    static func aheadOfGoal(_ hours: Double) -> String {
        es ? String(format: "%.1fh por delante del objetivo semanal.", hours)
           : String(format: "%.1fh ahead of your weekly goal.", hours)
    }
    static func behindGoal(_ hours: Double) -> String {
        es ? String(format: "%.1fh detrás del objetivo semanal.", hours)
           : String(format: "%.1fh behind your weekly goal.", hours)
    }
    static var tasksHeader: String { es ? "TAREAS CON TIEMPO ESTA SEMANA" : "TASKS WITH TIME THIS WEEK" }
    static var noTimeLoggedYet: String { es ? "Sin tiempo registrado aún" : "No time logged yet" }
    static func updatedAt(_ time: String) -> String { es ? "Actualizado \(time)" : "Updated \(time)" }
    static var updatingNow: String { es ? "Actualizando…" : "Updating…" }

    // MARK: Menu
    static var refreshNowMenu: String { es ? "Actualizar ahora" : "Refresh now" }
    static var settingsMenu: String { es ? "Configuración…" : "Settings…" }
    static var aboutMenu: String { es ? "Acerca de AsanaStatus" : "About AsanaStatus" }
    static var quitMenu: String { es ? "Salir de AsanaStatus" : "Quit AsanaStatus" }
    static func goalReachedNotification(_ hours: Double) -> String {
        let h = String(format: "%.0f", hours)
        return es ? "¡Llegaste a tu meta de \(h)h esta semana! 🎉" : "You hit your \(h)h goal for the week! 🎉"
    }

    // MARK: About window
    static var aboutWindowTitle: String { es ? "Acerca de AsanaStatus" : "About AsanaStatus" }
    static var aboutSubtitle: String {
        es ? "Muestra en la barra de menú cuántas horas has logueado en Asana esta semana frente a tu meta semanal."
           : "Shows in the menu bar how many hours you've logged in Asana this week against your weekly goal."
    }
    static var originHeader: String { es ? "Origen" : "Origin" }
    static var originBody: String {
        es ? "Construido por Roberto Pacheco para ver de un vistazo si va al día con sus horas de la semana, sin entrar a Asana."
           : "Built by Roberto Pacheco to see at a glance whether he's on track with his hours for the week, without opening Asana."
    }
    static var supportHeader: String { es ? "Soporte" : "Support" }
}
