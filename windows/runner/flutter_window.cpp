#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include "tone_generator.h"

/**
 * @brief Handles method calls related to window management from the Flutter app.
 */
void FlutterWindow::WindowMethodCallHandler(const flutter::MethodCall<>& call,
                                            std::unique_ptr<flutter::MethodResult<>> result) {
  if (call.method_name() == "setWindowPlacement") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (arguments) {
      try {
        WINDOWPLACEMENT placement = {0};
        placement.length = sizeof(WINDOWPLACEMENT);
        placement.ptMaxPosition.x =
            std::get<int>(arguments->at(flutter::EncodableValue("maximizedLeft")));
        placement.ptMaxPosition.y =
            std::get<int>(arguments->at(flutter::EncodableValue("maximizedTop")));
        placement.rcNormalPosition.left =
            std::get<int>(arguments->at(flutter::EncodableValue("left")));
        placement.rcNormalPosition.top =
            std::get<int>(arguments->at(flutter::EncodableValue("top")));
        placement.rcNormalPosition.right =
            std::get<int>(arguments->at(flutter::EncodableValue("right")));
        placement.rcNormalPosition.bottom =
            std::get<int>(arguments->at(flutter::EncodableValue("bottom")));
        placement.showCmd = std::get<bool>(arguments->at(flutter::EncodableValue("maximized")))
                                ? SW_SHOWMAXIMIZED
                                : SW_SHOWNORMAL;

        if (SetWindowPlacement(GetHandle(), &placement) == 0) {
          result->Error("Error in SetWindowPlacement");
        } else {
          result->Success();
        }
      } catch (std::out_of_range&) {
        result->Error("Bad arguments", "Missing required arguments.");
      } catch (std::bad_variant_access&) {
        result->Error("Bad arguments", "Invalid argument type.");
      }
    } else {
      result->Error("Bad arguments", "Arguments not an EncodableMap.");
    }
    placement_set_ = true;
  } else if (call.method_name() == "getWindowPlacement") {
    WINDOWPLACEMENT placement = {0};
    placement.length = sizeof(WINDOWPLACEMENT);
    if (GetWindowPlacement(GetHandle(), &placement) == 0) {
      result->Error("Error in GetWindowPlacement");
      return;
    }
    const flutter::EncodableMap ret = {
        {"left", placement.rcNormalPosition.left},
        {"top", placement.rcNormalPosition.top},
        {"right", placement.rcNormalPosition.right},
        {"bottom", placement.rcNormalPosition.bottom},
        {"maximizedLeft", placement.ptMaxPosition.x},
        {"maximizedTop", placement.ptMaxPosition.y},
        {"maximized", placement.showCmd == SW_SHOWMAXIMIZED},
    };
    result->Success(ret);
  } else if (call.method_name() == "destroyWindow") {
    if (PostMessage(GetHandle(), WM_APP, 0, 0) == 0) {
      result->Error("Error in PostMessage");
    } else {
      result->Success();
    }
  } else {
    result->NotImplemented();
  }
}

/**
 * @brief Handles method calls related to tone generator from the Flutter app.
 */
void FlutterWindow::ToneGeneratorMethodCallHandler(
    const flutter::MethodCall<>& call, std::unique_ptr<flutter::MethodResult<>> result) {
  if (call.method_name() == "setWaveParameters") {
    if (!tone_generator_) {
      result->Error("Runtime error", "Tone generator not initialized.");
      return;
    }

    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!arguments) {
      result->Error("Bad arguments", "Arguments not an EncodableMap.");
      return;
    }

    try {
      tone_generator_->set_wave_parameters(
          std::get<double>(arguments->at(flutter::EncodableValue("leftVolume"))),
          std::get<double>(arguments->at(flutter::EncodableValue("rightVolume"))),
          std::get<double>(arguments->at(flutter::EncodableValue("leftFrequency"))),
          std::get<double>(arguments->at(flutter::EncodableValue("rightFrequency"))));
      result->Success();
    } catch (std::out_of_range&) {
      result->Error("Bad arguments", "Missing required arguments.");
    } catch (std::bad_variant_access&) {
      result->Error("Bad arguments", "Invalid argument type.");
    } catch (std::invalid_argument&) {
      result->Error("Bad arguments", "Arguments out of range.");
    }
  } else if (call.method_name() == "startPlayingTone") {
    if (!tone_generator_) {
      result->Error("Runtime error", "Tone generator not initialized.");
      return;
    }
    tone_generator_->start();
    result->Success();
  } else if (call.method_name() == "stopPlayingTone") {
    if (!tone_generator_) {
      result->Error("Runtime error", "Tone generator not initialized.");
      return;
    }
    tone_generator_->stop();
    result->Success();
  } else if (call.method_name() == "getAudioDeviceInfo") {
    if (!tone_generator_) {
      result->Error("Runtime error", "Tone generator not initialized.");
      return;
    }
    try {
      result->Success(flutter::EncodableValue(tone_generator_->get_device_info()));
    } catch (const std::runtime_error& e) {
      result->Error("Runtime error", e.what());
    }
  } else {
    result->NotImplemented();
  }
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project) : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Set up the method channel for communication with the Flutter app.
  window_method_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(), "ahts4962.com/binaural_beats/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_method_channel_->SetMethodCallHandler(
      [&](const flutter::MethodCall<>& call, std::unique_ptr<flutter::MethodResult<>> result) {
        WindowMethodCallHandler(call, std::move(result));
      });
  tone_generator_method_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(), "ahts4962.com/binaural_beats/tone_generator",
      &flutter::StandardMethodCodec::GetInstance());
  try {
    HWND hwnd = GetHandle();
    tone_generator_ = std::make_unique<ToneGenerator>(100, [&, hwnd](const std::string& error) {
      std::lock_guard<std::mutex> lock(mutex_);
      error_queue_.push(error);
      PostMessage(hwnd, WM_APP + 1, 0, 0);
    });
  } catch (const std::runtime_error& e) {
    tone_generator_method_channel_->InvokeMethod(
        "reportError", std::make_unique<flutter::EncodableValue>(e.what()));
  }
  tone_generator_method_channel_->SetMethodCallHandler(
      [&](const flutter::MethodCall<>& call, std::unique_ptr<flutter::MethodResult<>> result) {
        ToneGeneratorMethodCallHandler(call, std::move(result));
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (window_method_channel_) {
      window_method_channel_->InvokeMethod("onWindowReady", nullptr);
    } else {
      Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (tone_generator_) {
    tone_generator_ = nullptr;
  }
  if (tone_generator_method_channel_) {
    tone_generator_method_channel_->SetMethodCallHandler(nullptr);
    tone_generator_method_channel_ = nullptr;
  }
  if (window_method_channel_) {
    window_method_channel_->SetMethodCallHandler(nullptr);
    window_method_channel_ = nullptr;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message, WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_GETMINMAXINFO: {
      // Set the minimum window size.
      MINMAXINFO* mmi = reinterpret_cast<MINMAXINFO*>(lparam);
      mmi->ptMinTrackSize.x = 260;
      mmi->ptMinTrackSize.y = 350;
      return 0;
    }
    case WM_DPICHANGED:
      if (!placement_set_) {
        return 0;
      }
      break;
    case WM_CLOSE:
      if (window_method_channel_) {
        window_method_channel_->InvokeMethod("onWindowClose", nullptr);
        return 0;
      }
      break;
    case WM_APP:  // destroyWindow was called.
      DestroyWindow(hwnd);
      return 0;
    case WM_APP + 1:  // Error message posted.
      if (tone_generator_method_channel_) {
        std::lock_guard<std::mutex> lock(mutex_);
        while (!error_queue_.empty()) {
          tone_generator_method_channel_->InvokeMethod(
              "reportError", std::make_unique<flutter::EncodableValue>(error_queue_.front()));
          error_queue_.pop();
        }
      }
      return 0;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
