/**
 * @file tone_generator.h
 * @brief `ToneGenerator` class declaration.
 */

#pragma once

#include <audioclient.h>
#include <audiopolicy.h>
#include <mmdeviceapi.h>
#include <windows.h>

#include <functional>
#include <mutex>

/**
 * @brief A class to play a sine wave tone using WASAPI.
 * @details This class generates a sine wave tone and plays it using the Windows
 * Audio Session API (shared mode). A new thread is created and the audio
 * rendering is performed in that thread. This class is thread-safe.
 */
class ToneGenerator {
 private:
  /**
   * @brief A class to generate wave data (sine wave).
   * @details By setting the waveform data parameters in the public member variables and calling
   * `write_tone_data`, the waveform data generated by the calculation is written to the buffer.
   */
  class ToneDataGenerator {
   private:
    double m_left_phase = 0.0;   // Phase of the next generated data (left).
    double m_right_phase = 0.0;  // Phase of the next generated data (right).
    int m_left_prev_sign = 0;    // The sign of the last generated data (left). 1, 0, or -1.
    int m_right_prev_sign = 0;   // The sign of the last generated data (right). 1, 0, or -1.

   public:
    // Parameters used to generate waveform data.
    double left_amplitude;         // Amplitude of the left channel (0.0-1.0).
    double right_amplitude;        // Amplitude of the right channel (0.0-1.0).
    double left_frequency;         // Frequency of the left channel in Hz.
    double right_frequency;        // Frequency of the right channel in Hz.
    unsigned int bits_per_sample;  // Bits per sample (8, 16, or 32).
    double samples_per_second;     // Samples per second in Hz. Must be greater than the frequency.
    unsigned int channels_count;   // Number of channels (2 or more).

    /**
     * If `stopping` is `true` in the call of `write_tone_data`, glitches can occur if
     * playback is stopped immediately. To prevent this, playback continues until the waveform data
     * value reaches 0, after which sequence of 0 is written to the buffer. This function is used
     * to determine if the value has reached 0 for both the left and right channels.
     */
    bool is_silent = false;

    /**
     * @brief Function to write waveform data to the buffer.
     * @param buffer A pointer to the buffer to write the waveform data.
     * @param frames_count The number of frames to write.
     * @param is_stopping If true, sine wave data is written to the point where the value reaches 0,
     * then sequence of 0 is written after that.
     */
    void write_tone_data(BYTE *buffer, unsigned int frames_count, bool is_stopping);
  };

  /**
   * @brief Audio event handler class.
   * @details This class is a COM object that implements the `IMMNotificationClient` and
   * `IAudioSessionEvents` interfaces. This is used to handle events notified by the audio endpoint
   * device enumerator and the audio session control.
   */
  class AudioEventHandler : public IMMNotificationClient, public IAudioSessionEvents {
   private:
    ULONG m_reference_count = 1;  // Reference count of the COM object.
    ToneGenerator &m_instance;

   public:
    /**
     * @brief Construct a new `AudioEventHandler` object.
     * @param instance The reference to the `ToneGenerator` instance.
     */
    AudioEventHandler(ToneGenerator &instance) : m_instance(instance) {}

    // Member functions of IUnknown.
    STDMETHOD_(ULONG, AddRef)();
    STDMETHOD_(ULONG, Release)();
    STDMETHOD(QueryInterface)(REFIID, VOID **);

    // Member functions of IMMNotificationClient.
    STDMETHOD(OnDefaultDeviceChanged)(EDataFlow, ERole, LPCWSTR);
    STDMETHOD(OnDeviceAdded)(LPCWSTR) { return S_OK; }
    STDMETHOD(OnDeviceRemoved)(LPCWSTR) { return S_OK; }
    STDMETHOD(OnDeviceStateChanged)(LPCWSTR, DWORD) { return S_OK; }
    STDMETHOD(OnPropertyValueChanged)(LPCWSTR, const PROPERTYKEY) { return S_OK; }

    // Member functions of IAudioSessionEvents.
    STDMETHOD(OnChannelVolumeChanged)(DWORD, float[], DWORD, LPCGUID) { return S_OK; }
    STDMETHOD(OnDisplayNameChanged)(LPCWSTR, LPCGUID) { return S_OK; }
    STDMETHOD(OnGroupingParamChanged)(LPCGUID, LPCGUID) { return S_OK; }
    STDMETHOD(OnIconPathChanged)(LPCWSTR, LPCGUID) { return S_OK; }
    STDMETHOD(OnSessionDisconnected)(AudioSessionDisconnectReason);
    STDMETHOD(OnSimpleVolumeChanged)(float, BOOL, LPCGUID) { return S_OK; }
    STDMETHOD(OnStateChanged)(AudioSessionState) { return S_OK; }
  };

  /**
   * @brief A class to wrap the WASAPI functions.
   */
  class AudioApiWrapper {
   private:
    // Variables related to COM initialization and the device enumerator.
    bool m_com_initialized = false;
    IMMDeviceEnumerator *m_enumerator = NULL;
    AudioEventHandler *m_event_handler = NULL;
    bool m_endpoint_callback_registered = false;

    // Variables for WASAPI management.
    IMMDevice *m_device = NULL;
    IAudioClient *m_client = NULL;
    WAVEFORMATEXTENSIBLE *m_wave_format = NULL;
    IAudioRenderClient *m_render_client = NULL;
    IAudioSessionControl *m_session_control = NULL;
    bool m_session_callback_registered = false;

    // State variables.
    bool m_is_initialized = false;
    bool m_device_initialized = false;
    bool m_client_started = false;

    UINT32 m_buffer_size = 0;  // Buffer size of the audio client in frames.

   public:
    /**
     * @brief `true` if COM and device enumerator are initialized.
     */
    bool is_initialized() const { return m_is_initialized; }

    /**
     * @brief `true` if the audio device is initialized.
     */
    bool device_initialized() const { return m_device_initialized; }

    /**
     * @brief `true` if the render client is started.
     */
    bool client_started() const { return m_client_started; }

    /**
     * @brief Buffer size of the audio client in frames.
     */
    UINT32 buffer_size() const { return m_buffer_size; }

    /**
     * @brief Returns the audio client.
     */
    IAudioClient *client() const { return m_client; }

    /**
     * @brief Returns the audio render client.
     */
    IAudioRenderClient *render_client() const { return m_render_client; }

    /**
     * @brief Initializes COM and the device enumerator.
     * @param instance The reference to the `ToneGenerator` instance.
     * @exception `std::runtime_error` is thrown if the initialization fails.
     * @details `is_initialized` returns `true` if the initialization is successful.
     */
    void initialize(ToneGenerator &instance);

    /**
     * @brief Initializes the audio device and the related objects.
     * @param latency Latency in milliseconds.
     * @param buffer_ready_event The handle to the event object to signal when the buffer is ready.
     * @param tone_data_generator The reference to the `ToneDataGenerator` instance.
     * `bits_per_sample`, `samples_per_second`, and `channels_count` are set to the values of the
     * initialized audio client.
     * @exception `std::runtime_error` is thrown if the initialization fails.
     * @details `device_initialized` returns `true` if the initialization is successful.
     */
    void initialize_device(unsigned int latency, HANDLE buffer_ready_event,
                           ToneDataGenerator &tone_data_generator);

    /**
     * @brief Get the information of the current audio device.
     * @return A string containing the audio device information.
     * @exception `std::runtime_error` is thrown if the audio device information cannot be obtained.
     * @details This function retrieves the information using `m_device` and `m_wave_format`, so
     * this function throws if these are not initialized.
     */
    std::string get_device_info();

    /**
     * @brief Starts the audio client.
     * @exception `std::runtime_error` is thrown if any error occurs during the starting process.
     * @details `client_started` returns `true` if the audio client is started successfully.
     */
    void start_client();

    /**
     * @brief Stops the audio client.
     * @exception `std::runtime_error` is thrown if any error occurs during the stopping process.
     * @details `client_started` returns `false` after this function is called.
     */
    void stop_client();

    /**
     * @brief Releases the audio device and the related objects.
     * @details This function corresponds to the `initialize_device` function.
     * `device_initialized` returns `false` after this function is called.
     */
    void cleanup_device();

    /**
     * @brief Releases COM and the device enumerator.
     * @details This function corresponds to the `initialize` function.
     * `is_initialized` returns `false` after this function is called.
     */
    void cleanup();
  };

  // Components for audio rendering.
  AudioApiWrapper m_audio_api_wrapper;
  ToneDataGenerator m_tone_data_generator;

  // Variables for multithreading.
  HANDLE m_render_thread = NULL;
  HANDLE m_exit_event = NULL;
  HANDLE m_stream_switch_event = NULL;
  HANDLE m_release_device_event = NULL;
  HANDLE m_parameter_changed_event = NULL;
  HANDLE m_play_state_changed_event = NULL;
  HANDLE m_buffer_ready_event = NULL;
  std::mutex m_mutex;

  // State variables.
  bool m_is_stopping = false;  // `true` while the render client is stopping.
  bool m_is_exiting = false;   // `true` while the render thread is exiting.

  // Parameters for audio rendering.
  unsigned int m_latency;  // Latency in milliseconds.

  // These variables are used to control the audio rendering, and not
  // necessarily represent the actual state of the audio device.
  // Exclusive access is required to modify or read these variables.
  double m_left_amplitude = 1.0;   // Amplitude of the left channel (0.0-1.0).
  double m_right_amplitude = 1.0;  // Amplitude of the right channel (0.0-1.0).
  double m_left_frequency = 440;   // Frequency of the left channel in Hz.
  double m_right_frequency = 440;  // Frequency of the right channel in Hz.
  bool m_is_playing = false;       // Set `true` to play the sine wave, `false` to stop.
  std::string m_device_info = "";  // Information of the current audio device. "" if not available.

  std::function<void(const std::string &)> m_error_callback;

  /**
   * @brief Render thread function.
   * @param lpParam A pointer to the `ToneGenerator` instance. This is passed as
   * the parameter of the `CreateThread` function.
   * @details Audio rendering is performed in this thread.
   */
  static DWORD WINAPI render_thread(LPVOID lpParam);

  /**
   * @brief Initializes the audio device and the related objects.
   * @details `m_audio_api_wrapper.initialize_device` and `update_wave_parameters` are called.
   * `m_device_info` is updated with the information of the current audio device.
   */
  void initialize_device();

  /**
   * @brief Applies the updated wave parameters to `ToneDataGenerator`.
   */
  void update_wave_parameters();

  /**
   * @brief Writes the wave data to the audio buffer.
   */
  void write_wave_data();

  /**
   * @brief Starts the audio client.
   */
  void start_client();

  /**
   * @brief Stops the audio client.
   */
  void stop_client();

  /**
   * @brief Releases the audio device and the related objects.
   * @details `m_audio_api_wrapper.cleanup_device` is called.
   * `m_device_info` is set to an empty string.
   */
  void cleanup_device();

  /**
   * @brief Closes the handles used for synchronization.
   */
  void close_handles();

  /**
   * @brief Helper function to report an error message.
   * @param message The error message.
   * @details Use this function to report an error encountered in the audio rendering thread.
   */
  void report_error(const std::string &message) {
    if (m_error_callback) {
      m_error_callback(message);
    }
  }

 public:
  /**
   * @brief Construct a new `ToneGenerator` object.
   * @param latency Latency in milliseconds. This affects the buffer size of the audio client.
   * @param error_callback A callback function to receive error messages. Errors encountered in the
   * audio rendering thread are reported through this function.
   * @exception `std::runtime_error` is thrown if the initialization fails.
   * @details A new thread is created and the audio rendering is performed in that thread.
   */
  ToneGenerator(unsigned int latency,
                std::function<void(const std::string &)> error_callback = nullptr);

  /**
   * @brief Destroy the `ToneGenerator` object.
   * @details The audio rendering is stopped, and the resources are released.
   */
  ~ToneGenerator();

  /**
   * @brief Set the parameters of the sine wave.
   * @param left_amplitude Amplitude of the left channel (0.0-1.0).
   * @param right_amplitude Amplitude of the right channel (0.0-1.0).
   * @param left_frequency Frequency of the left channel in Hz.
   * @param right_frequency Frequency of the right channel in Hz.
   * @exception `std::invalid_argument` is thrown if the parameters are out of range.
   * @details This function can be called without waiting for the audio device initialization.
   * This function can be called while the audio rendering is running.
   * `set_wave_parameters`, `start`, and `stop` can safely be called in any order.
   */
  void set_wave_parameters(double left_amplitude, double right_amplitude, double left_frequency,
                           double right_frequency);

  /**
   * @brief Start to play the audio.
   * @details This function can be called without waiting for the audio device initialization.
   * `set_wave_parameters`, `start`, and `stop` can safely be called in any order.
   */
  void start();

  /**
   * @brief Stop playing the audio.
   * @details This function can be called without waiting for the audio device initialization.
   * `set_wave_parameters`, `start`, and `stop` can safely be called in any order.
   */
  void stop();

  /**
   * @brief Get the current audio device information.
   * @return A string containing the audio device information.
   * @exception `std::runtime_error` is thrown if the audio device information cannot be obtained.
   */
  std::string get_device_info();
};
