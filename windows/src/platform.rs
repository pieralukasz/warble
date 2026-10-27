//! Which program the user was typing into, recorded with each dictation.

/// Returns `(display name, executable name)` of the foreground window's program.
#[cfg(windows)]
pub fn foreground_app() -> Option<(String, String)> {
    use windows_sys::Win32::Foundation::CloseHandle;
    use windows_sys::Win32::System::Threading::{
        OpenProcess, QueryFullProcessImageNameW, PROCESS_NAME_WIN32, PROCESS_QUERY_LIMITED_INFORMATION,
    };
    use windows_sys::Win32::UI::WindowsAndMessaging::{GetForegroundWindow, GetWindowThreadProcessId};

    unsafe {
        let hwnd = GetForegroundWindow();
        if hwnd.is_null() {
            return None;
        }
        let mut pid = 0u32;
        GetWindowThreadProcessId(hwnd, &mut pid);
        if pid == 0 {
            return None;
        }
        let process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
        if process.is_null() {
            return None;
        }
        let mut buf = [0u16; 1024];
        let mut len = buf.len() as u32;
        let ok = QueryFullProcessImageNameW(process, PROCESS_NAME_WIN32, buf.as_mut_ptr(), &mut len);
        CloseHandle(process);
        if ok == 0 {
            return None;
        }
        let path = String::from_utf16_lossy(&buf[..len as usize]);
        let exe = path.rsplit(['\\', '/']).next()?.to_string();
        let name = exe.strip_suffix(".exe").or_else(|| exe.strip_suffix(".EXE")).unwrap_or(&exe).to_string();
        Some((name, exe))
    }
}

#[cfg(not(windows))]
pub fn foreground_app() -> Option<(String, String)> {
    None
}

/// Waits up to a second for Shift, Ctrl, Alt and the Windows key to be let go.
#[cfg(windows)]
pub fn wait_for_modifiers_released() {
    use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
        GetAsyncKeyState, VK_CONTROL, VK_LWIN, VK_MENU, VK_RWIN, VK_SHIFT,
    };
    let held = || unsafe {
        [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN]
            .iter()
            .any(|vk| (GetAsyncKeyState(*vk as i32) as u16 & 0x8000) != 0)
    };
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(1);
    while held() && std::time::Instant::now() < deadline {
        std::thread::sleep(std::time::Duration::from_millis(15));
    }
}

#[cfg(not(windows))]
pub fn wait_for_modifiers_released() {}

/// Attaches to the console of the terminal that started us, so CLI commands
/// print output even though the app is built as a windowed program. Skipped
/// when output is already redirected (a pipe or file), which works as is.
#[cfg(windows)]
pub fn attach_parent_console() {
    use windows_sys::Win32::System::Console::{AttachConsole, GetStdHandle, ATTACH_PARENT_PROCESS, STD_OUTPUT_HANDLE};
    unsafe {
        let out = GetStdHandle(STD_OUTPUT_HANDLE);
        if out.is_null() || out == windows_sys::Win32::Foundation::INVALID_HANDLE_VALUE {
            AttachConsole(ATTACH_PARENT_PROCESS);
        }
    }
}

#[cfg(not(windows))]
pub fn attach_parent_console() {}
