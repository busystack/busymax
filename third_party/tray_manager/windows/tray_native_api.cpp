#include "tray_native_api.h"

#include <strsafe.h>

#include <utility>

namespace tray_manager {

UINT TrayCallbackEvent(LPARAM value) {
  return LOWORD(static_cast<DWORD_PTR>(value));
}

UINT TrayCallbackIconId(LPARAM value) {
  return HIWORD(static_cast<DWORD_PTR>(value));
}

namespace {

TrayOperationResult Success() {
  TrayOperationResult result{};
  result.succeeded = true;
  return result;
}

}  // namespace

HICON WindowsTrayNativeApi::LoadIconFile(const wchar_t* path,
                                         int width,
                                         int height) {
  return static_cast<HICON>(::LoadImageW(nullptr, path, IMAGE_ICON, width,
                                         height, LR_LOADFROMFILE));
}

bool WindowsTrayNativeApi::DestroyIconHandle(HICON icon) {
  return ::DestroyIcon(icon) != FALSE;
}

bool WindowsTrayNativeApi::NotifyIcon(DWORD message,
                                      NOTIFYICONDATAW* data) {
  return ::Shell_NotifyIconW(message, data) != FALSE;
}

HRESULT WindowsTrayNativeApi::NotifyIconGetRect(
    const NOTIFYICONIDENTIFIER* identifier,
    RECT* rect) {
  return ::Shell_NotifyIconGetRect(identifier, rect);
}

HMENU WindowsTrayNativeApi::CreatePopupMenuHandle() {
  return ::CreatePopupMenu();
}

bool WindowsTrayNativeApi::AppendMenuItem(HMENU menu,
                                          UINT flags,
                                          UINT_PTR id,
                                          const wchar_t* label) {
  return ::AppendMenuW(menu, flags, id, label) != FALSE;
}

bool WindowsTrayNativeApi::DestroyMenuHandle(HMENU menu) {
  return ::DestroyMenu(menu) != FALSE;
}

bool WindowsTrayNativeApi::GetCursorPosition(POINT* point) {
  return ::GetCursorPos(point) != FALSE;
}

bool WindowsTrayNativeApi::SetForegroundWindowHandle(HWND window) {
  return ::SetForegroundWindow(window) != FALSE;
}

bool WindowsTrayNativeApi::TrackMenu(HMENU menu,
                                     int x,
                                     int y,
                                     HWND window) {
  ::SetLastError(ERROR_SUCCESS);
  const BOOL result = ::TrackPopupMenu(menu, TPM_BOTTOMALIGN | TPM_LEFTALIGN,
                                       x, y, 0, window, nullptr);
  // TrackPopupMenu also returns zero when the user dismisses the menu. That is
  // a successful interaction unless Windows set a concrete error.
  return result != FALSE || ::GetLastError() == ERROR_SUCCESS;
}

DWORD WindowsTrayNativeApi::LastError() const {
  return ::GetLastError();
}

TrayMenuController::~TrayMenuController() {
  if (menu_ != nullptr) {
    api_.DestroyMenuHandle(menu_);
    menu_ = nullptr;
  }
}

bool TrayMenuController::Build(HMENU menu,
                               const std::vector<TrayMenuItem>& items,
                               std::string* error) {
  for (const TrayMenuItem& item : items) {
    UINT flags = item.type == TrayMenuItemType::kSeparator ? MF_SEPARATOR
                                                           : MF_STRING;
    if (item.disabled) flags |= MF_GRAYED;
    if (item.type == TrayMenuItemType::kCheckbox) {
      flags |= item.checked ? MF_CHECKED : MF_UNCHECKED;
    }
    UINT_PTR item_id = static_cast<UINT_PTR>(item.id);
    HMENU unowned_submenu = nullptr;
    if (item.type == TrayMenuItemType::kSubmenu) {
      unowned_submenu = api_.CreatePopupMenuHandle();
      if (unowned_submenu == nullptr) {
        *error = "tray-submenu-create-failed";
        return false;
      }
      if (!Build(unowned_submenu, item.children, error)) {
        if (!api_.DestroyMenuHandle(unowned_submenu)) {
          *error = "tray-submenu-destroy-failed";
        }
        return false;
      }
      flags |= MF_POPUP;
      item_id = reinterpret_cast<UINT_PTR>(unowned_submenu);
    }
    if (!api_.AppendMenuItem(menu, flags, item_id, item.label.c_str())) {
      if (unowned_submenu != nullptr) {
        if (!api_.DestroyMenuHandle(unowned_submenu)) {
          *error = "tray-submenu-destroy-failed";
          return false;
        }
      }
      *error = "tray-menu-insert-failed";
      return false;
    }
    // After AppendMenu succeeds Windows transfers submenu ownership to root.
    unowned_submenu = nullptr;
  }
  return true;
}

TrayOperationResult TrayMenuController::SetItems(
    const std::vector<TrayMenuItem>& items) {
  HMENU replacement = api_.CreatePopupMenuHandle();
  if (replacement == nullptr) {
    return {false, "tray-menu-create-failed",
            "Windows could not create the BusyMax tray menu."};
  }
  std::string error;
  if (!Build(replacement, items, &error)) {
    if (!api_.DestroyMenuHandle(replacement)) {
      error = "tray-menu-destroy-failed";
    }
    return {false, error, "Windows could not build the BusyMax tray menu."};
  }
  HMENU previous = menu_;
  menu_ = replacement;
  if (previous != nullptr && !api_.DestroyMenuHandle(previous)) {
    return {false, "tray-menu-destroy-failed",
            "Windows could not release the previous BusyMax tray menu."};
  }
  return Success();
}

TrayOperationResult TrayMenuController::Show(HWND window,
                                             bool bring_to_front) {
  if (menu_ == nullptr || window == nullptr) {
    return {false, "tray-menu-unavailable",
            "The BusyMax tray menu is unavailable."};
  }
  POINT cursor{};
  if (!api_.GetCursorPosition(&cursor)) {
    return {false, "tray-cursor-query-failed",
            "Windows could not locate the pointer for the tray menu."};
  }
  if (bring_to_front && !api_.SetForegroundWindowHandle(window)) {
    return {false, "tray-window-foreground-failed",
            "Windows could not foreground BusyMax for its tray menu."};
  }
  if (!api_.TrackMenu(menu_, cursor.x, cursor.y, window)) {
    return {false, "tray-menu-display-failed",
            "Windows could not display the BusyMax tray menu."};
  }
  return Success();
}

TrayIconController::TrayIconController(TrayNativeApi& api) : api_(api) {
  notification_data_.cbSize = sizeof(notification_data_);
  identifier_.cbSize = sizeof(identifier_);
}

TrayIconController::~TrayIconController() {
  if (available_) {
    api_.NotifyIcon(NIM_DELETE, &notification_data_);
    available_ = false;
  }
  ReleaseIcon();
}

TrayOperationResult TrayIconController::Failure(const char* code,
                                                const char* message) const {
  TrayOperationResult result{};
  result.error_code = code;
  result.error_message = message;
  return result;
}

bool TrayIconController::FillNotificationData(HWND window, HICON icon) {
  notification_data_ = {};
  notification_data_.cbSize = sizeof(notification_data_);
  notification_data_.hWnd = window;
  notification_data_.uID = 1;
  notification_data_.uCallbackMessage = WM_USER + 1;
  notification_data_.uFlags = NIF_MESSAGE | NIF_ICON;
  notification_data_.hIcon = icon;
  if (!tooltip_.empty()) {
    notification_data_.uFlags |= NIF_TIP | NIF_SHOWTIP;
    if (FAILED(StringCchCopyW(notification_data_.szTip,
                              _countof(notification_data_.szTip),
                              tooltip_.c_str()))) {
      notification_data_.szTip[0] = L'\0';
      return false;
    }
  }
  return true;
}

void TrayIconController::FillIdentifier() {
  identifier_ = {};
  identifier_.cbSize = sizeof(identifier_);
  identifier_.hWnd = notification_data_.hWnd;
  identifier_.uID = notification_data_.uID;
  identifier_.guidItem = GUID_NULL;
}

bool TrayIconController::ReleaseIcon() {
  if (icon_ == nullptr) {
    return true;
  }
  const bool destroyed = api_.DestroyIconHandle(icon_);
  icon_ = nullptr;
  notification_data_.hIcon = nullptr;
  return destroyed;
}

TrayOperationResult TrayIconController::Install(HWND window,
                                                HICON icon,
                                                bool own_new_icon) {
  if (!FillNotificationData(window, icon)) {
    if (own_new_icon && icon != nullptr && !api_.DestroyIconHandle(icon)) {
      return Failure("tray-icon-destroy-failed",
                     "Windows could not release the invalid tray icon.");
    }
    return Failure("tray-tooltip-copy-failed",
                   "Windows could not prepare the BusyMax tray tooltip.");
  }
  if (!api_.NotifyIcon(NIM_ADD, &notification_data_)) {
    available_ = false;
    if (own_new_icon && icon != nullptr) {
      if (!api_.DestroyIconHandle(icon)) {
        return Failure("tray-add-rollback-failed",
                       "Windows could not add or release the tray icon.");
      }
    }
    notification_data_.hIcon = icon_;
    return Failure("tray-add-failed",
                   "Windows could not add the BusyMax notification icon.");
  }

  notification_data_.uVersion = NOTIFYICON_VERSION_4;
  if (!api_.NotifyIcon(NIM_SETVERSION, &notification_data_)) {
    const bool deleted = api_.NotifyIcon(NIM_DELETE, &notification_data_);
    available_ = false;
    if (own_new_icon && icon != nullptr) {
      if (!api_.DestroyIconHandle(icon)) {
        return Failure("tray-version-icon-rollback-failed",
                       "Windows could not release the rejected tray icon.");
      }
    }
    notification_data_.hIcon = icon_;
    return Failure(deleted ? "tray-version-failed"
                           : "tray-version-rollback-failed",
                   "Windows rejected the notification icon protocol version.");
  }

  HICON previous = icon_;
  icon_ = icon;
  available_ = true;
  FillIdentifier();
  if (own_new_icon && previous != nullptr && previous != icon_ &&
      !api_.DestroyIconHandle(previous)) {
    return Failure("tray-previous-icon-destroy-failed",
                   "Windows could not release the previous tray icon.");
  }
  return Success();
}

TrayOperationResult TrayIconController::SetIcon(HWND window,
                                                const std::wstring& path) {
  if (window == nullptr || path.empty()) {
    return Failure("tray-icon-arguments-invalid",
                   "The tray icon path or window was invalid.");
  }
  HICON replacement = api_.LoadIconFile(
      path.c_str(), GetSystemMetrics(SM_CXSMICON),
      GetSystemMetrics(SM_CYSMICON));
  if (replacement == nullptr) {
    return Failure("tray-icon-load-failed",
                   "Windows could not load the BusyMax tray icon.");
  }

  if (!available_) {
    return Install(window, replacement, true);
  }

  NOTIFYICONDATAW modified = notification_data_;
  modified.uFlags = NIF_MESSAGE | NIF_ICON;
  modified.hIcon = replacement;
  if (!tooltip_.empty()) {
    modified.uFlags |= NIF_TIP | NIF_SHOWTIP;
  }
  if (!api_.NotifyIcon(NIM_MODIFY, &modified)) {
    if (!api_.DestroyIconHandle(replacement)) {
      return Failure("tray-modify-rollback-failed",
                     "Windows could not replace or release the tray icon.");
    }
    return Failure("tray-modify-failed",
                   "Windows could not replace the BusyMax tray icon.");
  }

  HICON previous = icon_;
  icon_ = replacement;
  notification_data_ = modified;
  if (previous != nullptr && previous != replacement) {
    if (!api_.DestroyIconHandle(previous)) {
      return Failure("tray-previous-icon-destroy-failed",
                     "Windows could not release the previous tray icon.");
    }
  }
  return Success();
}

TrayOperationResult TrayIconController::SetTooltip(
    const std::wstring& tooltip) {
  if (tooltip.size() >= _countof(notification_data_.szTip)) {
    return Failure("tray-tooltip-too-long",
                   "The BusyMax tray tooltip exceeded the Windows limit.");
  }
  if (!available_) {
    tooltip_ = tooltip;
    return Success();
  }

  NOTIFYICONDATAW modified = notification_data_;
  modified.uFlags = NIF_MESSAGE | NIF_ICON;
  modified.szTip[0] = L'\0';
  if (!tooltip.empty()) {
    modified.uFlags |= NIF_TIP | NIF_SHOWTIP;
    const HRESULT copied = StringCchCopyW(
        modified.szTip, _countof(modified.szTip), tooltip.c_str());
    if (FAILED(copied)) {
      return Failure("tray-tooltip-copy-failed",
                     "Windows could not prepare the BusyMax tray tooltip.");
    }
  }
  if (!api_.NotifyIcon(NIM_MODIFY, &modified)) {
    return Failure("tray-tooltip-modify-failed",
                   "Windows could not update the BusyMax tray tooltip.");
  }
  tooltip_ = tooltip;
  notification_data_ = modified;
  return Success();
}

TrayOperationResult TrayIconController::Recover(HWND window) {
  if (icon_ == nullptr || window == nullptr) {
    available_ = false;
    return Failure("tray-recovery-unavailable",
                   "No valid tray icon was available for recovery.");
  }
  available_ = false;
  return Install(window, icon_, false);
}

TrayOperationResult TrayIconController::Destroy() {
  bool deleted = true;
  if (available_) {
    deleted = api_.NotifyIcon(NIM_DELETE, &notification_data_);
  }
  available_ = false;
  const bool icon_destroyed = ReleaseIcon();
  notification_data_ = {};
  notification_data_.cbSize = sizeof(notification_data_);
  identifier_ = {};
  identifier_.cbSize = sizeof(identifier_);
  if (!deleted) {
    return Failure("tray-delete-failed",
                   "Windows could not remove the BusyMax tray icon.");
  }
  if (!icon_destroyed) {
    return Failure("tray-icon-destroy-failed",
                   "Windows could not release the BusyMax tray icon.");
  }
  return Success();
}

TrayOperationResult TrayIconController::GetBounds(RECT* rect) {
  if (!available_ || rect == nullptr) {
    return Failure("tray-bounds-unavailable",
                   "The BusyMax tray icon is not available.");
  }
  *rect = {};
  if (FAILED(api_.NotifyIconGetRect(&identifier_, rect))) {
    return Failure("tray-bounds-query-failed",
                   "Windows could not locate the BusyMax tray icon.");
  }
  return Success();
}

}  // namespace tray_manager
