import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import QuickLook

struct AttachmentSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HomeAttachment.createdAt, order: .reverse) private var allAttachments: [HomeAttachment]

    let owner: AttachmentOwnerReference
    var showsPhotos: Bool = true
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var importError: String?

    private var attachments: [HomeAttachment] {
        allAttachments.filter { attachment in
            owner.matches(attachment) && (showsPhotos || !attachment.isImage)
        }
    }

    var body: some View {
        Section(showsPhotos ? "Photos & Documents" : "Documents") {
            if attachments.isEmpty {
                Text(showsPhotos ? "No photos or documents yet" : "No documents yet")
                    .foregroundStyle(.secondary)
            }

            ForEach(attachments) { attachment in
                NavigationLink {
                    AttachmentDetailView(attachment: attachment)
                } label: {
                    AttachmentRow(attachment: attachment)
                }
            }

            if showsPhotos {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Add Photo", systemImage: "photo")
                }
            }
            Button {
                showFileImporter = true
            } label: {
                Label("Add Document", systemImage: "doc")
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        let attachment = HomeAttachment(
                            name: "Photo",
                            category: "Photo",
                            fileName: "photo-\(Int(Date().timeIntervalSince1970)).jpg",
                            typeIdentifier: "image/jpeg",
                            fileData: data
                        )
                        owner.assign(to: attachment)
                        modelContext.insert(attachment)
                        try? modelContext.save()
                    }
                }
                await MainActor.run { selectedPhoto = nil }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let values = try? url.resourceValues(forKeys: [.contentTypeKey])
                let typeIdentifier = values?.contentType?.identifier ?? "application/octet-stream"
                let attachment = HomeAttachment(
                    name: url.deletingPathExtension().lastPathComponent,
                    category: "Document",
                    fileName: url.lastPathComponent,
                    typeIdentifier: typeIdentifier,
                    fileData: data
                )
                owner.assign(to: attachment)
                modelContext.insert(attachment)
                try modelContext.save()
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert("Could Not Add File", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Unknown error")
        }
    }
}


struct RoomPhotoGridSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \HomeAttachment.createdAt, order: .reverse) private var allAttachments: [HomeAttachment]

    let room: Room
    @State private var selectedPhoto: PhotosPickerItem?

    private var photos: [HomeAttachment] {
        allAttachments.filter { attachment in
            attachment.room?.persistentModelID == room.persistentModelID && attachment.isImage
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: horizontalSizeClass == .regular ? 3 : 2)
    }

    var body: some View {
        Section("Room Photos") {
            if photos.isEmpty {
                Text("No room photos yet")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(photos) { attachment in
                        NavigationLink {
                            AttachmentDetailView(attachment: attachment)
                        } label: {
                            if let image = UIImage(data: attachment.fileData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(4.0 / 3.0, contentMode: .fill)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.quaternary, lineWidth: 1)
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.quaternary)
                                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                                    .overlay { Image(systemName: "photo") }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(attachment.caption.isEmpty ? "Open room photo" : attachment.caption)
                    }
                }
                .padding(.vertical, 4)
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Add Room Photo", systemImage: "photo.badge.plus")
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        let attachment = HomeAttachment(
                            name: "Room Photo",
                            category: "Photo",
                            fileName: "room-photo-\(Int(Date().timeIntervalSince1970)).jpg",
                            typeIdentifier: "image/jpeg",
                            fileData: data
                        )
                        attachment.room = room
                        modelContext.insert(attachment)
                        try? modelContext.save()
                    }
                }
                await MainActor.run { selectedPhoto = nil }
            }
        }
    }
}

struct AttachmentRow: View {
    let attachment: HomeAttachment

    var body: some View {
        HStack(spacing: 12) {
            if attachment.isImage,
               let image = UIImage(data: attachment.fileData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: attachmentIcon)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.name)
                    .font(.headline)
                    .lineLimit(1)
                if !attachment.caption.isEmpty {
                    Text(attachment.caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("\(attachment.category) · \(attachment.fileName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var attachmentIcon: String {
        let ext = (attachment.fileName as NSString).pathExtension.lowercased()
        if ext == "pdf" { return "doc.richtext" }
        return "doc"
    }
}

struct AttachmentDetailView: View {
    let attachment: HomeAttachment

    var body: some View {
        List {
            Section {
                if attachment.isImage,
                   let image = UIImage(data: attachment.fileData) {
                    ExpandablePhoto(image: image, cornerRadius: 12)
                } else {
                    NavigationLink {
                        QuickLookAttachmentPreview(attachment: attachment)
                            .ignoresSafeArea()
                    } label: {
                        Label("Open Document", systemImage: "doc.text.magnifyingglass")
                    }
                }
            }

            Section("Details") {
                LabeledContent("Category", value: attachment.category)
                LabeledContent("File", value: attachment.fileName)
                LabeledContent("Added", value: attachment.createdAt.formatted(date: .abbreviated, time: .shortened))
                if !attachment.caption.isEmpty { Text(attachment.caption) }
            }
        }
        .navigationTitle(attachment.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") {
                    AttachmentEditView(attachment: attachment)
                }
            }
        }
    }
}

struct AttachmentEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let attachment: HomeAttachment
    @State private var name: String
    @State private var caption: String
    @State private var category: String
    @State private var showDelete = false

    init(attachment: HomeAttachment) {
        self.attachment = attachment
        _name = State(initialValue: attachment.name)
        _caption = State(initialValue: attachment.caption)
        _category = State(initialValue: attachment.category)
    }

    var body: some View {
        Form {
            Section("Attachment") {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(["Photo", "Manual", "Warranty", "Receipt", "Invoice", "Estimate", "Proposal", "Document", "Other"], id: \.self) { Text($0).tag($0) }
                }
                TextField("Caption / notes", text: $caption, axis: .vertical)
                LabeledContent("Original file", value: attachment.fileName)
            }
            Section {
                Button("Delete Attachment", role: .destructive) { showDelete = true }
            }
        }
        .navigationTitle("Edit Attachment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    attachment.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? attachment.fileName : name
                    attachment.caption = caption
                    attachment.category = category
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .confirmationDialog("Delete this attachment?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete Attachment", role: .destructive) {
                modelContext.delete(attachment)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

struct QuickLookAttachmentPreview: UIViewControllerRepresentable {
    let attachment: HomeAttachment

    func makeCoordinator() -> Coordinator {
        Coordinator(attachment: attachment)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) { }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let item: PreviewItem

        init(attachment: HomeAttachment) {
            let safeName = attachment.fileName.isEmpty ? "attachment" : attachment.fileName
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + safeName)
            try? attachment.fileData.write(to: url, options: .atomic)
            self.item = PreviewItem(url: url, title: attachment.name)
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { item }
    }
}

final class PreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(url: URL, title: String) {
        self.previewItemURL = url
        self.previewItemTitle = title
    }
}
