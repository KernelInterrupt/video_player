//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <file_selector_windows/file_selector_windows.h>
#include <fvp/fvp_plugin_c_api.h>
#include <native_opencv_windows/native_opencv_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  FvpPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FvpPluginCApi"));
  NativeOpencvWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("NativeOpencvWindowsPlugin"));
}
