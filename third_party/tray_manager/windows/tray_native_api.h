#ifndef TRAY_MANAGER_TRAY_NATIVE_API_H_
#define TRAY_MANAGER_TRAY_NATIVE_API_H_

#include <windows.h>

#include <shellapi.h>

#include <string>
#include <vector>

namespace tray_manager {

UINT TrayCallbackEvent(LPARAM value);
UINT TrayCallbackIconId(LPARAM value);

struct TrayOperationResult {
  bool succeeded = false;
  std::string error_code;
  std::string error_message;
};

class TrayNativeApi {
 public:
  virtual ~TrayNativeApi() = default;

  virtual HICON LoadIconFile(const wchar_t* path, int width, int height) = 0;
  virtual bool DestroyIconHandle(HICON icon) = 0;
  virtual bool NotifyIcon(DWORD message, NOTIFYICONDATAW* data) = 0;
  virtual HRESULT NotifyIconGetRect(const NOTIFYICONIDENTIFIER* identifier,
                                    RECT* rect) = 0;
  virtual HMENU CreatePopupMenuHandle() = 0;
  virtual bool AppendMenuItem(HMENU menu,
                              UINT flags,
                              UINT_PTR id,
                              const wchar_t* label) = 0;
  virtual bool DestroyMenuHandle(HMENU menu) = 0;
  virtual bool GetCursorPosition(POINT* point) = 0;
  virtual bool SetForegroundWindowHandle(HWND window) = 0;
  virtual bool TrackMenu(HMENU menu, int x, int y, HWND window) = 0;
  virtual DWORD LastError() const = 0;
};

class WindowsTrayNativeApi final : public TrayNativeApi {
 public:
  HICON LoadIconFile(const wchar_t* path, int width, int height) override;
  bool DestroyIconHandle(HICON icon) override;
  bool NotifyIcon(DWORD message, NOTIFYICONDATAW* data) override;
  HRESULT NotifyIconGetRect(const NOTIFYICONIDENTIFIER* identifier,
                            RECT* rect) override;
  HMENU CreatePopupMenuHandle() override;
  bool AppendMenuItem(HMENU menu,
                      UINT flags,
                      UINT_PTR id,
                      const wchar_t* label) override;
  bool DestroyMenuHandle(HMENU menu) override;
  bool GetCursorPosition(POINT* point) override;
  bool SetForegroundWindowHandle(HWND window) override;
  bool TrackMenu(HMENU menu, int x, int y, HWND window) override;
  DWORD LastError() const override;
};

enum class TrayMenuItemType { kNormal, kSeparator, kCheckbox, kSubmenu };

struct TrayMenuItem {
  int id = 0;
  TrayMenuItemType type = TrayMenuItemType::kNormal;
  std::wstring label;
  bool disabled = false;
  bool checked = false;
  std::vector<TrayMenuItem> children;
};

class TrayMenuController {
 public:
  explicit TrayMenuController(TrayNativeApi& api) : api_(api) {}
  ~TrayMenuController();

  TrayOperationResult SetItems(const std::vector<TrayMenuItem>& items);
  TrayOperationResult Show(HWND window, bool bring_to_front);
  bool available() const { return menu_ != nullptr; }

 private:
  bool Build(HMENU menu, const std::vector<TrayMenuItem>& items,
             std::string* error);

  TrayNativeApi& api_;
  HMENU menu_ = nullptr;
};

class TrayIconController {
 public:
  explicit TrayIconController(TrayNativeApi& api);
  ~TrayIconController();

  TrayIconController(const TrayIconController&) = delete;
  TrayIconController& operator=(const TrayIconController&) = delete;

  bool available() const { return available_; }
  const std::wstring& tooltip() const { return tooltip_; }

  TrayOperationResult SetIcon(HWND window, const std::wstring& path);
  TrayOperationResult SetTooltip(const std::wstring& tooltip);
  TrayOperationResult Recover(HWND window);
  TrayOperationResult Destroy();
  TrayOperationResult GetBounds(RECT* rect);

 private:
  TrayOperationResult Install(HWND window, HICON icon, bool own_new_icon);
  TrayOperationResult Failure(const char* code, const char* message) const;
  bool FillNotificationData(HWND window, HICON icon);
  void FillIdentifier();
  bool ReleaseIcon();

  TrayNativeApi& api_;
  NOTIFYICONDATAW notification_data_{};
  NOTIFYICONIDENTIFIER identifier_{};
  HICON icon_ = nullptr;
  std::wstring tooltip_;
  bool available_ = false;
};

}  // namespace tray_manager

#endif  // TRAY_MANAGER_TRAY_NATIVE_API_H_
