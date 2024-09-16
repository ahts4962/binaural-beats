#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <mutex>
#include <queue>

#include "win32_window.h"

class ToneGenerator;

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Method channels for communication between the Flutter app and the host.
  std::unique_ptr<flutter::MethodChannel<>> window_method_channel_;
  std::unique_ptr<flutter::MethodChannel<>> tone_generator_method_channel_;

  // Whether the window placement has been set.
  // This is used to prevent resizing by WM_DPICHANGED after the initial window placement.
  bool placement_set_ = false;

  // Tone generator for playing binaural beats.
  std::unique_ptr<ToneGenerator> tone_generator_;

  // Since some error messages are generated in a different thread, we need to
  // queue them up and post a message to the main thread to handle them.
  std::queue<std::string> error_queue_;
  std::mutex mutex_;

  // Handlers for method calls from the Flutter app.
  void WindowMethodCallHandler(const flutter::MethodCall<>&,
                               std::unique_ptr<flutter::MethodResult<>>);
  void ToneGeneratorMethodCallHandler(const flutter::MethodCall<>&,
                                      std::unique_ptr<flutter::MethodResult<>>);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
