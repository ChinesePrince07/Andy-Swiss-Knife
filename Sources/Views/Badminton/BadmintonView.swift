import SwiftUI

struct BadmintonView: View {
    let engine: BadmintonEngine
    @State private var calibrating = false
    @State private var settingCourt = false
    @Environment(\.scenePhase) private var scenePhase

    // Compact HUD fonts (the on-camera overlay text should stay out of the way).
    private let hudFont = Font.system(size: 10, weight: .semibold, design: .monospaced)
    private let tinyFont = Font.system(size: 8, weight: .regular, design: .monospaced)

    init(services: Services) { self.engine = services.badminton }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isRunning {
                CameraPreview(session: engine.camera.session).ignoresSafeArea()
                OverlayRenderer(
                    trail: engine.trail, latest: engine.latestPoint, players: engine.players,
                    imageSize: engine.frameSize, accent: AppColors.accent, roi: engine.settings.courtROI
                ).ignoresSafeArea()
                ShotFlash(marker: engine.lastShot, imageSize: engine.frameSize).ignoresSafeArea()
            }

            VStack {
                HStack {
                    Text(String(format: "%.0f FPS", engine.fps))
                    Spacer()
                    Text("SHOTS \(engine.shotCount)")
                }
                .font(hudFont).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.black.opacity(0.55))

                Scoreboard(
                    p1: engine.scoreP1, p2: engine.scoreP2,
                    onAdjust: { engine.adjustScore($0, by: $1) },
                    onReset: { engine.resetScore() }
                )
                .padding(.top, 4)

                Spacer()

                if engine.settings.scale == nil {
                    Text("CALIBRATE TO SHOW SPEED")
                        .font(hudFont).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 5).background(Color.black.opacity(0.6))
                } else {
                    VStack(spacing: 3) {
                        SpeedReadout(last: engine.lastSpeed, max: engine.maxSpeed, settings: engine.settings)
                        Text("≈ ESTIMATE — measured at the hit, side-on")
                            .font(tinyFont).foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.black.opacity(0.5))
                    }
                }

                HStack {
                    Button("CALIBRATE") { calibrating = true }
                        .disabled(engine.frameSize == .zero)
                    Spacer()
                    Button(engine.settings.courtROI == nil ? "SET COURT" : "COURT ✓") { settingCourt = true }
                        .disabled(engine.frameSize == .zero)
                    Spacer()
                    Button(engine.settings.unit.label.uppercased()) { toggleUnit() }
                }
                .font(hudFont).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 7).background(Color.black.opacity(0.55))
            }
            .padding()

            if engine.cameraDenied {
                Text("CAMERA ACCESS DENIED — enable it in Settings")
                    .font(hudFont).foregroundStyle(.white)
                    .padding(8).background(Color.black.opacity(0.7))
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
        .fullScreenCover(isPresented: $settingCourt) {
            CourtRegionView(
                session: engine.camera.session,
                imageSize: engine.frameSize,
                onDone: { roi in engine.setCourtROI(roi); settingCourt = false },
                onCancel: { settingCourt = false }
            )
        }
    }

    private func toggleUnit() {
        engine.settings.unit = engine.settings.unit == .kmh ? .mph : .kmh
    }
}
