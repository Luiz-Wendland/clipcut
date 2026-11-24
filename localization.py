"""Runtime language preferences and ClipCut's application text catalog."""

from PySide6.QtCore import QCoreApplication, QLocale, QObject, QTranslator, Signal

from translations_pt_br import PT_BR


LANGUAGE_MODES = ("system", "en", "pt-BR")
CONTEXTS = frozenset(("ClipCut", "Main", "ClipTimeline", "ExportPopover", "ToolInspector"))


def resolve_language(mode, ui_languages):
    if mode in ("en", "pt-BR"):
        return mode
    for locale in ui_languages:
        base = locale.replace("_", "-").split("-", 1)[0].lower()
        if base == "pt":
            return "pt-BR"
        if base == "en":
            return "en"
    return "en"


def tr(source, **values):
    message = QCoreApplication.translate("ClipCut", source)
    return message.format(**values) if values else message


class PortugueseTranslator(QTranslator):
    def isEmpty(self):
        return False

    def translate(self, context, sourceText, disambiguation=None, n=-1):
        return PT_BR.get(sourceText) if context in CONTEXTS else None


class LanguagePreference(QObject):
    changed = Signal()

    def __init__(self, settings, parent=None):
        super().__init__(parent)
        self._settings = settings
        saved = settings.value("ui/language", "system", type=str)
        self.mode = saved if saved in LANGUAGE_MODES else "system"
        self._translator = PortugueseTranslator(self)
        self._installed = False
        self._engine = None

    def attach(self, engine):
        """Attach before loading QML so the first frame is localized."""
        self._engine = engine
        self._apply()

    def set_mode(self, mode):
        if mode not in LANGUAGE_MODES or mode == self.mode:
            return
        self.mode = mode
        self._settings.setValue("ui/language", mode)
        self._settings.sync()
        self._apply()
        self.changed.emit()

    def _apply(self):
        if self._engine is None:
            return
        use_portuguese = resolve_language(self.mode, QLocale.system().uiLanguages()) == "pt-BR"
        if use_portuguese == self._installed:
            return
        if use_portuguese:
            QCoreApplication.installTranslator(self._translator)
        else:
            QCoreApplication.removeTranslator(self._translator)
        self._installed = use_portuguese
        self._engine.retranslate()

    def detach(self):
        if self._installed:
            QCoreApplication.removeTranslator(self._translator)
            self._installed = False
        self._engine = None
