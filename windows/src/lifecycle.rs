//! Turns raw hotkey events into start/stop decisions.
//!
//! Windows repeats "pressed" while a shortcut is held, so a press only counts
//! when the key was up before. Without that, Toggle mode would start and stop
//! many times a second while the key is down.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    None,
    Start,
    Stop,
}

#[derive(Debug, Default)]
pub struct Lifecycle {
    recording: bool,
    key_down: bool,
}

impl Lifecycle {
    pub fn is_recording(&self) -> bool {
        self.recording
    }

    pub fn key_down(&mut self, toggle_mode: bool) -> Action {
        if self.key_down {
            return Action::None;
        }
        self.key_down = true;
        if toggle_mode && self.recording {
            self.recording = false;
            return Action::Stop;
        }
        if self.recording {
            return Action::None;
        }
        self.recording = true;
        Action::Start
    }

    pub fn key_up(&mut self, toggle_mode: bool) -> Action {
        self.key_down = false;
        if toggle_mode || !self.recording {
            return Action::None;
        }
        self.recording = false;
        Action::Stop
    }

    /// Recording could not start (no microphone, permission denied).
    pub fn start_failed(&mut self) {
        self.recording = false;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hold_mode_records_while_the_key_is_down() {
        let mut l = Lifecycle::default();
        assert_eq!(l.key_down(false), Action::Start);
        assert_eq!(l.key_down(false), Action::None); // auto-repeat
        assert_eq!(l.key_up(false), Action::Stop);
        assert_eq!(l.key_up(false), Action::None);
    }

    #[test]
    fn toggle_mode_ignores_auto_repeat() {
        let mut l = Lifecycle::default();
        assert_eq!(l.key_down(true), Action::Start);
        assert_eq!(l.key_down(true), Action::None);
        assert_eq!(l.key_down(true), Action::None);
        assert_eq!(l.key_up(true), Action::None);
        assert!(l.is_recording());
        assert_eq!(l.key_down(true), Action::Stop);
        assert_eq!(l.key_up(true), Action::None);
        assert!(!l.is_recording());
    }

    #[test]
    fn failed_start_lets_the_next_press_try_again() {
        let mut l = Lifecycle::default();
        assert_eq!(l.key_down(true), Action::Start);
        l.start_failed();
        l.key_up(true);
        assert_eq!(l.key_down(true), Action::Start);
    }
}
