import SwiftUI

struct BadmintonView: View {
    let engine: BadmintonEngine
    @State private var calibrating = false
    @Environment(\.scenePhase) private var scenePhase

    init(services: Services) { self.engine = services.badminton }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isRunning {
                CameraPreview(session: engine.camera.session).ignoresSafeArea()
                OverlayRenderer(
                    trail: engine.trail, latest: engine.latestPoint, poses: engine.poses,
                    imageSize: engine.frameSize, accent: AppColors.accent
                ).ignoresSafeArea()
            }

            VStack {
                HStack {
                    Text(String(format: "%.0f FPS", engine.fps))
                    Spacer()
                    Text("SHOTS \(engine.shotCount)")
                }
                .font(AppType.mono).foregroundStyle(.white)
                .padding(8).background(Color.black.opacity(0.55))

                Spacer()

                if engine.settings.scale == nil {
                    Text("CALIBRATE TO SHOW SPEED")
                        .font(AppType.mono).foregroundStyle(.white)
                        .padding(8).background(Color.black.opacity(0.6))
                } else {
                    VStack(spacing: 4) {
                        SpeedReadout(last: engine.lastSpeed, max: engine.maxSpeed, settings: engine.settings)
                        Text("≈ ESTIMATE — measured at the hit, side-on")
                            .font(AppType.tiny).foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                    }
                }

                HStack {
                    Button("CALIBRATE") { calibrating = true }
                        .disabled(engine.frameSize == .zero)
                    Spacer()
                    Button(engine.usingTrackNet ? "TRACKNET" : "CLASSIC") { engine.toggleDetector() }
                    Spacer()
                    Button(engine.settings.unit.label.uppercased()) { toggleUnit() }
                }
                .font(AppType.mono).foregroundStyle(.white)
                .padding().background(Color.black.opacity(0.55))
            }
            .padding()

            if engine.cameraDenied {
                Text("CAMERA ACCESS DENIED — enable it in Settings")
                    .font(AppType.mono).foregroundStyle(.white)
                    .padding(10).background(Color.black.opacity(0.7))
            }
        }
        .navigationTitle("Badminton")
        .navigationBarTitleDisplayMode(.inline)
        .task { await engine.start() }
        .onDisappear { engine.stop() }
        .onChange(of: scenePhase) { _, phase in
            // Don't keep the camera running when the app isn't foreground-active.
            switch phase {
            case .active: Task { await engine.start() }
            case .inactive, .background: engine.stop()
            @unknown default: break
            }
        }
        .fullScreenCover(isPresented: $calibrating) {
            CalibrationView(
                session: engine.camera.session,
                imageSize: engine.frameSize,
                realMeters: 1.55,
                onDone: { scale in
                    engine.settings.scale = scale
                    engine.resetSpeeds()   // prior speeds were under the old scale
                    calibrating = false
                },
                onCancel: { calibrating = false }
            )
        }
    }

    private func toggleUnit() {
        engine.settings.unit = engine.settings.unit == .kmh ? .mph : .kmh
    }
}
