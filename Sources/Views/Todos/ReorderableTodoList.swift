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
    @State private var liveFrames: [UUID: CGRect] = [:]
    @State private var dragFrames: [UUID: CGRect] = [:]
    @State private var lastSwappedID: UUID?

    private let coordSpace = "todoReorder"

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { todo in
                rowCell(todo)
            }
        }
        .coordinateSpace(name: coordSpace)
        .onPreferenceChange(TodoRowFramesKey.self) { liveFrames = $0 }
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
        .gesture(dragGesture(for: todo))
    }

    private func dragGesture(for todo: Todo) -> some Gesture {
        LongPressGesture(minimumDuration: 0.30)
            .sequenced(before: DragGesture(coordinateSpace: .named(coordSpace)))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    if draggingID == nil {
                        draggingID = todo.id
                        // Freeze the frame snapshot at lift time so the hit-
                        // test doesn't chase a moving target during reorder.
                        dragFrames = liveFrames
                        lastSwappedID = nil
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
                lastSwappedID = nil
                dragFrames = [:]
            }
    }

    private func handleSwap(dragged: Todo, location: CGPoint) {
        guard let hit = dragFrames.first(where: { entry in
            entry.key != dragged.id && entry.value.contains(location)
        }) else { return }
        // Debounce: don't re-swap with the same neighbour until finger has
        // moved to a different row. Prevents oscillation on boundaries.
        if hit.key == lastSwappedID { return }

        guard let fromIdx = items.firstIndex(where: { $0.id == dragged.id }),
              let toIdx = items.firstIndex(where: { $0.id == hit.key }),
              let oldDraggedFrame = dragFrames[dragged.id]
        else { return }
        let oldTargetFrame = hit.value

        // Swap entries in the snapshot so subsequent hit tests and offset
        // rebases use the new logical layout.
        dragFrames[dragged.id] = oldTargetFrame
        dragFrames[hit.key] = oldDraggedFrame

        var arr = items
        arr.remove(at: fromIdx)
        arr.insert(dragged, at: toIdx)
        let total = arr.count
        for (i, t) in arr.enumerated() {
            t.sortOrder = Double(total - i)
        }
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()

        // Rebase offset so the card stays under the finger after layout shift.
        let delta = CGSize(
            width: oldDraggedFrame.midX - oldTargetFrame.midX,
            height: oldDraggedFrame.midY - oldTargetFrame.midY
        )
        dragOffset = CGSize(
            width: dragOffset.width + delta.width,
            height: dragOffset.height + delta.height
        )

        lastSwappedID = hit.key
    }
}

struct TodoRowFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
