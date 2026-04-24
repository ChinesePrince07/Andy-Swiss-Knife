import SwiftUI
import SwiftData
import UIKit

/// Things3-style reorderable list. Long-press a row to lift; drag to reorder.
/// Siblings spring-animate into place as the dragged row passes over them.
///
/// Reorder is kept local (in-memory) while the finger is down. Only on drop
/// does the new order get written to SwiftData. This prevents the @Query
/// refresh storm that otherwise re-enters the view mid-drag and causes jitter.
struct ReorderableTodoList: View {
    let items: [Todo]
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @State private var draggingID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var liveFrames: [UUID: CGRect] = [:]
    @State private var dragFrames: [UUID: CGRect] = [:]
    @State private var lastSwappedID: UUID?
    @State private var workingOrder: [Todo] = []

    private let coordSpace = "todoReorder"

    private var displayItems: [Todo] {
        draggingID == nil ? items : workingOrder
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(displayItems) { todo in
                rowCell(todo)
            }
        }
        .frame(maxWidth: .infinity)
        .coordinateSpace(name: coordSpace)
        .onPreferenceChange(TodoRowFramesKey.self) { liveFrames = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: displayItems.map(\.id))
    }

    @ViewBuilder
    private func rowCell(_ todo: Todo) -> some View {
        let isDragging = draggingID == todo.id
        VStack(spacing: 0) {
            TodoRow(todo: todo, services: services)
                .frame(maxWidth: .infinity, alignment: .leading)
            HairlineDivider()
        }
        .frame(maxWidth: .infinity)
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
        .transaction { t in
            // Dragged row follows the finger instantly; never let the parent
            // animation lerp its offset or slot position.
            if isDragging { t.animation = nil }
        }
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
                        workingOrder = items
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
                commitWorkingOrder()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    draggingID = nil
                    dragOffset = .zero
                }
                lastSwappedID = nil
                dragFrames = [:]
                workingOrder = []
            }
    }

    private func handleSwap(dragged: Todo, location: CGPoint) {
        guard let hit = dragFrames.first(where: { entry in
            entry.key != dragged.id && entry.value.contains(location)
        }) else { return }
        if hit.key == lastSwappedID { return }

        guard let fromIdx = workingOrder.firstIndex(where: { $0.id == dragged.id }),
              let toIdx = workingOrder.firstIndex(where: { $0.id == hit.key }),
              let oldDraggedFrame = dragFrames[dragged.id]
        else { return }
        let oldTargetFrame = hit.value

        // Swap frame entries in the snapshot — keeps hit-test and the offset
        // rebase consistent with the new logical layout.
        dragFrames[dragged.id] = oldTargetFrame
        dragFrames[hit.key] = oldDraggedFrame

        workingOrder.remove(at: fromIdx)
        workingOrder.insert(dragged, at: toIdx)

        // Shift offset so the card stays visually glued to the finger once
        // the slot moves.
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

    private func commitWorkingOrder() {
        guard !workingOrder.isEmpty else { return }
        let total = workingOrder.count
        for (i, t) in workingOrder.enumerated() {
            t.sortOrder = Double(total - i)
        }
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
    }
}

struct TodoRowFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
