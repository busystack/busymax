#include "tray_native_api.h"

#include <gtest/gtest.h>

#include <map>
#include <vector>

namespace tray_manager {
namespace {

class FakeTrayApi final : public TrayNativeApi {
 public:
  HICON loaded_icon = reinterpret_cast<HICON>(static_cast<INT_PTR>(0x100));
  bool destroy_result = true;
  bool add_result = true;
  bool modify_result = true;
  bool delete_result = true;
  bool version_result = true;
  HRESULT rect_result = S_OK;
  std::vector<HICON> destroyed;
  std::vector<DWORD> notify_calls;
  std::wstring loaded_path;
  std::wstring modified_tooltip;
  HMENU created_menu = reinterpret_cast<HMENU>(static_cast<INT_PTR>(0x300));
  bool append_result = true;
  bool destroy_menu_result = true;
  bool cursor_result = true;
  bool foreground_result = true;
  bool track_result = true;
  int destroyed_menus = 0;

  HICON LoadIconFile(const wchar_t* path, int, int) override {
    loaded_path = path == nullptr ? L"" : path;
    return loaded_icon;
  }

  bool DestroyIconHandle(HICON icon) override {
    destroyed.push_back(icon);
    return destroy_result;
  }

  bool NotifyIcon(DWORD message, NOTIFYICONDATAW* data) override {
    notify_calls.push_back(message);
    if (message == NIM_MODIFY && data != nullptr) {
      modified_tooltip = data->szTip;
    }
    if (message == NIM_ADD) return add_result;
    if (message == NIM_MODIFY) return modify_result;
    if (message == NIM_DELETE) return delete_result;
    if (message == NIM_SETVERSION) return version_result;
    return false;
  }

  HRESULT NotifyIconGetRect(const NOTIFYICONIDENTIFIER*,
                            RECT* rect) override {
    if (SUCCEEDED(rect_result) && rect != nullptr) {
      *rect = {1, 2, 11, 22};
    }
    return rect_result;
  }

  HMENU CreatePopupMenuHandle() override { return created_menu; }
  bool AppendMenuItem(HMENU, UINT, UINT_PTR, const wchar_t*) override {
    return append_result;
  }
  bool DestroyMenuHandle(HMENU) override {
    ++destroyed_menus;
    return destroy_menu_result;
  }
  bool GetCursorPosition(POINT* point) override {
    if (cursor_result && point != nullptr) *point = {1, 2};
    return cursor_result;
  }
  bool SetForegroundWindowHandle(HWND) override { return foreground_result; }
  bool TrackMenu(HMENU, int, int, HWND) override { return track_result; }

  DWORD LastError() const override { return ERROR_GEN_FAILURE; }
};

const HWND kWindow = reinterpret_cast<HWND>(static_cast<INT_PTR>(0x200));

TEST(TrayCallbackTest, DecodesVersionFourEventAndIconIdentifier) {
  const LPARAM value = MAKELPARAM(WM_RBUTTONUP, 1);
  EXPECT_EQ(TrayCallbackEvent(value), WM_RBUTTONUP);
  EXPECT_EQ(TrayCallbackIconId(value), 1u);
}

TEST(TrayIconControllerTest, CreatesTrayAndNegotiatesCurrentVersion) {
  FakeTrayApi api;
  TrayIconController controller(api);
  const auto result = controller.SetIcon(kWindow, L"busymax.ico");
  EXPECT_TRUE(result.succeeded);
  EXPECT_TRUE(controller.available());
  EXPECT_EQ(api.notify_calls, (std::vector<DWORD>{NIM_ADD, NIM_SETVERSION}));
  EXPECT_TRUE(api.destroyed.empty());
}

TEST(TrayIconControllerTest, RejectsMissingOrCorruptIcon) {
  FakeTrayApi api;
  api.loaded_icon = nullptr;
  TrayIconController controller(api);
  const auto result = controller.SetIcon(kWindow, L"missing.ico");
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "tray-icon-load-failed");
  EXPECT_FALSE(controller.available());
  EXPECT_TRUE(api.destroyed.empty());
}

TEST(TrayIconControllerTest, AddFailureDoesNotClaimAvailability) {
  FakeTrayApi api;
  api.add_result = false;
  TrayIconController controller(api);
  const auto result = controller.SetIcon(kWindow, L"busymax.ico");
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "tray-add-failed");
  EXPECT_FALSE(controller.available());
  EXPECT_EQ(api.destroyed, (std::vector<HICON>{api.loaded_icon}));
}

TEST(TrayIconControllerTest, ReplacesIconOnlyAfterSuccessfulModify) {
  FakeTrayApi api;
  TrayIconController controller(api);
  const HICON first = api.loaded_icon;
  ASSERT_TRUE(controller.SetIcon(kWindow, L"first.ico").succeeded);
  const HICON second =
      reinterpret_cast<HICON>(static_cast<INT_PTR>(0x101));
  api.loaded_icon = second;
  ASSERT_TRUE(controller.SetIcon(kWindow, L"second.ico").succeeded);
  EXPECT_EQ(api.destroyed, (std::vector<HICON>{first}));

  const HICON rejected =
      reinterpret_cast<HICON>(static_cast<INT_PTR>(0x102));
  api.loaded_icon = rejected;
  api.modify_result = false;
  EXPECT_FALSE(controller.SetIcon(kWindow, L"rejected.ico").succeeded);
  EXPECT_TRUE(controller.available());
  EXPECT_EQ(api.destroyed, (std::vector<HICON>{first, rejected}));
}

TEST(TrayIconControllerTest, PreservesTooltipAcrossIconReplacement) {
  FakeTrayApi api;
  TrayIconController controller(api);
  ASSERT_TRUE(controller.SetIcon(kWindow, L"first.ico").succeeded);
  ASSERT_TRUE(controller.SetTooltip(L"BusyMax offline").succeeded);
  api.loaded_icon =
      reinterpret_cast<HICON>(static_cast<INT_PTR>(0x101));
  ASSERT_TRUE(controller.SetIcon(kWindow, L"second.ico").succeeded);
  EXPECT_EQ(controller.tooltip(), L"BusyMax offline");
  EXPECT_EQ(api.modified_tooltip, L"BusyMax offline");
}

TEST(TrayIconControllerTest, ExplorerRecoveryReportsFailureAndSuccess) {
  FakeTrayApi api;
  TrayIconController controller(api);
  ASSERT_TRUE(controller.SetIcon(kWindow, L"busymax.ico").succeeded);
  api.add_result = false;
  EXPECT_FALSE(controller.Recover(kWindow).succeeded);
  EXPECT_FALSE(controller.available());
  api.add_result = true;
  EXPECT_TRUE(controller.Recover(kWindow).succeeded);
  EXPECT_TRUE(controller.available());
}

TEST(TrayIconControllerTest, DestroyAndRecreateReleasesEachIconOnce) {
  FakeTrayApi api;
  TrayIconController controller(api);
  const HICON first = api.loaded_icon;
  ASSERT_TRUE(controller.SetIcon(kWindow, L"first.ico").succeeded);
  ASSERT_TRUE(controller.Destroy().succeeded);
  EXPECT_EQ(api.destroyed, (std::vector<HICON>{first}));
  api.loaded_icon =
      reinterpret_cast<HICON>(static_cast<INT_PTR>(0x101));
  ASSERT_TRUE(controller.SetIcon(kWindow, L"second.ico").succeeded);
  EXPECT_TRUE(controller.available());
}

TEST(TrayIconControllerTest, GetBoundsFailureIsPropagated) {
  FakeTrayApi api;
  TrayIconController controller(api);
  ASSERT_TRUE(controller.SetIcon(kWindow, L"busymax.ico").succeeded);
  api.rect_result = E_FAIL;
  RECT rect{};
  const auto result = controller.GetBounds(&rect);
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "tray-bounds-query-failed");
}

TEST(TrayMenuControllerTest, MenuCreationFailureIsPropagated) {
  FakeTrayApi api;
  api.created_menu = nullptr;
  TrayMenuController menu(api);
  const auto result = menu.SetItems({});
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "tray-menu-create-failed");
  EXPECT_FALSE(menu.available());
}

TEST(TrayMenuControllerTest, MenuInsertionFailureDestroysReplacementOnce) {
  FakeTrayApi api;
  api.append_result = false;
  TrayMenuController menu(api);
  TrayMenuItem item;
  item.id = 1;
  item.label = L"Open BusyMax";
  const auto result = menu.SetItems({item});
  EXPECT_FALSE(result.succeeded);
  EXPECT_EQ(result.error_code, "tray-menu-insert-failed");
  EXPECT_EQ(api.destroyed_menus, 1);
}

}  // namespace
}  // namespace tray_manager
