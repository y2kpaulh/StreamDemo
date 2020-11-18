import AVFoundation
import HaishinKit
import Photos
import UIKit
import VideoToolbox
import RxSwift
import RxCocoa
import ReplayKit
import VerticalSlider

final class ExampleRecorderDelegate: DefaultAVRecorderDelegate {
  static let `default` = ExampleRecorderDelegate()

  override func didFinishWriting(_ recorder: AVRecorder) {
    guard let writer: AVAssetWriter = recorder.writer else { return }
    PHPhotoLibrary.shared().performChanges({() -> Void in
      PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
    }, completionHandler: { _, error -> Void in
      do {
        try FileManager.default.removeItem(at: writer.outputURL)
      } catch {
        print(error)
      }
    })
  }
}

final class PushStreamViewController: UIViewController {
  private static let maxRetryCount: Int = 5
  let preferences = UserDefaults.standard
  var uri = ""
  var streamName = "ShallWeShop-iOS"
  let controller = RPBroadcastController()
  let recorder = RPScreenRecorder.shared()

  @IBOutlet weak var zoomSlider: VerticalSlider!
  @IBOutlet weak var publishStateView: UIView!
  @IBOutlet private weak var lfView: GLHKView?
  @IBOutlet weak var closeBtn: UIButton!

  private var rtmpConnection = RTMPConnection()
  private var rtmpStream: RTMPStream!
  private var sharedObject: RTMPSharedObject!
  private var currentEffect: VideoEffect?
  private var currentPosition: AVCaptureDevice.Position = .back
  private var retryCount: Int = 0
  private var disposeBag = DisposeBag()

  let hdResolution: CGSize = CGSize(width: 720, height: 1280)
  let fhdResolution: CGSize = CGSize(width: 1080, height: 1920)
  var currentResolution: CGSize!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.currentResolution = self.hdResolution

    let image = UIImage(named: "close")?.withRenderingMode(.alwaysTemplate)
    closeBtn.setImage(image, for: .normal)
    closeBtn.tintColor = .white

    zoomSlider.slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
    zoomSlider.slider.thumbRect(forBounds: zoomSlider.slider.bounds, trackRect: CGRect(x: 0, y: 0, width: 10, height: 10), value: 0.0)
    zoomSlider.slider.setThumbImage(self.progressImage(with: self.zoomSlider.slider.value), for: UIControl.State.normal)
    zoomSlider.slider.setThumbImage(self.progressImage(with: self.zoomSlider.slider.value), for: UIControl.State.selected)
    configStreaming()
  }

  func progressImage(with progress: Float) -> UIImage {
    let layer = CALayer()
    layer.backgroundColor = UIColor.white.cgColor
    layer.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
    layer.cornerRadius = 15

    let label = UILabel(frame: layer.frame)
    label.text = String(format: "%dx", Int(progress))//String(format: "%.1fx", progress)
    label.font = UIFont.systemFont(ofSize: 12)
    layer.addSublayer(label.layer)
    label.textAlignment = .center
    label.tag = 100

    UIGraphicsBeginImageContext(layer.frame.size)
    layer.render(in: UIGraphicsGetCurrentContext()!)

    let degrees = 30.0
    let radians = CGFloat(degrees * M_PI / 180)
    layer.transform = CATransform3DMakeRotation(radians, 0.0, 0.0, 1.0)

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image!
  }

  func configStreaming() {
    guard let pushUrl =  preferences.string(forKey: "pushUrl") else { return }
    guard let streamKey =  preferences.string(forKey: "streamKey") else { return }

    uri = pushUrl
    streamName = streamKey

    let session = AVAudioSession.sharedInstance()
    do {
      try session.setPreferredSampleRate(44_100)
      // https://stackoverflow.com/questions/51010390/avaudiosession-setcategory-swift-4-2-ios-12-play-sound-on-silent
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      try session.setActive(true)
    } catch {
    }

    rtmpStream = RTMPStream(connection: rtmpConnection)

    if let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation) {
      rtmpStream.orientation = orientation
    }

    self.configResolution(resolution: self.currentResolution)

    rtmpStream.mixer.recorder.delegate = ExampleRecorderDelegate.shared

    NotificationCenter.default.rx.notification(UIDevice.orientationDidChangeNotification)
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { _ in
        guard let orientation = DeviceUtil.videoOrientation(by: (UIApplication.shared.windows
                                                                  .first?
                                                                  .windowScene!
                                                                  .interfaceOrientation)!) else {
          return
        }

        print("orientationDidChangeNotification", orientation.rawValue)

        self.rtmpStream.orientation = orientation
      })
      .disposed(by: disposeBag)

    NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification)
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { _ in
        print("didEnterBackgroundNotification")
        self.rtmpStream.receiveVideo = false
      })
      .disposed(by: disposeBag)

    NotificationCenter.default.rx.notification(UIApplication.didBecomeActiveNotification)
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { _ in
        print("didBecomeActiveNotification")
        self.rtmpStream.receiveVideo = true
      })
      .disposed(by: disposeBag)
  }

  override func viewWillAppear(_ animated: Bool) {
    //logger.info("viewWillAppear")
    super.viewWillAppear(animated)

    rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
      print(error.description)

    }
    rtmpStream.attachCamera(DeviceUtil.device(withPosition: currentPosition)) { error in
      print(error.description)
    }
    rtmpStream.rx.observeWeakly(UInt16.self, "currentFPS", options: .new)
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { [weak self] fps in
        guard let self = self else { return }
        guard let currentFps = fps else { return }
        //        self.currentFPSLabel?.text = "\(currentFps) fps"
      })
      .disposed(by: disposeBag)

    lfView?.attachStream(rtmpStream)
    lfView?.videoGravity = .resizeAspect
    lfView?.cornerRadius = 8
  }

  override func viewWillDisappear(_ animated: Bool) {
    //logger.info("viewWillDisappear")
    super.viewWillDisappear(animated)

    rtmpStream.close()
    rtmpStream.dispose()
  }

  @IBAction func tapCloseBtn(_ sender: Any) {
    self.dismiss(animated: true, completion: nil)
  }

  @IBAction func rotateCamera(_ sender: UIButton) {
    //logger.info("rotateCamera")
    let position: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
    rtmpStream.attachCamera(DeviceUtil.device(withPosition: position)) { error in
      print(error.description)
    }
    currentPosition = position
  }

  @IBAction func toggleTorch(_ sender: UIButton) {
    rtmpStream.torch.toggle()
  }

  @objc internal func sliderChanged() {
    print(#function, zoomSlider.value)
    zoomSlider.slider.setThumbImage(self.progressImage(with: self.zoomSlider.slider.value), for: UIControl.State.normal)
    zoomSlider.slider.setThumbImage(self.progressImage(with: self.zoomSlider.slider.value), for: UIControl.State.selected)

    rtmpStream.setZoomFactor(CGFloat(zoomSlider.value), ramping: true, withRate: 5.0)

  }

  @IBAction func on(pause: UIButton) {
    if UIApplication.shared.isIdleTimerDisabled != true && pause.isSelected != true {
      let alert =  UIAlertController(title: nil, message: "cannot pause event. current state is recording state.", preferredStyle: .alert)
      let ok = UIAlertAction(title: "OK", style: .default, handler: nil)
      alert.addAction(ok)
      self.present(alert, animated: true, completion: nil)
      return
    }

    pause.isSelected = !pause.isSelected

    if pause.isSelected {
      pause.backgroundColor = .gray
    } else {
      pause.backgroundColor = .systemBlue
    }

    rtmpStream.paused.toggle()
  }

  @IBAction func on(publish: UIButton) {
    if publish.isSelected {
      UIApplication.shared.isIdleTimerDisabled = false
      rtmpConnection.close()
      rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
      rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
      self.publishStateView.backgroundColor = .red

      //      if pauseButton!.isSelected {
      //        self.on(pause: pauseButton!)
      //      }
      self.stopRecording()
    } else {
      UIApplication.shared.isIdleTimerDisabled = true
      rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
      rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
      rtmpConnection.connect(uri)
      self.publishStateView.backgroundColor = .lightGray
      self.startRecording()
    }

    publish.isSelected.toggle()
  }

  @objc
  private func rtmpStatusHandler(_ notification: Notification) {
    let e = Event.from(notification)
    guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
      return
    }
    //logger.info(code)
    switch code {
    case RTMPConnection.Code.connectSuccess.rawValue:
      retryCount = 0
      rtmpStream!.publish(streamName)
    // sharedObject!.connect(rtmpConnection)

    case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
      guard retryCount <= PushStreamViewController.maxRetryCount else {
        return
      }
      Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
      rtmpConnection.connect(uri)
      retryCount += 1

    default:
      break
    }
  }

  @objc
  private func rtmpErrorHandler(_ notification: Notification) {
    let e = Event.from(notification)
    print("rtmpErrorHandler: \(e)")

    DispatchQueue.main.async {
      self.rtmpConnection.connect(self.uri)
    }
  }

  func tapScreen(_ gesture: UIGestureRecognizer) {
    if let gestureView = gesture.view, gesture.state == .ended {
      let touchPoint: CGPoint = gesture.location(in: gestureView)
      let pointOfInterest = CGPoint(x: touchPoint.x / gestureView.bounds.size.width, y: touchPoint.y / gestureView.bounds.size.height)
      print("pointOfInterest: \(pointOfInterest)")
      rtmpStream.setPointOfInterest(pointOfInterest, exposure: pointOfInterest)
    }
  }

  @IBAction private func resolutionValueChanged(_ segment: UISegmentedControl) {
    switch segment.selectedSegmentIndex {
    case 0:
      self.configResolution(resolution: hdResolution)
    case 1:
      self.configResolution(resolution: fhdResolution)
    default:
      break
    }
  }

  @IBAction private func onEffectValueChanged(_ segment: UISegmentedControl) {
    if let currentEffect: VideoEffect = currentEffect {
      _ = rtmpStream.unregisterVideoEffect(currentEffect)
    }
    switch segment.selectedSegmentIndex {
    case 1:
      currentEffect = CurrentTimeEffect()
      _ = rtmpStream.registerVideoEffect(currentEffect!)
    case 2:
      currentEffect = PsyEffect()
      _ = rtmpStream.registerVideoEffect(currentEffect!)
    default:
      break
    }
  }
}

extension PushStreamViewController: RPPreviewViewControllerDelegate {
  //  @objc func startRecording() {
  func startRecording() {
    recorder.startRecording { [unowned self] (error) in
      if let unwrappedError = error {
        print(unwrappedError.localizedDescription)
        let alert =  UIAlertController(title: nil, message: unwrappedError.localizedDescription, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(ok)
        self.present(alert, animated: true, completion: nil)
      } else {
        //self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Stop", style: .plain, target: self, action: #selector(self.stopRecording))
      }
    }
  }

  //  @objc func stopRecording() {
  func stopRecording() {
    recorder.stopRecording { [unowned self] (preview, _) in
      // self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Start", style: .plain, target: self, action: #selector(self.startRecording))
      if let unwrappedPreview = preview {
        unwrappedPreview.previewControllerDelegate = self
        self.present(unwrappedPreview, animated: true)
      }
    }
  }

  func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
    dismiss(animated: true)
  }
}

extension PushStreamViewController {
  func configResolution(resolution: CGSize) {
    let captureSize = resolution.width == 720 ? AVCaptureSession.Preset.hd1280x720 : AVCaptureSession.Preset.hd1920x1080

    print(#function, captureSize, resolution.width, resolution.height)

    rtmpStream.captureSettings = [
      .sessionPreset: captureSize,
      .continuousAutofocus: true,
      .continuousExposure: true,
      .preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode.auto
    ]

    rtmpStream.videoSettings = [
      .width: resolution.width,
      .height: resolution.height,
      .profileLevel: kVTProfileLevel_H264_High_AutoLevel
    ]

    if resolution.width == 720 {
      rtmpStream.videoSettings[.bitrate] = 128 * 1024
      rtmpStream.captureSettings[.fps] = 29.97
    } else {
      rtmpStream.videoSettings[.bitrate] = 1024 * 1024
      rtmpStream.captureSettings[.fps] = 60
    }

    rtmpStream.audioSettings[.bitrate] = 128 * 1024
  }
}
