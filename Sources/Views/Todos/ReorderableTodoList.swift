import SwiftUI
import SwiftData
import UIKit

/// Things3-style reorderable list. Long-press a row to lift; drag to reorder.
/// Siblings spring-animate into place as the dragged row passes over them.
struct ReorderableTodoList: View {
    let items: [Todo]
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @State private var draggingID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var frames: [UUID: CGRect] = [:]

    private let coordSpace = "todoReorder"

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { todo in
                rowCell(todo)
            }
        }
        .coordinateSpace(name: coordSpace)
        .onPreferenceChange(TodoRowFramesKey.self) { frames = $0 }
    }

    @ViewBuilder
    private func rowCell(_ todo: Todo) -> some View {
        let isDragging = draggingID == todo.id
        VStack(spacing: 0) {
            TodoRow(todo: todo, services: services)
            HairlineDivider()
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: TodoRowFramesKey.self,
                    value: [todo.id: geo.frame(in: .named(coordSpace))]
                )
            }
        )
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .shadow(
            color: isDragging ? AppColors.primary.opacity(0.35) : .clear,
            radius: isDragging ? 16 : 0,
            x: 0,
            y: isDragging ? 10 : 0
        )
        .offset(x: isDragging ? dragOffset.width : 0,
                y: isDragging ? dragOffset.height : 0)
        .zIndex(isDragging ? 10 : 0)
        .opacity(draggingID != nil && !isDragging ? 0.92 : 1.0)
        .animation(isDragging ? nil : .spring(response: 0.32, dampingFraction: 0.76), value: draggingID)
        .gesture(
            LongPressGesture(minimumDuration: 0.30)
                .sequenced(before: DragGesture(coordinateSpace: .named(coordSpace)))
                .onChanged { value in
                    switch value {
                    case .second(true, let drag):
                        if draggingID == nil {
                            draggingID = todo.id
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        if let drag {
                            dragOffset = drag.translation
                            handleSwap(dragged: todo, location: drag.location)
                        }
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        draggingID = nil
                        dragOffset = .zero
                    }
                }
        )
    }

    private func handleSwap(dragged: Todo, location: CGPoint) {
        guard let targetEntry = frames.first(where: { entry in
            entry.key != dragged.id && entry.value.contains(location)
        }) else { return }
        let targetID = targetEntry.key
        guard let fromIdx = items.firstIndex(where: { $0.id == dragged.id }),
              let toIdx = items.firstIndex(where: { $0.id == targetID })
        else { return }
        var arr = items
        arr.remove(at: fromIdx)
        arr.insert(dragged, at: toIdx)
        let total = arr.count
        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
            for (i, t) in arr.enumerated() {
                t.sortOrder = Double(total - i)
            }
        }
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
        // Keep the finger visually on the dragged row after layout shifts.
        if let oldFrame = targetEntry.value as CGRect?,
           let newFrame = frames[dragged.id] {
            let delta = CGSize(
                width: oldFrame.midX - newFrame.midX,
                height: oldFrame.midY - newFrame.midY
            )
            dragOffset = CGSize(
                width: dragOffset.width + delta.width,
                height: dragOffset.height + delta.height
            )
        }
    }
}

struct TodoRowFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
