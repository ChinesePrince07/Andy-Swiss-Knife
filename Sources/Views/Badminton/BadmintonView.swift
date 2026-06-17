// Sources/Views/Badminton/BadmintonView.swift
import SwiftUI

struct BadmintonView: View {
    let engine: BadmintonEngine

    init(services: Services) { self.engine = services.badminton }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isRunning {
                CameraPreview(session: engine.camera.session).ignoresSafeArea()
                OverlayRenderer(
                    trail: engine.trail, latest: engine.latestPoint,
                    imageSize: engine.frameSize, accent: AppColors.accent
                ).ignoresSafeArea()
            }

            VStack {
                HStack {
                    Text(String(format: "%.0f FPS", engine.fps))
                    Spacer()
                    Text("SHOTS \(engine.shotCount)")
                }
                .font(AppType.mono)
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.black.opacity(0.55))
                Spacer()
                if engine.cameraDenied {
                    Text("CAMERA ACCESS DENIED — enable it in Settings")
                        .font(AppType.mono).foregroundStyle(.white)
                        .padding(10).background(Color.black.opacity(0.7))
                }
            }
            .padding()
        }
        .navigationTitle("Badminton")
        .navigationBarTitleDisplayMode(.inline)
        .task { await engine.start() }
        .onDisappear { engine.stop() }
    }
}
