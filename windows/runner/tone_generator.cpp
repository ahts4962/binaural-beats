/**
 * @file tone_generator.cpp
 * @brief `ToneGenerator` class implementation.
 */

#include "tone_generator.h"

#include <functiondiscoverykeys_devpkey.h>

#include <cassert>
#include <iomanip>
#include <sstream>

// Constants.
constexpr double PI = 3.14159265358979323846;

/**
 * @brief Helper function to safely release a COM interface pointer.
 * @tparam T The type of the COM interface.
 * @param ppT A pointer to the COM interface pointer.
 */
template <class T>
static void safe_release(T **ppT) {
  if (*ppT) {
    (*ppT)->Release();
    *ppT = NULL;
  }
}

/**
 * @brief Helper function to safely close a handle.
 * @param ph A pointer to the handle.
 */
static void safe_close(HANDLE *ph) {
  if (*ph) {
    CloseHandle(*ph);
    *ph = NULL;
  }
}

/**
 * @brief Helper function to create an event object.
 * @return The handle to the event object.
 * @exception `std::runtime_error` is thrown if `CreateEventEx` fails.
 */
static HANDLE create_event() {
  HANDLE event = CreateEventEx(NULL, NULL, 0, EVENT_MODIFY_STATE | SYNCHRONIZE);
  if (event == NULL) {
    std::stringstream ss;
    ss << "CreateEventEx failed. GetLastError: " << GetLastError();
    throw std::runtime_error(ss.str());
  }
  return event;
}

/**
 * @brief Helper function to set an event.
 * @param event The handle to the event object.
 * @exception `std::runtime_error` is thrown if `SetEvent` fails.
 */
static void set_event(HANDLE event) {
  if (SetEvent(event) == 0) {
    std::stringstream ss;
    ss << "SetEvent failed. GetLastError: " << GetLastError();
    throw std::runtime_error(ss.str());
  }
}

/**
 * @brief Helper function to reset an event.
 * @param event The handle to the event object.
 * @exception `std::runtime_error` is thrown if `ResetEvent` fails.
 */
static void reset_event(HANDLE event) {
  if (ResetEvent(event) == 0) {
    std::stringstream ss;
    ss << "ResetEvent failed. GetLastError: " << GetLastError();
    throw std::runtime_error(ss.str());
  }
}

void ToneGenerator::ToneDataGenerator::write_tone_data(BYTE *buffer, unsigned int frames_count,
                                                       bool is_stopping) {
  assert(channels_count >= 2);
  assert(bits_per_sample == 8 || bits_per_sample == 16 || bits_per_sample == 32);
  assert(left_frequency > 0 && right_frequency > 0);
  assert(left_frequency < samples_per_second && right_frequency < samples_per_second);

  double left_phase_delta = 2 * PI * left_frequency / samples_per_second;
  double right_phase_delta = 2 * PI * right_frequency / samples_per_second;

  for (unsigned int i = 0; i < frames_count; ++i) {
    double left_value = left_amplitude * std::sin(m_left_phase);
    double right_value = right_amplitude * std::sin(m_right_phase);
    if (is_stopping) {
      // The value of the waveform data is determined to have reached to zero if the immediately
      // preceding value is zero or has a different sign.
      if (m_left_prev_sign == 0 || left_value > 0 && m_left_prev_sign < 0 ||
          left_value < 0 && m_left_prev_sign > 0) {
        left_value = 0;
      }
      if (m_right_prev_sign == 0 || right_value > 0 && m_right_prev_sign < 0 ||
          right_value < 0 && m_right_prev_sign > 0) {
        right_value = 0;
      }
      is_silent = (left_value == 0 && right_value == 0);
    } else {
      is_silent = false;
    }
    m_left_prev_sign = left_value > 0 ? 1 : left_value < 0 ? -1 : 0;
    m_right_prev_sign = right_value > 0 ? 1 : right_value < 0 ? -1 : 0;

    if (bits_per_sample == 8) {
      UINT8 *wave_data = static_cast<UINT8 *>(buffer);
      wave_data[i * channels_count] = static_cast<UINT8>(left_value * 127 + 128);
      wave_data[i * channels_count + 1] = static_cast<UINT8>(right_value * 127 + 128);
      for (unsigned int j = 2; j < channels_count; ++j) {
        wave_data[i * channels_count + j] = 128;
      }
    } else if (bits_per_sample == 16) {
      INT16 *wave_data = reinterpret_cast<INT16 *>(buffer);
      wave_data[i * channels_count] = static_cast<INT16>(left_value * 32767);
      wave_data[i * channels_count + 1] = static_cast<INT16>(right_value * 32767);
      for (unsigned int j = 2; j < channels_count; ++j) {
        wave_data[i * channels_count + j] = 0;
      }
    } else if (bits_per_sample == 32) {
      float *wave_data = reinterpret_cast<float *>(buffer);
      wave_data[i * channels_count] = static_cast<float>(left_value);
      wave_data[i * channels_count + 1] = static_cast<float>(right_value);
      for (unsigned int j = 2; j < channels_count; ++j) {
        wave_data[i * channels_count + j] = 0.0f;
      }
    }

    m_left_phase += left_phase_delta;
    m_right_phase += right_phase_delta;
    while (m_left_phase >= 2 * PI) {
      m_left_phase -= 2 * PI;
    }
    while (m_right_phase >= 2 * PI) {
      m_right_phase -= 2 * PI;
    }
    if (is_stopping) {
      if (left_value == 0) {
        m_left_phase = 0;
      }
      if (right_value == 0) {
        m_right_phase = 0;
      }
    }
  }
}

ULONG ToneGenerator::AudioEventHandler::AddRef() {
  return InterlockedIncrement(&m_reference_count);
}

ULONG ToneGenerator::AudioEventHandler::Release() {
  ULONG ref = InterlockedDecrement(&m_reference_count);
  if (ref == 0) {
    delete this;
  }
  return ref;
}

HRESULT ToneGenerator::AudioEventHandler::QueryInterface(REFIID riid, VOID **ppvInterface) {
  if (ppvInterface == NULL) {
    return E_POINTER;
  }

  if (riid == IID_IUnknown) {
    *ppvInterface = static_cast<IUnknown *>(static_cast<IMMNotificationClient *>(this));
  } else if (riid == __uuidof(IMMNotificationClient)) {
    *ppvInterface = static_cast<IMMNotificationClient *>(this);
  } else if (riid == __uuidof(IAudioSessionEvents)) {
    *ppvInterface = static_cast<IAudioSessionEvents *>(this);
  } else {
    *ppvInterface = NULL;
    return E_NOINTERFACE;
  }

  AddRef();
  return S_OK;
}

HRESULT ToneGenerator::AudioEventHandler::OnDefaultDeviceChanged(EDataFlow flow, ERole role,
                                                                 LPCWSTR) {
  if (flow == eRender && role == eConsole) {
    // Notify the render thread to switch the audio stream.
    // This is called, for example, in the following situations:
    // - The default audio device has been changed from Windows settings by the user.
    // - The default audio device has been changed by disconnecting the current audio device.
    // - The default audio device has been changed by connecting a new audio device.
    set_event(m_instance.m_stream_switch_event);
  }

  return S_OK;
}

HRESULT ToneGenerator::AudioEventHandler::OnSessionDisconnected(
    AudioSessionDisconnectReason DisconnectReason) {
  switch (DisconnectReason) {
    case DisconnectReasonFormatChanged:
      // Notify the render thread to switch the audio stream.
      // This is called when the audio format (e.g., sample rate, bit depth, channel count) of the
      // current audio device has been changed.
      set_event(m_instance.m_stream_switch_event);
      break;
    case DisconnectReasonDeviceRemoval:
    case DisconnectReasonServerShutdown:
    case DisconnectReasonSessionLogoff:
    case DisconnectReasonSessionDisconnected:
    case DisconnectReasonExclusiveModeOverride:
      // Notify the render thread to release the current audio device.
      set_event(m_instance.m_release_device_event);
      break;
  }

  return S_OK;
}

void ToneGenerator::AudioApiWrapper::initialize(ToneGenerator &instance) {
  assert(!m_is_initialized);

  HRESULT hr;
  std::stringstream ss;

  hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(hr)) {
    ss << "CoInitializeEx failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }
  m_com_initialized = true;

  hr =
      CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, IID_PPV_ARGS(&m_enumerator));
  if (FAILED(hr)) {
    ss << "CoCreateInstance failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  try {
    m_event_handler = new AudioEventHandler(instance);
  } catch (const std::bad_alloc &e) {
    ss << "new AudioEventHandler failed. Error detail: " << e.what();
    throw std::runtime_error(ss.str());
  }

  hr = m_enumerator->RegisterEndpointNotificationCallback(m_event_handler);
  if (FAILED(hr)) {
    ss << "RegisterEndpointNotificationCallback failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }
  m_endpoint_callback_registered = true;

  m_is_initialized = true;
}

void ToneGenerator::AudioApiWrapper::initialize_device(unsigned int latency,
                                                       HANDLE buffer_ready_event,
                                                       ToneDataGenerator &tone_data_generator) {
  assert(m_is_initialized);
  assert(!m_device_initialized);

  HRESULT hr;
  std::stringstream ss;

  hr = m_enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &m_device);
  if (FAILED(hr)) {
    ss << "IMMDeviceEnumerator::GetDefaultAudioEndpoint failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  hr = m_device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, NULL,
                          reinterpret_cast<void **>(&m_client));
  if (FAILED(hr)) {
    ss << "IMMDevice::Activate failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  hr = m_client->GetMixFormat(reinterpret_cast<WAVEFORMATEX **>(&m_wave_format));
  if (FAILED(hr)) {
    ss << "IAudioClient::GetMixFormat failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  // Check the format.
  if (m_wave_format->Format.nChannels < 2) {
    throw std::runtime_error(
        "Unsupported format. At least 2 channels are required "
        "(ToneGenerator::initialize_device).");
  }

  if (m_wave_format->Format.wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
    if (m_wave_format->SubFormat != KSDATAFORMAT_SUBTYPE_PCM &&
        m_wave_format->SubFormat != KSDATAFORMAT_SUBTYPE_IEEE_FLOAT) {
      throw std::runtime_error("Unsupported format (ToneGenerator::initialize_device).");
    }
  } else {
    if (m_wave_format->Format.wFormatTag != WAVE_FORMAT_PCM) {
      throw std::runtime_error("Unsupported format (ToneGenerator::initialize_device).");
    }
  }

  tone_data_generator.bits_per_sample = m_wave_format->Format.wBitsPerSample;
  tone_data_generator.samples_per_second = m_wave_format->Format.nSamplesPerSec;
  tone_data_generator.channels_count = m_wave_format->Format.nChannels;

  hr = m_client->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                            static_cast<REFERENCE_TIME>(latency) * 10000, 0,
                            reinterpret_cast<WAVEFORMATEX *>(m_wave_format), NULL);
  if (FAILED(hr)) {
    ss << "IAudioClient::Initialize failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  hr = m_client->SetEventHandle(buffer_ready_event);
  if (FAILED(hr)) {
    ss << "IAudioClient::SetEventHandle failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  hr = m_client->GetService(IID_PPV_ARGS(&m_render_client));
  if (FAILED(hr)) {
    ss << "IAudioClient::GetService failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  hr = m_client->GetService(IID_PPV_ARGS(&m_session_control));
  if (FAILED(hr)) {
    ss << "IAudioClient::GetService failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  hr = m_session_control->RegisterAudioSessionNotification(m_event_handler);
  if (FAILED(hr)) {
    ss << "IAudioSessionControl::RegisterAudioSessionNotification failed. HRESULT: " << std::hex
       << hr;
    throw std::runtime_error(ss.str());
  }
  m_session_callback_registered = true;

  hr = m_client->GetBufferSize(&m_buffer_size);
  if (FAILED(hr)) {
    ss << "IAudioClient::GetBufferSize failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  m_device_initialized = true;
}

std::string ToneGenerator::AudioApiWrapper::get_device_info() {
  if (!m_device || !m_wave_format) {
    throw std::runtime_error("Audio device information is not available.");
  }

  LPWSTR device_id = NULL;
  IPropertyStore *props = NULL;
  PROPVARIANT name;

  try {
    HRESULT hr;
    std::stringstream ss;

    hr = m_device->GetId(&device_id);
    if (FAILED(hr)) {
      ss << "IMMDevice::GetId failed. HRESULT: " << std::hex << hr;
      throw std::runtime_error(ss.str());
    }

    hr = m_device->OpenPropertyStore(STGM_READ, &props);
    if (FAILED(hr)) {
      ss << "IMMDevice::OpenPropertyStore failed. HRESULT: " << std::hex << hr;
      throw std::runtime_error(ss.str());
    }

    PropVariantInit(&name);
    hr = props->GetValue(PKEY_Device_FriendlyName, &name);
    if (FAILED(hr)) {
      ss << "IPropertyStore::GetValue failed. HRESULT: " << std::hex << hr;
      throw std::runtime_error(ss.str());
    }

    if (name.vt == VT_EMPTY) {
      ss << "Device friendly name is not available.";
      throw std::runtime_error(ss.str());
    }

    int len = WideCharToMultiByte(CP_UTF8, 0, name.pwszVal, -1, NULL, 0, NULL, NULL);
    if (len == 0) {
      ss << "WideCharToMultiByte failed. GetLastError: " << GetLastError();
      throw std::runtime_error(ss.str());
    }

    std::string device_name(len, '\0');
    len = WideCharToMultiByte(CP_UTF8, 0, name.pwszVal, -1, device_name.data(),
                              static_cast<int>(device_name.size()), NULL, NULL);
    if (len == 0) {
      ss << "WideCharToMultiByte failed. GetLastError: " << GetLastError();
      throw std::runtime_error(ss.str());
    }

    device_name.resize(len - 1);

    ss << device_name << "\n[" << m_wave_format->Format.wBitsPerSample << " bit, "
       << std::setprecision(4) << static_cast<double>(m_wave_format->Format.nSamplesPerSec) / 1000.0
       << " kHz, " << m_wave_format->Format.nChannels << " channels]";

    PropVariantClear(&name);
    safe_release(&props);
    if (device_id) {
      CoTaskMemFree(device_id);
    }
    return ss.str();
  } catch (const std::runtime_error &e) {
    PropVariantClear(&name);
    safe_release(&props);
    if (device_id) {
      CoTaskMemFree(device_id);
    }
    throw e;
  }
}

void ToneGenerator::AudioApiWrapper::start_client() {
  assert(m_device_initialized);

  HRESULT hr;
  std::stringstream ss;

  hr = m_client->Start();
  if (FAILED(hr)) {
    ss << "IAudioClient::Start failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  m_client_started = true;
}

void ToneGenerator::AudioApiWrapper::stop_client() {
  assert(m_device_initialized);

  HRESULT hr;
  std::stringstream ss;

  hr = m_client->Stop();
  if (FAILED(hr)) {
    ss << "IAudioClient::Stop failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  hr = m_client->Reset();
  if (FAILED(hr)) {
    ss << "IAudioClient::Reset failed. HRESULT: " << std::hex << hr;
    throw std::runtime_error(ss.str());
  }

  m_client_started = false;
}

void ToneGenerator::AudioApiWrapper::cleanup_device() {
  if (m_wave_format) {
    CoTaskMemFree(m_wave_format);
    m_wave_format = NULL;
  }

  if (m_client && m_client_started) {
    m_client->Stop();
  }
  m_client_started = false;

  if (m_session_control && m_event_handler && m_session_callback_registered) {
    m_session_control->UnregisterAudioSessionNotification(m_event_handler);
    m_session_callback_registered = false;
  }

  safe_release(&m_render_client);
  safe_release(&m_session_control);
  safe_release(&m_client);
  safe_release(&m_device);

  m_buffer_size = 0;
  m_device_initialized = false;
}

void ToneGenerator::AudioApiWrapper::cleanup() {
  if (m_enumerator && m_event_handler && m_endpoint_callback_registered) {
    m_enumerator->UnregisterEndpointNotificationCallback(m_event_handler);
    m_endpoint_callback_registered = false;
  }

  safe_release(&m_enumerator);
  safe_release(&m_event_handler);

  if (m_com_initialized) {
    CoUninitialize();
    m_com_initialized = false;
  }

  m_is_initialized = false;
}

DWORD ToneGenerator::render_thread(LPVOID lpParam) {
  ToneGenerator &instance = *static_cast<ToneGenerator *>(lpParam);
  std::stringstream ss;

  try {
    instance.m_audio_api_wrapper.initialize(instance);
    instance.initialize_device();

    HANDLE events[] = {instance.m_exit_event,
                       instance.m_stream_switch_event,
                       instance.m_release_device_event,
                       instance.m_parameter_changed_event,
                       instance.m_play_state_changed_event,
                       instance.m_buffer_ready_event};

    // Event loop.
    while (true) {
      DWORD result =
          WaitForMultipleObjects(sizeof(events) / sizeof(HANDLE), events, FALSE, INFINITE);

      if (result == WAIT_OBJECT_0) {  // exit_event
        instance.m_is_stopping = true;
        instance.m_is_exiting = true;

        // To prevent glitches, do not leave the loop immediately when it is playing.
        if (!instance.m_audio_api_wrapper.client_started()) {
          break;
        }
      } else if (result == WAIT_OBJECT_0 + 1 ||  // stream_switch_event,
                 result == WAIT_OBJECT_0 + 2) {  // release_device_event
        // The stream switch event is set when the current audio stream needs to be
        // recreated (e.g., the default audio device has been changed).
        // The release device event is set when the current audio device needs to be
        // released (e.g., the current audio device has been disconnected).

        // Release the current audio device.
        if (instance.m_audio_api_wrapper.device_initialized()) {
          if (instance.m_audio_api_wrapper.client_started()) {
            instance.stop_client();
          }
          instance.cleanup_device();
        }

        // Since the stream switch event and the release device event might be set multiple times
        // in a short period, wait for a while before initializing the audio device.
        bool initialization_required = result == WAIT_OBJECT_0 + 1;  // stream_switch_event
        Sleep(500);
        switch (WaitForSingleObject(instance.m_stream_switch_event, 0)) {
          case WAIT_OBJECT_0:
            initialization_required = true;
            break;
          case WAIT_TIMEOUT:
            break;
          case WAIT_FAILED:
            ss << "WaitForSingleObject failed. GetLastError: " << GetLastError();
            throw std::runtime_error(ss.str());
        }
        reset_event(instance.m_release_device_event);

        if (initialization_required) {
          instance.initialize_device();
          if (instance.m_audio_api_wrapper.device_initialized()) {
            {
              bool is_playing;
              {
                std::lock_guard<std::mutex> lock(instance.m_mutex);
                is_playing = instance.m_is_playing;
              }
              if (is_playing) {
                // If the audio was playing before the stream switch event,
                // start playing the audio again.
                instance.write_wave_data();  // Prevent glitches.
                instance.start_client();
              }
            }
          }
        }
      } else if (result == WAIT_OBJECT_0 + 3) {  // parameter_changed_event
        // The parameter changed event is set when the audio parameters (e.g., amplitude,
        // frequency) have been changed by the user of this class.
        if (!instance.m_audio_api_wrapper.device_initialized()) {
          instance.initialize_device();
        } else {
          instance.update_wave_parameters();
        }
      } else if (result == WAIT_OBJECT_0 + 4) {  // play_state_changed_event
        // The play state changed event is set when the play state (playing or stopped) has
        // been changed by the user of this class.
        bool is_playing;
        {
          std::lock_guard<std::mutex> lock(instance.m_mutex);
          is_playing = instance.m_is_playing;
        }
        if (is_playing) {
          if (!instance.m_audio_api_wrapper.device_initialized()) {
            instance.initialize_device();
          }
          if (instance.m_audio_api_wrapper.device_initialized() &&
              !instance.m_audio_api_wrapper.client_started()) {
            instance.write_wave_data();  // Prevent glitches.
            instance.start_client();
          }
        } else {
          // To prevent glitches, do not stop the playback immediately.
          instance.m_is_stopping = true;
        }
      } else if (result == WAIT_OBJECT_0 + 5) {  // buffer_ready_event
        // The buffer ready event is set when the audio buffer is ready to write the wave
        // data. This event is set by the audio client.
        if (instance.m_audio_api_wrapper.device_initialized() &&
            instance.m_audio_api_wrapper.client_started()) {
          instance.write_wave_data();

          if ((instance.m_is_exiting || instance.m_is_stopping) &&
              instance.m_tone_data_generator.is_silent) {
            Sleep(instance.m_latency + 100);  // Wait for written data to be played.
            instance.stop_client();
            if (instance.m_is_exiting) {
              break;
            } else {
              instance.m_is_stopping = false;
            }
          }
        }
      } else if (result == WAIT_FAILED) {
        ss << "WaitForMultipleObjects failed. GetLastError: " << GetLastError();
        throw std::runtime_error(ss.str());
      }
    }
  } catch (const std::runtime_error &e) {  // Exit the event loop when a fatal error occurs.
    instance.report_error(e.what());
    instance.cleanup_device();
    instance.m_audio_api_wrapper.cleanup();
    return 1;
  }

  instance.cleanup_device();
  instance.m_audio_api_wrapper.cleanup();

  return 0;
}

void ToneGenerator::initialize_device() {
  try {
    m_audio_api_wrapper.initialize_device(m_latency, m_buffer_ready_event, m_tone_data_generator);
  } catch (const std::runtime_error &e) {
    // Record the error message and continue, as the failure of device initialization
    // might be recovered later.
    report_error(e.what());
    m_audio_api_wrapper.cleanup_device();
    return;
  }

  {
    std::string device_info;
    try {
      device_info = m_audio_api_wrapper.get_device_info();
    } catch (std::runtime_error &) {
      device_info = "";
    }
    std::lock_guard<std::mutex> lock(m_mutex);
    m_device_info = std::move(device_info);
  }

  update_wave_parameters();
}

void ToneGenerator::update_wave_parameters() {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_tone_data_generator.left_amplitude = m_left_amplitude;
  m_tone_data_generator.right_amplitude = m_right_amplitude;
  m_tone_data_generator.left_frequency = m_left_frequency;
  m_tone_data_generator.right_frequency = m_right_frequency;
}

void ToneGenerator::write_wave_data() {
  try {
    HRESULT hr;
    std::stringstream ss;

    // Calculate the unoccupied frames in the buffer.
    UINT32 padding;
    hr = m_audio_api_wrapper.client()->GetCurrentPadding(&padding);
    if (FAILED(hr)) {
      ss << "IAudioClient::GetCurrentPadding failed. HRESULT: " << std::hex << hr;
      throw std::runtime_error(ss.str());
    }

    UINT32 frames_to_write = m_audio_api_wrapper.buffer_size() - padding;
    if (frames_to_write == 0) {
      return;
    }

    BYTE *buffer;
    hr = m_audio_api_wrapper.render_client()->GetBuffer(frames_to_write, &buffer);
    if (FAILED(hr)) {
      ss << "IAudioRenderClient::GetBuffer failed. HRESULT: " << std::hex << hr;
      throw std::runtime_error(ss.str());
    }

    m_tone_data_generator.write_tone_data(buffer, frames_to_write, m_is_stopping);

    hr = m_audio_api_wrapper.render_client()->ReleaseBuffer(frames_to_write, 0);
    if (FAILED(hr)) {
      ss << "IAudioRenderClient::ReleaseBuffer failed. HRESULT: " << std::hex << hr;
      throw std::runtime_error(ss.str());
    }
  } catch (const std::runtime_error &e) {
    // Record the error message and continue, as the failure of
    // writing can be caused by the audio device lost.
    report_error(e.what());
    cleanup_device();
    m_tone_data_generator.is_silent = true;  // Prevent the thread from being blocked from exiting.
  }
}

void ToneGenerator::start_client() {
  try {
    m_audio_api_wrapper.start_client();
  } catch (const std::runtime_error &e) {
    report_error(e.what());
  }
}

void ToneGenerator::stop_client() {
  try {
    m_audio_api_wrapper.stop_client();
  } catch (const std::runtime_error &e) {
    report_error(e.what());
  }
}

void ToneGenerator::cleanup_device() {
  m_audio_api_wrapper.cleanup_device();
  std::lock_guard<std::mutex> lock(m_mutex);
  m_device_info = "";
}

void ToneGenerator::close_handles() {
  safe_close(&m_exit_event);
  safe_close(&m_stream_switch_event);
  safe_close(&m_release_device_event);
  safe_close(&m_parameter_changed_event);
  safe_close(&m_play_state_changed_event);
  safe_close(&m_buffer_ready_event);
  safe_close(&m_render_thread);
}

ToneGenerator::ToneGenerator(unsigned int latency,
                             std::function<void(const std::string &)> error_callback)
    : m_latency(latency), m_error_callback(error_callback) {
  try {
    m_exit_event = create_event();
    m_stream_switch_event = create_event();
    m_release_device_event = create_event();
    m_parameter_changed_event = create_event();
    m_play_state_changed_event = create_event();
    m_buffer_ready_event = create_event();
  } catch (const std::runtime_error &e) {
    close_handles();
    throw e;
  }

  m_render_thread = CreateThread(NULL, 0, render_thread, this, 0, NULL);
  if (m_render_thread == NULL) {
    close_handles();
    throw std::runtime_error("CreateThread failed. GetLastError: " + GetLastError());
  }
}

ToneGenerator::~ToneGenerator() {
  if (m_render_thread) {
    if (m_exit_event) {
      SetEvent(m_exit_event);
    }

    DWORD result = WaitForSingleObject(m_render_thread, 1000);
    if (result == WAIT_TIMEOUT) {
      if (m_exit_event) {
        SetEvent(m_exit_event);
      }
      result = WaitForSingleObject(m_render_thread, 3000);
      if (result == WAIT_TIMEOUT || result == WAIT_FAILED) {
        TerminateThread(m_render_thread, 1);
      }
    } else if (result == WAIT_FAILED) {
      TerminateThread(m_render_thread, 1);
    }
  }

  close_handles();
}

void ToneGenerator::set_wave_parameters(double left_amplitude, double right_amplitude,
                                        double left_frequency, double right_frequency) {
  std::lock_guard<std::mutex> lock(m_mutex);

  if (left_amplitude < 0 || left_amplitude > 1 || right_amplitude < 0 || right_amplitude > 1) {
    throw std::invalid_argument("Amplitude must be in the range [0, 1].");
  }
  if (left_frequency <= 0 || right_frequency <= 0) {
    throw std::invalid_argument("Frequencies must be greater than 0.");
  }

  m_left_amplitude = left_amplitude;
  m_right_amplitude = right_amplitude;
  m_left_frequency = left_frequency;
  m_right_frequency = right_frequency;

  set_event(m_parameter_changed_event);
}

void ToneGenerator::start() {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_is_playing = true;
  set_event(m_play_state_changed_event);
}

void ToneGenerator::stop() {
  std::lock_guard<std::mutex> lock(m_mutex);
  m_is_playing = false;
  set_event(m_play_state_changed_event);
}

std::string ToneGenerator::get_device_info() {
  std::lock_guard<std::mutex> lock(m_mutex);
  if (m_device_info.empty()) {
    throw std::runtime_error("Audio device information is not available.");
  } else {
    return std::string(m_device_info);
  }
}
