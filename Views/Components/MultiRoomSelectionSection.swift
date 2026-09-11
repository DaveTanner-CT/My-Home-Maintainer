import SwiftUI

/// Reusable room/area multi-selection used by records that can serve or belong to
/// more than one room. The first selected room is retained as the record's primary
/// room for backward compatibility; the full set is stored through additionalRooms.
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
                ForEach(rooms) { room in
                    Button {
                        toggle(room)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(room.name)
                                    .foregroundStyle(.primary)
                                Text(room.areaType.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: isSelected(room) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected(room) ? .tint : .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(helpText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onAppear { normalizeSelection() }
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
