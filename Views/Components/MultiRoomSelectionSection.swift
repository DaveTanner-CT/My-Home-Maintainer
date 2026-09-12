import SwiftUI

/// Compact multi-room selector used by records that can serve or belong to more
/// than one room. It intentionally mirrors the single-room Picker presentation
/// used elsewhere instead of rendering every room as a long inline list.
struct MultiRoomSelectionSection: View {
    let rooms: [Room]
    @Binding var primaryRoom: Room?
    @Binding var selectedRooms: [Room]
    var title: String = "Rooms / Areas"
    var helpText: String = "Select every room or area this record applies to. One room is kept as the primary location for compatibility, but all selected rooms remain linked."

    var body: some View {
        Section(title) {
            if rooms.isEmpty {
                Text("No rooms or areas have been added yet.")
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(rooms) { room in
                        Button {
                            toggle(room)
                        } label: {
                            if isSelected(room) {
                                Label(room.name, systemImage: "checkmark")
                            } else {
                                Text(room.name)
                            }
                        }
                    }

                    if !selectedRooms.isEmpty {
                        Divider()
                        Button("Clear Selection") {
                            selectedRooms.removeAll()
                            primaryRoom = nil
                        }
                    }
                } label: {
                    HStack {
                        Text("Room / Area")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(selectionSummary)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text(helpText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onAppear { normalizeSelection() }
    }

    private var selectionSummary: String {
        switch selectedRooms.count {
        case 0:
            return "Choose room / area"
        case 1:
            return selectedRooms[0].name
        case 2:
            return selectedRooms.map(\.name).joined(separator: ", ")
        default:
            return "\(selectedRooms.count) selected"
        }
    }

    private func isSelected(_ room: Room) -> Bool {
        selectedRooms.contains { $0.persistentModelID == room.persistentModelID }
    }

    private func toggle(_ room: Room) {
        if isSelected(room) {
            selectedRooms.removeAll { $0.persistentModelID == room.persistentModelID }
            if primaryRoom?.persistentModelID == room.persistentModelID {
                primaryRoom = selectedRooms.first
            }
        } else {
            selectedRooms.append(room)
            if primaryRoom == nil { primaryRoom = room }
        }
        normalizeSelection()
    }

    private func normalizeSelection() {
        var unique: [Room] = []
        for room in selectedRooms where !unique.contains(where: { $0.persistentModelID == room.persistentModelID }) {
            unique.append(room)
        }
        selectedRooms = unique

        if let primaryRoom {
            if !selectedRooms.contains(where: { $0.persistentModelID == primaryRoom.persistentModelID }) {
                selectedRooms.insert(primaryRoom, at: 0)
            }
        } else if let first = selectedRooms.first {
            primaryRoom = first
        }
    }
}
