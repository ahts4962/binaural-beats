#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shellscalingapi.h>
#include <windows.h>

#include <queue>

#include "flutter/generated_plugin_registrant.h"
#include "tone_generator.h"

static HWND g_hwnd = NULL;  // Holds the window handle of the Flutter window.

static std::unique_ptr<flutter::MethodChannel<>> g_window_method_channel = nullptr;

/**
 * @brief Handles method calls related to window management from the Flutter app.
 */
static void window_method_call_handler(const flutter::MethodCall<>& call,
                                       std::unique_ptr<flutter::MethodResult<>> result) {
  if (call.method_name() == "getScaleFactor") {
    // Get the scale factor [%] of the monitor that the window is on.
    DEVICE_SCALE_FACTOR scale_factor;
    if (SUCCEEDED(GetScaleFactorForMonitor(MonitorFromWindow(g_hwnd, MONITOR_DEFAULTTONEAREST),
                                           &scale_factor))) {
      if (scale_factor == DEVICE_SCALE_FACTOR_INVALID) {
        result->Error("Runtime error", "Invalid scale factor.");
      } else {
        result->Success(static_cast<double>(scale_factor));
      }
    } else {
      result->Error("Runtime error", "Failed to get scale factor.");
    }
  } else {
    result->NotImplemented();
  }
}

static std::unique_ptr<flutter::MethodChannel<>> g_tone_generator_method_channel = nullptr;
static std::unique_ptr<ToneGenerator> g_tone_generator = nullptr;

// Since some error messages are generated in a different thread, we need to
// queue them up and post a message to the main thread to handle them.
static std::queue<std::string> g_error_queue;
static std::mutex g_mutex;

/**
 * @brief Handles method calls related to tone generator from the Flutter app.
 */
static void tone_generator_method_call_handler(const flutter::MethodCall<>& call,
                                               std::unique_ptr<flutter::MethodResult<>> result) {
  if (call.method_name() == "setWaveParameters") {
    if (!g_tone_generator) {
      result->Error("Runtime error", "Tone generator not initialized.");
      return;
    }

    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!arguments) {
      result->Error("Bad arguments", "Arguments not an EncodableMap.");
      return;
    }

    try {
      double left_frequency =
          std::get<double>(arguments->at(flutter::EncodableValue("leftFrequency")));
      double right_frequency =
          std::get<double>(arguments->at(flutter::EncodableValue("rightFrequency")));
      double left_volume = std::get<double>(arguments->at(flutter::EncodableValue("leftVolume")));
      double right_volume = std::get<double>(arguments->at(flutter::EncodableValue("rightVolume")));
      g_tone_generator->set_wave_parameters(left_volume, right_volume, left_frequency,
                                            right_frequency);
    } catch (std::out_of_range&) {
      result->Error("Bad arguments", "Missing required arguments.");
      return;
    } catch (std::bad_variant_access&) {
      result->Error("Bad arguments", "Invalid argument type.");
      return;
    } catch (std::invalid_argument&) {
      result->Error("Bad arguments", "Arguments out of range.");
      return;
    }

    result->Success();
  } else if (call.method_name() == "startPlayingTone") {
    if (!g_tone_generator) {
      result->Error("Runtime error", "Tone generator not initialized.");
      return;
    }
    g_tone_generator->start();
    result->Success();
  } else if (call.method_name() == "stopPlayingTone") {
    if (!g_tone_generator) {
      result->Error("Runtime error", "Tone generator not initialized.");
      return;
    }
    g_tone_generator->stop();
    result->Success();
  } else if (call.method_name() == "getAudioDeviceInfo") {
    if (!g_tone_generator) {
      result->Error("Runtime error", "Tone generator not initialized.");
      return;
    }
    try {
      result->Success(flutter::EncodableValue(g_tone_generator->get_device_info()));
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
  g_hwnd = GetHandle();
  g_window_method_channel = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(), "ahts4962.com/binaural_beats/window",
      &flutter::StandardMethodCodec::GetInstance());
  g_window_method_channel->SetMethodCallHandler(window_method_call_handler);
  g_tone_generator_method_channel = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(), "ahts4962.com/binaural_beats/tone_generator",
      &flutter::StandardMethodCodec::GetInstance());
  try {
    g_tone_generator = std::make_unique<ToneGenerator>(100, [](const std::string& error) {
      std::lock_guard<std::mutex> lock(g_mutex);
      g_error_queue.push(error);
      PostMessage(g_hwnd, WM_APP, 0, 0);
    });
  } catch (const std::runtime_error& e) {
    g_tone_generator_method_channel->InvokeMethod(
        "reportError", std::make_unique<flutter::EncodableValue>(e.what()));
  }
  g_tone_generator_method_channel->SetMethodCallHandler(tone_generator_method_call_handler);

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  g_window_method_channel.reset();
  g_tone_generator_method_channel.reset();
  g_tone_generator.reset();

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
    case WM_APP:  // Error message posted.
      if (g_tone_generator_method_channel) {
        std::lock_guard<std::mutex> lock(g_mutex);
        while (!g_error_queue.empty()) {
          g_tone_generator_method_channel->InvokeMethod(
              "reportError", std::make_unique<flutter::EncodableValue>(g_error_queue.front()));
          g_error_queue.pop();
        }
      }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
