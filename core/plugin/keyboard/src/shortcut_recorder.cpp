#include "shortcut_recorder.h"

#include <QGuiApplication>
#include <QFile>
#include <QDir>
#include <QKeyEvent>
#include <QQuickWindow>
#include <xkbcommon/xkbcommon.h>

ShortcutRecorder::ShortcutRecorder(QObject *parent) : QObject(parent) { qGuiApp->installEventFilter(this); }
ShortcutRecorder::~ShortcutRecorder() { qGuiApp->removeEventFilter(this); }

bool ShortcutRecorder::eventFilter(QObject *object, QEvent *event)
{
    if (!m_target || object != m_target->window())
        return false;
    if (m_escapeHeld && (event->type() == QEvent::KeyRelease || event->type() == QEvent::KeyPress ||
                         event->type() == QEvent::ShortcutOverride)) {
        auto *key = static_cast<QKeyEvent *>(event);
        if (key->key() == Qt::Key_Escape) {
            if (event->type() == QEvent::KeyRelease && !key->isAutoRepeat())
                m_escapeHeld = false;
            event->accept();
            return true;
        }
    }
    if (!m_enabled)
        return false;
    if (event->type() == QEvent::ShortcutOverride) {
        event->accept();
        return true;
    }
    if (event->type() == QEvent::FocusOut || event->type() == QEvent::WindowDeactivate) {
        emit cancelled();
        return false;
    }
    if (event->type() != QEvent::KeyPress)
        return false;
    auto *key = static_cast<QKeyEvent *>(event);
    if (key->isAutoRepeat())
        return true;
    const auto shortcutModifiers = Qt::ControlModifier | Qt::AltModifier | Qt::MetaModifier |
                                   Qt::ShiftModifier | Qt::GroupSwitchModifier;
    switch (key->key()) {
    case Qt::Key_Control:
    case Qt::Key_Shift:
    case Qt::Key_Alt:
    case Qt::Key_Meta:
    case Qt::Key_AltGr:
    case Qt::Key_NumLock:
    case Qt::Key_CapsLock:
        return true;
    default:
        break;
    }
    auto *context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    const auto rules = m_keymap.value("rules").toString().toUtf8();
    const auto model = m_keymap.value("model").toString().toUtf8();
    const auto layout = m_keymap.value("layout").toString().toUtf8();
    const auto variant = m_keymap.value("variant").toString().toUtf8();
    const auto options = m_keymap.value("options").toString().toUtf8();
    xkb_rule_names names{
        rules.isEmpty() ? nullptr : rules.constData(), model.isEmpty() ? nullptr : model.constData(),
        layout.isEmpty() ? nullptr : layout.constData(), variant.isEmpty() ? nullptr : variant.constData(),
        options.isEmpty() ? nullptr : options.constData()};
    xkb_keymap *map = nullptr;
    QString keymapFile = m_keymap.value("file").toString();
    if (!keymapFile.isEmpty()) {
        if (keymapFile.startsWith("~/"))
            keymapFile.replace(0, 1, QDir::homePath());
        QFile file(keymapFile);
        if (QDir::isAbsolutePath(keymapFile) && file.open(QIODevice::ReadOnly)) {
            const auto contents = file.readAll();
            map = xkb_keymap_new_from_string(context, contents.constData(), XKB_KEYMAP_FORMAT_TEXT_V1,
                                             XKB_KEYMAP_COMPILE_NO_FLAGS);
        }
    } else {
        map = xkb_keymap_new_from_names(context, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    }
    bool levelFive = false;
    xkb_keysym_t symbol = XKB_KEY_NoSymbol;
    if (map) {
        // Qt Wayland supplies an XKB scan code. Match the native keysym before
        // using level zero so a different live layout is never silently guessed.
        const auto code = key->nativeScanCode();
        for (xkb_layout_index_t group = 0; group < xkb_keymap_num_layouts_for_key(map, code); ++group) {
            bool matches = false;
            for (xkb_level_index_t level = 0; level < xkb_keymap_num_levels_for_key(map, code, group);
                 ++level) {
                const xkb_keysym_t *symbols = nullptr;
                int count = xkb_keymap_key_get_syms_by_level(map, code, group, level, &symbols);
                for (int i = 0; i < count; ++i)
                    matches |= symbols[i] == key->nativeVirtualKey();
            }
            if (!matches)
                continue;
            const xkb_keysym_t *symbols = nullptr;
            if (xkb_keymap_key_get_syms_by_level(map, code, group, 0, &symbols) == 1)
                symbol = symbols[0];
            break;
        }
        auto *state = xkb_state_new(map);
        xkb_state_update_mask(state, key->nativeModifiers(), 0, 0, 0, 0, 0);
        levelFive = xkb_state_mod_name_is_active(state, "LevelFive", XKB_STATE_MODS_EFFECTIVE) > 0;
        xkb_state_unref(state);
        xkb_keymap_unref(map);
    }
    xkb_context_unref(context);
    if (key->key() == Qt::Key_Escape && !(key->modifiers() & shortcutModifiers) && !levelFive) {
        m_escapeHeld = true;
        emit cancelled();
        return true;
    }
    // Keypad NumLock chooses a distinct trigger; retain that native keysym.
    if (key->modifiers().testFlag(Qt::KeypadModifier))
        symbol = key->nativeVirtualKey();
    char name[128]{};
    if (symbol == XKB_KEY_NoSymbol || xkb_keysym_get_name(symbol, name, sizeof(name)) <= 0) {
        emit failed(tr("The live keymap could not be matched. Enter the XKB key name manually."));
        return true;
    }
    QStringList parts;
    const auto modifiers = key->modifiers();
    if (modifiers.testFlag(Qt::ControlModifier))
        parts << "Ctrl";
    if (modifiers.testFlag(Qt::AltModifier))
        parts << "Alt";
    if (modifiers.testFlag(Qt::MetaModifier))
        parts << "Super";
    if (modifiers.testFlag(Qt::ShiftModifier))
        parts << "Shift";
    if (modifiers.testFlag(Qt::GroupSwitchModifier))
        parts << "ISO_Level3_Shift";
    if (levelFive)
        parts << "ISO_Level5_Shift";
    parts << QString::fromLatin1(name);
    emit captured(parts.join('+'));
    return true;
}

void ShortcutRecorder::captureMouse(int button, int modifiers)
{
    if (!m_enabled)
        return;
    QString name;
    switch (button) {
    case Qt::LeftButton:
        name = "MouseLeft";
        break;
    case Qt::MiddleButton:
        name = "MouseMiddle";
        break;
    case Qt::RightButton:
        name = "MouseRight";
        break;
    case Qt::BackButton:
        name = "MouseBack";
        break;
    case Qt::ForwardButton:
        name = "MouseForward";
        break;
    default:
        return;
    }
    QStringList parts;
    if (modifiers & Qt::ControlModifier)
        parts << "Ctrl";
    if (modifiers & Qt::AltModifier)
        parts << "Alt";
    if (modifiers & Qt::MetaModifier)
        parts << "Super";
    if (modifiers & Qt::ShiftModifier)
        parts << "Shift";
    if (modifiers & Qt::GroupSwitchModifier)
        parts << "ISO_Level3_Shift";
    parts << name;
    emit captured(parts.join('+'));
}
